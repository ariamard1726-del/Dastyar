import 'dart:math';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/lawyer/case_facts.dart';
import 'package:dastyar/domain/lawyer/case_reasoner.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';
import 'package:dastyar/domain/lawyer/phrase_variator.dart';
import 'package:dastyar/domain/templates.dart';

/// پاسخ آمادهٔ «صدای وکیل».
class LawyerReply {
  final String text;
  final List<String> chips;
  final LegalGuide? guide;
  const LawyerReply({required this.text, this.chips = const [], this.guide});
}

/// لایهٔ «صدای وکیل»: پاسخ‌های خشکِ موتور جست‌وجو را به گفتگوی گرم، منطقی و
/// مرحله‌به‌مرحلهٔ یک وکیل تبدیل می‌کند. کاملاً آفلاین و قطعی است و هیچ
/// مدل زبانی‌ای استفاده نمی‌کند.
///
/// سه کار اصلی دارد:
///   * [matchGuide]: تشخیص اینکه پیام کاربر به کدام مسئلهٔ رایج حقوقی مربوط است.
///   * [composeGuide]: ساخت پاسخ کامل وکیل‌مانند (همدلی → توضیح → قدم‌ها →
///     هشدار → مبنای قانونی از متن رسمی → پرسش پیگیری).
///   * [frameEngineAnswer]: قاب‌بندی پاسخ مستقیم موتور (متن ماده) با مقدمه و
///     جمع‌بندی انسانی، و نوشتن پاسخ صادقانه و راهگشا وقتی چیزی پیدا نشد.
class LawyerVoice {
  /// موضوع مشاورهٔ گام‌به‌گامی که هر راهنما با آن سازگار است. اگر مشاورِ
  /// گام‌به‌گام موضوع دیگری تشخیص دهد (مثلاً «ابلاغیه» را به چک ببرد)،
  /// به‌جای شروع مشاورهٔ نامرتبط، پاسخ کامل راهنما داده می‌شود.
  static const Map<String, String> _guideTopic = {
    'cheque_guarantee': 'cheque',
    'cheque_issuer': 'cheque',
    'cheque_bounced': 'cheque',
    'dismissal': 'labor',
    'unpaid_wages': 'labor',
    'labor_insurance': 'labor',
    'deposit_return': 'lease',
    'eviction': 'lease',
    'mahrieh': 'family',
    'nafaqeh': 'family',
    'custody': 'family',
    'divorce': 'family',
    'tamkin': 'family',
    'debt_claim': 'debt',
    'insolvency': 'debt',
    'fraud': 'fraud_cyber',
    'private_media': 'fraud_cyber',
    'trust_breach': 'fraud_cyber',
    'insult_threat': 'criminal_harm',
    'defamation': 'criminal_harm',
    'assault': 'criminal_harm',
    'diyeh': 'criminal_harm',
    'appeal': 'litigation_defense',
    'summons': 'litigation_defense',
  };

  static bool counselTopicFits(LegalGuide guide, String topicId) =>
      _guideTopic[guide.id] == topicId;

  /// راهنمای اصلی متناظر با موضوع یک جلسهٔ مشاوره (برای ادامهٔ گفتگو پس از
  /// جمع‌بندی)، یا `null`.
  static LegalGuide? guideForCounselTopic(String topicId) {
    for (final e in _guideTopic.entries) {
      if (e.value != topicId) continue;
      for (final g in legalGuides) {
        if (g.id == e.key) return g;
      }
    }
    return null;
  }

  LawyerVoice._();

  // ───────────────────────── تشخیص ─────────────────────────

  static final RegExp _directArtRe = RegExp(r'(?:ماده|اصل)\s*(?:واحده|\d+)');

  static String _phrase(String s) => ' ${PersianText.phrase(s)} ';

  static final Map<String, List<List<String>>> _normTriggers = {
    for (final g in legalGuides)
      g.id: [
        for (final group in g.triggers)
          [for (final t in group) PersianText.phrase(t)],
      ],
  };

  static final Map<String, List<String>> _normExcludes = {
    for (final g in legalGuides)
      g.id: [for (final t in g.excludes) PersianText.phrase(t)],
  };

  /// آیا پیام ارجاع مستقیم به یک ماده است («ماده ۱۰ قانون مدنی»)؟
  static bool isDirectArticleRef(String rawText) =>
      _directArtRe.hasMatch(PersianText.normalize(rawText));

  /// مناسب‌ترین راهنما برای پیام کاربر، یا `null`.
  static LegalGuide? matchGuide(String rawText) {
    final all = matchGuides(rawText);
    return all.isEmpty ? null : all.first;
  }

  /// پیشوند دکمه‌ای که کاربر را به یک موضوع دیگرِ همان ماجرا می‌برد.
  static const String topicChipPrefix = 'دربارهٔ ';

  /// همهٔ راهنماهای منطبق، به ترتیب امتیاز (بهترین اول). عنوان دقیق یک
  /// راهنما (یا «دربارهٔ <عنوان>») مستقیماً همان راهنما را برمی‌گرداند.
  static List<LegalGuide> matchGuides(String rawText) {
    if (rawText.trim().isEmpty || isDirectArticleRef(rawText)) return const [];
    final p = _phrase(rawText);
    final bare = PersianText.phrase(rawText);
    for (final g in legalGuides) {
      final t = PersianText.phrase(g.title);
      if (bare == t || bare == PersianText.phrase('$topicChipPrefix${g.title}')) {
        return [g];
      }
    }
    final scored = <(LegalGuide, int)>[];
    for (final g in legalGuides) {
      if (_normExcludes[g.id]!.any((e) => e.isNotEmpty && p.contains(e))) {
        continue;
      }
      var score = 0;
      for (final group in _normTriggers[g.id]!) {
        if (group.every((t) => t.isNotEmpty && p.contains(t))) {
          final s = group.fold<int>(0, (a, t) => a + t.length) * 10;
          if (s > score) score = s;
        }
      }
      if (score == 0) continue;
      score += g.priority;
      scored.add((g, score));
    }
    // مرتب‌سازی پایدار: در تساوی، ترتیب تعریف حفظ می‌شود (قطعی).
    final idx = {for (var i = 0; i < legalGuides.length; i++) legalGuides[i].id: i};
    scored.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : idx[a.$1.id]!.compareTo(idx[b.$1.id]!);
    });
    return [for (final x in scored) x.$1];
  }

  /// موضوع‌های دیگری از همان ماجرا (برای پیام‌های چندمسئله‌ای)؛ فقط
  /// راهنماهای هم‌خانواده و حداکثر دو مورد.
  static List<LegalGuide> relatedIssues(LegalGuide main, String rawText) {
    final fam = _family(main.id);
    final out = <LegalGuide>[];
    for (final g in matchGuides(rawText)) {
      if (g.id == main.id || out.length >= 2) continue;
      if (fam != null && _family(g.id) == fam) out.add(g);
    }
    return out;
  }

  static String? _family(String id) => _guideFamily[id];

  /// آیا دو راهنما به یک ماجرا (یک خانوادهٔ موضوعی) تعلق دارند؟
  static bool sameFamily(String a, String b) =>
      a == b || (_family(a) != null && _family(a) == _family(b));

  static final RegExp _lawOverviewRe = RegExp(
    r'^(?:(?:درباره|در مورد|راجع به|از) )?(?:قانون|ق) (.+?) (?:بگو|بگین|بگید|توضیح بده|توضیح بدین|توضیح بدید|چی میدونی|چیه|چیست|رو بگو|را توضیح بده)$',
  );

  /// شناسهٔ قانونی که کاربر کلی دربارهٔ آن پرسیده («دربارهٔ قانون کار بگو»).
  static String? lawOverviewId(String rawText, Map<String, Map<String, dynamic>> meta) {
    final m = _lawOverviewRe.firstMatch(PersianText.phrase(rawText));
    if (m == null) return null;
    final name = m.group(1)!.trim();
    if (name.isEmpty || RegExp(r'\d').hasMatch(name)) return null;
    String? best;
    var bestLen = 1 << 30;
    meta.forEach((id, v) {
      final title = PersianText.phrase('${v['title'] ?? ''}');
      if (title == 'قانون $name' ||
          title.startsWith('قانون $name ') ||
          (title.startsWith('قانون ') && title.endsWith(' $name')) ||
          title == name) {
        if (title.length < bestLen) {
          bestLen = title.length;
          best = id;
        }
      }
    });
    return best;
  }

  /// موضوع پرسش‌های پیشنهادی برای هر قانون.
  static const Map<String, String> lawTopic = {
    'labor': 'labor',
    'social_security': 'labor',
    'landlord_tenant': 'lease',
    'cheque': 'cheque',
    'family_protection': 'family',
    'marriage': 'family',
    'penal_taazirat': 'criminal_harm',
    'cybercrime': 'fraud_cyber',
    'fraud_intensify': 'fraud_cyber',
    'civil_procedure': 'litigation_defense',
    'criminal_procedure': 'litigation_defense',
    'financial_sentences': 'debt',
    'consumer_protection': 'consumer',
    'civil_liability': 'accident',
  };

  static const Map<String, String> _guideFamily = {
    'dismissal': 'labor',
    'unpaid_wages': 'labor',
    'labor_insurance': 'labor',
    'deposit_return': 'lease',
    'eviction': 'lease',
    'mahrieh': 'family',
    'nafaqeh': 'family',
    'custody': 'family',
    'divorce': 'family',
    'tamkin': 'family',
    'cheque_bounced': 'cheque',
    'cheque_issuer': 'cheque',
    'cheque_guarantee': 'cheque',
    'accident': 'accident',
    'diyeh': 'accident',
    'assault': 'harm',
    'insult_threat': 'harm',
    'defamation': 'harm',
  };

  static bool _cueHit(String p, CaseFacts facts, List<String> group) {
    for (final c in group) {
      if (c.startsWith('@')) {
        if (!facts.has(c.substring(1))) return false;
      } else {
        final t = PersianText.phrase(c);
        if (t.isEmpty || !p.contains(t)) return false;
      }
    }
    return true;
  }

  /// نکته‌های شرطی راهنما که با جزئیات پیام کاربر جور درمی‌آیند.
  static List<String> notesFor(LegalGuide g, String rawText, [CaseFacts? f]) {
    final facts = f ?? CaseFacts.extract(rawText);
    final p = _phrase(rawText);
    return [
      for (final n in g.notes)
        if (n.cues.any((grp) => _cueHit(p, facts, grp))) n.text,
    ];
  }

  static const List<String> _notesHeads = [
    'با توجه به آنچه گفتید:',
    'با جزئیاتی که گفتید، این نکته‌ها مخصوص وضعیت شماست:',
    'دربارهٔ شرایط خاص شما:',
  ];

  static const List<String> _factsHeads = [
    CaseFacts.summaryHead,
    'این جزئیات را از توضیح شما برداشتم:',
    'برای اینکه دوباره نپرسم، این‌ها را از پیام شما یادداشت کردم:',
  ];

  static const List<String> _multiHeads = [
    'در ماجرای شما بیش از یک موضوع حقوقی هست:',
    'در توضیح شما چند مسئلهٔ جدا از هم دیده می‌شود:',
  ];

  /// بلوک «یادداشت‌ها + نکته‌های شرطی + موضوع‌های دیگر» برای پیام شخصی.
  static String personalizedBlock(
    LegalGuide g,
    String rawText, {
    PhraseVariator? v,
    CaseFacts? facts,
    bool includeFacts = true,
  }) {
    final f = facts ?? CaseFacts.extract(rawText);
    final parts = <String>[];
    if (includeFacts && f.summaryLines().length >= 2) {
      parts.add(f.render(
        head: v == null ? CaseFacts.summaryHead : v.pick('facts', _factsHeads),
      ));
    }
    final notes = notesFor(g, rawText, f);
    if (notes.isNotEmpty) {
      final h = v == null ? _notesHeads.first : v.pick('notes', _notesHeads);
      parts.add('$h\n${notes.map((n) => '• ${_fa(n)}').join('\n')}');
    }
    final rel = relatedIssues(g, rawText);
    if (rel.isNotEmpty) {
      final all = [g, ...rel].map((x) => '«${x.title}»').join('، ');
      final h = v == null ? _multiHeads.first : v.pick('multi', _multiHeads);
      parts.add(
        '$h $all. در این پاسخ روی «${g.title}» تمرکز کرده‌ام؛ برای بقیه، دکمه‌های پایین را بزنید تا جداگانه بررسی کنیم.',
      );
    }
    return parts.join('\n\n');
  }

  /// دکمه‌های موضوع‌های دیگرِ همان ماجرا.
  static List<String> relatedChips(LegalGuide g, String rawText) => [
        for (final r in relatedIssues(g, rawText)) '$topicChipPrefix${r.title}',
      ];

  static LegalGuide? guideById(String id) {
    for (final g in legalGuides) {
      if (g.id == id) return g;
    }
    return null;
  }

  static final List<String> _distressCues = [
    'ناراحت',
    'نگران',
    'استرس',
    'میترسم',
    'می ترسم',
    'ترسیدم',
    'بدبخت',
    'کلافه',
    'خسته شدم',
    'گریه',
    'داغون',
    'افسرده',
    'بیچاره',
    'تو رو خدا',
    'تورو خدا',
    'کمکم کن',
    'کمکم کنید',
    'نمیدونم چکار',
    'نمی دونم چکار',
    'نمیدونم چیکار',
    'نمی دانم چه کنم',
    'ظلم',
    'عصبانی',
    'اعصابم',
    'حالم بد',
    'دلم شکست',
    'آبروم',
    'آبرویم',
    'زندگیم',
    'زندگیم نابود',
    'خیلی بد',
    'وحشت',
    'ترس',
  ].map(PersianText.phrase).toList();

  /// آیا کاربر احساس ناراحتی، ترس یا فشار روانی ابراز کرده است؟
  static bool expressesDistress(String rawText) {
    final p = _phrase(rawText);
    return _distressCues.any((c) => p.contains(' $c') || p.contains(c));
  }

  static final List<String> _personalCues = [
    'من',
    'مرا',
    'منو',
    'بهم',
    'ازم',
    'برام',
    'دارم',
    'هستم',
    'کردم',
    'شدم',
    'دادم',
    'گرفتم',
    'خریدم',
    'ندارم',
    'نمیتونم',
    'نمی تونم',
    'نمی توانم',
    'شوهرم',
    'همسرم',
    'زنم',
    'پدرم',
    'مادرم',
    'برادرم',
    'خواهرم',
    'بچه ام',
    'بچم',
    'پسرم',
    'دخترم',
    'کارفرمام',
    'کارفرمایم',
    'صاحبخانه ام',
    'صاحبخونه',
    'مستاجرم',
    'پولم',
    'حقوقم',
    'چکم',
    'مهریه ام',
    'خانه ام',
    'ماشینم',
    'اخراجم',
    'دوستم',
    'شریکم',
    'بگیرم',
    'کنم',
    'بکنم',
    'بدم',
    'تهدیدم',
    'عکسامو',
    'عکسهامو',
    'عکسام',
    'آبرومو',
    'گوشیمو',
    'پولمو',
    'حقوقمو',
    'ماشینمو',
    'خونمو',
    'خونه ما',
    'خانه ما',
    'خونمون',
    'زندانم',
    'شکایتم',
    'ازمون',
    'بهمون',
  ].map(PersianText.phrase).toList();

  /// آیا پیام دربارهٔ وضعیت شخصی خود کاربر است (نه یک پرسش کلی)؟
  static bool isPersonal(String rawText) {
    final p = _phrase(rawText);
    return _personalCues.any((c) => p.contains(' $c '));
  }

  static final List<String> _questionCues = [
    'چیست',
    'چیه',
    'چی',
    'چه',
    'چند',
    'چطور',
    'چگونه',
    'چجوری',
    'آیا',
    'کجا',
    'کی',
    'چرا',
    'میشه',
    'می شود',
    'میتونم',
    'می تونم',
    'می توانم',
    'باید',
    'یعنی',
    'کدام',
    'کدوم',
    'شرایط',
    'مجازات',
    'مهلت',
  ].map(PersianText.phrase).toList();

  /// آیا پیام شکل پرسش دارد؟
  static bool isQuestion(String rawText) {
    if (rawText.contains('؟') || rawText.contains('?')) return true;
    final p = _phrase(rawText);
    return _questionCues.any((c) => p.contains(' $c '));
  }

  static final RegExp _leadingGreetingRe = RegExp(
    r'^\s*(?:سلام(?:\s*(?:و\s*)?(?:وقت|روز|عصر|صبح|شب)\s*(?:تون|تان|شما)?\s*(?:بخیر|به\s*خیر))?|درود|وقت\s*(?:تون|تان|شما)?\s*(?:بخیر|به\s*خیر)|صبح\s*بخیر|عصر\s*بخیر|شب\s*بخیر|سلام\s*علیکم)\s*(?:[،,.!؛:\-]+\s*)?(?:(?:آقای|خانم|جناب)?\s*(?:وکیل|دکتر|استاد)\s*[،,.!؛:]*\s*)?',
  );

  /// اگر پیام با سلام شروع شده و بعد از آن پرسش حقوقی آمده، پرسش را جدا
  /// می‌کند. خروجی `(greeted, rest)` است.
  static (bool, String) splitLeadingGreeting(String rawText) {
    final m = _leadingGreetingRe.firstMatch(rawText);
    if (m == null || m.end == 0) return (false, rawText);
    final rest = rawText.substring(m.end).trim();
    if (rest.isEmpty) return (false, rawText);
    return (true, rest);
  }

  // ───────────────────────── ساخت پاسخ ─────────────────────────

  static const List<String> _neutralOpeners = [
    'سؤال مهم و بجایی است. بگذارید ساده و دقیق توضیح بدهم.',
    'پرسش خوبی است؛ خیلی‌ها با همین موضوع روبه‌رو می‌شوند. توضیح می‌دهم.',
    'حتماً؛ این موضوع را روشن و مرحله‌به‌مرحله توضیح می‌دهم.',
    'این از آن موضوع‌هایی است که دانستن جزئیاتش خیلی به کار می‌آید.',
    'بگذارید تصویر کلی را بگویم و بعد برسیم به کارهایی که می‌توانید بکنید.',
    'خلاصه و کاربردی بگویم:',
    'جواب کوتاهش این است، ولی چند ظرافت هم دارد که می‌گویم.',
  ];

  static const List<String> _greetingOpeners = [
    'سلام، وقت شما بخیر.',
    'سلام؛ خوشحالم که پرسیدید.',
    'سلام و احترام.',
    'سلام، در خدمتم.',
    'سلام؛ خوب کردید که پرسیدید.',
  ];

  static const List<String> _stepsHeadsWarm = [
    'پیشنهاد من برای قدم‌های بعدی شما:',
    'اگر جای شما بودم، این کارها را به ترتیب انجام می‌دادم:',
    'از همین امروز می‌توانید این کارها را شروع کنید:',
    'مسیری که پیشنهاد می‌کنم:',
  ];

  static const List<String> _stepsHeadsNeutral = [
    'قدم‌های عملی:',
    'در عمل این‌طور پیش بروید:',
    'کارهایی که باید انجام شود:',
    'ترتیب کار معمولاً این است:',
  ];

  static const List<String> _cautionHeadsOne = [
    'یک نکتهٔ مهم:',
    'فقط حواستان به این باشد:',
    'یک نکته را از قلم نیندازید:',
  ];

  static const List<String> _cautionHeadsMany = [
    'چند نکتهٔ مهم:',
    'چند چیز را حتماً در نظر داشته باشید:',
    'این نکته‌ها کار شما را راحت‌تر می‌کند:',
  ];

  static const List<String> _citeHeads = [
    'مبنای قانونی (از متن رسمی قوانین):',
    'آنچه گفتم بر این مواد تکیه دارد:',
    'متن قانونی مربوط:',
    'مستند قانونی:',
  ];

  static const String disclaimer =
      'این توضیحات برای آشنایی شما با حق و مسیر قانونی است و جای بررسی مدارک پرونده توسط وکیل را نمی‌گیرد.';

  /// با [variator] انتخاب قطعی و بدون تکرار پیاپی؛ بدون آن، رفتار قدیمی
  /// (تصادفی) حفظ می‌شود.
  static String _pick(
    List<String> xs,
    Random? rnd, {
    PhraseVariator? v,
    String key = '',
  }) {
    if (v != null) return v.pick(key, xs);
    return xs[(rnd ?? Random()).nextInt(xs.length)];
  }

  static String _fa(String s) => PersianText.toFaDigits(s);

  /// متن کوتاه‌شدهٔ یک ماده از بانک قوانین برنامه، یا `null` اگر نبود.
  static ({String source, String snippet})? citation(
    KnowledgeEngine engine,
    LegalRef ref, {
    int maxChars = 230,
  }) {
    final c = engine.findArticle(ref.lawId, 'ماده ${ref.article}');
    if (c == null) return null;
    var body = c.body.trim();
    final firstBreak = body.indexOf('\n');
    if (firstBreak > 0 && firstBreak < body.length) {
      final firstLine = body.substring(0, firstBreak).trim();
      if (firstLine.length > 60) body = firstLine;
    }
    body = body.replaceAll(RegExp(r'\s+'), ' ');
    if (body.length > maxChars) {
      var cut = body.lastIndexOf(' ', maxChars);
      if (cut < maxChars ~/ 2) cut = maxChars;
      body = '${body.substring(0, cut).trim()}…';
    }
    return (source: c.source, snippet: body);
  }

  /// قالب‌های پیش‌نویس مرتبط با راهنما (عنوان دقیق قالب، تا لمس دکمه
  /// مستقیماً تنظیم سند را شروع کند).
  static List<String> templateChips(
    LegalGuide g,
    List<LegalTemplate> templates,
  ) {
    final out = <String>[];
    for (final id in g.templateIds) {
      for (final t in templates) {
        if (t.id == id) {
          out.add(t.title);
          break;
        }
      }
    }
    return out;
  }

  /// پاسخ کامل وکیل‌مانند برای یک مسئلهٔ رایج.
  static LawyerReply composeGuide(
    LegalGuide g,
    String rawText,
    KnowledgeEngine engine, {
    List<LegalTemplate> templates = const [],
    bool greeted = false,
    bool includeDisclaimer = false,
    String counselChip = '',
    Random? rnd,
    PhraseVariator? variator,
    CaseFacts? knownFacts,
  }) {
    final v = variator;
    final sb = StringBuffer();
    final empathetic = (knownFacts?.isNotEmpty ?? false) ||
        expressesDistress(rawText) ||
        isPersonal(rawText) ||
        CaseFacts.extract(rawText).counterparties.isNotEmpty;
    if (greeted) {
      sb.write('${_pick(_greetingOpeners, rnd, v: v, key: 'greet')} ');
    }
    sb.write(
      empathetic
          ? g.empathy
          : _pick(_neutralOpeners, rnd, v: v, key: 'opener.neutral'),
    );
    sb.write('\n\n');
    sb.write(_fa(g.answer));

    final personal = isPersonal(rawText) ||
        expressesDistress(rawText) ||
        (knownFacts?.isNotEmpty ?? false);
    final block = personalizedBlock(
      g,
      rawText,
      v: v,
      facts: knownFacts,
      includeFacts: personal,
    );
    if (block.isNotEmpty) {
      sb.write('\n\n');
      sb.write(block);
    }

    if (g.steps.isNotEmpty) {
      sb.write('\n\n');
      sb.write(
        v == null
            ? (empathetic ? _stepsHeadsWarm.first : _stepsHeadsNeutral.first)
            : (empathetic
                ? v.pick('steps.warm', _stepsHeadsWarm)
                : v.pick('steps.neutral', _stepsHeadsNeutral)),
      );
      for (var i = 0; i < g.steps.length; i++) {
        sb.write('\n${_fa('${i + 1}')}. ${_fa(g.steps[i])}');
      }
    }

    if (g.cautions.isNotEmpty) {
      sb.write('\n\n');
      final heads =
          g.cautions.length == 1 ? _cautionHeadsOne : _cautionHeadsMany;
      sb.write(
          v == null ? heads.first : v.pick('caution.${heads.length}', heads));
      for (final c in g.cautions) {
        sb.write('\n• ${_fa(c)}');
      }
    }

    final cites = <String>[];
    for (final r in g.refs) {
      final c = citation(engine, r);
      if (c == null) continue;
      cites.add('• ماده ${_fa(r.article)} ${c.source}: «${_fa(c.snippet)}»');
    }
    if (cites.isNotEmpty) {
      sb.write('\n\n');
      sb.write(v == null ? _citeHeads.first : v.pick('cite', _citeHeads));
      sb.write('\n');
      sb.write(cites.join('\n'));
    }

    sb.write('\n\n');
    // پرسش اول، پرسش دست‌نوشتهٔ راهنماست؛ پرسش‌های بعدی از نیازهای پرونده
    // ([CaseReasoner.nextQuestion]) ساخته می‌شود.
    sb.write(_fa(g.followUp));
    if (includeDisclaimer) {
      sb.write('\n\n');
      sb.write(disclaimer);
    }

    final chips = <String>[
      ...relatedChips(g, rawText),
      if (counselChip.isNotEmpty) counselChip,
      ...templateChips(g, templates),
    ];
    return LawyerReply(text: sb.toString(), chips: chips, guide: g);
  }

  static const List<String> _followUpOpeners = [
    'ممنون که این جزئیات را گفتید؛ همین‌ها تصویر پرونده را روشن‌تر می‌کند.',
    'خوب شد گفتید؛ این اطلاعات در مسیر پرونده شما اهمیت دارد.',
    'این توضیح خیلی به کار می‌آید؛ بگذارید آن را در کنار بقیهٔ ماجرا ببینیم.',
  ];

  static const List<String> _followUpNext = [
    'قدم بعدی که پیشنهاد می‌کنم:',
    'با این اطلاعات، کار بعدی این است:',
    'از اینجا به بعد، این‌طور پیش برویم:',
  ];

  /// پاسخ به پیامی که در ادامهٔ یک راهنما، جزئیات تازه‌ای از ماجرا می‌دهد
  /// (مثل «پیام واتساپ دارم و یه شاهد»). جزئیات تأیید و در پرونده جمع
  /// می‌شود، ارزش مدارک گفته می‌شود و قدم بعدی پیشنهاد می‌شود.
  static LawyerReply composeFollowUp(
    LegalGuide g,
    String rawText, {
    required CaseFacts newFacts,
    required CaseFacts allFacts,
    List<LegalTemplate> templates = const [],
    String counselChip = '',
    PhraseVariator? variator,
    Set<String> skipNeeds = const {},
  }) {
    final v = variator;
    final sb = StringBuffer();
    sb.write(v == null
        ? _followUpOpeners.first
        : v.pick('followup.open', _followUpOpeners));
    final facts = allFacts.render(
      head: 'تا اینجا این‌ها را از ماجرای «${g.title}» یادداشت کرده‌ام:',
    );
    if (facts.isNotEmpty) {
      sb.write('\n\n');
      sb.write(_fa(facts));
    }
    final notes = <String>[
      ...newFacts.evidenceNotes(),
      ...notesFor(g, rawText, allFacts),
    ];
    if (notes.isNotEmpty) {
      sb.write('\n\n');
      sb.write(v == null ? _notesHeads.first : v.pick('notes', _notesHeads));
      for (final n in notes) {
        sb.write('\n• ${_fa(n)}');
      }
    }
    if (g.steps.isNotEmpty) {
      // اگر کاربر مدرک گفته، قدم «جمع‌آوری مدرک» را رد می‌کنیم.
      final idx = newFacts.evidence.isNotEmpty && g.steps.length > 1 ? 1 : 0;
      sb.write('\n\n');
      sb.write(v == null ? _followUpNext.first : v.pick('followup.next', _followUpNext));
      sb.write(' ${_fa(g.steps[idx])}');
    }
    final tChips = templateChips(g, templates);
    sb.write('\n\n');
    final next =
        CaseReasoner.nextQuestion(g, allFacts, v: v, skip: skipNeeds);
    if (next != null) {
      sb.write(_fa(next.$1));
    } else if (CaseReasoner.needsFor(g).isNotEmpty) {
      sb.write(CaseReasoner.chance(g, allFacts, skip: skipNeeds).text);
      sb.write('\n\n');
      sb.write(
        'اگر بپرسید «حالا چیکار کنم؟»، «کجا شکایت کنم؟» یا «اگه انکار کنه چی؟»، دقیق برای همین پرونده جواب می‌دهم.',
      );
    } else if (tChips.isNotEmpty) {
      sb.write(
        'اگر بخواهید، با همین اطلاعات پیش‌نویس «${tChips.first}» را با هم آماده می‌کنیم؛ یا با چند پرسش کوتاه، وضعیت پرونده را دقیق‌تر می‌سنجیم.',
      );
    } else {
      sb.write(
        'اگر بخواهید، با چند پرسش کوتاه وضعیت پرونده را دقیق‌تر می‌سنجیم؛ یا هر جزئیات دیگری هست بگویید.',
      );
    }
    return LawyerReply(
      text: sb.toString(),
      chips: [
        ...tChips,
        if (counselChip.isNotEmpty) counselChip,
      ],
      guide: g,
    );
  }

  static const List<String> clarifyTexts = [
    'حتماً، در خدمتم. برای اینکه دقیق راهنمایی‌تان کنم، ماجرا را به زبان خودتان کمی بیشتر توضیح دهید:\n• چه اتفاقی افتاده است؟\n• طرف مقابل کیست (کارفرما، صاحبخانه، همسر، بدهکار، …)؟\n• از کی شروع شده؟\n• چه مدرکی دارید (قرارداد، رسید، پیام، شاهد)؟\n\nیا اگر موضوع یکی از این‌هاست، روی آن بزنید.',
    'با کمال میل. هر چه دقیق‌تر بگویید، جواب من هم دقیق‌تر و به کارتر می‌شود. کافی است بنویسید:\n• چه پیش آمده و با چه کسی؟\n• چه زمانی؟\n• چه مدرکی در دست دارید؟\n\nاگر موضوع را در فهرست پایین می‌بینید، همان را انتخاب کنید.',
  ];

  static final RegExp _vagueRe = RegExp(
    r'^(?:سلام )?(?:یه|یک|چند)? ?(?:سوال|سئوال|سؤال|مشکل|پرسش|مسئله|مساله)(?: حقوقی)? ?(?:داشتم|دارم|هست|پیش اومده|پیش آمده)?(?: از شما| ازتون| ازت)?$'
    r'|^(?:من )?(?:حقوق من|حقوقم|حق من|حقم) (?:چیه|چیست|چی هست)$'
    r'|^(?:من )?چه حقی دارم$'
    r'|^(?:کمک|مشاوره|راهنمایی) (?:حقوقی )?(?:میخوام|می خوام|می خواهم|لازم دارم)$'
    r'|^(?:میشه|می شه|می شود) (?:کمکم کنی|کمکم کنید|راهنماییم کنی|راهنماییم کنید)$',
  );

  /// پیام کلی و مبهمی مثل «یه سوال حقوقی داشتم» یا «حقوق من چیه؟».
  static bool isVagueIntake(String rawText) =>
      _vagueRe.hasMatch(PersianText.phrase(rawText));

  /// مقدمهٔ همدلانه و خلاصهٔ اولیه برای وقتی که مشاورهٔ گام‌به‌گام شروع
  /// می‌شود؛ تا کاربر پیش از پرسش‌ها، تصویری از وضعیت خودش داشته باشد.
  static String counselPreface(
    LegalGuide g,
    String rawText, {
    PhraseVariator? variator,
  }) {
    final sb = StringBuffer();
    sb.write(g.empathy);
    sb.write('\n\n');
    sb.write(_fa(g.brief));
    final block = personalizedBlock(g, rawText, v: variator);
    if (block.isNotEmpty) {
      sb.write('\n\n');
      sb.write(block);
    }
    return sb.toString();
  }

  // ───────────────────── قاب‌بندی پاسخ موتور ─────────────────────

  static final RegExp _punishRe = RegExp(r'مجازات|جرم|حبس|جزای نقدی');
  static final RegExp _deadlineRe =
      RegExp(r'مهلت|چند روز|تا کی|چه مدت|مرور زمان');
  static final RegExp _defRe = RegExp(r'چیست|چیه|یعنی چه|یعنی چی|تعریف');
  static final RegExp _rightRe =
      RegExp(r'حق دار|میتونم|می تونم|می توانم|میشه|می شود|امکان');

  static const Map<String, List<String>> _engineOpeners = {
    'punish': [
      'قانون برای این موضوع حکم مشخصی دارد؛ مستقیم‌ترین ماده‌ای که به پرسش شما مربوط است این است:',
      'مجازات این کار را قانون صریح گفته است:',
      'در این مورد قانون ساکت نیست؛ ببینید چه گفته:',
    ],
    'deadline': [
      'در موضوع مهلت‌ها باید خیلی دقیق بود، چون از دست رفتن مهلت ممکن است حق را از بین ببرد. متن قانون در این باره:',
      'مهلت‌ها را قانون دقیق تعیین کرده و بهتر است روی تاریخ‌ها حساس باشید:',
      'این مهلت را جدی بگیرید؛ قانون می‌گوید:',
    ],
    'def': [
      'بهترین تعریف را خود قانون داده است؛ ببینید:',
      'تعریف دقیقش در قانون آمده است:',
      'قانون این مفهوم را این‌طور تعریف کرده:',
    ],
    'right': [
      'برای اینکه بدانید چه حقی دارید، اول باید دید قانون دقیقاً چه می‌گوید:',
      'جواب این «می‌شود یا نه» را متن قانون روشن می‌کند:',
      'حق شما در این مورد به این ماده برمی‌گردد:',
    ],
    'generic': [
      'پاسخ پرسش شما را مستند به متن قانون می‌دهم:',
      'نزدیک‌ترین متن قانونی به پرسش شما این است:',
      'در قانون، این ماده دقیقاً به همین موضوع می‌پردازد:',
      'بگذارید از خود متن قانون شروع کنیم:',
      'آنچه قانون در این باره می‌گوید:',
    ],
  };

  static String _engineOpener(
    String q,
    bool greeted,
    Random? rnd, {
    PhraseVariator? v,
  }) {
    final n = PersianText.normalize(q);
    final lead =
        greeted ? '${_pick(_greetingOpeners, rnd, v: v, key: 'greet')} ' : '';
    final kind = _punishRe.hasMatch(n)
        ? 'punish'
        : _deadlineRe.hasMatch(n)
            ? 'deadline'
            : _defRe.hasMatch(n)
                ? 'def'
                : _rightRe.hasMatch(n)
                    ? 'right'
                    : 'generic';
    final pool = _engineOpeners[kind]!;
    final line = v == null ? pool.first : v.pick('engine.$kind', pool);
    return '$lead$line';
  }

  static const List<String> _engineClosers = [
    'اگر بفرمایید دقیقاً در چه وضعیتی هستید (چه اتفاقی افتاده، طرف مقابل کیست و چه مدرکی دارید)، می‌توانم بگویم این ماده در پروندهٔ شما چه معنایی دارد و قدم بعدی‌تان چیست.',
    'اگر این سؤال به وضعیت خاصی مربوط است، کمی بیشتر توضیح دهید تا مسیر عملی (مرجع رسیدگی، مدارک لازم و مهلت‌ها) را هم برایتان روشن کنم.',
    'اگر بخواهید، می‌توانیم با چند سؤال کوتاه وضعیت شما را دقیق‌تر بررسی کنیم تا بدانید دقیقاً چه کاری باید بکنید.',
    'اگر ماجرای خودتان را بگویید، به زبان ساده می‌گویم این ماده برای شما چه نتیجه‌ای دارد.',
    'سؤال دیگری دربارهٔ همین موضوع دارید؟ مثلاً اینکه کجا باید مراجعه کنید یا چه مدارکی لازم است؟',
    'اگر جایی از این متن برایتان مبهم است، بگویید تا همان قسمت را باز کنم.',
  ];

  static const String notFoundText =
      'صادقانه بگویم، در قوانینی که در اختیار دارم متنی پیدا نکردم که دقیقاً به این پرسش پاسخ دهد، و نمی‌خواهم با حدس و گمان راهنمایی‌تان کنم.\n\nاگر کمی بیشتر توضیح دهید، بهتر می‌توانم کمک کنم: موضوع به کدام حوزه مربوط است (چک و طلب، اجاره، کار، خانواده، ارث یا کیفری)، چه اتفاقی افتاده و طرف مقابل کیست؟';

  /// جملهٔ پیوند «پاسخ پل» به نزدیک‌ترین ماده.
  static const String bridgeLeadIn =
      'تا آن موقع، نزدیک‌ترین متنی که در منابع پیدا کردم این است؛ ممکن است '
      'دقیقاً پاسخ وضعیت شما نباشد:';

  static const List<String> _bridgeLeadIns = [
    bridgeLeadIn,
    'در این فاصله، این نزدیک‌ترین ماده‌ای است که پیدا کردم؛ شاید کاملاً بر وضعیت شما منطبق نباشد:',
    'فعلاً این متن به پرسش شما نزدیک‌تر از بقیه است، ولی با جزئیات بیشتر دقیق‌تر می‌شود:',
  ];

  static const List<String> notFoundChips = [
    'چک برگشتی دارم',
    'مشکل اجاره دارم',
    'مشکل با کارفرما دارم',
    'مسئلهٔ خانوادگی دارم',
  ];

  /// پاسخ موتور را با مقدمه و جمع‌بندی انسانی قاب می‌گیرد.
  ///
  /// متن ماده دست‌نخورده می‌ماند تا استناد و ارزیابی‌ها حفظ شود. اگر پاسخ
  /// موتور پیام سیستمی باشد (مثلاً فهرست قوانین)، `null` برمی‌گردد و همان متن
  /// اصلی نمایش داده می‌شود.
  static String? frameEngineAnswer(
    String userText,
    EngineReply reply,
    String shownText, {
    required String notFoundRaw,
    bool greeted = false,
    Random? rnd,
    String? empathy,
    String? notFoundOverride,
    String? bridge,
    PhraseVariator? variator,
  }) {
    final v = variator;
    final shown = shownText.trim();
    if (shown.isEmpty) return null;
    final emp = empathy?.trim() ?? '';
    if (shown == notFoundRaw.trim()) {
      final lead =
          greeted ? '${_pick(_greetingOpeners, rnd, v: v, key: 'greet')} ' : '';
      final distress = emp.isNotEmpty
          ? '$emp\n\n'
          : (expressesDistress(userText) ? 'متوجه نگرانی‌تان هستم. ' : '');
      final body = (notFoundOverride?.trim().isNotEmpty ?? false)
          ? notFoundOverride!.trim()
          : notFoundText;
      return '$lead$distress$body';
    }
    if (reply.contextHits.isEmpty) return null;
    // ارجاع مستقیم به ماده: کاربر متن را خواسته؛ فقط یک جمع‌بندی کوتاه.
    if (isDirectArticleRef(userText)) {
      return '$shown\n\nاگر دربارهٔ معنا یا کاربرد این ماده در وضعیت خودتان سؤالی دارید، بپرسید تا به زبان ساده توضیح بدهم.';
    }
    final sb = StringBuffer();
    final br = bridge?.trim() ?? '';
    if (br.isNotEmpty) {
      // شباهت متوسط: اول برداشت و پرسش جزئیات، بعد نزدیک‌ترین ماده با
      // صراحت دربارهٔ اینکه ممکن است دقیقاً پاسخ وضعیت شما نباشد.
      if (greeted) {
        sb.write('${_pick(_greetingOpeners, rnd, v: v, key: 'greet')} ');
      }
      if (emp.isNotEmpty) sb.write('$emp\n\n');
      sb.write(br);
      sb.write('\n\n');
      sb.write(v == null ? bridgeLeadIn : v.pick('bridge', _bridgeLeadIns));
      sb.write('\n\n');
      sb.write(shown);
      return sb.toString();
    }
    if (emp.isNotEmpty) {
      sb.write('$emp\n\n');
    } else if (expressesDistress(userText)) {
      sb.write('متوجه نگرانی‌تان هستم و کمک می‌کنم موضوع روشن شود. ');
    }
    sb.write(_engineOpener(userText, greeted, rnd, v: v));
    sb.write('\n\n');
    sb.write(shown);
    sb.write('\n\n');
    sb.write(_pick(_engineClosers, rnd, v: v, key: 'engine.closer'));
    return sb.toString();
  }
}
