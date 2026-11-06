import 'dart:math';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';
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
    if (rawText.trim().isEmpty || isDirectArticleRef(rawText)) return null;
    final p = _phrase(rawText);
    LegalGuide? best;
    var bestScore = 0;
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
      if (score > bestScore) {
        bestScore = score;
        best = g;
      }
    }
    return best;
  }

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
  }) {
    final v = variator;
    final sb = StringBuffer();
    final empathetic = expressesDistress(rawText) || isPersonal(rawText);
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
    sb.write(_fa(g.followUp));
    if (includeDisclaimer) {
      sb.write('\n\n');
      sb.write(disclaimer);
    }

    final chips = <String>[
      if (counselChip.isNotEmpty) counselChip,
      ...templateChips(g, templates),
    ];
    return LawyerReply(text: sb.toString(), chips: chips, guide: g);
  }

  /// مقدمهٔ همدلانه و خلاصهٔ اولیه برای وقتی که مشاورهٔ گام‌به‌گام شروع
  /// می‌شود؛ تا کاربر پیش از پرسش‌ها، تصویری از وضعیت خودش داشته باشد.
  static String counselPreface(LegalGuide g, String rawText) {
    final sb = StringBuffer();
    sb.write(g.empathy);
    sb.write('\n\n');
    sb.write(_fa(g.brief));
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
