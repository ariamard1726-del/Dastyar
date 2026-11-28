// تولیدشده از dev/tools/contracts/engine_rules.json — دستی ویرایش نکنید.
// تولید دوباره: python3 dev/tools/gen_engine_rules.py --write
// بررسی تازگی:  python3 dev/tools/gen_engine_rules.py --check


/// قاعده‌های یکتای موتور بازیابی — تنها مرجع، `dev/tools/contracts/engine_rules.json`.
///
/// آینهٔ پایتونی‌اش `dev/brain/engine_rules.py` است و از همین قرارداد تولید
/// می‌شود؛ `python3 dev/tools/check.py enginerules` کهنه‌بودن هر دو را خطا می‌دهد.
class EngineRules {
  EngineRules._();

  // ---- الگوی «ماده/اصل N» ----
  static const String articleQueryPattern = r'(ماده|اصل)\s*(?:(واحده)(?![\u0600-\u06FFa-z0-9])|(\d+)(?:\s*(مکرر)(?:\s*(\d{1,2})(?!\d))?)?)(?!\s*(?:تومان|ریال|درصد|سکه|ماه|سال|روز))';

  // ---- ضرایب BM25F و آستانه‌های پاسخ‌سازی ----
  static const double bm25K1 = 0.9;
  static const double bm25B = 0.7;
  static const double bm25WT = 3.0;
  static const double bm25WB = 1.0;
  static const double bm25WC = 0.5;
  static const double obsoletePenalty = 0.1;
  static const double explicitScore = 99.0;
  static const int prefixMinLen = 3;
  static const double prefixWeight = 0.5;
  static const double minHitScore = 0.3;
  static const double lowCover = 0.4;
  static const double coverageMargin = 0.25;
  static const double nearAlternativeFactor = 0.5;
  static const int maxNearAlternatives = 2;
  static const double altMinScoreRatio = 0.4;

  // ---- تشخیص مادهٔ منسوخ و پاک‌سازی سرِ متن ----
  static const int obsoleteMaxLen = 300;
  static const String obsoleteTrimPattern = r'^[\(\[\s]+';
  static const String cleanBodyPattern = r'^[(\[][^)\]]*[)\]]\s*-?\s*';
  static const List<String> obsoletePrefixes = <String>[
    'منسوخ', 'ملغی', 'ملغا', 'حذف شد',
  ];

  // ---- ارتقای مواد تعریفی («X چیست / یعنی چه») ----
  static const String defQuestionPattern = r'چیست|چیه|کیست|یعنی چی|یعنی چه|چه معنی|تعریف|چی هست|به چه گویند|به چه کسی می گویند|به چی می گن|گفته می شود';
  static const Set<String> defWords = <String>{
    'یعنی', 'چی', 'چه', 'معنی', 'تعریف', 'هست',
    'چیست', 'چیه', 'گویند', 'کسی', 'کیست', 'گفته',
    'شود',
  };
  static const Set<String> defMetaPrefixes = <String>{
    'مجازات', 'مجازاتی', 'شرایط', 'حکم', 'مهلت', 'موارد',
    'نحوه', 'میزان',
  };
  static const String defMarkPattern = r'عقدی|عبارت|است|گویند|حاصل';
  static const String defStrongPattern = r'^[\s،]*(عقدی|عبارت|شرکتی|کسی)';
  static const int defTailWindow = 30;
  static const int defMaxPicked = 2;

  // ---- شناسایی نام قانون در متن ----
  static const List<String> lawPrefixes = <String>[
    'قانون ', 'لایحه ',
  ];
  static const String shortLawPrefix = 'قانون ';
  static const int shortLawMinLen = 5;

  // ---- نگهبان حوزه‌های خارج از پوشش ----
  static const List<String> unloadedPenalTerms = <String>[
    'سرقت', 'دزدی', 'کلاهبرداری', 'قتل', 'ضرب و جرح', 'خیانت در امانت',
    'توهین', 'افترا', 'جعل', 'رشوه', 'اختلاس', 'جرایم رایانه',
    'هک',
  ];
  static const List<String> penalContextMarkers = <String>[
    'مجازات', 'دیه', 'قصاص', 'حدود', 'تعزیر', 'جرم',
  ];
  static const List<String> loadedCriminalExceptions = <String>[
    'چک', 'ورشکست', 'شرکت', 'سهام', 'برات', 'سفته',
    'کارگر', 'کارفرما',
  ];
  static const List<String> taxTriggers = <String>[
    'مالیات بر درآمد', 'محاسبه مالیات', 'نرخ مالیات', 'معافیت مالیاتی',
  ];
  static const List<String> socialSecurityTriggers = <String>[
    'حق بیمه', 'مستمری', 'بازنشستگی',
  ];
  static const List<(String, List<String>)> anchorGroups = <(
      String, List<String>)>[
    ('طلاق', <String>['طلاق', 'خلع', 'مبارات', 'عده']),
    ('حضانت', <String>['حضانت', 'طفل']),
    ('مهریه', <String>['مهر', 'صداق', 'مهریه']),
    ('دیه', <String>['دیه']),
    ('سربازی', <String>['سربازی', 'وظیفه عمومی']),
    ('گمرک', <String>['گمرک', 'گمرکی', 'ترخیص']),
    ('گواهینامه', <String>['گواهینامه', 'رانندگی']),
    ('خلافی', <String>['خلافی', 'رانندگی']),
    ('ویزا', <String>['ویزا', 'روادید']),
    ('شنگن', <String>['شنگن', 'روادید']),
    ('پناهندگی', <String>['پناهندگی', 'پناهنده']),
  ];

  // ---- زنجیرهٔ تضاد مواد ----
  static const int conflictsMaxDepth = 32;
  static const String conflictsCycleSuffix = ' ⚠️ (حلقه)';
}
