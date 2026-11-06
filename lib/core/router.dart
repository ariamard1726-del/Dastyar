import 'package:dastyar/core/utils/persian_normalizer.dart';

/// تشخیص قصدهای ثابت پرسش و متن پاسخ آن‌ها.
/// (فعلاً فقط دو قصد؛ قصدهای دیگر در قدم‌های بعد به اینجا می‌آیند.)
class QueryRouter {
  QueryRouter._();

  static final RegExp _compactRe = RegExp(r'[\s‌‍‎‏،؛؟,.!?:]+');

  static bool asksCapabilities(String n) {
    final compact = n.replaceAll(_compactRe, '');
    final asksWhat =
        compact.contains('چهکاری') || compact.contains('چهکارهایی');
    final capabilityVerb =
        compact.contains('انجاممیدهی') ||
        compact.contains('انجاممیدی') ||
        compact.contains('میتوانی') ||
        compact.contains('میتونی') ||
        compact.contains('میکنی') ||
        compact.contains('ازدستتبرمیاد');
    final asksAboutCapabilities =
        (compact.contains('قابلیتهای') ||
         compact.contains('تواناییهای')) &&
        (compact.contains('دستیار') ||
         compact.contains('برنامه') ||
         compact.contains('تو'));
    return (asksWhat && capabilityVerb) || asksAboutCapabilities;
  }

  static bool asksOutcomePrediction(String n) {
    final compact = n.replaceAll(_compactRe, '');
    final asksCase = compact.contains('پرونده') ||
        compact.contains('حکمقاضی') ||
        compact.contains('نتیجهدادگاه');
    final asksPrediction =
        compact.contains('چهحکمی') ||
        compact.contains('صادرخواهدکرد') ||
        compact.contains('پیشبینینتیجه') ||
        compact.contains('نتیجهقطعی') ||
        compact.contains('حکمدقیق');
    return asksCase && asksPrediction;
  }
}

// ---------------------------------------------------------------------------
// مسیریابی ترکیبی قصد (Hybrid Intent Routing)
// ---------------------------------------------------------------------------

/// یک کلیدواژهٔ وزن‌دار: حضور [phrase] در متن، [weight] امتیاز به [intent]
/// می‌دهد. عبارت‌های دقیق‌تر (مثل «مطالبه وجه») وزن بیشتری از واژه‌های
/// کلی (مثل «چک») دارند.
class WeightedKeyword {
  const WeightedKeyword(this.phrase, this.intent, this.weight);

  final String phrase;
  final String intent;
  final double weight;
}

/// عبارت قطعی پیش از شبکه: اگر پیدا شود، شبکهٔ عصبی کنار گذاشته می‌شود و
/// [intent] با اطمینان ثابت انتخاب می‌شود. در تطبیق هم‌زمان چند عبارت،
/// [priority] بالاتر و سپس عبارت بلندتر برنده است.
class StrictPhrase {
  const StrictPhrase(this.phrase, this.intent, this.priority);

  final String phrase;
  final String intent;
  final int priority;
}

/// منبع تصمیم نهایی مسیریاب؛ برای دیباگ و تست.
enum RoutingSource {
  /// عبارت قطعی پیش از شبکه تطبیق خورد.
  strictPhrase,

  /// به شبکه اعتماد شد (اطمینان بالا یا متوسط بدون مخالفت جدی کلیدواژه‌ها).
  network,

  /// اطمینان شبکه بالا بود، ولی کلیدواژه‌ها با اختلاف زیاد مخالف بودند.
  keywordConflictOverride,

  /// اطمینان شبکه متوسط بود و کلیدواژه‌ها قویاً قصد دیگری را نشان دادند.
  keywordOverride,

  /// اطمینان شبکه پایین بود؛ ترکیب ۷۵٪ کلیدواژه + ۲۵٪ شبکه.
  blended,

  /// هیچ شاهدی (نه کلیدواژه، نه شبکه) وجود نداشت.
  none,
}

/// آستانه‌ها و ضرایب مسیریاب؛ همه قابل تنظیم برای آزمایش.
class HybridRouterConfig {
  const HybridRouterConfig({
    this.strictConfidence = 0.99,
    this.highConfidence = 0.80,
    this.midConfidence = 0.60,
    this.conflictMargin = 0.30,
    this.overrideMargin = 0.20,
    this.keywordBlendWeight = 0.75,
    this.networkBlendWeight = 0.25,
    this.minKeywordEvidence = 1.0,
  });

  /// اطمینانِ گزارش‌شده برای تطبیق عبارت قطعی.
  final double strictConfidence;

  /// بالاتر از این، شبکه قابل اعتماد است (مگر در تعارض شدید).
  final double highConfidence;

  /// پایین‌تر از این، کلیدواژه‌ها غالب‌اند.
  final double midConfidence;

  /// اختلاف امتیاز کلیدواژه که در محدودهٔ اطمینان بالا «تعارض شدید» است.
  final double conflictMargin;

  /// اختلاف امتیاز کلیدواژه که در محدودهٔ متوسط برای جایگزینی کافی است.
  final double overrideMargin;

  final double keywordBlendWeight;
  final double networkBlendWeight;

  /// حداقل مجموع وزن خام کلیدواژه‌ها تا بتوانند تصمیم شبکه را بشکنند؛
  /// یک واژهٔ کلیِ تنها (مثل «چک» با وزن ۰٫۷) کافی نیست.
  final double minKeywordEvidence;
}

/// نتیجهٔ امتیازدهی کلیدواژه‌ها.
class KeywordScores {
  const KeywordScores({
    required this.raw,
    required this.normalized,
    required this.matched,
  });

  static const KeywordScores empty =
      KeywordScores(raw: {}, normalized: {}, matched: []);

  /// مجموع وزن کلیدواژه‌های تطبیق‌خورده برای هر قصد.
  final Map<String, double> raw;

  /// سهم هر قصد از کل امتیاز (جمع = ۱)، قابل مقایسه با احتمال شبکه.
  final Map<String, double> normalized;

  /// کلیدواژه‌های تطبیق‌خورده به ترتیب بررسی.
  final List<WeightedKeyword> matched;

  double get totalEvidence => raw.values.fold(0.0, (a, b) => a + b);

  bool get isEmpty => raw.isEmpty;

  double scoreOf(String intent) => normalized[intent] ?? 0.0;

  String? get topIntent => HybridIntentRouter.argMax(normalized);
}

/// تصمیم نهایی مسیریاب.
class RoutingDecision {
  const RoutingDecision({
    required this.intent,
    required this.confidence,
    required this.source,
    required this.probabilities,
    required this.keywordScores,
    required this.networkProbabilities,
    this.strictPhrase,
  });

  /// قصد انتخاب‌شده؛ اگر هیچ شاهدی نباشد [HybridIntentRouter.noneIntent].
  final String intent;

  /// اطمینان نهایی در بازهٔ ۰ تا ۱.
  final double confidence;

  final RoutingSource source;

  /// توزیع نهایی احتمال قصدها؛ ورودی مناسب برای
  /// `DialoguePlanner.generateClarificationPrompt`.
  final Map<String, double> probabilities;

  final KeywordScores keywordScores;
  final Map<String, double> networkProbabilities;
  final StrictPhrase? strictPhrase;

  bool get isNone => intent == HybridIntentRouter.noneIntent;

  @override
  String toString() =>
      'RoutingDecision($intent, ${confidence.toStringAsFixed(3)}, ${source.name})';
}

/// پوستهٔ ایمنی قطعی دور طبقه‌بند عصبی قصد.
///
/// ترتیب تصمیم:
/// ۱. **عبارت قطعی** ([StrictPhrase]): اگر پیدا شود، شبکه دور زده می‌شود و
///    اطمینان [HybridRouterConfig.strictConfidence] (۰٫۹۹) گزارش می‌شود.
/// ۲. **اطمینان شبکه > ۰٫۸۰**: به شبکه اعتماد می‌شود، مگر کلیدواژه‌ها قصد
///    دیگری را با اختلاف بیش از ۰٫۳۰ ترجیح دهند (تعارض شدید).
/// ۳. **اطمینان ۰٫۶۰ تا ۰٫۸۰**: اگر کلیدواژه‌ها قویاً (اختلاف بیش از
///    [HybridRouterConfig.overrideMargin]) قصد دیگری را نشان دهند، جایگزین
///    می‌شود.
/// ۴. **اطمینان < ۰٫۶۰**: کلیدواژه غالب است؛ امتیاز = ۷۵٪ کلیدواژه +
///    ۲۵٪ احتمال شبکه. اگر هیچ کلیدواژه‌ای نباشد، همان خروجی شبکه با
///    اطمینان پایینش برمی‌گردد تا لایهٔ شفاف‌سازی از کاربر بپرسد.
///
/// کلاس بی‌حالت و قطعی است: برای ورودی یکسان همیشه خروجی یکسان دارد.
/// به برچسب‌های شبکهٔ خاصی وابسته نیست؛ هر نقشهٔ `قصد → احتمال` را می‌پذیرد.
class HybridIntentRouter {
  HybridIntentRouter({
    List<WeightedKeyword>? keywords,
    List<StrictPhrase>? strictPhrases,
    this.config = const HybridRouterConfig(),
  })  : _keywords = _prepareKeywords(keywords ?? defaultKeywords),
        _strict = _prepareStrict(strictPhrases ?? preNetworkStrictPhrases);

  static const String noneIntent = 'none';

  final HybridRouterConfig config;
  final List<_PreparedKeyword> _keywords;
  final List<_PreparedStrict> _strict;

  /// کلیدواژه‌های وزن‌دار پیش‌فرض برای قصدهای قالب‌های حقوقی.
  static const List<WeightedKeyword> defaultKeywords = [
    // مطالبهٔ پول
    WeightedKeyword('مطالبه وجه', 'demand_money', 1.2),
    WeightedKeyword('مطالبه طلب', 'demand_money', 1.2),
    WeightedKeyword('مطالبه پول', 'demand_money', 1.2),
    WeightedKeyword('وجه چک', 'demand_money', 1.0),
    WeightedKeyword('طلبکار', 'demand_money', 0.8),
    WeightedKeyword('طلب', 'demand_money', 0.6),
    WeightedKeyword('قرض', 'demand_money', 0.8),
    WeightedKeyword('سفته', 'demand_money', 0.9),
    WeightedKeyword('بدهی', 'demand_money', 0.5),
    WeightedKeyword('بدهکار', 'demand_money', 0.5),
    WeightedKeyword('پس نمی‌دهد', 'demand_money', 0.6),
    WeightedKeyword('پس نمیده', 'demand_money', 0.6),
    WeightedKeyword('پول', 'demand_money', 0.4),
    WeightedKeyword('چک', 'demand_money', 0.7),
    WeightedKeyword('برگشت خورده', 'demand_money', 0.5),

    // شکایت کیفری
    WeightedKeyword('شکایت کیفری', 'complaint', 1.2),
    WeightedKeyword('شکواییه', 'complaint', 1.2),
    WeightedKeyword('سرقت', 'complaint', 1.0),
    WeightedKeyword('دزدی', 'complaint', 1.0),
    WeightedKeyword('دزدیده', 'complaint', 1.0),
    WeightedKeyword('دزدیدند', 'complaint', 1.0),
    WeightedKeyword('کلاهبرداری', 'complaint', 1.0),
    WeightedKeyword('خیانت در امانت', 'complaint', 1.1),
    WeightedKeyword('ضرب و جرح', 'complaint', 1.1),
    WeightedKeyword('جعل', 'complaint', 0.9),
    WeightedKeyword('تهدید', 'complaint', 0.8),
    WeightedKeyword('توهین', 'complaint', 0.8),
    WeightedKeyword('فحاشی', 'complaint', 0.8),
    WeightedKeyword('کتک', 'complaint', 0.8),
    WeightedKeyword('مزاحمت', 'complaint', 0.7),
    WeightedKeyword('هتک حیثیت', 'complaint', 0.9),
    WeightedKeyword('شکایت', 'complaint', 0.5),

    // اظهارنامه
    WeightedKeyword('اظهارنامه', 'formal_notice', 1.2),
    WeightedKeyword('اخطار رسمی', 'formal_notice', 1.0),
    WeightedKeyword('اخطار', 'formal_notice', 0.5),

    // لایحهٔ دفاعیه
    WeightedKeyword('لایحه دفاعیه', 'defense_brief', 1.2),
    WeightedKeyword('دفاعیه', 'defense_brief', 1.0),
    WeightedKeyword('لایحه', 'defense_brief', 0.9),
    WeightedKeyword('دفاع', 'defense_brief', 0.7),
    WeightedKeyword('متهم', 'defense_brief', 0.6),
    WeightedKeyword('علیه من', 'defense_brief', 0.6),
    WeightedKeyword('احضاریه', 'defense_brief', 0.6),
    WeightedKeyword('ابلاغیه', 'defense_brief', 0.6),

    // اعسار
    WeightedKeyword('اعسار', 'insolvency', 1.2),
    WeightedKeyword('تقسیط', 'insolvency', 0.9),
    WeightedKeyword('توان پرداخت ندارم', 'insolvency', 1.1),
    WeightedKeyword('محکومیت مالی', 'insolvency', 0.8),
    WeightedKeyword('پول ندارم', 'insolvency', 0.6),

    // معاضدت قضایی
    WeightedKeyword('معاضدت', 'legal_aid', 1.2),
    WeightedKeyword('وکیل تسخیری', 'legal_aid', 1.1),
    WeightedKeyword('وکیل رایگان', 'legal_aid', 1.1),
    WeightedKeyword('پول وکیل', 'legal_aid', 0.9),
    WeightedKeyword('هزینه وکیل', 'legal_aid', 0.9),
    WeightedKeyword('هزینه دادرسی', 'legal_aid', 0.8),

    // اجرائیهٔ چک
    WeightedKeyword('اجراییه چک', 'cheque_execution', 1.2),
    WeightedKeyword('اجراییه', 'cheque_execution', 0.7),
  ];

  /// عبارت‌های قطعی که شبکه را دور می‌زنند.
  static const List<StrictPhrase> preNetworkStrictPhrases = [
    StrictPhrase('سرقت چک', 'complaint', 100),
    StrictPhrase('چک سرقتی', 'complaint', 100),
    StrictPhrase('چک دزدی', 'complaint', 100),
    StrictPhrase('دزدیدن چک', 'complaint', 100),
    StrictPhrase('جعل چک', 'complaint', 95),
    StrictPhrase('جعل امضا', 'complaint', 95),
    StrictPhrase('شکایت کیفری', 'complaint', 85),
    StrictPhrase('مطالبه وجه چک', 'demand_money', 95),
    StrictPhrase('دادخواست مطالبه وجه', 'demand_money', 95),
    StrictPhrase('چک برگشتی', 'demand_money', 90),
    StrictPhrase('چک برگشت خورد', 'demand_money', 90),
    StrictPhrase('چک برگشت خورده', 'demand_money', 90),
    StrictPhrase('اجراییه چک', 'cheque_execution', 96),
    StrictPhrase('دادخواست اعسار', 'insolvency', 95),
    StrictPhrase('معاضدت قضایی', 'legal_aid', 95),
    StrictPhrase('لایحه دفاعیه', 'defense_brief', 95),
    StrictPhrase('اظهارنامه رسمی', 'formal_notice', 90),
  ];

  // ---------------------------------------------------------------- API

  /// عبارت قطعیِ برنده در [text]، یا null.
  StrictPhrase? matchStrict(String text) {
    final toks = PersianNormalizer.tokens(text);
    if (toks.isEmpty) return null;
    _PreparedStrict? best;
    for (final s in _strict) {
      if (!PersianNormalizer.containsPhraseTokens(toks, s.tokens)) continue;
      if (best == null ||
          s.source.priority > best.source.priority ||
          (s.source.priority == best.source.priority &&
              s.tokens.length > best.tokens.length)) {
        best = s;
      }
    }
    return best?.source;
  }

  /// امتیاز کلیدواژه‌ها با «تطبیق بلندترین عبارت»: اگر «مطالبه وجه» پیدا
  /// شود، «وجه» داخل همان بازه دوباره شمرده نمی‌شود.
  KeywordScores scoreKeywords(String text) {
    final toks = PersianNormalizer.tokens(text);
    if (toks.isEmpty) return KeywordScores.empty;
    final covered = List<bool>.filled(toks.length, false);
    final raw = <String, double>{};
    final matched = <WeightedKeyword>[];
    for (final k in _keywords) {
      final span = _findFreeSpan(toks, k.tokens, covered);
      if (span < 0) continue;
      for (var j = 0; j < k.tokens.length; j++) {
        covered[span + j] = true;
      }
      raw[k.source.intent] = (raw[k.source.intent] ?? 0) + k.source.weight;
      matched.add(k.source);
    }
    if (raw.isEmpty) return KeywordScores.empty;
    final total = raw.values.fold(0.0, (a, b) => a + b);
    final normalized = <String, double>{
      for (final e in raw.entries) e.key: e.value / total,
    };
    return KeywordScores(
      raw: Map.unmodifiable(raw),
      normalized: Map.unmodifiable(normalized),
      matched: List.unmodifiable(matched),
    );
  }

  /// تصمیم نهایی برای [text] با توجه به احتمال‌های شبکه.
  ///
  /// [networkProbabilities] خروجی softmax طبقه‌بند (قصد → احتمال) است؛ اگر
  /// شبکه در دسترس نباشد، null یا خالی بدهید تا فقط کلیدواژه‌ها تصمیم بگیرند.
  RoutingDecision route(
    String text, {
    Map<String, double>? networkProbabilities,
  }) {
    final nn = _sanitize(networkProbabilities);
    final kw = scoreKeywords(text);

    // ۱. عبارت قطعی → دور زدن شبکه.
    final strict = matchStrict(text);
    if (strict != null) {
      return RoutingDecision(
        intent: strict.intent,
        confidence: config.strictConfidence,
        source: RoutingSource.strictPhrase,
        probabilities: {strict.intent: config.strictConfidence},
        keywordScores: kw,
        networkProbabilities: nn,
        strictPhrase: strict,
      );
    }

    final nnTop = argMax(nn);
    final nnConf = nnTop == null ? 0.0 : nn[nnTop]!;
    final kwTop = kw.topIntent;
    final strongEvidence = kw.totalEvidence >= config.minKeywordEvidence;
    final kwMargin = (kwTop == null || nnTop == null)
        ? 0.0
        : kw.scoreOf(kwTop) - kw.scoreOf(nnTop);
    final disagrees = kwTop != null && nnTop != null && kwTop != nnTop;

    // ۲. اطمینان بالا.
    if (nnTop != null && nnConf > config.highConfidence) {
      if (disagrees && strongEvidence && kwMargin > config.conflictMargin) {
        return _override(kwTop, kw, nn, RoutingSource.keywordConflictOverride);
      }
      return _trustNetwork(nnTop, nnConf, kw, nn);
    }

    // ۳. اطمینان متوسط.
    if (nnTop != null && nnConf >= config.midConfidence) {
      if (disagrees && strongEvidence && kwMargin > config.overrideMargin) {
        return _override(kwTop, kw, nn, RoutingSource.keywordOverride);
      }
      return _trustNetwork(nnTop, nnConf, kw, nn);
    }

    // ۴. اطمینان پایین: کلیدواژه غالب.
    if (!kw.isEmpty) {
      final blended = _blend(kw, nn);
      final top = argMax(blended)!;
      return RoutingDecision(
        intent: top,
        confidence: blended[top]!,
        source: RoutingSource.blended,
        probabilities: blended,
        keywordScores: kw,
        networkProbabilities: nn,
      );
    }
    if (nnTop != null) {
      // هیچ کلیدواژه‌ای نیست؛ خروجی خامِ کم‌اطمینان شبکه برمی‌گردد تا
      // لایهٔ شفاف‌سازی تصمیم بگیرد (حدس با اطمینان ساختگی نمی‌زنیم).
      return _trustNetwork(nnTop, nnConf, kw, nn);
    }
    return RoutingDecision(
      intent: noneIntent,
      confidence: 0.0,
      source: RoutingSource.none,
      probabilities: const {},
      keywordScores: kw,
      networkProbabilities: nn,
    );
  }

  // ------------------------------------------------------------ helpers

  /// بیشینهٔ نقشه با شکستن تساوی بر اساس ترتیب الفبایی (قطعی).
  static String? argMax(Map<String, double> m) {
    String? best;
    var bestV = double.negativeInfinity;
    for (final e in m.entries) {
      if (e.value > bestV ||
          (e.value == bestV && best != null && e.key.compareTo(best) < 0)) {
        best = e.key;
        bestV = e.value;
      }
    }
    return best;
  }

  RoutingDecision _trustNetwork(
    String intent,
    double conf,
    KeywordScores kw,
    Map<String, double> nn,
  ) =>
      RoutingDecision(
        intent: intent,
        confidence: conf,
        source: RoutingSource.network,
        probabilities: nn,
        keywordScores: kw,
        networkProbabilities: nn,
      );

  RoutingDecision _override(
    String intent,
    KeywordScores kw,
    Map<String, double> nn,
    RoutingSource source,
  ) {
    final blended = _blend(kw, nn);
    return RoutingDecision(
      intent: intent,
      confidence: blended[intent] ?? kw.scoreOf(intent),
      source: source,
      probabilities: blended,
      keywordScores: kw,
      networkProbabilities: nn,
    );
  }

  Map<String, double> _blend(KeywordScores kw, Map<String, double> nn) {
    final keys = <String>{...kw.normalized.keys, ...nn.keys};
    return {
      for (final k in keys)
        k: config.keywordBlendWeight * kw.scoreOf(k) +
            config.networkBlendWeight * (nn[k] ?? 0.0),
    };
  }

  static Map<String, double> _sanitize(Map<String, double>? m) {
    if (m == null || m.isEmpty) return const {};
    final out = <String, double>{};
    for (final e in m.entries) {
      final v = e.value;
      if (v.isNaN || v <= 0) continue;
      out[e.key] = v > 1 ? 1.0 : v;
    }
    return Map.unmodifiable(out);
  }

  static int _findFreeSpan(
    List<String> text,
    List<String> phrase,
    List<bool> covered,
  ) {
    final n = phrase.length;
    for (var i = 0; i + n <= text.length; i++) {
      var ok = true;
      for (var j = 0; j < n; j++) {
        if (covered[i + j] ||
            !PersianNormalizer.containsPhraseTokens(
                [text[i + j]], [phrase[j]])) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  static List<_PreparedKeyword> _prepareKeywords(List<WeightedKeyword> ks) {
    final out = [
      for (final k in ks)
        if (k.weight > 0)
          _PreparedKeyword(k, PersianNormalizer.tokens(k.phrase)),
    ]..removeWhere((p) => p.tokens.isEmpty);
    // بلندترین عبارت اول، سپس وزن بیشتر، سپس ترتیب تعریف (مرتب‌سازی پایدار).
    final indexed = out.asMap().entries.toList()
      ..sort((a, b) {
        final c = b.value.tokens.length.compareTo(a.value.tokens.length);
        if (c != 0) return c;
        final w = b.value.source.weight.compareTo(a.value.source.weight);
        if (w != 0) return w;
        return a.key.compareTo(b.key);
      });
    return List.unmodifiable(indexed.map((e) => e.value));
  }

  static List<_PreparedStrict> _prepareStrict(List<StrictPhrase> ss) =>
      List.unmodifiable([
        for (final s in ss)
          if (PersianNormalizer.tokens(s.phrase).isNotEmpty)
            _PreparedStrict(s, PersianNormalizer.tokens(s.phrase)),
      ]);
}

class _PreparedKeyword {
  const _PreparedKeyword(this.source, this.tokens);
  final WeightedKeyword source;
  final List<String> tokens;
}

class _PreparedStrict {
  const _PreparedStrict(this.source, this.tokens);
  final StrictPhrase source;
  final List<String> tokens;
}
