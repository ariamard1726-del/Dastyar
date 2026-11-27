part of 'labor.dart';

// پرسش‌ها، بحث‌ها و خودِ تعریفِ موضوعِ کار.

final Topic laborTopic = Topic(
  id: 'labor',
  title: topicText('laborIss_0'),
  claims: laborClaims,
  recap: laborRecap,
  cues: {
    'حقوق(?:م|مو)?[^ ]* (?:[^ ]+ ){0,2}(?:نگرفت|پرداخت نکرد|پرداخت نشد|نریخت)|حقوق(?:م|مو)? (?:رو |را )?(?:کم|کمتر) | مزد | مزدم |حق ماموریت|قرارداد(?:م| کارم| کار)? (?:رو |را )?تمدید نکرد|سابقه بیمه|حق بیمه|رد نکردن بیمه|بیمه بیکاری': 3,
    'دیگ(?:ه|ر) نیا|از (?:محیط |سر )?کار(?:م)? (?:[^ ]+ ){0,1}بیرون|کارگر|کارگاه|کارخانه|استخدام': 2,
    'کارفرما|صاحب ?کار|رئیسم|رییسم|مدیرم': 2,
    'اخراج|از فردا نیا|دیگه نیا سر|عذرم(?: رو)? خواست|تعدیل نیرو|بیرونم کرد(?:ن|ه)? از (?:کار|شرکت)': 3,
    'حقوق[^ ]* (?:رو |را )?(?:نمید|نداد)|حقوق معوق|دستمزد|سنوات|اداره کار|عیدی[^ ]* (?:نداد|نمید)|تسویه ?حساب|اضافه ?کار': 3,
    'بیمه[^ ]* (?:[^ ]+ ){0,2}رد نکرد|بیمه نکرد|بیمه نمیکنه': 3,
    'سر کار|محل کار|شرکت(?:ی)? که کار': 1,
  },
  anti: 'شوهر|همسرم|طلاق',
  slots: [
    Slot(
      id: 'event',
      ask: topicText('laborIss_1'),
      why: topicText('laborIss_2'),
      options: [topicText('laborIss_3'), topicText('laborIss_4'), topicText('laborIss_5')],
      read: _laborEvent,
      first: true,
      yesValue: '',
      noValue: '',
      effect: (f) => f.eq('event', 'fired')
          ? topicText('laborIss_6')
          : (f.eq('event', 'unpaid')
              ? topicText('laborIss_7')
              : ''),
    ),
    Slot(
      id: 'contract',
      ask: topicText('laborIss_8'),
      why: topicText('laborIss_9'),
      options: [topicText('laborIss_10'), topicText('laborIss_11')],
      read: _laborContract,
      effect: (f) => f.yes('contract')
          ? topicText('laborIss_12')
          : topicText('laborIss_13'),
    ),
    Slot(
      id: 'insured',
      ask: topicText('laborIss_14'),
      why: topicText('laborIss_15'),
      options: [topicText('laborIss_16'), topicText('laborIss_17')],
      read: _laborInsured,
      effect: (f) => f.yes('insured')
          ? topicText('laborIss_18')
          : topicText('laborIss_19'),
    ),
    Slot(
      id: 'proof',
      ask: topicText('laborIss_20'),
      why: topicText('laborIss_21'),
      options: [topicText('laborIss_22'), topicText('laborIss_23'), topicText('laborIss_24')],
      read: (n) => Sense.yn(
        n,
        'شاهد|همکار|فیش|واریز|کارت به کارت|پیام|عکس|فیلم|حضور و غیاب|کارت ورود|لباس کار',
        'هیچ مدرک|مدرک(?:ی)? ندارم|شاهد(?:ی)? ندارم',
      ),
      when: (f) =>
          f.touched('contract') &&
          f.touched('insured') &&
          !f.yes('contract') &&
          !f.yes('insured'),
      effect: (f) => f.yes('proof')
          ? topicText('laborIss_25')
          : topicText('laborIss_26'),
    ),
    Slot(
      id: 'signed',
      ask: topicText('laborIss_27'),
      why: topicText('laborIss_28'),
      options: [topicText('laborIss_29'), topicText('laborIss_30')],
      read: _laborSigned,
      effect: (f) => f.no('signed')
          ? topicText('laborIss_31')
          : topicText('laborIss_32'),
    ),
    Slot(
      id: 'expired',
      ask: topicText('laborIss_33'),
      why: topicText('laborIss_34'),
      options: [topicText('laborIss_35'), topicText('laborIss_36'), topicText('laborIss_37')],
      read: _laborExpired,
      yesValue: '',
      noValue: '',
      when: (f) => laborFired(f) && f.yes('contract'),
      effect: (f) => f.yes('expired')
          ? topicText('laborIss_38')
          : topicText('laborIss_39'),
    ),
    Slot(
      id: 'warned',
      ask: topicText('laborIss_40'),
      why: topicText('laborIss_41'),
      options: [topicText('laborIss_42'), topicText('laborIss_43')],
      read: _laborWarned,
      when: (f) => laborFired(f),
      effect: (f) => f.no('warned')
          ? topicText('laborIss_44')
          : topicText('laborIss_45'),
    ),
    Slot(
      id: 'working',
      ask: topicText('laborIss_46'),
      why: topicText('laborIss_47'),
      options: [topicText('laborIss_48'), topicText('laborIss_49')],
      read: _laborWorking,
      yesValue: '',
      noValue: '',
      when: (f) => f.touched('event') && !laborFired(f),
      effect: (f) => f.yes('working')
          ? topicText('laborIss_50')
          : '',
    ),
    Slot(
      id: 'months',
      ask: topicText('laborIss_51'),
      why: topicText('laborIss_52'),
      read: _laborMonths,
      readPending: (n) {
        final m = Sense.months(n);
        return m == null || m < 1 ? null : m.round().toString();
      },
      yesValue: '',
      noValue: '',
      effect: (f) {
        final m = f.n('months') ?? 0;
        return topicText('laborSlotMonthsA') + ' ' + Sense.span(m) + ' ' + topicText('laborSlotMonthsB') + ' ' + (m >= 12 ? topicText('laborSlotMonthsGe12') : topicText('laborSlotMonthsLt12')) + '.';
      },
    ),
    Slot(
      id: 'salary',
      ask: topicText('laborIss_53'),
      why: topicText('laborIss_54'),
      read: _laborSalary,
      readPending: (n) => Sense.amount(n)?.toString(),
      yesValue: '',
      noValue: '',
      effect: _laborMoney,
    ),
    // این دو پرسیده نمی‌شوند؛ فقط یادِ پرونده می‌مانند. «اتفاق اصلی» با هر
    // حرف تازه عوض می‌شود، ولی اخراج و حقوقِ نگرفته نباید با آمدنِ حرفِ
    // بیمه از یاد بروند؛ هر کدام ادعای خودش را روی میز نگه می‌دارد.
    Slot(
      id: 'fired',
      ask: '',
      why: '',
      read: (n) => Sense.has(n, _laborFiredRe) ? 'yes' : null,
      yesValue: '',
      noValue: '',
    ),
    Slot(
      id: 'owed',
      ask: '',
      why: '',
      read: (n) => Sense.has(n, _laborUnpaid) ? 'yes' : null,
      yesValue: '',
      noValue: '',
    ),
  ],
  opening: (f) =>
      topicText('laborIss_55'),
  issues: [
    Issue(
      id: 'sanavat',
      chip: topicText('laborIss_56'),
      cues: 'سنوات|پایان کار|مزایای پایان',
      body: (f) {
        final m = f.n('months');
        final sal = f.n('salary');
        final sb = StringBuffer(
            topicText('laborIss_57'));
        if (m != null && sal != null) {
          sb.write('\n' + topicText('laborSanavatCalcA') + ' ' + Sense.span(m) + ' ' + topicText('laborSanavatCalcB') + ' ' + Sense.toman(sal) + topicText('laborSanavatCalcC') + ' ' + Sense.toman((sal * m / 12.0).round()) + ' ' + topicText('laborSanavatCalcD'));
        } else if (m != null) {
          sb.write('\n' + topicText('laborSanavatNoSalA') + ' ' + Sense.span(m) + ' ' + topicText('laborSanavatNoSalB'));
        }
        return sb.toString();
      },
      covers: const {'months'},
    ),
    Issue(
      id: 'howmuch',
      chip: topicText('laborIss_58'),
      cues: 'چقدر (?:میشه|بهم|باید بده|طلب|میرسه|گیرم)|حساب کن|چقدر میتونم بگیرم|مبلغش چقدر',
      body: _laborMoney,
      covers: const {'months', 'salary'},
    ),
    Issue(
      id: 'sign',
      chip: topicText('laborIss_59'),
      cues: 'استعفا|امضا (?:کنم|بدم|کردم|بزنم)|تسویه ?حساب|رضایت ?نامه|برگه (?:سفید|تسویه)|سفید امضا|انگشت بزن',
      covers: const {'signed'},
      body: (f) => f.yes('signed')
          ? topicText('laborIss_60')
          : topicText('laborIss_61'),
    ),
    Issue(
      id: 'insurance',
      chip: topicText('laborIss_62'),
      cues: 'بیمه',
      body: (f) => (f.yes('insured') || f.no('insured') ? '' : topicText('laborInsIssuePre') + '\n') + topicText('laborInsIssueBody'),
      covers: const {'insured', 'event'},
    ),
    Issue(
      id: 'wage',
      chip: topicText('laborIss_63'),
      cues: 'حقوق[^ ]* (?:رو |را )?(?:نمید|نداد|عقب)|معوق|دستمزد|عیدی|اضافه ?کار|مرخصی',
      body: (f) =>
          topicText('laborIss_64'),
      covers: const {'event'},
    ),
  ],
  follow: {
    'next': _laborPlan,
    'where': (f) =>
        topicText('laborIss_65'),
    'cost': (f) =>
        topicText('laborIss_66'),
    'time': (f) =>
        topicText('laborIss_67'),
    'deadline': (f) =>
        topicText('laborIss_68'),
    'chance': _laborChance,
    'evidence': (f) =>
        topicText('laborIss_69'),
    'refuse': (f) =>
        topicText('laborIss_70'),
    'lawyer': (f) =>
        topicText('laborIss_71'),
  },
  drafts: (f) => const ['formal_notice'],
);
