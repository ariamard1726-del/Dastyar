// موضوع: خرید و فروش ملک.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic propertyTopic = Topic(
  id: 'property',
  title: topicText('property_0'),
  cues: {
    'خونه(?:م|ام)?[^؟]{0,25}تصرف|ملک(?:م|ام)?[^؟]{0,25}(?:تصرف|غصب)|زمین(?:م)?[^؟]{0,25}(?:تصرف|غصب)|تصرف (?:غیرقانونی|عدوانی)|غاصب|غصب (?:ملک|خونه|زمین)': 4,
    'سند[^ ]* (?:رو |را )?(?:نمیزن|نزد|نمیده|نمیاد بزن)|انتقال سند|تنظیم سند|الزام به تنظیم|سند به نام(?:م| من)': 5,
    'قولنامه|مبایعه ?نامه|پیش ?فروش|پیش ?خرید': 3,
    '(?:زمین|ملک|خونه|مال|آپارتمان)(?:م|ام|مو|امو)? (?:رو )?(?:به (?:اسم|نام) (?:خودش|خودشون|برادرم|برادرش|پدرش|خواهرش|زنش|شوهرش))': 4,
    '(?:ملک|خونه|آپارتمان|زمین|واحد|مغازه|ویلا)[^ ]* (?:که )?(?:رو |را )?(?:خریدم|خریدیم|فروختم|فروخته|معامله کردم)': 3,
    'به (?:یکی|کس|یک نفر) دیگه[^؟]{0,10}فروخت|دوباره فروخت': 3,
    'به (?:دو|چند) نفر فروخت|فروش مال غیر|دفترخونه|دفترخانه|سند رسمی|تک ?برگ|بنگاه|مشاور املاک': 2,
  },
  anti: 'اجاره|مستاجر|صاحبخونه|ازم شکایت|علیه من|ارث|شریک|متهم',
  recap: (f) => [
    if (f.eq('role', 'buyer')) topicText('property_1'),
    if (f.eq('role', 'seller')) topicText('property_2'),
    if (f.yes('written')) topicText('property_3'),
    if (f.no('written')) topicText('property_4'),
    if (f.yes('paid')) topicText('property_5'),
    if (f.no('paid')) topicText('property_6'),
    if (f.yes('registered')) topicText('property_7'),
    if (f.no('registered')) topicText('property_8'),
  ],
  claims: [
    Claim(
      goal: topicText('property_9'),
      when: (f) => !f.eq('role', 'seller'),
      elements: [
        Element(
          topicText('property_10'),
          (f) => f.tri('written'),
          ifNo:
              topicText('property_11'),
        ),
        Element(
          topicText('property_12'),
          (f) => f.tri('paid'),
          ifNo:
              topicText('property_13'),
        ),
        Element(
          topicText('property_14'),
          (f) => f.tri('registered'),
          ifNo:
              topicText('property_15'),
        ),
      ],
      win: (f) =>
          topicText('property_16'),
      counter: (f) =>
          topicText('property_17'),
    ),
  ],
  slots: [
    Slot(
      id: 'role',
      ask: topicText('property_18'),
      why: topicText('property_19'),
      options: [topicText('property_20'), topicText('property_21')],
      yesValue: '',
      noValue: '',
      read: (n) {
        if (Sense.has(n, 'خریدم|خریدیم|خریدار(?:م| هستم)|پیش ?خرید|سند(?:م| رو)? (?:رو )?(?:نمیزن|نزد|نمیده)|به نام(?:م| من) نمیزن')) return 'buyer';
        if (Sense.has(n, 'فروختم|فروخته ام|فروشنده(?: ?ام| هستم)|خریدار (?:پول|نمیده|بقیه)')) return 'seller';
        return null;
      },
      effect: (f) => f.eq('role', 'seller')
          ? topicText('property_22')
          : '',
    ),
    Slot(
      id: 'written',
      ask: topicText('property_23'),
      why: topicText('property_24'),
      options: [topicText('property_25'), topicText('property_26')],
      read: (n) => Sense.yn(
        n,
        'قولنامه (?:دارم|داریم|نوشتیم|کردیم)|مبایعه ?نامه (?:دارم|داریم|نوشتیم)|قولنامه ای|با قولنامه|کد رهگیری|بنگاه نوشت',
        'قولنامه (?:ندارم|نداریم|ننوشتیم)|شفاهی|هیچی ننوشتیم|نوشته ای? ندار',
      ),
      effect: (f) => f.yes('written')
          ? topicText('property_27')
          : topicText('property_28'),
    ),
    Slot(
      id: 'paid',
      ask: topicText('property_29'),
      why: topicText('property_30'),
      options: [topicText('property_31'), topicText('property_32')],
      when: (f) => !f.eq('role', 'seller'),
      read: (n) => Sense.yn(
        n,
        'همه(?:ش| اش)?(?: پول| مبلغ)?(?:ش)? (?:رو |را )?(?:دادم|داده ام|پرداخت)|کل(?: پول| مبلغ)?(?:ش)? (?:رو )?دادم|تسویه (?:کردم|شده)|کامل (?:دادم|پرداخت)',
        'بخشی(?:ش)? مونده|مونده|مانده|باقی ?مونده|قرار(?:ه| بود) (?:موقع|روز) سند|نصف(?:ش)? (?:رو )?دادم|بیعانه دادم',
      ),
      effect: (f) => f.no('paid')
          ? topicText('property_33')
          : '',
    ),
    Slot(
      id: 'registered',
      ask: topicText('property_34'),
      why: topicText('property_35'),
      options: [topicText('property_36'), topicText('property_37')],
      when: (f) => !f.eq('role', 'seller'),
      read: (n) => Sense.yn(
        n,
        'به نام (?:خودش|خودشه|فروشنده)|سند(?:ش)? (?:داره|تک ?برگ)',
        'به نام (?:دیگری|یکی دیگه|کس دیگه|پدرش|شریکش|شرکت|تعاونی)|سند نداره|قولنامه ای(?:ه| است)|وکالتی',
      ),
      effect: (f) => f.no('registered')
          ? topicText('property_38')
          : '',
    ),
  ],
  opening: (f) =>
      topicText('property_39'),
  issues: [
    Issue(
      id: 'double',
      chip: topicText('property_40'),
      cues: 'به (?:دو|چند|یکی دیگه|یک نفر دیگه|کس دیگه|کس دیگری)[^؟]{0,12}فروخت|دوباره فروخت|معامله معارض|فروش مال غیر',
      body: (f) =>
          topicText('property_41'),
    ),
    Issue(
      id: 'noshow',
      chip: topicText('property_42'),
      cues: '(?:دفترخونه|محضر) (?:نیومد|نمیاد|نیاد|نیامد)|حاضر نمیشه|گواهی عدم حضور|نمیاد (?:محضر|سند)',
      body: (f) =>
          topicText('property_43'),
    ),
    Issue(
      id: 'tax',
      chip: topicText('property_44'),
      cues: 'مالیات|عوارض|هزینه (?:سند|انتقال|دفترخونه)|مفاصا',
      body: (f) =>
          topicText('property_45'),
    ),
    Issue(
      id: 'valid',
      chip: topicText('property_46'),
      cues: 'اعتبار|معتبر|قولنامه (?:دستی|عادی)|ارزش (?:قانونی|داره)|به درد',
      body: (f) =>
          topicText('property_47'),
    ),
  ],
  follow: {
    'next': (f) => f.eq('role', 'seller')
        ? topicText('property_48')
        : topicText('property_49'),
    'where': (f) =>
        topicText('property_50'),
    'evidence': (f) =>
        topicText('property_51'),
    'cost': (f) =>
        topicText('property_52'),
    'time': (f) =>
        topicText('property_53'),
    'chance': (f) =>
        topicText('property_54'),
    'refuse': (f) =>
        topicText('property_55'),
  },
  drafts: (f) => const ['formal_notice'],
);
