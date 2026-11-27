// موضوع: متهم (کسی که از او شکایت شده).
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

// ---- برداشت وکیل و ادعاها

List<String> accusedRecap(CaseFile f) {
  final names = {
    'fraud': topicText('accused_0'),
    'trust': topicText('accused_1'),
    'insult': topicText('accused_2'),
    'threat': topicText('accused_3'),
    'assault': topicText('accused_4'),
    'theft': topicText('accused_5'),
    'defame': topicText('accused_6'),
  };
  final c = names[f.get('charge')];
  return [
    if (c != null) topicText('accusedRecapChargeA') + ' ' + c + ' ' + topicText('accusedRecapChargeB'),
    if (f.eq('charge', '?')) topicText('accused_7'),
    if (f.yes('notice')) topicText('accused_8'),
    if (f.no('notice')) topicText('accused_9'),
    if (f.yes('docs')) topicText('accused_10'),
    if (f.no('docs')) topicText('accused_11'),
  ];
}

// ---- پرسش‌ها و پاسخ‌ها

String? _accCharge(String n) {
  if (Sense.has(n,
      'نمیدونم (?:برای|بابت|سر) چی|نمیدونم چرا|نگفتن (?:برای|بابت) چی|معلوم نیست (?:برای|بابت) چی|ننوشته (?:برای|بابت) چی')) {
    return '?';
  }
  if (Sense.has(n, 'کلاهبردار')) return 'fraud';
  if (Sense.has(n, 'خیانت در امانت')) return 'trust';
  if (Sense.has(n, 'توهین|فحاشی|فحش')) return 'insult';
  if (Sense.has(n, 'تهدید')) return 'threat';
  if (Sense.has(n, 'ضرب|کتک|دعوا|درگیری')) return 'assault';
  if (Sense.has(n, 'سرقت|دزدی')) return 'theft';
  if (Sense.has(n, 'افترا|تهمت|نشر اکاذیب')) return 'defame';
  return null;
}

String _accChargeName(CaseFile f) {
  switch (f.get('charge')) {
    case 'fraud':
      return topicText('accused_12');
    case 'trust':
      return topicText('accused_13');
    case 'insult':
      return topicText('accused_14');
    case 'threat':
      return topicText('accused_15');
    case 'assault':
      return topicText('accused_16');
    case 'theft':
      return topicText('accused_17');
    case 'defame':
      return topicText('accused_18');
    default:
      return topicText('accused_19');
  }
}

String _accRights(CaseFile f) =>
    topicText('accused_20');

String _accDefect(CaseFile f) =>
    topicText('accused_21');

final Topic accusedTopic = Topic(
  id: 'accused',
  title: topicText('accused_22'),
  recap: accusedRecap,
  cues: {
    'به من اتهام|اتهام زد|اتهام زده|اتهام(?:ی)? (?:بهم|به من)': 4,
    'احضار شد|رای غیابی|حکم غیابی|واخواهی|قرار (?:جلب به دادرسی|بازداشت|کفالت|وثیقه)|حکم جلب': 3,
    'ازم شکایت|از من شکایت|علیه من|برام (?:شکایت|پرونده)|ازمون شکایت|شکایت کرد(?:ه|ن|ند)? ازم': 4,
    'متهم(?:م| شدم| هستم| کرد)|به جرم|شاکی دارم|پاپوش|تهمت زد': 3,
    'احضاریه|ابلاغیه|احضار[^ ]* کرد|بازپرس|جلب[^ ]* (?:گرفت|کرد)|برگه جلب': 3,
    'کاری نکردم|بی ?گناه': 1,
  },
  slots: [
    Slot(
      id: 'charge',
      ask: topicText('accused_23'),
      why: topicText('accused_24'),
      read: _accCharge,
      readPending: (n) =>
          _accCharge(n) ??
          (Sense.words(n) <= 6 && !Sense.isQuestion(n) ? 'other' : null),
      yesValue: '',
      noValue: '',
      effect: (f) => f.eq('charge', 'fraud')
          ? topicText('accused_25')
          : '',
    ),
    Slot(
      id: 'notice',
      ask: topicText('accused_26'),
      why: topicText('accused_27'),
      options: [topicText('accused_28'), topicText('accused_29')],
      read: (n) => Sense.yn(
        n,
        'ابلاغیه|احضاریه|احضار[^ ]* کرد|پیامک ثنا|ثنا (?:اومد|پیام)|برام (?:نامه|برگه) (?:اومد|فرستاد)|زنگ زدن از (?:کلانتری|آگاهی|دادسرا)|باید برم (?:دادسرا|کلانتری|آگاهی)',
        'ابلاغیه(?:ای)? (?:نیومده|نیامده|ندارم)|هنوز (?:چیزی|خبری|ابلاغ) (?:نیومده|نیست|نشده)|فقط (?:گفته|تهدید)',
      ),
      effect: (f) => f.yes('notice')
          ? topicText('accused_30')
          : topicText('accused_31'),
    ),
    Slot(
      id: 'docs',
      ask: topicText('accused_32'),
      why: topicText('accused_33'),
      options: [topicText('accused_34'), topicText('accused_35')],
      when: (f) => f.get('charge') != '?',
      read: (n) => Sense.yn(
        n,
        'قولنامه|مبایعه ?نامه|قرارداد (?:دارم|داریم|نوشتیم)|رسید (?:دارم|گرفتم)|فاکتور|سند (?:زدیم|زدم)|برگه کارشناسی|کارشناسی (?:برد|کرد)|پیام(?:ها)?(?:ش)? (?:رو )?دارم',
        'هیچ(?:ی)? ننوشتیم|قولنامه (?:نداریم|ندارم)|مدرک(?:ی)? ندارم|شفاهی',
      ),
      effect: (f) => f.yes('docs')
          ? topicText('accused_36')
          : topicText('accused_37'),
    ),
  ],
  opening: (f) {
    final base = topicText('accusedOpenBase');
    if (f.get('charge') != '?') return base;
    return base + '\n' + topicText('accusedOpenUnknown');
  },
  issues: [
    Issue(
      id: 'noshow',
      chip: topicText('accused_38'),
      cues: 'نروم|نرم |نرفتم|حاضر نشم|حاضر نشوم|باید برم|برم یا ن|مجبورم برم|نیام |غیبت',
      body: (f) =>
          topicText('accused_39'),
    ),
    Issue(
      id: 'defect',
      chip: topicText('accused_40'),
      cues: 'ایراد|خراب(?:ه| بود| بوده| دراومد)|عیب|معیوب|تصادفی|رنگ داشت|موتور|فروختم|معامله',
      body: _accDefect,
      when: (f) => f.eq('charge', 'fraud') || f.eq('charge', 'other'),
    ),
    Issue(
      id: 'say',
      chip: topicText('accused_41'),
      cues: 'چی بگم|چه دفاعی|دفاع کنم|چطور(?:ی)? دفاع|چجوری دفاع|بازجویی|بازپرسی|چی بنویسم|لایحه|حق(?:وق)?(?:م)? چیه|سکوت',
      body: _accRights,
    ),
    Issue(
      id: 'jail',
      chip: topicText('accused_42'),
      cues: 'زندان|بازداشت|میگیرنم|دستگیر|وثیقه|کفیل|کفالت|قرار (?:تامین|وثیقه|بازداشت)|مجازات|حبس|چند سال',
      body: (f) {
        final pen = f.eq('charge', 'fraud')
            ? topicText('accused_43')
            : '';
        return topicText('accusedJailBody') + pen;
      },
    ),
    Issue(
      id: 'counter',
      chip: topicText('accused_44'),
      cues: 'متقابل|ازش شکایت (?:کنم|میکنم)|افترا|اعاده حیثیت|تهمت|آبرو',
      body: (f) =>
          topicText('accused_45'),
    ),
    Issue(
      id: 'settle',
      chip: topicText('accused_46'),
      cues: 'رضایت|سازش|مصالحه|صلح|کنار بیام|پول(?:ش| شو)? (?:رو )?بدم',
      body: (f) =>
          topicText('accused_47'),
    ),
  ],
  follow: {
    'next': (f) {
      final first = f.yes('notice')
          ? topicText('accused_48')
          : topicText('accused_49');
      return topicText('accusedNextLead') + '\n' + first + '\n' + topicText('accusedNextTail');
    },
    'where': (f) =>
        topicText('accused_50'),
    'lawyer': (f) =>
        topicText('accusedLawyerA') + (f.has('charge') && !f.eq('charge', 'other') ? topicText('accusedLawyerCharge') + ' ' + _accChargeName(f) : '') + topicText('accusedLawyerB'),
    'chance': (f) =>
        topicText('accused_51'),
    'time': (f) =>
        topicText('accused_52'),
    'cost': (f) =>
        topicText('accused_53'),
    'evidence': (f) =>
        topicText('accused_54'),
  },
  drafts: (f) => const ['defense_brief', 'legal_aid'],
);
