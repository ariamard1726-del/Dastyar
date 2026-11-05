import 'package:dastyar/core/debug_logger.dart';
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

  /// لاگر دیباگ. پیش‌فرض، لاگر سراسری است که به‌طور پیش‌فرض **خاموش** است؛
  /// پس در تولید هیچ ردی ساخته نمی‌شود و با `DebugLogger.instance.enabled = true`
  /// می‌توان پرامپت و خروجی مدل را دید.
  final DebugLogger debug;

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
    DebugLogger? debug,
  })  : llm = llm ?? NoLlm(),
        prompts = prompts ?? const PromptBuilder(),
        options = options ?? const LlmOptions(),
        debug = debug ?? DebugLogger.instance {
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
    final trace = debug.start(question);
    try {
      yield* _askTraced(
        question,
        maxAlternatives: maxAlternatives,
        debugger: debug,
        trace: trace,
      );
    } finally {
      // بستن نوبت حتی وقتی مصرف‌کننده پیش از پایان، استریم را رها کند.
      debug.finish(trace);
    }
  }

  /// پیادهٔ واقعیِ [askWithAlternatives] با ثبت اختیاریِ ردِ دیباگ.
  Stream<AssistantTurn> _askTraced(
    String question, {
    required int maxAlternatives,
    DebugLogger? debugger,
    TurnTrace? trace,
  }) async* {
    void record(TurnStage stage, String label, [Object? data]) {
      if (debugger != null && trace != null) {
        debugger.record(trace, stage, label, data);
      }
    }

    final base = _pipeline.retrieve(question, maxAlternatives: maxAlternatives);
    record(TurnStage.retrieval, 'شواهد بازیابی‌شده', <String, Object?>{
      'question': question,
      'count': base.contextHits.length,
      'hits': base.contextHits
          .map((h) => <String, Object?>{
                'law': h.chunk.lawId,
                'article': h.chunk.title,
                'source': h.chunk.source,
                'score': h.score,
              })
          .toList(),
      'answer_without_llm': base.text,
    });

    var ready = false;
    try {
      ready = await llm.isReady();
    } catch (_) {}
    if (!ready) {
      record(TurnStage.llm, 'مدل زبانی آماده نیست', <String, Object?>{
        'backend': llm.name,
        'fallback': 'answer_without_llm',
      });
      record(TurnStage.response, 'پاسخ نهایی (بدون مدل)', <String, Object?>{
        'text': base.text,
      });
      yield AssistantTurn(
        text: base.text,
        alternatives: base.alternatives,
        conflictChains: base.conflictChains,
      );
      return;
    }

    final ctx = base.contextHits;
    if (ctx.isEmpty) {
      record(TurnStage.llm, 'زمینه‌ای برای مدل نیست', <String, Object?>{
        'count': 0,
        'fallback': 'answer_without_llm',
      });
      record(TurnStage.response, 'پاسخ نهایی (بدون زمینه)', <String, Object?>{
        'text': base.text,
      });
      yield AssistantTurn(
        text: base.text,
        alternatives: base.alternatives,
        conflictChains: base.conflictChains,
      );
      return;
    }

    final allowed = CitationGuard.allowedArticles(ctx);
    final prompt = prompts.build(question, ctx);
    record(TurnStage.prompt, 'پرامپت نهایی', <String, Object?>{
      'backend': llm.name,
      'chars': prompt.length,
      'allowed_articles': allowed.toList(),
      'text': prompt,
    });
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

    record(TurnStage.llm, 'خروجی مدل', <String, Object?>{
      'text': acc,
      'chars': acc.length,
      'stalled': stalled,
      'accepted_prefix': good,
    });

    if (!good || stalled || acc.trim().isEmpty) {
      record(TurnStage.guard, 'رد خروجی مدل', <String, Object?>{
        'reason': stalled ? 'stall' : (good ? 'empty' : 'invalid_citation'),
        'fallback': 'answer_without_llm',
      });
      record(TurnStage.response, 'پاسخ نهایی (بازگشت به موتور)', <String, Object?>{
        'text': base.text,
      });
      yield AssistantTurn(
        text: base.text,
        alternatives: base.alternatives,
        conflictChains: base.conflictChains,
      );
      return;
    }

    final grounded = isAnswerGrounded(acc, ctx);
    record(TurnStage.guard, 'گارد استناد', <String, Object?>{
      'grounded': grounded,
      'cited': CitationGuard.citedArticles(acc).toList(),
      'allowed': allowed.toList(),
    });

    if (!grounded) {
      record(TurnStage.response, 'پاسخ نهایی (استناد نامعتبر)', <String, Object?>{
        'text': base.text,
      });
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
    final answer = '$acc\n\nمنبع: ${srcs.join('، ')}';
    record(TurnStage.response, 'پاسخ نهایی (مدل + منبع)', <String, Object?>{
      'text': answer,
      'sources': srcs,
    });
    yield AssistantTurn(
      text: answer,
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
