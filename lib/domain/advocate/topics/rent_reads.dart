part of 'rent.dart';

// خواندنِ نقش، موضوع، هدف و واقعیت‌های بله/نه از متنِ کاربر و وضعیت‌های پرونده.

const ReadRule _rentRoleSaidRead = ReadBeforeMatch(
  ' $_q ',
  ReadCases([
    ReadCase(_cSaidLandlord, 'landlord'),
    ReadCase(_cSaidTenant, 'tenant'),
  ]),
);

const ReadRule _rentRoleRead = ReadSeq([
  _rentRoleSaidRead,
  ReadCases([
    ReadCase(
      'صاحبخونه|موجر|پول پیشم|پول رهنم|ودیعه ام|رهنم |مالک (?:قصد|میخواهد|میخواد|میگه|میگوید|حاضر)',
      'tenant',
    ),
    ReadCase(
      'مستاجر[^ ]* (?:[^ ]+ ){0,9}(?:نمیده|نمیدهد|نداده|نمیکنه|نمیکند|نکرده|کرده|نمیشه|نمیشود|نمیره|نمیرود|نمیپردازه|نمیپردازد|نپرداخته|نمینماید|ننموده|خودداری|امتناع|استنکاف|خراب کرد|خسارت زد|زده|برده|شکسته|گذاشته|رفته|مونده|مانده|نشسته|اجاره داده|واگذار|فوت کرد|اعتراض کرد)',
      'landlord',
    ),
    ReadCase(_cSaidLandlord, 'landlord'),
    ReadCase(_cSaidTenant, 'tenant'),
    ReadCase('مستاجرم|پول پیش|ودیعه', 'tenant'),
  ]),
]);

const ReadRule _rentMatterRead = ReadCases([
  ReadCase(_cOrderCame, 'order'),
  ReadCase(_cDeliver, 'deliver'),
  ReadCase(
    'پول پیش|پول رهن|ودیعه|رهن(?:م| خونه| رو| کامل)|پیش خونه| پول(?:م|مو) ',
    'deposit',
  ),
  ReadCase(_cRaise, 'raise'),
  ReadCase(_cLeave, 'leave'),
  ReadCase(_cEvict, 'evict'),
  ReadCase(_cRepair, 'repair'),
  ReadCase(
    'خراب کرد|خسارت(?! تاخیر| دادرسی)|کسر (?:کنه|میکنه|کرد)',
    'deposit',
  ),
]);

const ReadRule _rentAimRead = ReadCases([
  ReadCase(_cWontLeave, 'evict'),
  ReadCase(_cBreach, 'breach'),
  ReadCase(_cUnpaid, 'unpaid'),
  ReadCase(_cLDamage, 'damage'),
]);

const ReadRule _rentVacatedRead = ReadYn(
  'خالی کردم|تخلیه کردم|تحویل دادم|کلید(?: رو| را)? (?:دادم|تحویل داد)|اسباب ?کشی کردم|بلند شدم|از اونجا رفتم|خونه رو پس دادم|خالی کرده ام|تخلیه شده|تخلیه کرده ام|تخلیه نموده ام',
  'خالی نکردم|تخلیه نکردم|تخلیه نکرده ام|هنوز (?:اونجام|توش|تو خونه|ساکن|نشستم|همونجام|تو همون)|بلند نشدم|تحویل ندادم|کلید دست(?:م| خودم)|هنوز خالی|تحویل نمیگیر|کلید(?: رو| را)? نمیگیر',
);

const ReadRule _rentEndedRead = ReadYn(
  'قرارداد[^ ]* (?:تموم|تمام|سر اومد|به پایان|منقضی)|مدت[^ ]* (?:تموم|تمام|منقضی|به پایان)|سررسید|موعد[^ ]* (?:رسید|گذشت)|اجاره[^ ]* تموم شد|انقضا(?:ی)? مدت',
  'هنوز (?:قرارداد|مدت)|(?:قرارداد|مدت)[^ ]* (?:تموم|تمام) نشده|(?:قبل|پیش) از (?:انقضا|پایان|اتمام|موعد|سررسید)|وسط قرارداد|مونده به پایان|ماه (?:دیگه )?مونده|قرارداد دار(?:م|یم) تا |تا (?:آخر|اخر|پایان|سر) (?:سال|ماه|تابستون|تابستان|پاییز|زمستون|زمستان|بهار)',
);

const ReadRule _rentContractRead = ReadYn(
  'اجاره ?نامه|قولنامه|قرارداد (?:دارم|داریم|کتبی|نوشتیم|بنگاه)|کد رهگیری|بنگاه|املاک|محضر',
  'قرارداد(?: کتبی)? (?:ندارم|نداریم|ننوشتیم)|شفاهی|قولنامه (?:ندارم|نداریم)|هیچ نوشته|اجاره ?نامه (?:ندارم|نداریم)',
);

const ReadRule _rentWitnessRead = ReadYn(
  '(?:دو|2|چند) (?:تا |نفر )?شاهد|دوتا شاهد|شاهد (?:داره|دارد|امضا)|شهود (?:امضا|دارد)|کد رهگیری (?:داره|دارد|داریم|گرفت)|با کد رهگیری|سند رسمی|محضری|دفترخونه',
  'شاهد (?:نداره|ندارد|نداریم|نیست)|بدون شاهد|بی شاهد',
);

const ReadRule _rentClauseRead = ReadYn(
  'حق فسخ (?:دارم|داریم|گذاشت|نوشت|شرط|هست)|شرط فسخ|خیار (?:فسخ|شرط|تخلف)|(?:شرط|قید) (?:کرده ایم|کردیم|شده)',
  'حق فسخ (?:ندار|نگذاشت|ننوشت|نیست)|شرط(?:ی)? (?:نکرد|نشده|نیست|نداریم)|چنین (?:شرطی|بندی) (?:نیست|نداریم)',
);

const ReadRule _rentProofRead = ReadYn(
  'عکس|فیلم|صورت ?جلسه|کارشناس|تامین دلیل|استشهاد',
  'مدرک(?:ی)? ندارم|عکس(?:ی)? ندارم|هیچ (?:مدرک|عکس)|ثابت نمیشه',
);

const ReadRule _rentToldRead = ReadYn(
  'پیام دادم|پیامک (?:دادم|زدم)|نامه (?:دادم|نوشتم)|اظهارنامه (?:دادم|فرستادم)|کتبی (?:گفتم|خبر|اعلام)|(?:واتس ?اپ|تلگرام|ایتا|بله)[^ ]* (?:[^ ]+ ){0,2}(?:گفتم|نوشتم|فرستادم)|خبر دادم|اطلاع دادم',
  'خبر ندادم|نگفتم|فقط (?:زبانی|تلفنی|حضوری)|هنوز (?:نگفتم|خبر)',
);

const ReadRule _rentOfficialRead = ReadYn(
  _cOrderCame,
  'فقط (?:خودش|میگه|حرف|زبونی|زبانی|تلفنی|پیام)|برگه ای (?:نیومده|نیامده)|چیزی (?:نیومده|نیامده)|ابلاغ نشده|هیچ برگه|رسمی نیست',
);

const ReadRule _rentConsentRead = ReadYn(
  'راضی(?: ه| است| شده|ه )|موافق(?:ه | است|ت کرد)|قبول (?:کرد|داره|دارد)|مشکلی نداره|توافق کردیم',
  'راضی (?:نیست|نمیشه|نمیشود)|موافق نیست|قبول ن(?:میکنه|میکند|کرد)|نمیذاره|نمیگذارد|میگه (?:نه|نمیشه)',
);

// ============================================================== وضعیت‌ها

const FactExpr _landlordSide = FactEq('role', 'landlord');
const FactExpr _tenantSide = FactNot(_landlordSide);
const FactExpr _isTenantRole = FactEq('role', 'tenant');

const FactExpr _rentDeposit = FactAll([
  _isTenantRole,
  FactAny([FactNot(FactHas('matter')), FactEq('matter', 'deposit')]),
]);

const FactExpr _rentOtherMatter = FactAll([
  _isTenantRole,
  FactHas('matter'),
  FactNot(FactEq('matter', 'deposit')),
]);

const FactExpr _mDeposit = FactAll([_isTenantRole, FactEq('matter', 'deposit')]);
const FactExpr _mRaise = FactAll([_isTenantRole, FactEq('matter', 'raise')]);
const FactExpr _mEvict = FactAll([_isTenantRole, FactEq('matter', 'evict')]);
const FactExpr _mOrder = FactAll([_isTenantRole, FactEq('matter', 'order')]);
const FactExpr _mRepair = FactAll([_isTenantRole, FactEq('matter', 'repair')]);
const FactExpr _mLeave = FactAll([_isTenantRole, FactEq('matter', 'leave')]);
const FactExpr _mDeliver = FactAll([_isTenantRole, FactEq('matter', 'deliver')]);

const FactExpr _aEvict = FactAll([_landlordSide, FactEq('aim', 'evict')]);
const FactExpr _aUnpaid = FactAll([_landlordSide, FactEq('aim', 'unpaid')]);
const FactExpr _aDamage = FactAll([_landlordSide, FactEq('aim', 'damage')]);
const FactExpr _aBreach = FactAll([_landlordSide, FactEq('aim', 'breach')]);

/// دستور رسمی تخلیه علیه مستأجر در کار است.
const FactExpr _ordered = FactAny([
  _mOrder,
  FactAll([_mEvict, FactYes('official')]),
]);

/// موجر تخلیه می‌خواهد ولی نه مدت تمام شده و نه شرط فسخی در کار است.
const FactExpr _noGround = FactAll([
  _landlordSide,
  FactIn('aim', ['evict', 'breach']),
  FactNo('ended'),
  FactNo('clause'),
]);

/// موجر دنبال تخلیه است (یا هنوز نگفته دنبال چیست).
const FactExpr _evicting = FactAll([
  _landlordSide,
  FactAny([FactNot(FactHas('aim')), FactEq('aim', 'evict')]),
]);

/// مستأجری که حرفش ودیعه است (یا هنوز نگفته دعوا سرِ چیست)، حتی وقتی
/// دستور تخلیه هم آمده باشد.
const FactExpr _depositTalk = FactAll([
  _tenantSide,
  FactAny([FactNot(FactHas('matter')), FactEq('matter', 'deposit'), _ordered]),
]);

const FactExpr _shop = FactEq('place', 'shop');

/// «هنوز تمام نشده» به‌عنوان شرط: برقرار، نابرقرار یا نامعلوم.
const FactExpr _running = FactTriCases([
  FactCase(FactNo('ended'), FactConst(true)),
  FactCase(FactYes('ended'), FactConst(false)),
]);

/// مرجعِ مبلغی که سرِ آن دعواست (ودیعه برای مستأجر، طلب برای موجر).
const TextExpr _rentSumForum = TxCond(
  _landlordSide,
  TxCond(FactHasNum('due'), TxForum('due'), TxForum('amount')),
  TxForum('amount'),
);

const FactExpr _rentSumBig = FactAny([
  FactAll([
    _landlordSide,
    FactAny([
      FactNumMin('due', 100000001),
      FactAll([FactNot(FactHasNum('due')), FactNumMin('amount', 100000001)]),
    ]),
  ]),
  FactAll([FactNot(_landlordSide), FactNumMin('amount', 100000001)]),
]);
