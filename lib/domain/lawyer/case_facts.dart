/// استخراج «واقعیت‌های پرونده» از متن آزاد کاربر.
///
/// وکیل خوب جزئیاتی را که موکل گفته دوباره نمی‌پرسد و آن‌ها را در پاسخش
/// منعکس می‌کند. این کلاس، بدون هیچ مدل زبانی و کاملاً قطعی، مبلغ، زمان،
/// طرف مقابل، مدارک، سن و تعداد فرزندان و چند وضعیت مهم (مثل «قرارداد تمام
/// شده» یا «بیمه ندارد») را از پیام بیرون می‌کشد.
///
/// همهٔ تطبیق‌ها روی متن یکدست‌شده ([PersianText.phrase]) انجام می‌شود تا
/// «ي/ك» عربی، ارقام فارسی و نیم‌فاصله مشکلی ایجاد نکنند.
library;

import 'package:dastyar/core/persian_text.dart';

/// وضعیت‌های مهمی که در پاسخ و یادداشت‌های راهنما به کار می‌آیند.
class CaseFlag {
  CaseFlag._();
  static const String contractEnded = 'contract_ended';
  static const String fired = 'fired';
  static const String noInsurance = 'no_insurance';
  static const String unreachable = 'unreachable';
  static const String detained = 'detained';
  static const String refusesPay = 'refuses_pay';
  static const String leftHome = 'left_home';
  static const String noEvidence = 'no_evidence';
  static const String noWrittenContract = 'no_written_contract';
  static const String minor = 'minor';
  static const String coinsOver110 = 'coins_over_110';
  static const String injured = 'injured';
}

class CaseFacts {
  /// مبلغ‌ها همان‌طور که کاربر گفته (با ارقام فارسی).
  final List<String> amounts;

  /// زمان یا مدت («دو ماه پیش»، «۳ ماه»).
  final List<String> durations;

  /// طرف مقابل ماجرا.
  final List<String> counterparties;

  /// مدارکی که کاربر دارد (کلید داخلی).
  final List<String> evidence;

  /// تعداد فرزندان، اگر گفته شده.
  final int? children;

  /// سن‌های ذکرشده.
  final List<int> ages;

  /// تعداد سکهٔ مهریه، اگر گفته شده.
  final int? coins;

  final Set<String> flags;

  const CaseFacts({
    this.amounts = const [],
    this.durations = const [],
    this.counterparties = const [],
    this.evidence = const [],
    this.children,
    this.ages = const [],
    this.coins,
    this.flags = const {},
  });

  static const CaseFacts empty = CaseFacts();

  bool get isEmpty =>
      amounts.isEmpty &&
      durations.isEmpty &&
      counterparties.isEmpty &&
      evidence.isEmpty &&
      children == null &&
      ages.isEmpty &&
      flags.isEmpty;

  bool get isNotEmpty => !isEmpty;

  bool has(String flag) => flags.contains(flag);

  /// ادغام واقعیت‌های پیام تازه با آنچه قبلاً گفته شده (بدون تکرار).
  CaseFacts merge(CaseFacts o) {
    List<T> u<T>(List<T> a, List<T> b) => [
          ...a,
          for (final x in b)
            if (!a.contains(x)) x,
        ];
    return CaseFacts(
      amounts: u(amounts, o.amounts),
      durations: u(durations, o.durations),
      counterparties: u(counterparties, o.counterparties),
      evidence: u(evidence, o.evidence),
      children: o.children ?? children,
      ages: u(ages, o.ages),
      coins: o.coins ?? coins,
      flags: {...flags, ...o.flags},
    );
  }

  // ───────────────────────── واژگان ─────────────────────────

  static const String _numWords =
      'یک|یه|دو|سه|چهار|پنج|شش|شیش|هفت|هشت|نه|ده|یازده|دوازده|پانزده|'
      'بیست|سی|چهل|پنجاه|شصت|هفتاد|هشتاد|نود|صد|دویست|سیصد|چهارصد|پانصد|'
      'پونصد|ششصد|هفتصد|هشتصد|نهصد|چند|نیم';

  static final RegExp _amountRe = RegExp(
    '(?:^| )((?:\\d+(?: \\d{3})*|(?:$_numWords)(?: و (?:$_numWords))*) '
    '(?:(?:میلیارد|میلیون|هزار)(?: (?:تومان|تومن|ریال))?|تومان|تومن|ریال))'
    '(?= |\$)',
  );

  static final RegExp _coinRe =
      RegExp('(?:^| )((\\d+)|(?:$_numWords)) (?:تا )?(?:سکه)');

  static final RegExp _durationRe = RegExp(
    '(?:^| )((?:\\d+|$_numWords) (?:روز|هفته|ماه|سال))(ه)?'
    '(?: (پیش|قبل))?(?= |\$)',
  );

  static final RegExp _ageRe =
      RegExp(r'(?:^| )(\d{1,2}) ?(?:سالشه|ساله|سالمه|سالش|سالشونه|سالشان)');

  static final RegExp _childrenRe = RegExp(
    '(?:^| )(\\d+|یک|یه|دو|سه|چهار|پنج|شش) (?:تا )?(?:بچه|فرزند|اولاد)',
  );

  static const Map<String, int> _smallNums = {
    'یک': 1,
    'یه': 1,
    'دو': 2,
    'سه': 3,
    'چهار': 4,
    'پنج': 5,
    'شش': 6,
  };

  /// (نشانه‌ها، برچسب نمایشی). ترتیب = ترتیب نمایش.
  static const List<(List<String>, String)> _parties = [
    (['صاحبخانه', 'صاحبخونه', 'صاحب خانه', 'صاحب خونه', 'موجر'], 'صاحبخانه'),
    (['مستاجر', 'مستأجر'], 'مستأجر'),
    (['کارفرما', 'رئیسم', 'رییسم', 'صاحب کارم', 'صاحبکارم'], 'کارفرما'),
    (['شوهرم', 'شوهر', 'همسرم', 'زنم', 'خانمم'], 'همسر'),
    (['دوستم', 'رفیقم'], 'دوست'),
    (['برادرم', 'داداشم', 'خواهرم', 'آبجیم'], 'خواهر یا برادر'),
    (['همسایه'], 'همسایه'),
    (['همکارم', 'همکار'], 'همکار'),
    (['سازنده', 'بساز بفروش', 'پیمانکار'], 'سازنده'),
    (['فروشنده', 'مغازه دار', 'نمایشگاه'], 'فروشنده'),
    (['طلبکار'], 'طلبکار'),
    (['بدهکار'], 'بدهکار'),
    (['شریکم', 'شریک'], 'شریک'),
  ];

  /// (کلید، نشانه‌ها). برچسب‌ها در [evidenceLabel].
  static const List<(String, List<String>)> _evidence = [
    ('messages', ['واتساپ', 'واتس اپ', 'پیامک', 'پیام', 'چت', 'تلگرام', 'ایتا']),
    ('screenshot', ['اسکرین شات', 'اسکرین', 'عکس از صفحه']),
    ('witness', ['شاهد', 'شهود', 'شاهدم']),
    ('contract', ['قرارداد', 'قولنامه', 'اجاره نامه', 'مبایعه نامه']),
    ('receipt', ['رسید', 'واریز', 'فیش', 'کارت به کارت', 'پرینت حساب']),
    ('cheque', ['چک']),
    ('promissory', ['سفته']),
    ('police_report', ['کروکی', 'گزارش پلیس']),
    ('recording', ['صدا ضبط', 'ضبط کردم', 'فایل صوتی', 'ویس']),
    ('photos', ['عکس دارم', 'عکس گرفتم', 'فیلم دارم', 'فیلم گرفتم', 'عکس و فیلم', 'عکس از', 'فیلم از', 'عکسها رو دارم']),
  ];

  static const Map<String, String> evidenceLabel = {
    'messages': 'پیام‌ها (واتساپ/پیامک)',
    'screenshot': 'اسکرین‌شات',
    'witness': 'شاهد',
    'contract': 'قرارداد',
    'receipt': 'رسید یا سابقهٔ واریز بانکی',
    'cheque': 'چک',
    'promissory': 'سفته',
    'police_report': 'کروکی یا گزارش پلیس',
    'recording': 'فایل صوتی',
    'photos': 'عکس یا فیلم',
  };

  static const List<String> _negAfter = [
    ' ندارم',
    ' نداریم',
    ' نداشتم',
    ' نداشتیم',
    ' ننوشتیم',
    ' نبستیم',
    ' نگرفتم',
    ' نیست',
    ' نداره',
    'ی ندارم',
    'ی نداریم',
    'ی نداشتیم',
    'ی ننوشتیم',
    'ی نبستیم',
    'ی در کار نیست',
  ];

  static const Map<String, List<String>> _flagCues = {
    CaseFlag.contractEnded: [
      'تموم شده',
      'تمام شده',
      'تموم شد',
      'تمام شد',
      'سر رسیده',
      'سررسید شده',
      'به پایان رسیده',
      'منقضی شده',
    ],
    CaseFlag.fired: [
      'اخراجم',
      'اخراج شدم',
      'اخراج کرد',
      'اخراج کردن',
      'بیرونم کرد',
      'بیرونم کردن',
      'عذرمو خواست',
      'عذرم را خواست',
      'تعدیلم',
    ],
    CaseFlag.noInsurance: [
      'بیمه ندار',
      'بیمه نداره',
      'بیمه نداشت',
      'بیمه نکرده',
      'بیمه نکرد',
      'بیمه ام نکرده',
      'بیمم نکرده',
      'بیمه رد نکرده',
      'بیمه نمیکنه',
      'بیمه نمی کند',
    ],
    CaseFlag.unreachable: [
      'جواب تلفن',
      'جوابمو نمیده',
      'جواب نمیده',
      'جواب نمی دهد',
      'در دسترس نیست',
      'گوشیشو خاموش',
      'گوشیش خاموش',
      'فرار کرده',
      'غیبش زده',
      'بلاکم کرده',
      'بلاک کرده',
    ],
    CaseFlag.detained: [
      'بازداشت',
      'دستگیر',
      'گرفتنش',
      'بردنش کلانتری',
      'بردنش آگاهی',
    ],
    CaseFlag.refusesPay: [
      'نمیده',
      'نمی دهد',
      'پس نمیده',
      'پس نمی دهد',
      'پرداخت نمیکنه',
      'پرداخت نمی کند',
      'نداده',
      'نمیپردازه',
      'زیر بار نمیره',
    ],
    CaseFlag.leftHome: [
      'قهر کرده',
      'از خونه رفته',
      'از خانه رفته',
      'خونه رو ترک',
      'خانه را ترک',
      'ترکم کرده',
      'ولمون کرده',
      'رفته خونه باباش',
      'رفته خانه پدرش',
    ],
    CaseFlag.noEvidence: [
      'مدرکی ندارم',
      'مدرک ندارم',
      'هیچ مدرکی',
      'سندی ندارم',
      'سند ندارم',
      'هیچ سندی',
      'دلیلی ندارم',
      'مدرکی نداریم',
    ],
    CaseFlag.noWrittenContract: [
      'قرارداد ندارم',
      'قراردادی ندارم',
      'قرارداد نداریم',
      'قراردادی نداریم',
      'قرارداد نبستیم',
      'قراردادی نبستیم',
      'قرارداد ننوشتیم',
      'قرارداد کتبی نداریم',
      'قرارداد نداشتیم',
      'قراردادی نداشتیم',
    ],
    CaseFlag.injured: [
      'زخمی',
      'مصدوم',
      'آسیب دیدم',
      'آسیب دید',
      'بیمارستان',
      'شکستگی',
    ],
  };

  static const Map<String, String> flagLabel = {
    CaseFlag.contractEnded: 'مدت قرارداد تمام شده',
    CaseFlag.fired: 'کار شما قطع شده (اخراج)',
    CaseFlag.noInsurance: 'بیمه وجود ندارد یا پرداخت نشده',
    CaseFlag.unreachable: 'طرف مقابل پاسخ نمی‌دهد یا در دسترس نیست',
    CaseFlag.detained: 'فرد بازداشت شده است',
    CaseFlag.refusesPay: 'طرف مقابل به تعهدش عمل نمی‌کند (پرداخت، استرداد یا تحویل)',
    CaseFlag.leftHome: 'همسر خانه را ترک کرده است',
    CaseFlag.noEvidence: 'فعلاً مدرک کتبی ندارید',
    CaseFlag.noWrittenContract: 'قرارداد کتبی ندارید',
    CaseFlag.injured: 'آسیب جسمی وارد شده',
  };

  // ───────────────────────── استخراج ─────────────────────────

  static String _p(String raw) => ' ${PersianText.phrase(raw)} ';

  static bool _negatedAt(String p, int end) {
    final tail = p.substring(end);
    return _negAfter.any(tail.startsWith);
  }

  static CaseFacts extract(String rawText) {
    if (rawText.trim().isEmpty) return empty;
    final p = _p(rawText);
    final core = p.trim();

    final amounts = <String>[];
    for (final m in _amountRe.allMatches(core)) {
      final s = PersianText.toFaDigits(m.group(1)!.trim());
      if (!amounts.contains(s)) amounts.add(s);
    }

    int? coins;
    final cm = _coinRe.firstMatch(core);
    if (cm != null) {
      final d = cm.group(2);
      coins = d == null ? null : int.tryParse(d);
      final s = '${PersianText.toFaDigits(cm.group(1)!.trim())} سکه';
      if (!amounts.contains(s)) amounts.add(s);
    }

    final durations = <String>[];
    for (final m in _durationRe.allMatches(core)) {
      final base = m.group(1)!;
      if (base.startsWith('نیم ')) continue;
      final ago = m.group(3);
      final s = PersianText.toFaDigits(ago == null ? base : '$base پیش');
      if (!durations.contains(s)) durations.add(s);
    }

    final ages = <int>[];
    for (final m in _ageRe.allMatches(core)) {
      final a = int.tryParse(m.group(1)!);
      if (a != null && a > 0 && a < 100 && !ages.contains(a)) ages.add(a);
    }

    int? children;
    final ch = _childrenRe.firstMatch(core);
    if (ch != null) {
      final g = ch.group(1)!;
      children = int.tryParse(g) ?? _smallNums[g];
    }

    final parties = <String>[];
    for (final (cues, label) in _parties) {
      if (cues.any((c) => p.contains(' ${PersianText.phrase(c)}'))) {
        if (!parties.contains(label)) parties.add(label);
      }
    }

    final flags = <String>{};
    _flagCues.forEach((flag, cues) {
      if (cues.any((c) => p.contains(' ${PersianText.phrase(c)}'))) {
        flags.add(flag);
      }
    });
    if (flags.contains(CaseFlag.contractEnded) &&
        !RegExp(r' (قرارداد|اجاره|مدت|اجاره نامه|قراردادم|قراردادمون) ')
            .hasMatch(p) &&
        !p.contains(' قرارداد')) {
      flags.remove(CaseFlag.contractEnded);
    }
    if (ages.any((a) => a < 18) ||
        p.contains(' نوجوان') ||
        p.contains(' زیر 18')) {
      flags.add(CaseFlag.minor);
    }
    if (coins != null && coins > 110) flags.add(CaseFlag.coinsOver110);

    final evidence = <String>[];
    for (final (key, cues) in _evidence) {
      for (final c in cues) {
        final needle = ' ${PersianText.phrase(c)}';
        var i = p.indexOf(needle);
        var positive = false;
        while (i >= 0) {
          final wordEnd = p.indexOf(' ', i + needle.length);
          final endExact = i + needle.length;
          final end = wordEnd < 0 ? endExact : wordEnd;
          if (!_negatedAt(p, endExact) && !_negatedAt(p, end)) {
            positive = true;
            break;
          }
          i = p.indexOf(needle, i + 1);
        }
        if (positive) {
          if (!evidence.contains(key)) evidence.add(key);
          break;
        }
      }
    }
    // «قرارداد تموم شده» یعنی قراردادی وجود دارد؛ «قرارداد ندارم» یعنی ندارد.
    if (flags.contains(CaseFlag.noWrittenContract)) evidence.remove('contract');
    // چک وقتی موضوع اصلی دعواست مدرک جداگانه حساب نمی‌شود، ولی نمایشش ضرری
    // ندارد؛ اما «پیام» در «پیام دادم جواب نداد» هم مدرک است.

    return CaseFacts(
      amounts: amounts,
      durations: durations,
      counterparties: parties,
      evidence: evidence,
      children: children,
      ages: ages,
      coins: coins,
      flags: flags,
    );
  }

  // ───────────────────────── نمایش ─────────────────────────

  /// سطرهای یادداشت برای نمایش به کاربر.
  List<String> summaryLines() {
    final out = <String>[];
    if (amounts.isNotEmpty) out.add('مبلغ: ${amounts.join('، ')}');
    if (durations.isNotEmpty) out.add('زمان: ${durations.join('، ')}');
    if (counterparties.isNotEmpty) {
      out.add('طرف مقابل: ${counterparties.join('، ')}');
    }
    if (children != null) {
      out.add('فرزندان: ${PersianText.toFaDigits('$children')} فرزند');
    }
    if (ages.isNotEmpty) {
      out.add(
        'سن: ${ages.map((a) => PersianText.toFaDigits('$a')).join('، ')} سال',
      );
    }
    if (evidence.isNotEmpty) {
      out.add(
        'مدارک: ${evidence.map((e) => evidenceLabel[e] ?? e).join('، ')}',
      );
    }
    for (final f in [
      CaseFlag.contractEnded,
      CaseFlag.fired,
      CaseFlag.noInsurance,
      CaseFlag.refusesPay,
      CaseFlag.unreachable,
      CaseFlag.leftHome,
      CaseFlag.detained,
      CaseFlag.injured,
      CaseFlag.noWrittenContract,
      CaseFlag.noEvidence,
    ]) {
      final l = flagLabel[f];
      if (flags.contains(f) && l != null) out.add(l);
    }
    return out;
  }

  static const String summaryHead = 'از صحبت شما این‌ها را یادداشت کردم:';

  /// بلوک «یادداشت‌ها»، یا رشتهٔ خالی اگر چیزی استخراج نشده.
  String render({String head = summaryHead}) {
    final lines = summaryLines();
    if (lines.isEmpty) return '';
    return '$head\n${lines.map((l) => '• $l').join('\n')}';
  }

  /// نکته‌های عمومی و بی‌خطر دربارهٔ ارزش مدارکی که کاربر گفته.
  List<String> evidenceNotes() {
    final out = <String>[];
    if (evidence.contains('messages') || evidence.contains('screenshot')) {
      out.add(
        'پیام‌ها را پاک نکنید؛ از آن‌ها همراه با تاریخ و شمارهٔ فرستنده اسکرین‌شات بگیرید و نسخه‌ای جای امن نگه دارید. دادگاه این پیام‌ها را در کنار سایر قرائن بررسی می‌کند و اگر طرف مقابل انکار کند، ممکن است به کارشناسی ارجاع شود.',
      );
    }
    if (evidence.contains('witness')) {
      out.add(
        'شهادت شاهد از دلایل پذیرفته‌شده در دادگاه است؛ نام و نشانی شاهد را داشته باشید و از آمادگی او برای حضور در جلسه مطمئن شوید.',
      );
    }
    if (evidence.contains('receipt')) {
      out.add(
        'رسید یا سابقهٔ واریز بانکی نشان می‌دهد پول چه زمانی و به حساب چه کسی رفته است؛ پرینت گردش حساب را از بانک بگیرید.',
      );
    }
    if (evidence.contains('contract')) {
      out.add(
        'متن قرارداد ملاک اصلی است؛ بندهای مربوط به مدت، مبلغ و شرط‌های جریمه یا فسخ را پیدا کنید و همراه داشته باشید.',
      );
    }
    if (evidence.contains('recording')) {
      out.add(
        'فایل صوتی را بدون ویرایش و با فایل اصلی نگه دارید؛ ارزش آن را دادگاه در کنار سایر دلایل می‌سنجد.',
      );
    }
    if (evidence.contains('photos')) {
      out.add(
        'عکس‌ها و فیلم‌ها را با فایل اصلی (که تاریخ ثبت دارد) نگه دارید و ویرایش نکنید؛ اگر ممکن است آثار از بین برود، از دادگاه یا شورا «تأمین دلیل» بخواهید تا وضعیت رسماً ثبت شود.',
      );
    }
    if (flags.contains(CaseFlag.noWrittenContract)) {
      out.add(
        'نبودن قرارداد کتبی به معنای از دست رفتن حق شما نیست؛ رابطه و توافق را می‌شود با شاهد، پیام‌ها و سوابق واریز هم ثابت کرد.',
      );
    }
    if (flags.contains(CaseFlag.noEvidence) && evidence.isEmpty) {
      out.add(
        'نداشتن سند کتبی پایان راه نیست؛ اقرار طرف مقابل، شهادت شهود، پیام‌ها و سوابق بانکی هم در دادگاه دلیل به حساب می‌آیند. پیش از اقدام، همهٔ این‌ها را جمع کنید.',
      );
    }
    return out;
  }
}
