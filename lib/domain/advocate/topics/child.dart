// موضوع: آزار کودک.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic childTopic = Topic(
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
  recap: (f) => [
    if (f.eq('who', 'parent')) topicText('child_1'),
    if (f.eq('who', 'other')) topicText('child_2'),
    if (f.yes('urgent')) topicText('child_3'),
    if (f.no('urgent')) topicText('child_4'),
    if (f.yes('proof')) topicText('child_5'),
    if (f.no('proof')) topicText('child_6'),
  ],
  claims: [
    Claim(
      goal: topicText('child_7'),
      elements: [
        Element(
          topicText('child_8'),
          (f) => f.has('who') ? true : null,
        ),
        Element(
          topicText('child_9'),
          (f) => f.tri('urgent'),
          ifNo:
              topicText('child_10'),
        ),
        Element(
          topicText('child_11'),
          (f) => f.tri('proof'),
          ifNo:
              topicText('child_12'),
        ),
      ],
      win: (f) =>
          topicText('child_13'),
      counter: (f) =>
          topicText('child_14'),
    ),
  ],
  slots: [
    Slot(
      id: 'who',
      ask: topicText('child_15'),
      why: topicText('child_16'),
      options: [topicText('child_17'), topicText('child_18')],
      yesValue: '',
      noValue: '',
      read: (n) {
        if (Sense.has(n, 'معلم|ناظم|مدیر مدرسه|مربی|غریبه|صاحب ?کار|کسی دیگ|یکی دیگ')) return 'other';
        if (Sense.has(n, 'پدر|مادر|بابا|مامان|ناپدری|نامادری|سرپرست|شوهرم|زنم|همسرم')) return 'parent';
        return null;
      },
    ),
    Slot(
      id: 'urgent',
      ask: topicText('child_19'),
      why: topicText('child_20'),
      options: [topicText('child_21'), topicText('child_22')],
      read: (n) => Sense.yn(
        n,
        'خطر (?:جدی|داره)|هر روز|هر شب|همین حالا|کبود|زخم|خونریزی|شکست|جنسی|حبس(?:ش)? کرد|میترسم بکش',
        'فوری نیست|خطر(?:ی)? نداره|گاهی|فقط (?:داد|فحش)',
      ),
      effect: (f) => f.yes('urgent')
          ? topicText('child_23')
          : topicText('child_24'),
    ),
    Slot(
      id: 'proof',
      ask: topicText('child_25'),
      why: topicText('child_26'),
      options: [topicText('child_27'), topicText('child_28')],
      read: (n) => Sense.yn(
        n,
        'کبود|عکس (?:دارم|گرفتم)|پزشک(?:ی)? (?:قانونی|نامه)|گواهی|شاهد (?:دارم|هست)|خودش گفت|همه میدونن|دیدم',
        'مدرک(?:ی)? ندارم|فقط میدونم|ندیدم|شاهد ندارم',
      ),
      effect: (f) => f.yes('proof')
          ? topicText('child_29')
          : '',
    ),
  ],
  opening: (f) =>
      topicText('child_30'),
  issues: [
    Issue(
      id: 'report',
      chip: topicText('child_31'),
      cues: 'گزارش|کجا (?:بگم|زنگ|خبر)|به کی (?:بگم|خبر)|۱۲۳|123|اورژانس',
      body: (f) =>
          topicText('child_32'),
    ),
    Issue(
      id: 'school',
      chip: topicText('child_33'),
      cues: 'مدرسه نمی|درس (?:نمی|نخون)|تحصیل|ثبت ?نام',
      body: (f) =>
          topicText('child_34'),
    ),
    Issue(
      id: 'afraid',
      chip: topicText('child_35'),
      cues: 'میترسم بفهم|بفهم(?:ن|ه) (?:من|کار)|اسم(?:م| من)|لو (?:برم|بره)|دردسر',
      body: (f) =>
          topicText('child_36'),
    ),
  ],
  follow: {
    'next': (f) =>
        topicText('child_37'),
    'where': (f) =>
        topicText('child_38'),
    'evidence': (f) =>
        topicText('child_39'),
    'cost': (f) =>
        topicText('child_40'),
    'chance': (f) =>
        topicText('child_41'),
  },
  drafts: (f) => const ['complaint'],
);
