// موضوع: چک برگشتی.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/shared.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

// ---- برداشت وکیل و ادعاها

List<String> chequeRecap(CaseFile f) => [
      if (f.eq('role', 'holder')) topicText('cheque_0'),
      if (f.eq('role', 'issuer')) topicText('cheque_1'),
      if (f.n('amount') != null) topicText('chequeRecapAmtA') + ' ' + Sense.toman(f.n('amount')!) + ' ' + topicText('chequeRecapAmtB'),
      if (f.yes('cert')) topicText('cheque_2'),
      if (f.no('cert')) topicText('cheque_3'),
      if (f.eq('kind', 'guarantee')) topicText('cheque_4'),
      if (f.eq('kind', 'postdated')) topicText('cheque_5'),
      if (f.eq('kind', 'day')) topicText('cheque_6'),
    ];

final List<Claim> chequeClaims = [
  Claim(
    goal: topicText('cheque_7'),
    when: (f) => !f.eq('role', 'issuer'),
    cues: 'اجرائیه|اجراییه|وصول|پول(?:م|مو|ش)|نقد',
    uses: const ['amount'],
    elements: [
      Element(
        topicText('cheque_8'),
        (f) => f.tri('cert'),
        needs: const ['cert'],
        because: (f) => topicText('cheque_9'),
        ifNo:
            topicText('cheque_10'),
      ),
      Element(
        topicText('cheque_11'),
        (f) => f.has('kind') ? (f.eq('kind', 'guarantee') ? null : true) : null,
        needs: const ['kind'],
        because: (f) => topicText('cheque_12'),
      ),
    ],
    win: (f) =>
        topicText('cheque_13'),
    counter: (f) =>
        topicText('cheque_14'),
  ),
];

// ---- پرسش‌ها و پاسخ‌ها

String? _chequeRole(String n) {
  if (Sense.has(n,
      'خودم (?:چک[^ ]* )?(?:رو )?(?:کشیدم|دادم|نوشتم|صادر)|چک[^ ]* (?:رو |را )?(?:کشیدم|نوشتم|صادر کردم)|صادرکننده (?:ام|منم|هستم|خودمم)|چک دادم|حسابم (?:خالی|پول نداشت|موجودی نداشت)|نتونستم پاس|نمیتونم پاسش|پاسش کنم|چکم دست|چکم (?:رو )?(?:برگشت زد|گذاشت(?:ه)? اجرا)|برام اجرائیه')) {
    return 'issuer';
  }
  if (Sense.has(n,
      'چک[^ ]* (?:رو |را )?(?:گرفتم|گرفته بودم|داد(?:ه)? بهم|بهم داد)|ازش چک|چک(?:ی)? (?:[^ ]+ ){0,3}(?:دارم|دستمه|دست منه)|چکش|چک طرف|چک مشتری|بهم چک داد|دارنده (?:ام|هستم)|چک(?:ی)? (?:که )?(?:ازش|بهم)|(?:بذارم|بگذارم|میذارم) اجرا|اجرا (?:بذارم|بگذارم)|برگشت (?:زدم|بزنم)|گواهی عدم پرداخت(?: رو)? گرفتم|شکایت کیفری کنم|پاسش نمیکنه|پولمو نمیده')) {
    return 'holder';
  }
  return null;
}

String? _chequeKind(String n) {
  if (Sense.has(n, 'ضمانت|تضمین|امانی|امانت|سفید امضا|حسن انجام')) return 'guarantee';
  if (Sense.has(n, 'وعده ?دار|مدت ?دار|تاریخ[^ ]* (?:مال|برای) (?:بعد|ماه)|برای (?:چند|یه|دو|سه) ماه بعد')) return 'postdated';
  if (Sense.has(n, 'به روز|روز بود|همون روز|تاریخ روز')) return 'day';
  return null;
}

String _chequeKindEffect(CaseFile f) {
  final issuer = f.eq('role', 'issuer');
  switch (f.get('kind')) {
    case 'guarantee':
      return issuer
          ? topicText('cheque_15')
          : topicText('cheque_16');
    case 'postdated':
      return issuer
          ? topicText('cheque_17')
          : topicText('cheque_18');
    default:
      return issuer
          ? topicText('cheque_19')
          : topicText('cheque_20');
  }
}

String _chequeRoutes(CaseFile f) {
  final kind = f.get('kind');
  final late = (f.n('since') ?? 0) > 6;
  final sb = StringBuffer(
      topicText('cheque_21'));
  sb.write(topicText('cheque_22'));
  if (kind == 'guarantee') {
    sb.write(
        topicText('cheque_23'));
  } else if (kind == 'postdated') {
    sb.write(
        topicText('cheque_24'));
  } else if (late) {
    sb.write(
        topicText('cheque_25'));
  } else {
    sb.write(
        topicText('cheque_26'));
  }
  return sb.toString();
}

String _chequeIssuer(CaseFile f) {
  return topicText('cheque_27');
}

final Topic chequeTopic = Topic(
  id: 'cheque',
  title: topicText('cheque_28'),
  claims: chequeClaims,
  recap: chequeRecap,
  cues: {
    'چک(?!ار|ه |ه میکن| کرد| کن| میکن| نکرد| شد )': 3,
    'برگشت(?:ی| خورد| زد)|پاس نشد|پاس نمیشه|بلامحل|گواهی عدم پرداخت|صیاد': 1,
  },
  slots: [
    Slot(
      id: 'role',
      first: true,
      ask: topicText('cheque_29'),
      why: topicText('cheque_30'),
      options: [topicText('cheque_31'), topicText('cheque_32')],
      read: _chequeRole,
      readPending: (n) => Sense.has(n, 'خودم|صادر کرد|کشیدم|دادم')
          ? 'issuer'
          : (Sense.has(n, 'گرفتم|گرفته|دارنده|طلبکار|ازش|بهم') ? 'holder' : null),
      yesValue: '',
      noValue: '',
      effect: (f) =>
          f.eq('role', 'issuer') ? _chequeIssuer(f) : _chequeRoutes(f),
    ),
    Slot(
      id: 'cert',
      ask: topicText('cheque_33'),
      why: topicText('cheque_34'),
      options: [topicText('cheque_35'), topicText('cheque_36')],
      read: (n) => Sense.yn(
        n,
        'گواهی عدم پرداخت(?: رو| را)? (?:گرفتم|دارم)|برگشت زدم|برگشتی گرفتم|گواهی(?: رو)? گرفتم|گواهی دارم',
        'گواهی[^ ]*(?: عدم پرداخت)?(?: رو)? (?:نگرفتم|ندارم)|هنوز (?:بانک نرفتم|برگشت نزدم)|برگشت نزدم',
      ),
      when: (f) => f.eq('role', 'holder'),
      effect: (f) => f.yes('cert')
          ? topicText('cheque_37')
          : topicText('cheque_38'),
    ),
    Slot(
      id: 'kind',
      ask: topicText('cheque_39'),
      why: topicText('cheque_40'),
      options: [topicText('cheque_41'), topicText('cheque_42'), topicText('cheque_43')],
      read: _chequeKind,
      yesValue: '',
      noValue: '',
      effect: _chequeKindEffect,
    ),
    Slot(
      id: 'amount',
      ask: topicText('cheque_44'),
      why: topicText('cheque_45'),
      read: (n) => Sense.amount(n)?.toString(),
      readPending: (n) => Sense.looseAmount(n)?.toString(),
      yesValue: '',
      noValue: '',
      when: (f) => f.eq('role', 'holder'),
    ),
  ],
  opening: (f) {
    if (f.eq('role', 'issuer')) return '';
    if (f.eq('role', 'holder')) {
      return topicText('cheque_46');
    }
    return topicText('cheque_47');
  },
  issues: [
    Issue(
      id: 'compare',
      chip: topicText('cheque_48'),
      cues:
          'بهتره یا|بهتر است یا|اجرائیه (?:[^ ]+ ){0,4}کیفری|یا (?:[^ ]+ ){0,3}بهتره|کدوم (?:راه |یکی )?بهتر|کدام (?:راه )?بهتر|اجرا (?:[^ ]+ ){0,3}کیفری|کیفری (?:[^ ]+ ){0,3}(?:اجرا|حقوقی)|حقوقی (?:[^ ]+ ){0,3}کیفری|چه راه|راه هاش',
      body: _chequeRoutes,
      when: (f) => !f.eq('role', 'issuer'),
    ),
    Issue(
      id: 'criminal',
      chip: topicText('cheque_49'),
      cues: 'شکایت کیفری|کیفری|زندان[^ ]* (?:میره|میفته|بندازم)|جلب[^ ]* (?:کنم|بگیرم)|بندازمش|شکایت کنم',
      body: (f) =>
          topicText('cheque_50'),
      when: (f) => !f.eq('role', 'issuer'),
    ),
    Issue(
      id: 'onface',
      chip: topicText('cheque_51'),
      cues: 'روی چک|در متن چک|تو(?:ی)? چک (?:ننوشت|نوشت)|ننوشتم بابت|قید نکرد|قید نشده',
      body: (f) => f.eq('role', 'issuer')
          ? topicText('cheque_52')
          : topicText('cheque_53'),
      covers: const {'kind'},
    ),
    Issue(
      id: 'sayad',
      chip: topicText('cheque_54'),
      cues: 'صیاد|بنفش|ثبت (?:نشده|نکرد|نکرده)|تایید (?:نکردم|نشده)',
      body: (f) =>
          topicText('chequeSayadA') + ' ' + (f.eq('role', 'issuer') ? topicText('chequeSayadIssuer') : topicText('chequeSayadHolder')) + ' ' + topicText('chequeSayadB'),
    ),
    Issue(
      id: 'lost',
      chip: topicText('cheque_55'),
      cues: 'گم (?:شد|کرد)|مفقود|دزدی|سرقت|دزدید|کلاهبرداری[^ ]* چک|ازم گرفت[^ ]* به زور',
      body: (f) =>
          topicText('cheque_56'),
    ),
    Issue(
      id: 'noassets',
      chip: topicText('cheque_57'),
      cues: 'به نامش نباش|مال(?:ی)? (?:به نامش )?ندار|هیچی به نام|اموال(?:ی)? ندار|به نام (?:زنش|همسرش|کس دیگه)|فرار کرد|در رفت|پیداش نمیکنم|گوشی(?:ش)? خاموش',
      body: (f) =>
          topicText('cheque_58'),
      when: (f) => !f.eq('role', 'issuer'),
    ),
  ],
  follow: {
    'next': (f) {
      if (f.eq('role', 'issuer')) return _chequeIssuer(f);
      final first = f.yes('cert')
          ? topicText('cheque_59')
          : topicText('cheque_60');
      return topicText('chequeNextLead') + '\n' + first + '\n' + topicText('chequeNextTail');
    },
    'where': (f) =>
        topicText('cheque_61'),
    'cost': (f) => moneyCost,
    'time': (f) =>
        topicText('cheque_62'),
    'deadline': (f) =>
        topicText('cheque_63'),
    'chance': (f) => f.eq('role', 'issuer')
        ? topicText('cheque_64')
        : topicText('cheque_65'),
    'evidence': (f) =>
        topicText('cheque_66'),
    'refuse': (f) =>
        topicText('cheque_67'),
  },
  drafts: (f) => f.eq('role', 'issuer')
      ? const ['insolvency']
      : const ['cheque_execution', 'cheque_complaint'],
);
