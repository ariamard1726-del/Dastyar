"""تولیدشده از dev/tools/contracts/engine_rules.json — دستی ویرایش نکنید.

تولید دوباره: python3 dev/tools/gen_engine_rules.py --write
بررسی تازگی:  python3 dev/tools/gen_engine_rules.py --check
"""


ARTICLE_QUERY_PATTERN = r'(ماده|اصل)\s*(?:(واحده)(?![\u0600-\u06FFa-z0-9])|(\d+)(?:\s*(مکرر)(?:\s*(\d{1,2})(?!\d))?)?)(?!\s*(?:تومان|ریال|درصد|سکه|ماه|سال|روز))'

BM25_K1 = 0.9
BM25_B = 0.7
BM25_WT = 3.0
BM25_WB = 1.0
BM25_WC = 0.5
OBSOLETE_PENALTY = 0.1
EXPLICIT_SCORE = 99.0
PREFIX_MIN_LEN = 3
PREFIX_WEIGHT = 0.5
MIN_SCORE = 0.3
LOW_COVER = 0.4
COVERAGE_MARGIN = 0.25
NEAR_ALTERNATIVE_FACTOR = 0.5
MAX_NEAR_ALTERNATIVES = 2
ALT_MIN_SCORE_RATIO = 0.4

OBSOLETE_MAX_LEN = 300
OBSOLETE_TRIM_PATTERN = r'^[\(\[\s]+'
CLEAN_BODY_PATTERN = r'^[(\[][^)\]]*[)\]]\s*-?\s*'
OBSOLETE_PREFIXES = ('منسوخ', 'ملغی', 'ملغا', 'حذف شد')

DEF_QUESTION_PATTERN = r'چیست|چیه|کیست|یعنی چی|یعنی چه|چه معنی|تعریف|چی هست|به چه گویند|به چه کسی می گویند|به چی می گن|گفته می شود'
DEF_WORDS = frozenset({'یعنی', 'چی', 'چه', 'معنی', 'تعریف', 'هست', 'چیست', 'چیه', 'گویند', 'کسی', 'کیست', 'گفته', 'شود'})
DEF_META_PREFIXES = frozenset({'مجازات', 'مجازاتی', 'شرایط', 'حکم', 'مهلت', 'موارد', 'نحوه', 'میزان'})
DEF_MARK_PATTERN = r'عقدی|عبارت|است|گویند|حاصل'
DEF_STRONG_PATTERN = r'^[\s،]*(عقدی|عبارت|شرکتی|کسی)'
DEF_TAIL_WINDOW = 30
DEF_MAX_PICKED = 2

LAW_PREFIXES = ('قانون ', 'لایحه ')
SHORT_LAW_PREFIX = 'قانون '
SHORT_LAW_MIN_LEN = 5

UNLOADED_PENAL_TERMS = (
    'سرقت',
    'دزدی',
    'کلاهبرداری',
    'قتل',
    'ضرب و جرح',
    'خیانت در امانت',
    'توهین',
    'افترا',
    'جعل',
    'رشوه',
    'اختلاس',
    'جرایم رایانه',
    'هک',
)
PENAL_CONTEXT_MARKERS = ('مجازات', 'دیه', 'قصاص', 'حدود', 'تعزیر', 'جرم')
LOADED_CRIMINAL_EXCEPTIONS = (
    'چک',
    'ورشکست',
    'شرکت',
    'سهام',
    'برات',
    'سفته',
    'کارگر',
    'کارفرما',
)
TAX_TRIGGERS = ('مالیات بر درآمد', 'محاسبه مالیات', 'نرخ مالیات', 'معافیت مالیاتی')
SOCIAL_SECURITY_TRIGGERS = ('حق بیمه', 'مستمری', 'بازنشستگی')
ANCHOR_GROUPS = (
    ('طلاق', ('طلاق', 'خلع', 'مبارات', 'عده')),
    ('حضانت', ('حضانت', 'طفل')),
    ('مهریه', ('مهر', 'صداق', 'مهریه')),
    ('دیه', ('دیه',)),
    ('سربازی', ('سربازی', 'وظیفه عمومی')),
    ('گمرک', ('گمرک', 'گمرکی', 'ترخیص')),
    ('گواهینامه', ('گواهینامه', 'رانندگی')),
    ('خلافی', ('خلافی', 'رانندگی')),
    ('ویزا', ('ویزا', 'روادید')),
    ('شنگن', ('شنگن', 'روادید')),
    ('پناهندگی', ('پناهندگی', 'پناهنده')),
)

CONFLICTS_MAX_DEPTH = 32
CONFLICTS_CYCLE_SUFFIX = ' ⚠️ (حلقه)'
