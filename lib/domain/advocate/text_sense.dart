import 'package:dastyar/core/persian_text.dart';

/// فهم سطحی متن محاوره‌ای فارسی، بدون هیچ مدل آماری یا زبانی: فقط
/// یکسان‌سازی نویسه‌ها، الگوهای منظم و چند تجزیه‌گر کوچک (مبلغ، مدت).
class Sense {
  Sense._();

  static final Map<String, RegExp> _cache = {};

  static RegExp rx(String p) => _cache.putIfAbsent(p, () => RegExp(p));

  /// آیا الگو در متنِ یکسان‌شده هست؟
  static bool has(String n, String p) => rx(p).hasMatch(n);

  static const String _lb = r'(?<![\u0600-\u06FF])';
  static const String _rb = r'(?![\u0600-\u06FF])';

  /// تطبیق به‌صورت واژهٔ کامل (نه بخشی از واژهٔ دیگر).
  static bool word(String n, String alts) =>
      rx('$_lb(?:$alts)$_rb').hasMatch(n);

  static final RegExp _punct = RegExp(r'[،؛,!«»"()\[\]{}:;_\-/\\*…]+');
  static final RegExp _dot = RegExp(r'(?<![0-9])\.|\.(?![0-9])');
  static final RegExp _ws = RegExp(r'\s+');
  static final RegExp _mi = RegExp(r'(^| )(ن?می) (?=[\u0600-\u06FF])');

  static const List<List<String>> _canon = [
    ['چی ?کار|چکار|چه کار', 'چه کار'],
    ['صاب ?خونه|صاحب ?خونه|صاحب ?خانه', 'صاحبخونه'],
    ['خانه', 'خونه'],
    ['تومن', 'تومان'],
    ['ملیون', 'میلیون'],
    ['ملیارد', 'میلیارد'],
    ['بازم', 'باز هم'],
    [' اگه ', ' اگر '],
    [' واسه ', ' برای '],
    ['کارفرمام', 'کارفرما من'],
    ['شکواییه', 'شکوائیه'],
    ['اجراییه', 'اجرائیه'],
  ];

  /// متن را برای تطبیق الگو آماده می‌کند: نویسه‌ها یکسان، ارقام لاتین،
  /// علائم حذف، «می/نمی» به فعل چسبیده و دو سرِ متن فاصله‌دار.
  static String norm(String s) {
    var t = PersianText.normalize(s);
    t = t.replaceAll('?', '؟').replaceAll('؟', ' ؟ ');
    t = t.replaceAll(_punct, ' ');
    t = t.replaceAll(_dot, ' ');
    t = t.replaceAll(_ws, ' ').trim();
    t = t.replaceAllMapped(_mi, (m) => '${m[1]}${m[2]}');
    t = ' $t ';
    for (final c in _canon) {
      t = t.replaceAll(rx(c[0]), c[1]);
    }
    return t;
  }

  static int words(String n) {
    final t = n.replaceAll('؟', ' ').trim();
    if (t.isEmpty) return 0;
    return t.split(_ws).length;
  }

  static bool isQuestion(String n) => has(
        n,
        '؟|چطور|چجوری|چه جوری|چگونه|چقدر|چند |کجا|کی |چرا|آیا|ایا |میشه |میتونم|میتونه|چیه |چیست|چی میشه| یا نه ',
      );

  // ---------------------------------------------------------------- اعداد

  static const Map<String, int> _numWords = {
    'یک': 1, 'یه': 1, 'دو': 2, 'سه': 3, 'چهار': 4, 'چار': 4, 'پنج': 5,
    'شش': 6, 'شیش': 6, 'هفت': 7, 'هشت': 8, 'نه': 9, 'ده': 10, 'یازده': 11,
    'دوازده': 12, 'پانزده': 15, 'پونزده': 15, 'بیست': 20, 'سی': 30,
    'چهل': 40, 'پنجاه': 50, 'شصت': 60, 'هفتاد': 70, 'هشتاد': 80, 'نود': 90,
    'صد': 100, 'دویست': 200, 'سیصد': 300, 'چهارصد': 400, 'پانصد': 500,
    'پونصد': 500, 'ششصد': 600, 'هفتصد': 700, 'هشتصد': 800, 'نهصد': 900,
  };

  static final String _numAlt =
      '[0-9]+(?:[.][0-9]+)?|نیم|${_numWords.keys.join('|')}';

  static double? _num(String w) {
    if (w == 'نیم') return 0.5;
    final d = double.tryParse(w);
    if (d != null) return d;
    final i = _numWords[w];
    return i?.toDouble();
  }

  static double _mul(String unit) {
    if (unit.startsWith('میلیارد')) return 1000000000;
    if (unit.startsWith('میلیون')) return 1000000;
    return 1000;
  }

  /// نخستین مبلغِ متن به تومان (یا null).
  static int? amount(String n) {
    final m = rx(
      '(?<= )($_numAlt) ?(میلیارد|میلیون|هزار)'
      '(?: و ($_numAlt) ?(میلیون|هزار))?( تومان| ریال)?',
    ).firstMatch(n);
    if (m != null) {
      var v = (_num(m[1]!) ?? 0) * _mul(m[2]!);
      if (m[3] != null && m[4] != null) {
        v += (_num(m[3]!) ?? 0) * _mul(m[4]!);
      }
      if ((m[5] ?? '').contains('ریال')) v = v / 10;
      return v.round();
    }
    final p = rx('(?<= )([0-9]{4,}) ?(تومان|ریال)').firstMatch(n);
    if (p != null) {
      final v = int.tryParse(p[1]!) ?? 0;
      return p[2] == 'ریال' ? v ~/ 10 : v;
    }
    // «۳۰ تومن» در گفتار روزمره یعنی ۳۰ میلیون تومان.
    final c = rx('(?<= )([0-9]{1,3}) ?تومان').firstMatch(n);
    if (c != null) return (int.tryParse(c[1]!) ?? 0) * 1000000;
    return null;
  }

  /// مثل [amount]، ولی عددِ تنها («۳۰») را هم میلیون تومان می‌گیرد؛ فقط
  /// وقتی به کار می‌رود که همین حالا مبلغ پرسیده شده باشد.
  static int? looseAmount(String n) {
    final a = amount(n);
    if (a != null) return a;
    final m = rx('^ ?([0-9]{1,3}) ?\$').firstMatch(n);
    if (m == null) return null;
    return (int.tryParse(m[1]!) ?? 0) * 1000000;
  }

  /// آیا مبلغ با واحد روشن گفته شده (میلیون، هزار، …)؟
  static bool amountIsExplicit(String n) =>
      has(n, 'میلیون|میلیارد|هزار|ریال|[0-9]{4,}');

  /// نخستین مدتِ متن به ماه (سال×۱۲؛ هفته و روز به کسری از ماه).
  static double? months(String n) {
    final m = rx('(?<= )($_numAlt) ?(سال|ماه|هفته|روز)').firstMatch(n);
    if (m == null) return null;
    final v = _num(m[1]!);
    if (v == null) return null;
    switch (m[2]) {
      case 'سال':
        return v * 12;
      case 'ماه':
        return v;
      case 'هفته':
        return v / 4.0;
      default:
        return v / 30.0;
    }
  }

  /// عددِ پیش از یک واژه (مثل «۵ ساله»، «۱۱۰ سکه»).
  static int? numberBefore(String n, String unitAlts) {
    final m = rx('(?<= )($_numAlt) ?(?:تا )?(?:$unitAlts)').firstMatch(n);
    if (m == null) return null;
    return _num(m[1]!)?.round();
  }

  // --------------------------------------------------------------- نمایش

  static String fa(Object o) => PersianText.toFaDigits(o.toString());

  static String toman(int t) {
    if (t >= 1000000000) {
      final b = t ~/ 1000000000;
      final m = (t % 1000000000) ~/ 1000000;
      return m == 0
          ? '${fa(b)} میلیارد تومان'
          : '${fa(b)} میلیارد و ${fa(m)} میلیون تومان';
    }
    if (t >= 1000000) {
      final m = t ~/ 1000000;
      final k = (t % 1000000) ~/ 1000;
      return k == 0
          ? '${fa(m)} میلیون تومان'
          : '${fa(m)} میلیون و ${fa(k)} هزار تومان';
    }
    if (t >= 1000) return '${fa(t ~/ 1000)} هزار تومان';
    return '${fa(t)} تومان';
  }

  /// مدت به زبان آدمیزاد («۴ سال»، «۲ سال و ۶ ماه»، «۳ ماه»).
  static String span(int months) {
    final y = months ~/ 12;
    final m = months % 12;
    if (y == 0) return '${fa(m)} ماه';
    if (m == 0) return '${fa(y)} سال';
    return '${fa(y)} سال و ${fa(m)} ماه';
  }

  /// بله/نه بر پایهٔ دو الگو؛ الگوی منفی مقدم است.
  static String? yn(String n, String yes, String no) {
    if (no.isNotEmpty && has(n, no)) return 'no';
    if (yes.isNotEmpty && has(n, yes)) return 'yes';
    return null;
  }

  // ------------------------------------------------------ کنش‌های گفتاری

  static bool saysYes(String n) =>
      words(n) <= 5 &&
      has(n,
          '^ (?:اره|آره|بله|بلی|اوهوم|درسته|همینطوره|همین طوره|دقیقا|دارم|داره|داریم|گرفتم|هست|شده|دادم|اومده|آمده|رسیده|میخوام)(?: |\$)');

  static bool saysNo(String n) =>
      words(n) <= 5 &&
      has(n,
          '^ (?:نه|نخیر|خیر|ندارم|نداره|نداریم|نگرفتم|نیست|نشده|ندادم|نیومده|نیامده|هنوز نه|هیچی|هیچ|اصلا|نمیخوام)(?: |\$)');

  static bool saysDontKnow(String n) => has(
        n,
        'نمیدونم|نمیدانم|مطمئن نیستم|خبر ندارم|یادم نیست|اطلاع ندارم|نمیدونم والا',
      );

  /// نوع پرسشِ پیگیری (مستقل از موضوع)، یا رشتهٔ خالی.
  static String followKind(String n) {
    if (has(n,
        'اگر (?:باز هم |بازهم |دوباره )?(?:نداد|نده|ندهد|نیومد|نیاد|نیامد|قبول نکرد|قبول نکنه|گوش نکرد|گوش نداد|جواب نداد|انکار کرد|زیرش زد|نپرداخت|پرداخت نکرد|محل نذاشت|عمل نکرد)|نداد چی|نیومد چی|ندن چی|قبول نکرد چی')) {
      return 'refuse';
    }
    if (has(n,
        'چه مدرک|چه مدارک|مدرک(?:ی)? لازم|چی لازم|چی ببرم|چه دلیل|چطور(?:ی)? ثابت|چجوری ثابت|چه جوری ثابت|اثبات کنم|ثابت کنم|مدارک لازم')) {
      return 'evidence';
    }
    if (has(n,
        'هزینه|خرج(?:ش)? (?:چقدر|چنده|داره|زیاد|برمیداره|میشه)|چقدر خرج|چقدر (?:باید )?(?:پول )?(?:بدم|میگیرن|آب میخوره)|چقدر تموم میشه|هزینش|پول وکیل|تعرفه')) {
      return 'cost';
    }
    if (has(n,
        'چقدر طول|چند وقت طول|کی تموم|چند ماه طول|زمان میبره|طول میکشه|چقدر زمان|چند وقته جواب')) {
      return 'time';
    }
    if (has(n,
        'مهلت|تا کی وقت|دیر شده|دیر نشده|مرور زمان|فرصت دارم|چند روز وقت|وقت دارم')) {
      return 'deadline';
    }
    if (has(n,
        'شانس|برنده میشم|میبرم |میبازم|به نفع من|احتمال|نتیجه میگیرم|به جایی میرسه|ارزش داره|جواب میده |فایده داره|میتونم بگیرم|پس میگیرم')) {
      return 'chance';
    }
    if (has(n,
        'کجا (?:برم|باید|شکایت|مراجعه|ثبت|اقدام)|به کجا|کدوم دادگاه|کدام دادگاه|کدوم مرجع|مرجع صالح|کجا شکایت|کجا باید')) {
      return 'where';
    }
    if (has(n,
        'وکیل (?:بگیرم|لازم|میخواد|میخوام|نیاز|باید)|بدون وکیل|خودم میتونم|وکیل نگیرم')) {
      return 'lawyer';
    }
    if (has(n,
        'چه کار کنم|چه کنم|باید چه کار|چه کار باید|از کجا شروع|قدم بعد|بعدش چی|حالا چی|راه حل|راهش چیه|چه کاری از دستم|چطور(?:ی)? (?:پس )?بگیرم|چجوری (?:پس )?بگیرم|چه اقدامی|مراحل')) {
      return 'next';
    }
    return '';
  }
}
