// تولیدشده از tools/contracts/text_norm.json — دستی ویرایش نکنید.
// تولید دوباره: python3 tools/gen_text_norm.py --write
// بررسی تازگی:  python3 tools/gen_text_norm.py --check


/// قاعده‌های یکدست‌سازی متن — تنها مرجع، `tools/contracts/text_norm.json`.
///
/// پیش‌تر همین نگاشت‌ها و مجموعه‌ها در `persian_text.dart`، `text_sense.dart`
/// و سه ابزار پایتون جدا نوشته شده بودند؛ تغییرِ یک قاعده یعنی ویرایشِ پنج
/// جا و ریسکِ واگراییِ خاموش. حالا قاعده یک‌جاست.
class TextNormRules {
  TextNormRules._();

  /// نگاشت نویسه‌های عربی به فارسی.
  static const Map<String, String> charMap = <String, String>{
    'أ': 'ا', // U+0623
    'إ': 'ا', // U+0625
    'ة': 'ه', // U+0629
    'ك': 'ک', // U+0643
    'ى': 'ی', // U+0649
    'ي': 'ی', // U+064A
    'ٱ': 'ا', // U+0671
    'ۀ': 'ه', // U+06C0
  };

  /// نویسه‌هایی که کامل حذف می‌شوند (کشیدگی).
  static const List<int> dropCodepoints = <int>[1600];

  /// بازه‌های حذف (اعراب).
  static const List<List<int>> dropRanges = <List<int>>[
    <int>[1611, 1631],
  ];

  /// نویسه‌هایی که به فاصله تبدیل می‌شوند (نیم‌فاصله، پیوند و جهت).
  static const List<int> toSpaceCodepoints = <int>[8204, 8205, 8206, 8207];

  /// [از، تا، پایه] → رقم لاتین (فارسی و عربی).
  static const List<List<int>> digitRanges = <List<int>>[
    <int>[1776, 1785, 1776],
    <int>[1632, 1641, 1632],
  ];

  static const bool lowercase = true;

  // ---- لایهٔ دوم (`Sense.norm`) ----

  static const String questionMarkFrom = '?';
  static const String questionMarkTo = '؟';
  static const String normPunct = r'[،؛,!«»"()\[\]{}:;_\-/\\*…]+';
  static const String normDot = r'(?<![0-9])\.|\.(?![0-9])';
  static const String normJoinMi = r'(^| )(ن?می) (?=[\u0600-\u06FF])';
  static const bool normPad = true;

  /// بازنویسی‌های محاوره، به ترتیب؛ اولی زودتر اجرا می‌شود.
  static const List<List<String>> canon = <List<String>>[
    <String>[r'چی ?کار|چکار|چه کار', 'چه کار'],
    <String>[r'صاب ?خونه|صاحب ?خونه|صاحب ?خانه', 'صاحبخونه'],
    <String>[r'خانه', 'خونه'],
    <String>[r'تومن', 'تومان'],
    <String>[r'ملیون', 'میلیون'],
    <String>[r'ملیارد', 'میلیارد'],
    <String>[r'بازم', 'باز هم'],
    <String>[r' اگه ', ' اگر '],
    <String>[r' واسه ', ' برای '],
    <String>[r'سؤال', 'سوال'],
    <String>[r'کارفرمام', 'کارفرما من'],
    <String>[r'شکواییه', 'شکوائیه'],
    <String>[r'اجراییه', 'اجرائیه'],
  ];
}
