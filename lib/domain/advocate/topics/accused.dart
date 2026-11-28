// موضوع: متهم (کسی که از او شکایت شده).
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

const String _fraudRe = 'کلاهبردار';
const String _trustRe = 'خیانت در امانت';
const String _threatRe = 'تهدید';

const TextExpr _chargeDisplayName = TxSwitch(
  'charge',
  {
    'fraud': Tx('accused_12'),
    'trust': Tx('accused_13'),
    'insult': Tx('accused_14'),
    'threat': Tx('accused_15'),
    'assault': Tx('accused_16'),
    'theft': Tx('accused_17'),
    'defame': Tx('accused_18'),
  },
  fallback: Tx('accused_19'),
);

const ReadRule _accChargeRule = ReadCases([
  ReadCase(
      'نمیدونم (?:برای|بابت|سر) چی|نمیدونم چرا|نگفتن (?:برای|بابت) چی|معلوم نیست (?:برای|بابت) چی|ننوشته (?:برای|بابت) چی',
      '?'),
  ReadCase(_fraudRe, 'fraud'),
  ReadCase(_trustRe, 'trust'),
  ReadCase('توهین|فحاشی|فحش', 'insult'),
  ReadCase(_threatRe, 'threat'),
  ReadCase('ضرب|کتک|دعوا|درگیری', 'assault'),
  ReadCase('سرقت|دزدی', 'theft'),
  ReadCase('افترا|تهمت|نشر اکاذیب', 'defame'),
]);

const List<RecapItem> _accusedRecap = [
  RecapItem(
    when: FactIn('charge', ['fraud', 'trust', 'insult', 'threat', 'assault', 'theft', 'defame']),
    text: TxJoin(' ', [
      Tx('accusedRecapChargeA'),
      TxSwitch('charge', {
        'fraud': Tx('accused_0'),
        'trust': Tx('accused_1'),
        'insult': Tx('accused_2'),
        'threat': Tx('accused_3'),
        'assault': Tx('accused_4'),
        'theft': Tx('accused_5'),
        'defame': Tx('accused_6'),
      }),
      Tx('accusedRecapChargeB'),
    ]),
  ),
  RecapItem(when: FactEq('charge', '?'), text: Tx('accused_7')),
  RecapItem(when: FactYes('notice'), text: Tx('accused_8')),
  RecapItem(when: FactNo('notice'), text: Tx('accused_9')),
  RecapItem(when: FactYes('docs'), text: Tx('accused_10')),
  RecapItem(when: FactNo('docs'), text: Tx('accused_11')),
];

final Topic accusedTopic = Topic.dsl(
  id: 'accused',
  title: topicText('accused_22'),
  recap: _accusedRecap,
  cues: {
    'به من اتهام|اتهام زد|اتهام زده|اتهام(?:ی)? (?:بهم|به من)': 4,
    'احضار شد|رای غیابی|حکم غیابی|واخواهی|قرار (?:جلب به دادرسی|بازداشت|کفالت|وثیقه)|حکم جلب': 3,
    'ازم شکایت|از من شکایت|علیه من|برام (?:شکایت|پرونده)|ازمون شکایت|شکایت کرد(?:ه|ن|ند)? ازم': 4,
    'متهم(?:م| شدم| هستم| کرد)|به جرم|شاکی دارم|پاپوش|تهمت زد': 3,
    'احضاریه|ابلاغیه|احضار[^ ]* کرد|بازپرس|جلب[^ ]* (?:گرفت|کرد)|برگه جلب': 3,
    'کاری نکردم|بی ?گناه': 1,
  },
  slots: [
    Slot.dsl(
      id: 'charge',
      ask: topicText('accused_23'),
      why: topicText('accused_24'),
      read: _accChargeRule,
      readPending: const ReadSeq([
        _accChargeRule,
        ReadShortNonQuestion('other'),
      ]),
      yesValue: '',
      noValue: '',
      effect: const TxCond(FactEq('charge', 'fraud'), Tx('accused_25')),
    ),
    Slot.dsl(
      id: 'notice',
      ask: topicText('accused_26'),
      why: topicText('accused_27'),
      options: [topicText('accused_28'), topicText('accused_29')],
      read: const ReadYn(
        'ابلاغیه|احضاریه|احضار[^ ]* کرد|پیامک ثنا|ثنا (?:اومد|پیام)|برام (?:نامه|برگه) (?:اومد|فرستاد)|زنگ زدن از (?:کلانتری|آگاهی|دادسرا)|باید برم (?:دادسرا|کلانتری|آگاهی)',
        'ابلاغیه(?:ای)? (?:نیومده|نیامده|ندارم)|هنوز (?:چیزی|خبری|ابلاغ) (?:نیومده|نیست|نشده)|فقط (?:گفته|تهدید)',
      ),
      effect: const TxCond(
          FactYes('notice'), Tx('accused_30'), Tx('accused_31')),
    ),
    Slot.dsl(
      id: 'docs',
      ask: topicText('accused_32'),
      why: topicText('accused_33'),
      options: [topicText('accused_34'), topicText('accused_35')],
      when: const FactNot(FactEq('charge', '?')),
      read: const ReadYn(
        'قولنامه|مبایعه ?نامه|قرارداد (?:دارم|داریم|نوشتیم)|رسید (?:دارم|گرفتم)|فاکتور|سند (?:زدیم|زدم)|برگه کارشناسی|کارشناسی (?:برد|کرد)|پیام(?:ها)?(?:ش)? (?:رو )?دارم',
        'هیچ(?:ی)? ننوشتیم|قولنامه (?:نداریم|ندارم)|مدرک(?:ی)? ندارم|شفاهی',
      ),
      effect: const TxCond(
          FactYes('docs'), Tx('accused_36'), Tx('accused_37')),
    ),
  ],
  opening: const TxJoin('\n', [
    Tx('accusedOpenBase'),
    TxCond(FactEq('charge', '?'), Tx('accusedOpenUnknown')),
  ]),
  issues: [
    Issue.dsl(
      id: 'noshow',
      chip: topicText('accused_38'),
      cues: 'نروم|نرم |نرفتم|حاضر نشم|حاضر نشوم|باید برم|برم یا ن|مجبورم برم|نیام |غیبت',
      body: const Tx('accused_39'),
    ),
    Issue.dsl(
      id: 'defect',
      chip: topicText('accused_40'),
      cues: 'ایراد|خراب(?:ه| بود| بوده| دراومد)|عیب|معیوب|تصادفی|رنگ داشت|موتور|فروختم|معامله',
      body: const Tx('accused_21'),
      when: const FactIn('charge', ['fraud', 'other']),
    ),
    Issue.dsl(
      id: 'say',
      chip: topicText('accused_41'),
      cues: 'چی بگم|چه دفاعی|دفاع کنم|چطور(?:ی)? دفاع|چجوری دفاع|بازجویی|بازپرسی|چی بنویسم|لایحه|حق(?:وق)?(?:م)? چیه|سکوت',
      body: const Tx('accused_20'),
    ),
    Issue.dsl(
      id: 'jail',
      chip: topicText('accused_42'),
      cues: 'زندان|بازداشت|میگیرنم|دستگیر|وثیقه|کفیل|کفالت|قرار (?:تامین|وثیقه|بازداشت)|مجازات|حبس|چند سال',
      body: const TxConcat([
        Tx('accusedJailBody'),
        TxCond(FactEq('charge', 'fraud'), Tx('accused_43')),
      ]),
    ),
    Issue.dsl(
      id: 'counter',
      chip: topicText('accused_44'),
      cues: 'متقابل|ازش شکایت (?:کنم|میکنم)|افترا|اعاده حیثیت|تهمت|آبرو',
      body: const Tx('accused_45'),
    ),
    Issue.dsl(
      id: 'settle',
      chip: topicText('accused_46'),
      cues: 'رضایت|سازش|مصالحه|صلح|کنار بیام|پول(?:ش| شو)? (?:رو )?بدم',
      body: const Tx('accused_47'),
    ),
  ],
  follow: const {
    'next': TxJoin('\n', [
      Tx('accusedNextLead'),
      TxCond(FactYes('notice'), Tx('accused_48'), Tx('accused_49')),
      Tx('accusedNextTail'),
    ]),
    'where': Tx('accused_50'),
    'lawyer': TxConcat([
      Tx('accusedLawyerA'),
      TxCond(
        FactAll([FactHas('charge'), FactNot(FactEq('charge', 'other'))]),
        TxJoin(' ', [Tx('accusedLawyerCharge'), _chargeDisplayName]),
      ),
      Tx('accusedLawyerB'),
    ]),
    'chance': Tx('accused_51'),
    'time': Tx('accused_52'),
    'cost': Tx('accused_53'),
    'evidence': Tx('accused_54'),
  },
  drafts: const DraftRule.fixed(['defense_brief', 'legal_aid']),
);
