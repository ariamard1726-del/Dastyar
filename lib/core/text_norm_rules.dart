// تولیدشده از dev/tools/contracts/text_norm.json — دستی ویرایش نکنید.
// تولید دوباره: python3 dev/tools/gen_text_norm.py --write
// بررسی تازگی:  python3 dev/tools/gen_text_norm.py --check


/// قاعده‌های یکدست‌سازی متن — تنها مرجع، `dev/tools/contracts/text_norm.json`.
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
  static const bool questionMarkPad = true;
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

  // ---- لایهٔ واژه‌بندی و ریشه‌یابی (`PersianText` / `eval_py`) ----

  static const String nonWord = r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+';
  static const int stemMinStem = 3;
  static const List<String> suffixes = <String>['ترین', 'هایی', 'های', 'ها', 'تر', 'ان', 'ات', 'ی'];
  static const List<String> suffixesIndex = <String>['ترین', 'هایی', 'های', 'ها'];
  static const Set<String> stop = <String>{
    'آن', 'آیا', 'از', 'است', 'این', 'با', 'باشد', 'بر',
    'برای', 'به', 'بود', 'بگو', 'تا', 'تو', 'در', 'درباره',
    'را', 'شد', 'شما', 'قانون', 'لطفا', 'ماده', 'ممنون', 'من',
    'مورد', 'می', 'هر', 'هست', 'هم', 'و', 'چرا', 'چطور',
    'چه', 'چگونه', 'چی', 'چیست', 'کجا', 'کن', 'کند', 'کنم',
    'که', 'کی', 'یا', 'یک',
  };

  // ---- نسخه‌های فاصله‌دار (`TopicFlow` و `LawTerms`) ----

  static const Map<String, String> spacedToolsMap = <String, String>{
    'ء': '', // U+0621
    'أ': 'ا', // U+0623
    'ؤ': 'و', // U+0624
    'ك': 'ک', // U+0643
    'ي': 'ی', // U+064A
    'ۀ': 'ه', // U+06C0
    '\u200c': ' ', // U+200C
  };
  static const List<List<int>> spacedToolsDropRanges = <List<int>>[
    <int>[1611, 1631],
    <int>[1648, 1648],
  ];
  static const String spacedToolsPunct = r'[،,.;:!?؟()\[\]«»"\-/]+';
  static const bool spacedToolsPad = true;

  static const Map<String, String> spacedTermsMap = <String, String>{
    'ك': 'ک', // U+0643
    'ي': 'ی', // U+064A
    'ۀ': 'ه', // U+06C0
    '\u200c': ' ', // U+200C
  };
  static const List<List<int>> spacedTermsDropRanges = <List<int>>[];
  static const String spacedTermsPunct = r'[،,.;:!?؟()\[\]«»"\-/]+';
  static const bool spacedTermsPad = true;
}
