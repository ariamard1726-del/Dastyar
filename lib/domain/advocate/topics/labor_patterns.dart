part of 'labor.dart';

// برداشتِ وکیل، الگوهای شناسایی و خواندنِ پاسخ‌ها.

/// اخراج شده است؛ حتی اگر بعدتر حرفِ بیمه یا حقوق پیش آمده و «اتفاق اصلی»
/// در پرونده عوض شده باشد.
const FactExpr laborFiredRule = FactAny([
  FactEq('event', 'fired'),
  FactYes('fired'),
]);

const List<RecapItem> _laborRecap = [
  RecapItem(when: laborFiredRule, text: Tx('laborPat_0')),
  RecapItem(when: FactEq('event', 'unpaid'), text: Tx('laborPat_1')),
  RecapItem(when: FactEq('event', 'resign'), text: Tx('laborPat_2')),
  RecapItem(when: FactEq('event', 'insurance'), text: Tx('laborPat_3')),
  RecapItem(
    when: FactAll([FactYes('owed'), FactNot(FactEq('event', 'unpaid'))]),
    text: Tx('laborPat_4'),
  ),
  RecapItem(
    when: FactHasNum('months'),
    text: TxConcat([
      TxNum('months', fmt: NumFmt.span),
      TxRaw(' '),
      Tx('laborRecapMonths'),
    ]),
  ),
  RecapItem(
    when: FactHasNum('salary'),
    text: TxConcat([
      Tx('laborRecapSalaryA'),
      TxRaw(' '),
      TxNum('salary'),
      TxRaw(' '),
      Tx('laborRecapSalaryB'),
    ]),
  ),
  RecapItem(when: FactYes('contract'), text: Tx('laborPat_5')),
  RecapItem(when: FactNo('contract'), text: Tx('laborPat_6')),
  RecapItem(when: FactYes('insured'), text: Tx('laborPat_7')),
  RecapItem(when: FactNo('insured'), text: Tx('laborPat_8')),
  RecapItem(when: FactYes('proof'), text: Tx('laborPat_9')),
  RecapItem(when: FactNo('proof'), text: Tx('laborPat_10')),
  RecapItem(when: FactYes('signed'), text: Tx('laborPat_11')),
  RecapItem(when: FactNo('signed'), text: Tx('laborPat_12')),
  RecapItem(when: FactYes('expired'), text: Tx('laborPat_13')),
  RecapItem(when: FactYes('warned'), text: Tx('laborPat_14')),
  RecapItem(when: FactNo('warned'), text: Tx('laborPat_15')),
  RecapItem(when: FactYes('working'), text: Tx('laborPat_16')),
];

const String _laborFiredRe =
    'اخراج|از فردا نیا|دیگه نیا|نیا سر کار|عذرم|بیرونم کرد|بیرون کرد|تعدیل|تمدید نکرد|راهم نمید|جوابم کرد|گفته نیا|گفت نیا';

const String _laborUnpaid =
    'حقوق[^ ]* (?:رو |را )?(?:نمید|نداد|عقب|معوق)|دستمزد[^ ]* (?:رو |را )?(?:نمید|نداد)|ماه(?:ه)? (?:حقوق|پول) (?:نداد|نگرفتم)|حقوق نگرفتم|حقوق معوق';

const String _laborResignRe = 'استعفا';

const ReadRule _laborEventRead = ReadCases([
  ReadCase(_laborFiredRe, 'fired'),
  ReadCase(_laborUnpaid, 'unpaid'),
  ReadCase(_laborResignRe, 'resign'),
  ReadCase(
    'بیمه[^ ]* (?:رو |را |هم )?(?:رد )?(?:نکرد|نمیکنه|نمیکنن)|بیمه ندارم',
    'insurance',
  ),
]);

// «سه ماهه حقوقمو نداده» مدتِ نپرداختن است، نه سابقهٔ کار.
const ReadRule _laborMonthsRead = ReadGuard(
  'کار (?:میکنم|کردم|میکردم|کرده ام)|سابقه|اونجا(?:م| هستم| بودم| کار| مشغول)?|اینجا(?:م| هستم| کار)|استخدام|مشغول',
  ReadMonths(min: 1),
);

const ReadRule _laborSalaryRead = ReadGuard(
  'حقوق|دستمزد|ماهی|میگرفتم|دریافتی|مزد|میگیرم',
  ReadAmount(),
);

/// «قرارداد یک‌ساله» یا «قرارداد موقت» یعنی مدتِ قرارداد، نه این‌که قرارداد
/// کتبی در دست کاربر است.
const ReadRule _laborContractRead = ReadYn(
  'قرارداد (?:دارم|داشتم|داریم|کتبی|سفید|امضا کرد|بستم|بستیم)|قراردادم |قرارداد کتبی|(?:قرارداد|کنترات)[^ ]* (?:امضا|مکتوب)',
  'قرارداد(?: کتبی| هم)? (?:ندارم|نداشتم|نداریم|نبستیم|ننوشتیم|نداد)|بدون قرارداد|شفاهی|قراردادی (?:ندارم|نداریم|نیست)',
);

const ReadRule _laborInsuredRead = ReadYn(
  'بیمه (?:دارم|هستم|بودم|رد میشه|رد میکرد|رد کرد|ام میکرد)|بیمه[^ ]* (?:رو |را )?رد (?:کرده|میکنه|میکرد)',
  'بیمه(?: هم)? (?:ندارم|نداشتم|نیستم|نکرد|نشدم|نبودم|نمیکنه)|بیمه[^ ]* (?:رو |را |هم )?رد نکرد|بدون بیمه|نه بیمه|بیمه نکرد',
);

const ReadRule _laborSignedRead = ReadYn(
  'امضا (?:کردم|کرده ?ام|زدم|دادم)|تسویه (?:کردم|کرده ?ام)|استعفا (?:دادم|داده ?ام|نوشتم)|انگشت زدم',
  'امضا (?:نکردم|نکرده ?ام|نمیکنم|نزدم|ندادم)|استعفا (?:ندادم|نداده ?ام)|تسویه (?:نکردم|نکرده ?ام)',
);

const ReadRule _laborExpiredRead = ReadYn(
  'مدت(?:ش| قرارداد(?:م)?)? (?:تموم|تمام) شد|قرارداد(?:م)? (?:تموم|تمام) شد|تمدید نکرد|تمدید نشد',
  'وسط قرارداد|(?:تموم|تمام) نشده|قرارداد(?:م)? دائم|مدت نداشت|هنوز (?:[^ ]+ ){0,3}(?:مونده|مانده)',
);

const ReadRule _laborWarnedRead = ReadYn(
  '(?:اخطار|تذکر|توبیخ)(?:ی)? (?:کتبی )?(?:داد|گرفتم|زد)|(?:اخطار|تذکر) کتبی دار',
  'بدون (?:هیچ )?(?:اخطار|تذکر)|(?:اخطار|تذکر)(?:ی)? (?:کتبی )?(?:نداد|نگرفتم|نزد)|هیچ (?:اخطار|تذکر)|یهو|یکدفعه|یک دفعه|بی مقدمه',
);

const ReadRule _laborWorkingRead = ReadYn(
  'هنوز (?:[^ ]+ ){0,2}(?:کار میکنم|مشغولم|هستم|میرم سر)|سر کارم',
  'دیگ(?:ه|ر) (?:[^ ]+ ){0,1}(?:نیستم|کار نمیکنم|نمیرم)|اومدم بیرون|آمدم بیرون|ترک کردم|استعفا (?:دادم|داده ?ام)|کارم (?:تموم|تمام) شد',
);
