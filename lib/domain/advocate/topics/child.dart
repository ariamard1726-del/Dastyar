// موضوع: آزار کودک.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic childTopic = Topic.dsl(
  id: 'child',
  title: topicText('child_0'),
  cues: {
    'بچه(?:م|ش|مو|امو)?[^؟]{0,25}(?:برده|ببره|نمیده|نمیدهد|نده|نمیدن|نگه داشته)|(?:پسرم|دخترم|فرزندم)[^؟]{0,25}(?:برده|ببره|نمیده|نمیدهد|نگه داشته)': 4,
    'کودک ?آزاری|آزار جنسی|سوء ?استفاده جنسی|سوء ?استفاده از (?:بچه|کودک|دختر|پسر|فرزند)': 5,
    'بهزیستی|اورژانس اجتماعی': 3,
    '(?:بچه|کودک|دختر|پسر|شاگرد|دانش ?آموز)[^ ]*(?: [^ ]+){0,5} (?:کتک|میزن|آزار|شکنجه|حبس|داغ)': 4,
    '(?:بچه|کودک|دختر|پسر|شاگرد|دانش ?آموز)(?:م|ش|مون|شون)?(?:و| رو| را) (?:[^ ]+ ){0,2}(?:زد|زده|زدن)(?: |\$)': 4,
    'مدرسه نمیفرست|ترک تحصیل|نمیذار(?:ه|ن)? (?:[^ ]+ ){0,2}(?:درس|مدرسه)|از بچه کار میکش|کار کودک': 4,
  },
  anti: 'طلاق|مهریه|حضانت|نفقه',
  recap: const [
    RecapItem(when: FactEq('who', 'parent'), text: Tx('child_1')),
    RecapItem(when: FactEq('who', 'other'), text: Tx('child_2')),
    RecapItem(when: FactYes('urgent'), text: Tx('child_3')),
    RecapItem(when: FactNo('urgent'), text: Tx('child_4')),
    RecapItem(when: FactYes('proof'), text: Tx('child_5')),
    RecapItem(when: FactNo('proof'), text: Tx('child_6')),
  ],
  claims: [
    Claim.dsl(
      goal: topicText('child_7'),
      elements: [
        Element.dsl(
          topicText('child_8'),
          const FactTriIf(FactHas('who'), true),
        ),
        Element.dsl(
          topicText('child_9'),
          const FactTri('urgent'),
          ifNo: topicText('child_10'),
        ),
        Element.dsl(
          topicText('child_11'),
          const FactTri('proof'),
          ifNo: topicText('child_12'),
        ),
      ],
      win: const Tx('child_13'),
      counter: const Tx('child_14'),
    ),
  ],
  slots: [
    Slot.dsl(
      id: 'who',
      ask: topicText('child_15'),
      why: topicText('child_16'),
      options: [topicText('child_17'), topicText('child_18')],
      yesValue: '',
      noValue: '',
      read: const ReadCases([
        ReadCase('معلم|ناظم|مدیر مدرسه|مربی|غریبه|صاحب ?کار|کسی دیگ|یکی دیگ', 'other'),
        ReadCase('پدر|مادر|بابا|مامان|ناپدری|نامادری|سرپرست|شوهرم|زنم|همسرم', 'parent'),
      ]),
    ),
    Slot.dsl(
      id: 'urgent',
      ask: topicText('child_19'),
      why: topicText('child_20'),
      options: [topicText('child_21'), topicText('child_22')],
      read: const ReadYn(
        'خطر (?:جدی|داره)|هر روز|هر شب|همین حالا|کبود|زخم|خونریزی|شکست|جنسی|حبس(?:ش)? کرد|میترسم بکش',
        'فوری نیست|خطر(?:ی)? نداره|گاهی|فقط (?:داد|فحش)',
      ),
      effect: const TxCond(FactYes('urgent'), Tx('child_23'), Tx('child_24')),
    ),
    Slot.dsl(
      id: 'proof',
      ask: topicText('child_25'),
      why: topicText('child_26'),
      options: [topicText('child_27'), topicText('child_28')],
      read: const ReadYn(
        'کبود|عکس (?:دارم|گرفتم)|پزشک(?:ی)? (?:قانونی|نامه)|گواهی|شاهد (?:دارم|هست)|خودش گفت|همه میدونن|دیدم',
        'مدرک(?:ی)? ندارم|فقط میدونم|ندیدم|شاهد ندارم',
      ),
      effect: const TxCond(FactYes('proof'), Tx('child_29')),
    ),
  ],
  opening: const Tx('child_30'),
  issues: [
    Issue.dsl(
      id: 'report',
      chip: topicText('child_31'),
      cues: 'گزارش|کجا (?:بگم|زنگ|خبر)|به کی (?:بگم|خبر)|۱۲۳|123|اورژانس',
      body: const Tx('child_32'),
    ),
    Issue.dsl(
      id: 'school',
      chip: topicText('child_33'),
      cues: 'مدرسه نمی|درس (?:نمی|نخون)|تحصیل|ثبت ?نام',
      body: const Tx('child_34'),
    ),
    Issue.dsl(
      id: 'afraid',
      chip: topicText('child_35'),
      cues: 'میترسم بفهم|بفهم(?:ن|ه) (?:من|کار)|اسم(?:م| من)|لو (?:برم|بره)|دردسر',
      body: const Tx('child_36'),
    ),
  ],
  follow: const {
    'next': Tx('child_37'),
    'where': Tx('child_38'),
    'evidence': Tx('child_39'),
    'cost': Tx('child_40'),
    'chance': Tx('child_41'),
  },
  drafts: const DraftRule.fixed(['complaint']),
);
