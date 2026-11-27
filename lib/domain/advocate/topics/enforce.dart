// موضوع: اجرای حکم.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic enforceTopic = Topic(
  id: 'enforce',
  title: topicText('enforce_0'),
  cues: {
    'اجرای (?:حکم|احکام|رای)|حکم(?:م| رو)? اجرا|رای(?:م| رو)? اجرا': 5,
    'حکم (?:گرفتم|قطعی|به نفع)|رای (?:گرفتم|قطعی|به نفع)|محکوم (?:شد|کرد)|محکومیت': 4,
    'مزایده|توقیف (?:اموال|حساب|حقوق|ماشین|خونه|ملک)|حساب(?:م|مو| من)[^ ]* (?:رو |را )?(?:بستن|مسدود|توقیف)|حقوقم[^ ]* (?:رو |را )?(?:توقیف|کسر)': 4,
    'اجرائیه (?:گرفتم|صادر|اومد|دارم)': 4,
    '(?:ماشین|خونه|ملک|حساب|حقوق|اموال|مغازه)(?:م|مو|مون| من)(?: [^ ]+){0,5} (?:توقیف|مسدود)': 4,
    'اجرائیه|دایره اجرا|واحد اجرا': 2,
  },
  anti: 'چک|طلاق|مهریه|احضاریه|ضامن',
  recap: (f) => [
    if (f.eq('side', 'winner')) topicText('enforce_1'),
    if (f.eq('side', 'loser')) topicText('enforce_2'),
    if (f.eq('side', 'third')) topicText('enforce_3'),
    if (f.yes('final')) topicText('enforce_4'),
    if (f.no('final')) topicText('enforce_5'),
    if (f.yes('assets')) topicText('enforce_6'),
    if (f.no('assets')) topicText('enforce_7'),
  ],
  claims: [
    Claim(
      goal: topicText('enforce_8'),
      when: (f) => !f.eq('side', 'loser') && !f.eq('side', 'third'),
      elements: [
        Element(
          topicText('enforce_9'),
          (f) => f.tri('final'),
          ifNo:
              topicText('enforce_10'),
        ),
        Element(
          topicText('enforce_11'),
          (f) => null,
        ),
        Element(
          topicText('enforce_12'),
          // سراغ‌نداشتنِ مال یعنی «هنوز معلوم نیست»، نه اینکه شرط برقرار نیست.
          (f) => f.yes('assets') ? true : null,
        ),
      ],
      win: (f) =>
          topicText('enforce_13'),
      counter: (f) =>
          topicText('enforce_14'),
    ),
  ],
  slots: [
    Slot(
      id: 'side',
      ask: topicText('enforce_15'),
      why: topicText('enforce_16'),
      options: [topicText('enforce_17'), topicText('enforce_18'), topicText('enforce_19')],
      yesValue: '',
      noValue: '',
      read: (n) {
        if (Sense.has(n, 'به ?جای (?:دیگری|یکی|کس)|بدهی (?:برادر|پدر|شوهر|دیگری|یکی دیگه)|مال من(?:ه| است)? (?:ولی|اما)|ربطی به من نداره|شخص ثالث')) return 'third';
        if (Sense.has(n, 'علیه من|محکوم شدم|محکومم کرد|حساب(?:م| من)[^ ]* (?:رو |را )?(?:بستن|مسدود|توقیف)|حقوقم[^ ]* (?:رو |را )?(?:توقیف|کسر)|(?:ماشینم|خونم|خونه ام|اموالم)[^ ]* (?:رو |را )?توقیف|باید (?:بدم|بپردازم)')) return 'loser';
        if (Sense.has(n, 'به نفع (?:من|م)|حکم گرفتم|رای گرفتم|محکوم (?:شد |شده)|نمیده|نمیپردازه|اجرا نمیشه|طلبم')) return 'winner';
        return null;
      },
      effect: (f) => f.eq('side', 'loser')
          ? topicText('enforce_20')
          : f.eq('side', 'third')
              ? topicText('enforce_21')
              : '',
    ),
    Slot(
      id: 'final',
      ask: topicText('enforce_22'),
      why: topicText('enforce_23'),
      options: [topicText('enforce_24'), topicText('enforce_25')],
      when: (f) => f.eq('side', 'winner'),
      read: (n) => Sense.yn(
        n,
        'قطعی (?:شد|است|هست)|تجدید ?نظر(?:م| هم)? (?:تایید|رد شد)|اجرائیه (?:صادر|گرفتم|اومد)',
        'قطعی (?:نشد|نیست)|هنوز (?:بدوی|تجدید)|تجدید ?نظر (?:داده|خواست|کرد)|اعتراض (?:کرده|داده)',
      ),
      effect: (f) => f.yes('final')
          ? topicText('enforce_26')
          : topicText('enforce_27'),
    ),
    Slot(
      id: 'assets',
      ask: topicText('enforce_28'),
      why: topicText('enforce_29'),
      options: [topicText('enforce_30'), topicText('enforce_31')],
      when: (f) => f.eq('side', 'winner'),
      read: (n) => Sense.yn(
        n,
        'ماشین داره|خونه داره|ملک داره|مغازه داره|حقوق (?:میگیره|بگیره)|کارمند|حساب داره|سراغ دارم|پولداره|وضعش خوبه',
        'هیچی نداره|چیزی نداره|به نام(?:ش)? (?:نیست|چیزی)|سراغ ندارم|نمیدونم چی داره|همه رو (?:زده|کرده) به نام',
      ),
      effect: (f) => f.yes('assets')
          ? topicText('enforce_32')
          : topicText('enforce_33'),
    ),
  ],
  opening: (f) =>
      topicText('enforce_34'),
  issues: [
    Issue(
      id: 'salary',
      chip: topicText('enforce_35'),
      cues: 'حقوق|کسر (?:از|میشه)|یک ?چهارم|یک ?سوم|ربع|ثلث',
      body: (f) =>
          topicText('enforce_36'),
    ),
    Issue(
      id: 'exempt',
      chip: topicText('enforce_37'),
      cues: 'خونه(?:م| ام)? (?:رو )?(?:میگیرن|میفروشن|توقیف)|مستثنیات|وسایل (?:زندگی|خونه)|ابزار کار|اثاث',
      body: (f) =>
          topicText('enforce_38'),
    ),
    Issue(
      id: 'install',
      chip: topicText('enforce_39'),
      cues: 'قسط|اعسار|ندارم (?:بدم|بپردازم)|نمیتونم (?:بدم|بپردازم)|تقسیط',
      body: (f) =>
          topicText('enforce_40'),
    ),
  ],
  follow: {
    'next': (f) => f.eq('side', 'loser')
        ? topicText('enforce_41')
        : topicText('enforce_42'),
    'where': (f) =>
        topicText('enforce_43'),
    'cost': (f) =>
        topicText('enforce_44'),
    'time': (f) =>
        topicText('enforce_45'),
    'chance': (f) =>
        topicText('enforce_46'),
    'refuse': (f) =>
        topicText('enforce_47'),
  },
  drafts: (f) => f.eq('side', 'loser') ? const ['insolvency'] : const <String>[],
);
