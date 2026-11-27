// موضوع: آسیب بدنی و دیه.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic injuryTopic = Topic(
  id: 'injury',
  title: topicText('injury_0'),
  cues: {
    'حادثه (?:ی )?(?:کار|ناشی از کار|حین کار)|از داربست|سر کار[^؟]{0,30}(?:آسیب|مصدوم|افتادم|شکست|قطع شد|سوخت|برق گرفت)|دستم (?:رفت )?(?:زیر|لای) (?:دستگاه|پرس)': 6,
    'تصادف|زیر(?:م)? گرفت|زد به (?:ماشینم|من)|کروکی': 4,
    'ماشین(?:م|ام)?[^؟]{0,20}(?:زد|زده|کوبید|خراب کرد)|(?:زد|زده) و فرار|فرار کرد[^؟]{0,20}(?:زد|ماشین)': 4,
    ' دیه |نقص عضو|از ?کار ?افتاد|مصدوم|قطع (?:عضو|انگشت|دست|پا)|خسارت بدنی': 3,
    'گاز(?:م)? گرفت|سگ(?:ش| همسایه)? (?:[^ ]+ ){0,2}حمله|(?:خطا|قصور)(?:ی)? (?:پزشک|دکتر|جراح)|(?:پزشک|دکتر|جراح)[^؟]{0,20}(?:اشتباه|خطا|قصور)|عمل(?:م)? (?:رو )?(?:اشتباه|خراب)': 4,
    'آسیب دید|(?:دست|پا|کمر|سر|چشم|دنده|انگشت)(?:م|ام)? (?:شکست|قطع شد|آسیب|سوخت)': 3,
  },
  anti: 'شوهر|طلاق|همسرم|مهریه',
  recap: (f) => [
    if (f.eq('kind', 'work')) topicText('injury_1'),
    if (f.eq('kind', 'car')) topicText('injury_2'),
    if (f.eq('kind', 'other')) topicText('injury_3'),
    if (f.yes('safe')) topicText('injury_4'),
    if (f.no('safe')) topicText('injury_5'),
    if (f.yes('report')) topicText('injury_6'),
    if (f.no('report')) topicText('injury_7'),
  ],
  claims: [
    Claim(
      goal: topicText('injury_8'),
      when: (f) => f.eq('kind', 'work'),
      elements: [
        Element(
          topicText('injury_9'),
          (f) => true,
        ),
        Element(
          topicText('injury_10'),
          (f) => f.has('safe') ? f.no('safe') : null,
          ifNo:
              topicText('injury_11'),
        ),
        Element(
          topicText('injury_12'),
          (f) => f.tri('report'),
          ifNo:
              topicText('injury_13'),
        ),
      ],
      win: (f) =>
          topicText('injury_14'),
      counter: (f) =>
          topicText('injury_15'),
    ),
    Claim(
      goal: topicText('injury_16'),
      elements: [
        Element(
          topicText('injury_17'),
          (f) => f.has('kind') ? true : null,
        ),
        Element(
          topicText('injury_18'),
          (f) => f.tri('report'),
          ifNo:
              topicText('injury_19'),
        ),
        Element(
          topicText('injury_20'),
          (f) => null,
        ),
      ],
      win: (f) =>
          topicText('injury_21'),
      counter: (f) =>
          topicText('injury_22'),
    ),
  ],
  slots: [
    Slot(
      id: 'kind',
      ask: topicText('injury_23'),
      why: topicText('injury_24'),
      options: [topicText('injury_25'), topicText('injury_26'), topicText('injury_27')],
      yesValue: '',
      noValue: '',
      read: (n) {
        if (Sense.has(n, 'سر کار|حین کار|محل کار|کارگاه|کارخونه|کارخانه|داربست|دستگاه|پرس|کارفرما|حادثه (?:ی )?کار')) return 'work';
        if (Sense.has(n, 'تصادف|راننده|زیر(?:م)? گرفت|کروکی|عابر|(?:ماشین|موتور)(?:ی)? (?:[^ ]+ ){0,2}(?:زد|خورد)')) return 'car';
        if (Sense.has(n, 'جای دیگ|(?:خطا|قصور|اشتباه)(?:ی)? (?:پزشک|دکتر|جراح)|(?:پزشک|دکتر|جراح) (?:[^ ]+ ){0,2}(?:اشتباه|خطا|خراب)|سگ|چاله|گود')) return 'other';
        return null;
      },
      effect: (f) => f.eq('kind', 'work')
          ? topicText('injury_28')
          : f.eq('kind', 'car')
              ? topicText('injury_29')
              : topicText('injury_30'),
    ),
    Slot(
      id: 'safe',
      ask: topicText('injury_31'),
      why: topicText('injury_32'),
      options: [topicText('injury_33'), topicText('injury_34')],
      when: (f) => f.eq('kind', 'work'),
      read: (n) => Sense.yn(
        n,
        'ایمنی (?:داشتیم|داده بودن|بود)|کلاه (?:داشتم|داده بودن)|آموزش (?:دیدم|داده بودن)|کمربند (?:داشتم|بسته بودم)|بله داده بودند',
        'ایمنی (?:نداشت|نبود|ندادن|نداده بودن)|کلاه (?:نداشتم|ندادن)|کمربند (?:نداشتم|نبود|ندادن)|آموزش (?:ندادن|ندیدم|نداده بودن)|حفاظ نداشت|هیچ(?:ی)? ندادن|بدون (?:ایمنی|کمربند|کلاه|حفاظ)|نداده بودن',
      ),
      effect: (f) => f.no('safe')
          ? topicText('injury_35')
          : topicText('injury_36'),
    ),
    Slot(
      id: 'report',
      ask: topicText('injury_37'),
      why: topicText('injury_38'),
      options: [topicText('injury_39'), topicText('injury_40')],
      read: (n) => Sense.yn(
        n,
        'پزشک(?:ی)? قانونی (?:رفتم|دارم|نظر داد)|گزارش (?:بازرس|حادثه|پلیس) (?:دارم|هست|نوشت)|کروکی (?:کشید|دارم)|صورت ?جلسه (?:شد|دارم)|طول درمان',
        'پزشک(?:ی)? قانونی نرفتم|گزارش(?:ی)? (?:ندارم|نشد|ننوشتن)|کروکی (?:نکشید|ندارم)|هنوز (?:نرفتم|هیچ کاری)',
      ),
      effect: (f) => f.yes('report')
          ? topicText('injury_41')
          : topicText('injury_42'),
    ),
  ],
  opening: (f) =>
      topicText('injury_43'),
  issues: [
    Issue(
      id: 'beyond',
      chip: topicText('injury_44'),
      cues: 'غیر از دیه|بیشتر از دیه|هزینه درمان|نمیتونم کار کنم|خرج (?:درمان|بیمارستان)|بیکار شدم',
      body: (f) =>
          topicText('injury_45'),
    ),
    Issue(
      id: 'ins',
      chip: topicText('injury_46'),
      cues: 'تامین اجتماعی|غرامت|مستمری|بیمه (?:چی|چه)',
      when: (f) => !f.eq('kind', 'car'),
      body: (f) =>
          topicText('injury_47'),
    ),
    Issue(
      id: 'boss',
      chip: topicText('injury_48'),
      cues: 'کارگر(?:ش| اون| شرکت| کس دیگ| یکی دیگ)|راننده(?:ی)? شرکت|مامور(?:ش)?|پیک',
      body: (f) =>
          topicText('injury_49'),
    ),
  ],
  follow: {
    'next': (f) => f.eq('kind', 'work')
        ? topicText('injury_50')
        : topicText('injury_51'),
    'where': (f) =>
        topicText('injury_52'),
    'evidence': (f) =>
        topicText('injury_53'),
    'time': (f) =>
        topicText('injury_54'),
    'chance': (f) =>
        topicText('injury_55'),
    'cost': (f) =>
        topicText('injury_56'),
  },
  drafts: (f) => const ['complaint'],
);
