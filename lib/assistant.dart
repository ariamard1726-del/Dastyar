import 'engine.dart';
import 'llm.dart';
import 'persian_text.dart';
import 'prompt_builder.dart';

class AssistantTurn {
  final String text;
  final List<String> alternatives;

  const AssistantTurn({
    required this.text,
    this.alternatives = const [],
  });
}

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

  static final RegExp _singleArtRe =
      RegExp(r'ماده(?:\s+(واحده)|\s*(\d+(?:\s+مکرر(?:\s+\d{1,2})?)?))');
  static final RegExp _pluralArtRe = RegExp(
    r'مواد\s+((?:\d+(?:\s+مکرر(?:\s+\d{1,2})?)?)(?:\s*(?:،|,|و|یا|تا|الی|-)\s*(?:\d+(?:\s+مکرر(?:\s+\d{1,2})?)?))*)',
  );
  static final RegExp _artNumTokenRe =
      RegExp(r'\d+(?:\s+مکرر(?:\s+\d{1,2})?)?');

  /// شماره‌های مادهٔ ذکرشده در یک متن (با ارقام لاتین؛ شامل «واحده»، «مکرر» و جمع «مواد»).
  static Set<String> citedArticles(String text) {
    final n = PersianText.collapse(PersianText.normalize(text));
    final out = <String>{};
    for (final m in _singleArtRe.allMatches(n)) {
      final raw = m.group(1) ?? m.group(2)!;
      out.add(PersianText.collapse(raw));
    }
    for (final pm in _pluralArtRe.allMatches(n)) {
      final listPart = pm.group(1)!;
      for (final tm in _artNumTokenRe.allMatches(listPart)) {
        out.add(PersianText.collapse(tm.group(0)!));
      }
    }
    return out;
  }

  static Set<String> _allowedArticles(List<Hit> ctx) {
    final allowed = <String>{};
    for (final h in ctx) {
      allowed.addAll(citedArticles(h.chunk.title));
      allowed.addAll(citedArticles(h.chunk.body));
    }
    return allowed;
  }

  /// اگر پاسخ مدل شمارهٔ ماده‌ای را بیاورد که در متن‌های بازیابی‌شده
  /// نیست، پاسخ اعتبار ندارد.
  static bool isGrounded(String answer, List<Hit> ctx) {
    final cited = citedArticles(answer);
    if (cited.isEmpty) return true;
    final allowed = _allowedArticles(ctx);
    return cited.every(allowed.contains);
  }

  static bool _isFormalStatuteName(String normName) {
    return normName.startsWith('قانون ') ||
        normName.startsWith('لایحه ') ||
        normName.startsWith('آیین دادرسی');
  }

  /// بررسی جامع استناد پاسخ به مواد و عناوین قوانین موجود در متن‌های بازیابی‌شده.
  bool isAnswerGrounded(String answer, List<Hit> ctx) {
    if (!isGrounded(answer, ctx)) return false;
    if (engine.catalog.isEmpty || ctx.isEmpty) return true;

    final ctxLawIds = <String>{
      for (final h in ctx)
        if (h.chunk.lawId.isNotEmpty) h.chunk.lawId,
    };
    final ctxNormText = ctx
        .map(
          (h) =>
              '${h.chunk.normSource} ${PersianText.collapse(PersianText.normalize(h.chunk.body))}',
        )
        .join(' \n ');

    final candidates = <({String lawId, String phrase})>[];
    for (final law in engine.catalog) {
      for (final raw in [law.title, ...law.aliases]) {
        final phrase = PersianText.collapse(PersianText.normalize(raw));
        if (phrase.isNotEmpty && _isFormalStatuteName(phrase)) {
          candidates.add((lawId: law.id, phrase: phrase));
        }
      }
    }
    candidates.sort((a, b) => b.phrase.length.compareTo(a.phrase.length));

    var remaining = PersianText.collapse(PersianText.normalize(answer));
    for (final c in candidates) {
      if (!remaining.contains(c.phrase)) continue;
      remaining = remaining.replaceAll(c.phrase, ' ');
      if (ctxLawIds.contains(c.lawId)) continue;
      if (ctxNormText.contains(c.phrase)) continue;
      return false;
    }
    return true;
  }

  static bool _isInvalidCompletedCite(
    String cite,
    String tailAfterMatch,
    Set<String> allowed,
  ) {
    if (allowed.contains(cite)) return false;
    final prefix = '$cite ';
    final suffixes = allowed
        .where((a) => a.startsWith(prefix))
        .map((a) => a.substring(prefix.length))
        .toList();
    if (suffixes.isEmpty) return true;
    final tail = PersianText.collapse(tailAfterMatch);
    if (tail.isEmpty) return false;
    return !suffixes.any((s) => s.startsWith(tail));
  }

  // فقط استنادهایی که تمام شده‌اند بررسی می‌شوند؛ «ماده ۱» در میانهٔ نوشتن
  // «ماده ۱۰» یا «ماده ۲۱ » در میانهٔ «ماده ۲۱ مکرر» مجاز خطا حساب نمی‌شود.
  static bool _hasInvalidStreamingCitation(String rawAcc, Set<String> allowed) {
    final n = PersianText.normalize(rawAcc);
    for (final m in _singleArtRe.allMatches(n)) {
      if (m.end == n.length) continue;
      final raw = m.group(1) ?? m.group(2)!;
      final cite = PersianText.collapse(raw);
      if (_isInvalidCompletedCite(cite, n.substring(m.end), allowed)) {
        return true;
      }
    }
    for (final pm in _pluralArtRe.allMatches(n)) {
      final listPart = pm.group(1)!;
      final listStart = pm.end - listPart.length;
      for (final tm in _artNumTokenRe.allMatches(listPart)) {
        final absEnd = listStart + tm.end;
        if (absEnd == n.length) continue;
        final cite = PersianText.collapse(tm.group(0)!);
        if (_isInvalidCompletedCite(cite, n.substring(absEnd), allowed)) {
          return true;
        }
      }
    }
    return false;
  }

  /// اجرای یک‌بارهٔ بازیابی به همراه تولید پاسخ و پیشنهادهای مرتبط (حذف rank تکراری).
  Stream<AssistantTurn> askWithAlternatives(
    String question, {
    int maxAlternatives = 3,
  }) async* {
    final base = engine.query(question, maxAlternatives: maxAlternatives);

    var ready = false;
    try {
      ready = await llm.isReady();
    } catch (_) {}
    if (!ready) {
      yield AssistantTurn(text: base.text, alternatives: base.alternatives);
      return;
    }

    final ctx = base.contextHits;
    if (ctx.isEmpty) {
      yield AssistantTurn(text: base.text, alternatives: base.alternatives);
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
        if (_hasInvalidStreamingCitation(acc, allowed)) {
          good = false;
          break;
        }
        if (acc.length > maxChars) {
          good = false;
          break;
        }
        yield AssistantTurn(text: acc, alternatives: base.alternatives);
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
      yield AssistantTurn(text: base.text, alternatives: base.alternatives);
      return;
    }

    // بازبینی نهایی: ماده یا قانون ساختگی یعنی بازگشت به پاسخ مطمئن موتور.
    if (!isAnswerGrounded(acc, ctx)) {
      yield AssistantTurn(text: base.text, alternatives: base.alternatives);
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
    );
  }

  /// هر بار متن کامل‌شدهٔ فعلی پاسخ را برمی‌گرداند.
  Stream<String> ask(String question) {
    return askWithAlternatives(question, maxAlternatives: 0).map((t) => t.text);
  }

  String buildPrompt(String question, List<Hit> ctx) =>
      prompts.build(question, ctx);
}
