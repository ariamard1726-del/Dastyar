import 'engine.dart';
import 'llm.dart';
import 'prompt_builder.dart';

class Assistant {
  final KnowledgeEngine engine;
  final LlmBackend llm;
  final PromptBuilder prompts;
  final LlmOptions options;

  /// اگر مدل این‌قدر هیچ تکه‌ای نفرستد، تولید متوقف و پاسخ موتور نشان داده می‌شود.
  final Duration stallTimeout;

  /// پاسخ بلندتر از این مشکوک است و کنار گذاشته می‌شود.
  final int maxChars;

  Assistant(
    this.engine, {
    LlmBackend? llm,
    PromptBuilder? prompts,
    LlmOptions? options,
    this.stallTimeout = const Duration(seconds: 60),
    this.maxChars = 4000,
  })  : llm = llm ?? NoLlm(),
        prompts = prompts ?? const PromptBuilder(),
        options = options ?? const LlmOptions();

  static final RegExp _artRef = RegExp(r'ماده\s*(\d+)');

  // فقط شماره‌هایی که تمام شده‌اند (بعدشان نویسهٔ غیرعددی آمده)؛ «ماده ۱» در
  // میانهٔ نوشتن «ماده ۱۰» خطا حساب نمی‌شود.
  static final RegExp _artDone = RegExp(r'ماده\s*(\d+)(?=\D)');

  /// شماره‌های مادهٔ ذکرشده در یک متن (با ارقام لاتین).
  static Set<String> citedArticles(String text) {
    final n = KnowledgeEngine.normalize(text);
    return _artRef.allMatches(n).map((m) => m.group(1)!).toSet();
  }

  static Set<String> _completedCitations(String text) {
    final n = KnowledgeEngine.normalize(text);
    return _artDone.allMatches(n).map((m) => m.group(1)!).toSet();
  }

  static Set<String> _allowedArticles(List<Hit> ctx) {
    final allowed = <String>{};
    for (final h in ctx) {
      allowed.addAll(citedArticles(h.chunk.title));
      allowed.addAll(citedArticles(h.chunk.body));
    }
    return allowed;
  }

  /// اگر پاسخ مدل شمارهٔ مادهٔ ‌ای را بیاورد که در متن‌های بازیابی‌شده
  /// نیست، پاسخ اعتبار ندارد.
  static bool isGrounded(String answer, List<Hit> ctx) {
    final cited = citedArticles(answer);
    if (cited.isEmpty) return true;
    final allowed = _allowedArticles(ctx);
    return cited.every(allowed.contains);
  }

  /// هر بار متن کامل‌شدهٔ فعلی پاسخ را برمی‌گرداند.
  Stream<String> ask(String question) async* {
    final fallback = engine.answer(question);

    var ready = false;
    try {
      ready = await llm.isReady();
    } catch (_) {}
    if (!ready) {
      yield fallback;
      return;
    }

    final r = engine.rank(question, k: 4);
    final ctx = r.hits.where((h) => h.score >= 0.3).toList();
    if (ctx.isEmpty) {
      yield fallback;
      return;
    }

    final allowed = _allowedArticles(ctx);
    final prompt = prompts.build(question, ctx);
    var acc = '';
    var good = true;
    var finished = false;
    var stalled = false;
    try {
      final stream = llm.generate(prompt, options: options).timeout(
        stallTimeout,
        onTimeout: (sink) {
          stalled = true;
          sink.close();
        },
      );
      await for (final t in stream) {
        acc += t;
        // مادهٔ ساختگی همان لحظه جلوی مدل را می‌گیرد، نه بعد از تمام شدن.
        if (!_completedCitations(acc).every(allowed.contains)) {
          good = false;
          break;
        }
        if (acc.length > maxChars) {
          good = false;
          break;
        }
        yield acc;
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
      yield fallback;
      return;
    }

    // بازبینی نهایی: مادهٔ ساختگی یعنی بازگشت به پاسخ مطمئن موتور.
    if (!isGrounded(acc, ctx)) {
      yield fallback;
      return;
    }

    final seen = <String>{};
    final srcs = <String>[];
    for (final h in ctx) {
      final c = h.chunk;
      final label = c.source.isEmpty ? c.title : '${c.source} — ${c.title}';
      if (seen.add(label)) srcs.add(label);
    }
    yield '$acc\n\nمنبع: ${srcs.join('، ')}';
  }

  String buildPrompt(String question, List<Hit> ctx) =>
      prompts.build(question, ctx);
}
