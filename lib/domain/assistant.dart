import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/llm.dart';
import 'package:dastyar/domain/guard/citation_guard.dart';
import 'package:dastyar/domain/prompt_builder.dart';
import 'package:dastyar/domain/search/retrieval_pipeline.dart';

class AssistantTurn {
  final String text;
  final List<String> alternatives;
  final List<String> conflictChains;

  const AssistantTurn({
    required this.text,
    this.alternatives = const [],
    this.conflictChains = const [],
  });
}

/// هماهنگ‌کنندهٔ پاسخ‌دهی (retrieval + streaming + citation guard).
///
/// پس از Phase 4، این کلاس دیگر منطق داخلی citation یا retrieval
/// ندارد؛ فقط orchestrator است. همهٔ منطق citation به
/// `CitationGuard` و همهٔ منطق بازیابی به `RetrievalPipeline` منتقل
/// شده‌اند. این تفکیک، هم تست‌پذیری را بالا می‌برد و هم اجازه می‌دهد
/// planner در Phase 2 از همان گارد برای پاسخ‌های تولیدی خودش استفاده
/// کند.
class Assistant {
  final KnowledgeEngine engine;
  final LlmBackend llm;
  final PromptBuilder prompts;
  final LlmOptions options;
  final Duration stallTimeout;
  final int maxChars;

  late final RetrievalPipeline _pipeline;
  late final CitationGuard _guard;

  Assistant(
    this.engine, {
    LlmBackend? llm,
    PromptBuilder? prompts,
    LlmOptions? options,
    RetrievalPipeline? pipeline,
    CitationGuard? guard,
    this.stallTimeout = const Duration(seconds: 60),
    this.maxChars = 4000,
  }) : llm = llm ?? NoLlm(),
       prompts = prompts ?? const PromptBuilder(),
       options = options ?? const LlmOptions() {
    _pipeline = pipeline ?? RetrievalPipeline(engine);
    _guard = guard ?? CitationGuard(catalog: engine.catalog);
  }

  /// Forwarding static برای سازگاری با کد و تست‌های موجود.
  static Set<String> citedArticles(String text) =>
      CitationGuard.citedArticles(text);

  /// Forwarding static برای سازگاری با کد و تست‌های موجود.
  static bool isGrounded(String answer, List<Hit> ctx) =>
      CitationGuard.isGrounded(answer, ctx);

  /// بررسی جامع استناد (مواد + نام قانون).
  bool isAnswerGrounded(String answer, List<Hit> ctx) =>
      _guard.isAnswerGrounded(answer, ctx);

  Stream<AssistantTurn> askWithAlternatives(
    String question, {
    int maxAlternatives = 3,
  }) async* {
    final base = _pipeline.retrieve(question, maxAlternatives: maxAlternatives);

    var ready = false;
    try {
      ready = await llm.isReady();
    } catch (_) {}
    if (!ready) {
      yield AssistantTurn(
        text: base.text,
        alternatives: base.alternatives,
        conflictChains: base.conflictChains,
      );
      return;
    }

    final ctx = base.contextHits;
    if (ctx.isEmpty) {
      yield AssistantTurn(
        text: base.text,
        alternatives: base.alternatives,
        conflictChains: base.conflictChains,
      );
      return;
    }

    final allowed = CitationGuard.allowedArticles(ctx);
    final prompt = prompts.build(question, ctx);
    var acc = '';
    var good = true;
    var finished = false;
    var stalled = false;
    try {
      final stream = llm
          .generate(prompt, options: options)
          .timeout(
            stallTimeout,
            onTimeout: (sink) {
              stalled = true;
              sink.close();
            },
          );
      await for (final t in stream) {
        acc += t;
        if (CitationGuard.checkStreaming(acc, allowed)) {
          good = false;
          break;
        }
        if (acc.length > maxChars) {
          good = false;
          break;
        }
        yield AssistantTurn(
          text: acc,
          alternatives: base.alternatives,
          conflictChains: base.conflictChains,
        );
      }
      finished = true;
    } catch (_) {
      good = false;
    } finally {
      if (!finished || !good || stalled) {
        try {
          llm.cancel();
        } catch (_) {}
      }
    }

    if (!good || stalled || acc.trim().isEmpty) {
      yield AssistantTurn(
        text: base.text,
        alternatives: base.alternatives,
        conflictChains: base.conflictChains,
      );
      return;
    }

    if (!isAnswerGrounded(acc, ctx)) {
      yield AssistantTurn(
        text: base.text,
        alternatives: base.alternatives,
        conflictChains: base.conflictChains,
      );
      return;
    }

    final seen = <String>{};
    final srcs = <String>[];
    for (final h in ctx) {
      final c = h.chunk;
      final label = c.source.isEmpty ? c.title : '${c.source} — ${c.title}';
      if (seen.add(label)) srcs.add(label);
    }
    yield AssistantTurn(
      text: '$acc\n\nمنبع: ${srcs.join('، ')}',
      alternatives: base.alternatives,
      conflictChains: base.conflictChains,
    );
  }

  Stream<String> ask(String question) {
    return askWithAlternatives(question, maxAlternatives: 0).map((t) => t.text);
  }

  String buildPrompt(String question, List<Hit> ctx) =>
      prompts.build(question, ctx);
}
