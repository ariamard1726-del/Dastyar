// موضوع: طلب و بدهی.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/shared.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

// ---- برداشت وکیل و ادعاها

List<String> debtRecap(CaseFile f) => [
      if (f.n('amount') != null) Sense.toman(f.n('amount')!) + ' ' + topicText('debtRecapAmt'),
      if (f.eq('proof', 'doc')) topicText('debt_0'),
      if (f.eq('proof', 'transfer')) topicText('debt_1'),
      if (f.eq('proof', 'msg')) topicText('debt_2'),
      if (f.eq('proof', 'witness')) topicText('debt_3'),
      if (f.eq('proof', 'none')) topicText('debt_4'),
      if (f.yes('admits')) topicText('debt_5'),
      if (f.no('admits')) topicText('debt_6'),
    ];

final List<Claim> debtClaims = [
  Claim(
    goal: topicText('debt_7'),
    cues: 'پول(?:م|مو)|طلب(?:م|مو)|حکم|محکوم',
    uses: const ['amount'],
    elements: [
      Element(
        topicText('debt_8'),
        (f) => f.has('proof') ? !f.eq('proof', 'none') : null,
        needs: const ['proof'],
        because: (f) => f.eq('proof', 'doc')
            ? topicText('debt_9')
            : (f.eq('proof', 'transfer')
                ? topicText('debt_10')
                : (f.eq('proof', 'witness')
                    ? topicText('debt_11')
                    : topicText('debt_12'))),
        ifNo:
            topicText('debt_13'),
      ),
      Element(
        topicText('debt_14'),
        (f) {
          if (f.yes('admits')) return true;
          if (!f.no('admits')) return null;
          if (f.eq('proof', 'doc') || f.eq('proof', 'transfer')) return true;
          return f.has('proof') ? false : null;
        },
        needs: const ['admits', 'proof'],
        because: (f) => f.yes('admits')
            ? topicText('debt_15')
            : topicText('debt_16'),
        ifNo:
            topicText('debt_17'),
      ),
    ],
    win: (f) =>
        topicText('debt_18'),
    counter: (f) =>
        topicText('debt_19'),
  ),
];

// ---- پرسش‌ها و پاسخ‌ها

String? _debtProof(String n) {
  if (Sense.has(n,
      'هیچ مدرک|مدرک(?:ی)? ندارم|نه سند|هیچی ندارم|فقط خودم و خودش|خودم و خودش میدون|کسی (?:نمیدونه|ندید|نبود)|شاهد(?:ی)? ندارم|هیچ(?:ی)? ننوشتیم|رسید(?:ی)? (?:نگرفتم|ندارم)|دست به دست|بدون (?:مدرک|رسید|سند)')) {
    return 'none';
  }
  if (Sense.has(n, 'سفته|رسید (?:دارم|گرفتم|داد)|دست ?نوشته|دستخط|قرارداد|نوشته (?:دارم|داد)|سند (?:دارم|داد)|امضا کرد')) {
    return 'doc';
  }
  if (Sense.has(n, 'کارت به کارت|واریز|حواله|انتقال(?:ی)? بانک|فیش|تراکنش|به حسابش|پایا|ساتنا')) return 'transfer';
  if (Sense.has(n, 'پیام|چت|واتساپ|تلگرام|اس ام اس|پیامک|ویس|صدا[^ ]* (?:رو )?ضبط|اسکرین')) return 'msg';
  if (Sense.has(n, 'شاهد (?:دارم|هست|داریم)|شاهد |جلوی (?:[^ ]+ ){0,3}دادم|(?:بقیه|چند نفر|دوستام|خانواده) (?:دیدن|میدونن|بودن)')) return 'witness';
  return null;
}

String _debtProofEffect(CaseFile f) {
  final amt = f.n('amount');
  final sum = amt == null ? topicText('debtSumGeneric') : topicText('debtSumPrefix') + ' ' + Sense.toman(amt) + topicText('debtSumSuffix');
  switch (f.get('proof')) {
    case 'none':
      return topicText('debtNoneA') + sum + ' ' + topicText('debtNoneB');
    case 'transfer':
      return topicText('debt_20');
    case 'msg':
      return topicText('debt_21');
    case 'witness':
      return topicText('debt_22');
    case 'doc':
      return topicText('debt_23');
    default:
      return '';
  }
}

String _debtPlan(CaseFile f) {
  return topicText('debtPlanLead') + '\n' + (f.eq('proof', 'doc') ? topicText('debtPlanDoc') : topicText('debtPlanNoDoc')) + '\n' + topicText('debtPlanRest') + '\n' + moneyForum(f.n('amount'));
}

final Topic debtTopic = Topic(
  id: 'debt',
  title: topicText('debt_24'),
  claims: debtClaims,
  recap: debtRecap,
  cues: {
    'پول(?:م|مو)? (?:مرا |من را |من رو |رو |را )?(?:پس )?(?:نمیده|نمیدهد|نداده|نمیدن|نمیدهند)|طلبکار هستم|بدهکار (?:است|هست|فرار)|خسارت تاخیر تادیه|از بدهکار': 3,
    'قرض (?:دادم|داده بودم|داده ام|گرفت|کرد)|پول (?:دادم|قرض)|دستی (?:دادم|گرفت)|قرض الحسنه دادم': 3,
    'پول ?(?:م|مو|منو|ام|امو)? ?(?:رو |را )?(?:خورد|خورده|خورده‌ست|بالا کشید|برداشت)': 3,
    'طلب(?:م| دارم|کارم)|ازش طلب|بهم بدهکاره|بدهکار منه|پولمو (?:نمیده|پس نمیده|خورد|بالا کشید)|پولم رو (?:نمیده|پس نمیده)': 3,
    'پس نمیده|نمیده|سفته|بدهی(?:ش)? رو': 1,
  },
  anti: 'بدهکارم|بدهی دارم|قرض گرفتم|قرض کردم|طلبکار(?:ا|ها|م)? (?:اومد|دارم|زیاد)|نمیتونم (?:بدم|پس بدم)|سایت|اینستا|تلگرام|کلاهبردار|حکم گرفتم|رای گرفتم|محکوم شد|اجرای حکم',
  slots: [
    Slot(
      id: 'proof',
      ask: topicText('debt_25'),
      why: topicText('debt_26'),
      options: [topicText('debt_27'), topicText('debt_28'), topicText('debt_29'), topicText('debt_30')],
      read: _debtProof,
      readPending: (n) => Sense.saysNo(n) || Sense.has(n, 'هیچ') ? 'none' : null,
      yesValue: '',
      noValue: 'none',
      effect: _debtProofEffect,
    ),
    Slot(
      id: 'admits',
      ask: topicText('debt_31'),
      why: topicText('debt_32'),
      options: [topicText('debt_33'), topicText('debt_34')],
      read: (n) => Sense.yn(
        n,
        'قبول دار|میگه میدم|قول میده|امروز فردا|هی میگه|انکار نمیکنه|میگه ندارم|وعده میده|دست به سر',
        'انکار(?! نمی)|زیرش (?:میزنه|زد)|میگه نگرفتم|میگه بدهکار نیستم|حاشا|گردن نمیگیره|منکر',
      ),
      effect: (f) => f.yes('admits')
          ? topicText('debt_35')
          : (f.eq('proof', 'doc')
              ? topicText('debt_36')
              : topicText('debt_37')),
    ),
    Slot(
      id: 'amount',
      ask: topicText('debt_38'),
      why: topicText('debt_39'),
      read: (n) => Sense.amount(n)?.toString(),
      readPending: (n) => Sense.looseAmount(n)?.toString(),
      yesValue: '',
      noValue: '',
      effect: (f) => moneyForum(f.n('amount')),
    ),
  ],
  opening: (f) =>
      topicText('debt_40'),
  issues: [
    Issue(
      id: 'record',
      chip: topicText('debt_41'),
      cues: 'ضبط|ویس|صدا[^ ]* (?:رو |را )?(?:بگیرم|دارم)|مکالمه',
      body: (f) =>
          topicText('debt_42'),
    ),
    Issue(
      id: 'interest',
      chip: topicText('debt_43'),
      cues: 'سود|دیرکرد|خسارت تاخیر|ضرر[^ ]* (?:تاخیر|تورم)|تورم|ارزش پول|به نرخ روز',
      body: (f) =>
          topicText('debt_44'),
    ),
    Issue(
      id: 'hide',
      chip: topicText('debt_45'),
      cues: 'به نام (?:زنش|همسرش|بچه|کس دیگه|دیگری)|اموال[^ ]* (?:رو )?(?:منتقل|انتقال)|فرار (?:از دین|کنه|کرد)|در بره|مال(?:ی)? ندار|هیچی نداره',
      body: (f) =>
          topicText('debt_46'),
    ),
    Issue(
      id: 'jail',
      chip: topicText('debt_47'),
      cues: 'زندان|حبس|بازداشت|جلب|شکایت کیفری|کلاهبرداری',
      body: (f) =>
          topicText('debt_48'),
    ),
  ],
  follow: {
    'next': _debtPlan,
    'where': (f) => moneyForum(f.n('amount')),
    'cost': (f) => moneyCost,
    'time': (f) => moneyTime,
    'deadline': (f) =>
        topicText('debt_49'),
    'evidence': (f) =>
        topicText('debt_50'),
    'chance': (f) {
      switch (f.get('proof')) {
        case 'doc':
          return topicText('debt_51');
        case 'none':
          return topicText('debt_52');
        case '':
          return topicText('debt_53');
        default:
          return topicText('debt_54');
      }
    },
    'refuse': (f) =>
        topicText('debt_55'),
  },
  drafts: (f) => const ['formal_notice', 'demand_money'],
);
