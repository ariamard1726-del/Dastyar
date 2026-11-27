part of 'labor.dart';

// برداشتِ وکیل، الگوهای شناسایی و خواندنِ پاسخ‌ها.

// ---- برداشتِ وکیل

/// اخراج شده است؛ حتی اگر بعدتر حرفِ بیمه یا حقوق پیش آمده و «اتفاق اصلی»
/// در پرونده عوض شده باشد.
bool laborFired(CaseFile f) => f.eq('event', 'fired') || f.yes('fired');

List<String> laborRecap(CaseFile f) => [
      if (laborFired(f)) topicText('laborPat_0'),
      if (f.eq('event', 'unpaid')) topicText('laborPat_1'),
      if (f.eq('event', 'resign')) topicText('laborPat_2'),
      if (f.eq('event', 'insurance')) topicText('laborPat_3'),
      if (f.yes('owed') && !f.eq('event', 'unpaid')) topicText('laborPat_4'),
      if (f.n('months') != null) Sense.span(f.n('months')!) + ' ' + topicText('laborRecapMonths'),
      if (f.n('salary') != null)
        topicText('laborRecapSalaryA') + ' ' + Sense.toman(f.n('salary')!) + ' ' + topicText('laborRecapSalaryB'),
      if (f.yes('contract')) topicText('laborPat_5'),
      if (f.no('contract')) topicText('laborPat_6'),
      if (f.yes('insured')) topicText('laborPat_7'),
      if (f.no('insured')) topicText('laborPat_8'),
      if (f.yes('proof')) topicText('laborPat_9'),
      if (f.no('proof')) topicText('laborPat_10'),
      if (f.yes('signed')) topicText('laborPat_11'),
      if (f.no('signed')) topicText('laborPat_12'),
      if (f.yes('expired')) topicText('laborPat_13'),
      if (f.yes('warned')) topicText('laborPat_14'),
      if (f.no('warned')) topicText('laborPat_15'),
      if (f.yes('working')) topicText('laborPat_16'),
    ];

/// شرط مشترک همهٔ ادعاهای کارگری: بشود نشان داد که آنجا کار می‌کرده‌اید.

// متنِ پاسخ‌ها: پول، خواسته‌ها، طرحِ دعوا و شانس.

// ---- خواندنِ پاسخ‌ها از متن

const String _laborFiredRe =
    'اخراج|از فردا نیا|دیگه نیا|نیا سر کار|عذرم|بیرونم کرد|بیرون کرد|تعدیل|تمدید نکرد|راهم نمید|جوابم کرد|گفته نیا|گفت نیا';

const String _laborUnpaid =
    'حقوق[^ ]* (?:رو |را )?(?:نمید|نداد|عقب|معوق)|دستمزد[^ ]* (?:رو |را )?(?:نمید|نداد)|ماه(?:ه)? (?:حقوق|پول) (?:نداد|نگرفتم)|حقوق نگرفتم|حقوق معوق';

String? _laborEvent(String n) {
  if (Sense.has(n, _laborFiredRe)) {
    return 'fired';
  }
  if (Sense.has(n, _laborUnpaid)) {
    return 'unpaid';
  }
  if (Sense.has(n, 'استعفا')) return 'resign';
  if (Sense.has(n, 'بیمه[^ ]* (?:رو |را |هم )?(?:رد )?(?:نکرد|نمیکنه|نمیکنن)|بیمه ندارم')) {
    return 'insurance';
  }
  return null;
}

String? _laborMonths(String n) {
  // «سه ماهه حقوقمو نداده» مدتِ نپرداختن است، نه سابقهٔ کار.
  if (!Sense.has(n,
      'کار (?:میکنم|کردم|میکردم|کرده ام)|سابقه|اونجا(?:م| هستم| بودم| کار| مشغول)?|اینجا(?:م| هستم| کار)|استخدام|مشغول')) {
    return null;
  }
  final m = Sense.months(n);
  if (m == null || m < 1) return null;
  return m.round().toString();
}

String? _laborSalary(String n) {
  if (!Sense.has(n, 'حقوق|دستمزد|ماهی|میگرفتم|دریافتی|مزد|میگیرم')) return null;
  return Sense.amount(n)?.toString();
}

/// «قرارداد یک‌ساله» یا «قرارداد موقت» یعنی مدتِ قرارداد، نه این‌که قرارداد
/// کتبی در دست کاربر است. پیش‌تر همین باعث می‌شد ربات بگوید «قرارداد کتبی
/// دارید» حتی وقتی کاربر فقط از مدت حرف زده بود.
String? _laborContract(String n) => Sense.yn(
      n,
      'قرارداد (?:دارم|داشتم|داریم|کتبی|سفید|امضا کرد|بستم|بستیم)|قراردادم |قرارداد کتبی|(?:قرارداد|کنترات)[^ ]* (?:امضا|مکتوب)',
      'قرارداد(?: کتبی| هم)? (?:ندارم|نداشتم|نداریم|نبستیم|ننوشتیم|نداد)|بدون قرارداد|شفاهی|قراردادی (?:ندارم|نداریم|نیست)',
    );

String? _laborInsured(String n) => Sense.yn(
      n,
      'بیمه (?:دارم|هستم|بودم|رد میشه|رد میکرد|رد کرد|ام میکرد)|بیمه[^ ]* (?:رو |را )?رد (?:کرده|میکنه|میکرد)',
      'بیمه(?: هم)? (?:ندارم|نداشتم|نیستم|نکرد|نشدم|نبودم|نمیکنه)|بیمه[^ ]* (?:رو |را |هم )?رد نکرد|بدون بیمه|نه بیمه|بیمه نکرد',
    );

String? _laborSigned(String n) => Sense.yn(
      n,
      'امضا (?:کردم|کرده ?ام|زدم|دادم)|تسویه (?:کردم|کرده ?ام)|استعفا (?:دادم|داده ?ام|نوشتم)|انگشت زدم',
      'امضا (?:نکردم|نکرده ?ام|نمیکنم|نزدم|ندادم)|استعفا (?:ندادم|نداده ?ام)|تسویه (?:نکردم|نکرده ?ام)',
    );

String? _laborExpired(String n) => Sense.yn(
      n,
      'مدت(?:ش| قرارداد(?:م)?)? (?:تموم|تمام) شد|قرارداد(?:م)? (?:تموم|تمام) شد|تمدید نکرد|تمدید نشد',
      'وسط قرارداد|(?:تموم|تمام) نشده|قرارداد(?:م)? دائم|مدت نداشت|هنوز (?:[^ ]+ ){0,3}(?:مونده|مانده)',
    );

String? _laborWarned(String n) => Sense.yn(
      n,
      '(?:اخطار|تذکر|توبیخ)(?:ی)? (?:کتبی )?(?:داد|گرفتم|زد)|(?:اخطار|تذکر) کتبی دار',
      'بدون (?:هیچ )?(?:اخطار|تذکر)|(?:اخطار|تذکر)(?:ی)? (?:کتبی )?(?:نداد|نگرفتم|نزد)|هیچ (?:اخطار|تذکر)|یهو|یکدفعه|یک دفعه|بی مقدمه',
    );

String? _laborWorking(String n) => Sense.yn(
      n,
      'هنوز (?:[^ ]+ ){0,2}(?:کار میکنم|مشغولم|هستم|میرم سر)|سر کارم',
      'دیگ(?:ه|ر) (?:[^ ]+ ){0,1}(?:نیستم|کار نمیکنم|نمیرم)|اومدم بیرون|آمدم بیرون|ترک کردم|استعفا (?:دادم|داده ?ام)|کارم (?:تموم|تمام) شد',
    );

/// حساب سرانگشتی مطالبات (سنوات و خسارت اخراج).
