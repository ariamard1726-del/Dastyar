// موضوع: شراکت.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/shared.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

// ---- برداشت وکیل

List<String> partnerRecap(CaseFile f) => [
      topicText('partner_0'),
      if (f.yes('written')) topicText('partner_1'),
      if (f.no('written')) topicText('partner_2'),
      if (f.eq('lease', 'both')) topicText('partner_3'),
      if (f.eq('lease', 'his')) topicText('partner_4'),
      if (f.eq('lease', 'mine')) topicText('partner_5'),
      if (f.eq('goal', 'exit')) topicText('partner_6'),
      if (f.eq('goal', 'stay')) topicText('partner_7'),
    ];

// ---- پرسش‌ها و پاسخ‌ها

final Topic partnerTopic = Topic(
  id: 'partner',
  title: topicText('partner_8'),
  recap: partnerRecap,
  cues: {
    'شرکت (?:زدیم|کردیم|راه انداختیم|داشتیم|داریم)|سهم(?:ش|م| من| منو)(?: رو)? (?:نمیده|نمی ?ده|نمیدهد)': 3,
    'شریک|شراکت|شراکتی': 3,
    'با هم (?:[^ ]+ ){0,3}(?:اجاره کردیم|خریدیم|راه انداختیم|زدیم|سرمایه گذاشتیم|کار میکنیم)': 3,
    'سود[^ ]* (?:رو |را )?(?:برمیداره|نمیده|بالا کشید|میبره)|همه سود|سهم(?:م| من| منو)(?: رو)? نمیده|حساب و کتاب': 2,
  },
  slots: [
    Slot(
      id: 'written',
      ask: topicText('partner_9'),
      why: topicText('partner_10'),
      options: [topicText('partner_11'), topicText('partner_12')],
      read: (n) => Sense.yn(
        n,
        'شراکت ?نامه|قرارداد (?:دارم|داریم|نوشتیم)|نوشتیم|کتبی|مشارکت نامه',
        'ننوشتیم|شفاهی|قرارداد (?:نداریم|ندارم)|هیچ(?:ی)? ننوشتیم|رو حساب (?:رفاقت|اعتماد|فامیلی)|نوشته ای? (?:نداریم|ندارم)',
      ),
      effect: (f) => f.yes('written')
          ? topicText('partner_13')
          : topicText('partner_14'),
    ),
    Slot(
      id: 'lease',
      ask: topicText('partner_15'),
      why: topicText('partner_16'),
      options: [topicText('partner_17'), topicText('partner_18'), topicText('partner_19')],
      read: (n) {
        if (Sense.has(n, 'به (?:اسم|نام) (?:هر ?دو|جفت|دوتامون)|هر دو(?:مون)? امضا|با هم (?:[^ ]+ ){0,3}اجاره کردیم|دوتایی اجاره')) return 'both';
        if (Sense.has(n, 'به (?:اسم|نام) (?:اون|خودش|شریکم|او)')) return 'his';
        if (Sense.has(n, 'به (?:اسم|نام) (?:من|خودم)')) return 'mine';
        return null;
      },
      readPending: (n) => Sense.has(n, 'هر ?دو|جفت')
          ? 'both'
          : (Sense.has(n, 'من|خودم') ? 'mine' : (Sense.has(n, 'اون|او |خودش|شریک') ? 'his' : null)),
      yesValue: '',
      noValue: '',
      effect: (f) {
        switch (f.get('lease')) {
          case 'both':
            return topicText('partner_20');
          case 'his':
            return topicText('partner_21');
          default:
            return topicText('partner_22');
        }
      },
    ),
    Slot(
      id: 'goal',
      ask: topicText('partner_23'),
      why: topicText('partner_24'),
      options: [topicText('partner_25'), topicText('partner_26')],
      read: (n) {
        if (Sense.has(n, 'جدا (?:شم|بشم|شیم|شوم|بشوم)|تموم(?:ش)? کنم|به هم بزنم|سهمم(?: رو)? بفروشم|بیام بیرون|انحلال')) return 'exit';
        if (Sense.has(n, 'ادامه|فقط (?:سهم|سود|حق)|سودم(?: رو)? (?:میخوام|بده)')) return 'stay';
        return null;
      },
      yesValue: '',
      noValue: '',
      effect: (f) => f.eq('goal', 'exit')
          ? topicText('partner_27')
          : topicText('partner_28'),
    ),
  ],
  opening: (f) =>
      topicText('partner_29'),
  issues: [
    Issue(
      id: 'profit',
      chip: topicText('partner_30'),
      cues: 'سود|دخل|حساب(?: و کتاب)?(?: رو)? (?:پس )?نمیده|برمیداره|بالا کشید|سهم(?:م| من)(?: رو)? نمیده',
      body: (f) =>
          topicText('partner_31'),
    ),
    Issue(
      id: 'criminal',
      chip: topicText('partner_32'),
      cues: 'شکایت|کیفری|خیانت در امانت|کلاهبرداری|دزدی|زندان',
      body: (f) =>
          topicText('partner_33'),
    ),
    Issue(
      id: 'lock',
      chip: topicText('partner_34'),
      cues: 'راه(?:م)? نمیده|قفل(?: رو| را)? عوض|بیرونم کرد|نمیذاره بیام|کلید(?: رو)? (?:نمیده|گرفت)',
      body: (f) =>
          topicText('partner_35'),
    ),
  ],
  follow: {
    'next': (f) =>
        topicText('partner_36'),
    'where': (f) => moneyForum(f.n('amount')),
    'cost': (f) =>
        moneyCost + '\n' + topicText('partnerCostTail'),
    'time': (f) => moneyTime,
    'evidence': (f) =>
        topicText('partner_37'),
    'chance': (f) =>
        (f.no('written') ? topicText('partnerChanceNoWritten') + ' ' : '') + topicText('partnerChanceRest'),
    'refuse': (f) =>
        topicText('partner_38'),
  },
  drafts: (f) => const ['formal_notice'],
);
