part of 'rent.dart';

// خواندنِ نقش، موضوع، هدف و واقعیت‌های بله/نه از متنِ کاربر.
//
// هر تابع این‌جا فقط الگوها را روی پیام اجرا می‌کند و یک مقدار می‌دهد؛ هیچ
// جمله‌ای نمی‌سازد و هیچ پرونده‌ای را عوض نمی‌کند.

String? _rentRoleSaid(String n) {
  final m = Sense.rx(' $_q ').firstMatch(n);
  final own = m == null ? n : n.substring(0, m.end);
  if (Sense.has(own, _cSaidLandlord)) return 'landlord';
  if (Sense.has(own, _cSaidTenant)) return 'tenant';
  return null;
}

String? _rentRole(String n) {
  // ۱) خودش گفته کدام طرف است.
  final said = _rentRoleSaid(n);
  if (said != null) return said;
  // ۲) از طرف مقابل حرف می‌زند.
  if (Sense.has(n,
      'صاحبخونه|موجر|پول پیشم|پول رهنم|ودیعه ام|رهنم |مالک (?:قصد|میخواهد|میخواد|میگه|میگوید|حاضر)')) {
    return 'tenant';
  }
  if (Sense.has(n,
      'مستاجر[^ ]* (?:[^ ]+ ){0,9}(?:نمیده|نمیدهد|نداده|نمیکنه|نمیکند|نکرده|کرده|نمیشه|نمیشود|نمیره|نمیرود|نمیپردازه|نمیپردازد|نپرداخته|نمینماید|ننموده|خودداری|امتناع|استنکاف|خراب کرد|خسارت زد|زده|برده|شکسته|گذاشته|رفته|مونده|مانده|نشسته|اجاره داده|واگذار|فوت کرد|اعتراض کرد)')) {
    return 'landlord';
  }
  // ۳) نشانه‌های ضعیف‌تر: آنچه فقط در نقلِ حرفِ طرف مقابل آمده.
  if (Sense.has(n, _cSaidLandlord)) return 'landlord';
  if (Sense.has(n, _cSaidTenant)) return 'tenant';
  if (Sense.has(n, 'مستاجرم|پول پیش|ودیعه')) return 'tenant';
  return null;
}

/// دعوای مستأجر با موجر سرِ چیست: ودیعه، بالابردن اجاره، بیرون‌کردن،
/// دستور تخلیه، تعمیر، زودتر رفتن یا تحویل‌ندادن ملک. پرسش‌ها و نقشهٔ راه از روی همین
/// انتخاب می‌شوند.
String? _rentMatter(String n) {
  if (Sense.has(n, _cOrderCame)) return 'order';
  if (Sense.has(n, _cDeliver)) return 'deliver';
  if (Sense.has(n,
      'پول پیش|پول رهن|ودیعه|رهن(?:م| خونه| رو| کامل)|پیش خونه| پول(?:م|مو) ')) {
    return 'deposit';
  }
  if (Sense.has(n, _cRaise)) return 'raise';
  if (Sense.has(n, _cLeave)) return 'leave';
  if (Sense.has(n, _cEvict)) return 'evict';
  if (Sense.has(n, _cRepair)) return 'repair';
  if (Sense.has(
      n, 'خراب کرد|خسارت(?! تاخیر| دادرسی)|کسر (?:کنه|میکنه|کرد)')) {
    return 'deposit';
  }
  return null;
}

/// موجر از مستأجر چه می‌خواهد: تخلیه، اجارهٔ عقب‌افتاده، خسارت یا برخورد
/// با تخلف از قرارداد.
String? _rentAim(String n) {
  if (Sense.has(n, _cWontLeave)) return 'evict';
  if (Sense.has(n, _cBreach)) return 'breach';
  if (Sense.has(n, _cUnpaid)) return 'unpaid';
  if (Sense.has(n, _cLDamage)) return 'damage';
  return null;
}

String? _rentVacated(String n) => Sense.yn(
      n,
      'خالی کردم|تخلیه کردم|تحویل دادم|کلید(?: رو| را)? (?:دادم|تحویل داد)|اسباب ?کشی کردم|بلند شدم|از اونجا رفتم|خونه رو پس دادم|خالی کرده ام|تخلیه شده|تخلیه کرده ام|تخلیه نموده ام',
      'خالی نکردم|تخلیه نکردم|تخلیه نکرده ام|هنوز (?:اونجام|توش|تو خونه|ساکن|نشستم|همونجام|تو همون)|بلند نشدم|تحویل ندادم|کلید دست(?:م| خودم)|هنوز خالی|تحویل نمیگیر|کلید(?: رو| را)? نمیگیر',
    );

String? _rentEnded(String n) => Sense.yn(
      n,
      'قرارداد[^ ]* (?:تموم|تمام|سر اومد|به پایان|منقضی)|مدت[^ ]* (?:تموم|تمام|منقضی|به پایان)|سررسید|موعد[^ ]* (?:رسید|گذشت)|اجاره[^ ]* تموم شد|انقضا(?:ی)? مدت',
      'هنوز (?:قرارداد|مدت)|(?:قرارداد|مدت)[^ ]* (?:تموم|تمام) نشده|(?:قبل|پیش) از (?:انقضا|پایان|اتمام|موعد|سررسید)|وسط قرارداد|مونده به پایان|ماه (?:دیگه )?مونده|قرارداد دار(?:م|یم) تا |تا (?:آخر|اخر|پایان|سر) (?:سال|ماه|تابستون|تابستان|پاییز|زمستون|زمستان|بهار)',
    );

String? _rentContract(String n) => Sense.yn(
      n,
      'اجاره ?نامه|قولنامه|قرارداد (?:دارم|داریم|کتبی|نوشتیم|بنگاه)|کد رهگیری|بنگاه|املاک|محضر',
      'قرارداد(?: کتبی)? (?:ندارم|نداریم|ننوشتیم)|شفاهی|قولنامه (?:ندارم|نداریم)|هیچ نوشته|اجاره ?نامه (?:ندارم|نداریم)',
    );

String? _rentWitness(String n) => Sense.yn(
      n,
      '(?:دو|2|چند) (?:تا |نفر )?شاهد|دوتا شاهد|شاهد (?:داره|دارد|امضا)|شهود (?:امضا|دارد)|کد رهگیری (?:داره|دارد|داریم|گرفت)|با کد رهگیری|سند رسمی|محضری|دفترخونه',
      'شاهد (?:نداره|ندارد|نداریم|نیست)|بدون شاهد|بی شاهد',
    );

String? _rentClause(String n) => Sense.yn(
      n,
      'حق فسخ (?:دارم|داریم|گذاشت|نوشت|شرط|هست)|شرط فسخ|خیار (?:فسخ|شرط|تخلف)|(?:شرط|قید) (?:کرده ایم|کردیم|شده)',
      'حق فسخ (?:ندار|نگذاشت|ننوشت|نیست)|شرط(?:ی)? (?:نکرد|نشده|نیست|نداریم)|چنین (?:شرطی|بندی) (?:نیست|نداریم)',
    );

String? _rentProof(String n) => Sense.yn(
      n,
      'عکس|فیلم|صورت ?جلسه|کارشناس|تامین دلیل|استشهاد',
      'مدرک(?:ی)? ندارم|عکس(?:ی)? ندارم|هیچ (?:مدرک|عکس)|ثابت نمیشه',
    );

String? _rentTold(String n) => Sense.yn(
      n,
      'پیام دادم|پیامک (?:دادم|زدم)|نامه (?:دادم|نوشتم)|اظهارنامه (?:دادم|فرستادم)|کتبی (?:گفتم|خبر|اعلام)|(?:واتس ?اپ|تلگرام|ایتا|بله)[^ ]* (?:[^ ]+ ){0,2}(?:گفتم|نوشتم|فرستادم)|خبر دادم|اطلاع دادم',
      'خبر ندادم|نگفتم|فقط (?:زبانی|تلفنی|حضوری)|هنوز (?:نگفتم|خبر)',
    );

String? _rentOfficial(String n) => Sense.yn(
      n,
      _cOrderCame,
      'فقط (?:خودش|میگه|حرف|زبونی|زبانی|تلفنی|پیام)|برگه ای (?:نیومده|نیامده)|چیزی (?:نیومده|نیامده)|ابلاغ نشده|هیچ برگه|رسمی نیست',
    );

String? _rentConsent(String n) => Sense.yn(
      n,
      'راضی(?: ه| است| شده|ه )|موافق(?:ه | است|ت کرد)|قبول (?:کرد|داره|دارد)|مشکلی نداره|توافق کردیم',
      'راضی (?:نیست|نمیشه|نمیشود)|موافق نیست|قبول ن(?:میکنه|میکند|کرد)|نمیذاره|نمیگذارد|میگه (?:نه|نمیشه)',
    );

// ============================================================== وضعیت‌ها

bool _tenantSide(CaseFile f) => !f.eq('role', 'landlord');

bool _landlordSide(CaseFile f) => f.eq('role', 'landlord');

bool _rentDeposit(CaseFile f) =>
    f.eq('role', 'tenant') && (!f.has('matter') || f.eq('matter', 'deposit'));

bool _matter(CaseFile f, String v) =>
    f.eq('role', 'tenant') && f.eq('matter', v);

bool _aim(CaseFile f, String v) => f.eq('role', 'landlord') && f.eq('aim', v);

/// دستور رسمی تخلیه علیه مستأجر در کار است.
bool _ordered(CaseFile f) =>
    _matter(f, 'order') || (_matter(f, 'evict') && f.yes('official'));

/// موجر تخلیه می‌خواهد ولی نه مدت تمام شده و نه شرط فسخی در کار است.
bool _noGround(CaseFile f) =>
    f.eq('role', 'landlord') &&
    (f.eq('aim', 'evict') || f.eq('aim', 'breach')) &&
    f.no('ended') &&
    f.no('clause');

/// موجر دنبال تخلیه است (یا هنوز نگفته دنبال چیست).
bool _evicting(CaseFile f) =>
    f.eq('role', 'landlord') && (!f.has('aim') || f.eq('aim', 'evict'));

/// مستأجری که حرفش ودیعه است (یا هنوز نگفته دعوا سرِ چیست)، حتی وقتی
/// دستور تخلیه هم آمده باشد.
bool _depositTalk(CaseFile f) =>
    _tenantSide(f) &&
    (!f.has('matter') || f.eq('matter', 'deposit') || _ordered(f));

/// مبلغی که سرِ آن دعواست (ودیعه برای مستأجر، طلب برای موجر).
int? _rentSum(CaseFile f) => f.eq('role', 'landlord')
    ? (f.n('due') ?? f.n('amount'))
    : f.n('amount');

bool _shop(CaseFile f) => f.eq('place', 'shop');

/// «هنوز تمام نشده» به‌عنوان شرط: برقرار، نابرقرار یا نامعلوم.
bool? _running(CaseFile f) =>
    f.no('ended') ? true : (f.yes('ended') ? false : null);

