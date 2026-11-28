// موضوع: خرید و فروش ملک.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic propertyTopic = Topic.dsl(
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
  recap: const [
    RecapItem(when: FactEq('role', 'buyer'), text: Tx('property_1')),
    RecapItem(when: FactEq('role', 'seller'), text: Tx('property_2')),
    RecapItem(when: FactYes('written'), text: Tx('property_3')),
    RecapItem(when: FactNo('written'), text: Tx('property_4')),
    RecapItem(when: FactYes('paid'), text: Tx('property_5')),
    RecapItem(when: FactNo('paid'), text: Tx('property_6')),
    RecapItem(when: FactYes('registered'), text: Tx('property_7')),
    RecapItem(when: FactNo('registered'), text: Tx('property_8')),
  ],
  claims: [
    Claim.dsl(
      goal: topicText('property_9'),
      when: const FactNot(FactEq('role', 'seller')),
      elements: [
        Element.dsl(
          topicText('property_10'),
          const FactTri('written'),
          ifNo: topicText('property_11'),
        ),
        Element.dsl(
          topicText('property_12'),
          const FactTri('paid'),
          ifNo: topicText('property_13'),
        ),
        Element.dsl(
          topicText('property_14'),
          const FactTri('registered'),
          ifNo: topicText('property_15'),
        ),
      ],
      win: const Tx('property_16'),
      counter: const Tx('property_17'),
    ),
  ],
  slots: [
    Slot.dsl(
      id: 'role',
      ask: topicText('property_18'),
      why: topicText('property_19'),
      options: [topicText('property_20'), topicText('property_21')],
      yesValue: '',
      noValue: '',
      read: const ReadCases([
        ReadCase('خریدم|خریدیم|خریدار(?:م| هستم)|پیش ?خرید|سند(?:م| رو)? (?:رو )?(?:نمیزن|نزد|نمیده)|به نام(?:م| من) نمیزن', 'buyer'),
        ReadCase('فروختم|فروخته ام|فروشنده(?: ?ام| هستم)|خریدار (?:پول|نمیده|بقیه)', 'seller'),
      ]),
      effect: const TxCond(FactEq('role', 'seller'), Tx('property_22')),
    ),
    Slot.dsl(
      id: 'written',
      ask: topicText('property_23'),
      why: topicText('property_24'),
      options: [topicText('property_25'), topicText('property_26')],
      read: const ReadYn(
        'قولنامه (?:دارم|داریم|نوشتیم|کردیم)|مبایعه ?نامه (?:دارم|داریم|نوشتیم)|قولنامه ای|با قولنامه|کد رهگیری|بنگاه نوشت',
        'قولنامه (?:ندارم|نداریم|ننوشتیم)|شفاهی|هیچی ننوشتیم|نوشته ای? ندار',
      ),
      effect: const TxCond(
          FactYes('written'), Tx('property_27'), Tx('property_28')),
    ),
    Slot.dsl(
      id: 'paid',
      ask: topicText('property_29'),
      why: topicText('property_30'),
      options: [topicText('property_31'), topicText('property_32')],
      when: const FactNot(FactEq('role', 'seller')),
      read: const ReadYn(
        'همه(?:ش| اش)?(?: پول| مبلغ)?(?:ش)? (?:رو |را )?(?:دادم|داده ام|پرداخت)|کل(?: پول| مبلغ)?(?:ش)? (?:رو )?دادم|تسویه (?:کردم|شده)|کامل (?:دادم|پرداخت)',
        'بخشی(?:ش)? مونده|مونده|مانده|باقی ?مونده|قرار(?:ه| بود) (?:موقع|روز) سند|نصف(?:ش)? (?:رو )?دادم|بیعانه دادم',
      ),
      effect: const TxCond(FactNo('paid'), Tx('property_33')),
    ),
    Slot.dsl(
      id: 'registered',
      ask: topicText('property_34'),
      why: topicText('property_35'),
      options: [topicText('property_36'), topicText('property_37')],
      when: const FactNot(FactEq('role', 'seller')),
      read: const ReadYn(
        'به نام (?:خودش|خودشه|فروشنده)|سند(?:ش)? (?:داره|تک ?برگ)',
        'به نام (?:دیگری|یکی دیگه|کس دیگه|پدرش|شریکش|شرکت|تعاونی)|سند نداره|قولنامه ای(?:ه| است)|وکالتی',
      ),
      effect: const TxCond(FactNo('registered'), Tx('property_38')),
    ),
  ],
  opening: const Tx('property_39'),
  issues: [
    Issue.dsl(
      id: 'double',
      chip: topicText('property_40'),
      cues: 'به (?:دو|چند|یکی دیگه|یک نفر دیگه|کس دیگه|کس دیگری)[^؟]{0,12}فروخت|دوباره فروخت|معامله معارض|فروش مال غیر',
      body: const Tx('property_41'),
    ),
    Issue.dsl(
      id: 'noshow',
      chip: topicText('property_42'),
      cues: '(?:دفترخونه|محضر) (?:نیومد|نمیاد|نیاد|نیامد)|حاضر نمیشه|گواهی عدم حضور|نمیاد (?:محضر|سند)',
      body: const Tx('property_43'),
    ),
    Issue.dsl(
      id: 'tax',
      chip: topicText('property_44'),
      cues: 'مالیات|عوارض|هزینه (?:سند|انتقال|دفترخونه)|مفاصا',
      body: const Tx('property_45'),
    ),
    Issue.dsl(
      id: 'valid',
      chip: topicText('property_46'),
      cues: 'اعتبار|معتبر|قولنامه (?:دستی|عادی)|ارزش (?:قانونی|داره)|به درد',
      body: const Tx('property_47'),
    ),
  ],
  follow: const {
    'next': TxCond(FactEq('role', 'seller'), Tx('property_48'), Tx('property_49')),
    'where': Tx('property_50'),
    'evidence': Tx('property_51'),
    'cost': Tx('property_52'),
    'time': Tx('property_53'),
    'chance': Tx('property_54'),
    'refuse': Tx('property_55'),
  },
  drafts: const DraftRule.fixed(['formal_notice']),
);
