part of 'labor.dart';

// پرسش‌ها، بحث‌ها و خودِ تعریفِ موضوعِ کار.

final Topic laborTopic = Topic.dsl(
  id: 'labor',
  title: topicText('laborIss_0'),
  claims: laborClaims,
  recap: _laborRecap,
  cues: const {
    'حقوق(?:م|مو)?[^ ]* (?:[^ ]+ ){0,2}(?:نگرفت|پرداخت نکرد|پرداخت نشد|نریخت)|حقوق(?:م|مو)? (?:رو |را )?(?:کم|کمتر) | مزد | مزدم |حق ماموریت|قرارداد(?:م| کارم| کار)? (?:رو |را )?تمدید نکرد|سابقه بیمه|حق بیمه|رد نکردن بیمه|بیمه بیکاری':
        3,
    'دیگ(?:ه|ر) نیا|از (?:محیط |سر )?کار(?:م)? (?:[^ ]+ ){0,1}بیرون|کارگر|کارگاه|کارخانه|استخدام':
        2,
    'کارفرما|صاحب ?کار|رئیسم|رییسم|مدیرم': 2,
    'اخراج|از فردا نیا|دیگه نیا سر|عذرم(?: رو)? خواست|تعدیل نیرو|بیرونم کرد(?:ن|ه)? از (?:کار|شرکت)':
        3,
    'حقوق[^ ]* (?:رو |را )?(?:نمید|نداد)|حقوق معوق|دستمزد|سنوات|اداره کار|عیدی[^ ]* (?:نداد|نمید)|تسویه ?حساب|اضافه ?کار':
        3,
    'بیمه[^ ]* (?:[^ ]+ ){0,2}رد نکرد|بیمه نکرد|بیمه نمیکنه': 3,
    'سر کار|محل کار|شرکت(?:ی)? که کار': 1,
  },
  anti: 'شوهر|همسرم|طلاق',
  slots: [
    Slot.dsl(
      id: 'event',
      ask: topicText('laborIss_1'),
      why: topicText('laborIss_2'),
      options: [
        topicText('laborIss_3'),
        topicText('laborIss_4'),
        topicText('laborIss_5'),
      ],
      read: _laborEventRead,
      first: true,
      yesValue: '',
      noValue: '',
      effect: const TxSwitch(
        'event',
        {
          'fired': Tx('laborIss_6'),
          'unpaid': Tx('laborIss_7'),
        },
      ),
    ),
    Slot.dsl(
      id: 'contract',
      ask: topicText('laborIss_8'),
      why: topicText('laborIss_9'),
      options: [topicText('laborIss_10'), topicText('laborIss_11')],
      read: _laborContractRead,
      effect: const TxCond(
        FactYes('contract'),
        Tx('laborIss_12'),
        Tx('laborIss_13'),
      ),
    ),
    Slot.dsl(
      id: 'insured',
      ask: topicText('laborIss_14'),
      why: topicText('laborIss_15'),
      options: [topicText('laborIss_16'), topicText('laborIss_17')],
      read: _laborInsuredRead,
      effect: const TxCond(
        FactYes('insured'),
        Tx('laborIss_18'),
        Tx('laborIss_19'),
      ),
    ),
    Slot.dsl(
      id: 'proof',
      ask: topicText('laborIss_20'),
      why: topicText('laborIss_21'),
      options: [
        topicText('laborIss_22'),
        topicText('laborIss_23'),
        topicText('laborIss_24'),
      ],
      read: const ReadYn(
        'شاهد|همکار|فیش|واریز|کارت به کارت|پیام|عکس|فیلم|حضور و غیاب|کارت ورود|لباس کار',
        'هیچ مدرک|مدرک(?:ی)? ندارم|شاهد(?:ی)? ندارم',
      ),
      when: const FactAll([
        FactTouched('contract'),
        FactTouched('insured'),
        FactNot(FactYes('contract')),
        FactNot(FactYes('insured')),
      ]),
      effect: const TxCond(
        FactYes('proof'),
        Tx('laborIss_25'),
        Tx('laborIss_26'),
      ),
    ),
    Slot.dsl(
      id: 'signed',
      ask: topicText('laborIss_27'),
      why: topicText('laborIss_28'),
      options: [topicText('laborIss_29'), topicText('laborIss_30')],
      read: _laborSignedRead,
      effect: const TxCond(
        FactNo('signed'),
        Tx('laborIss_31'),
        Tx('laborIss_32'),
      ),
    ),
    Slot.dsl(
      id: 'expired',
      ask: topicText('laborIss_33'),
      why: topicText('laborIss_34'),
      options: [
        topicText('laborIss_35'),
        topicText('laborIss_36'),
        topicText('laborIss_37'),
      ],
      read: _laborExpiredRead,
      yesValue: '',
      noValue: '',
      when: const FactAll([laborFiredRule, FactYes('contract')]),
      effect: const TxCond(
        FactYes('expired'),
        Tx('laborIss_38'),
        Tx('laborIss_39'),
      ),
    ),
    Slot.dsl(
      id: 'warned',
      ask: topicText('laborIss_40'),
      why: topicText('laborIss_41'),
      options: [topicText('laborIss_42'), topicText('laborIss_43')],
      read: _laborWarnedRead,
      when: laborFiredRule,
      effect: const TxCond(
        FactNo('warned'),
        Tx('laborIss_44'),
        Tx('laborIss_45'),
      ),
    ),
    Slot.dsl(
      id: 'working',
      ask: topicText('laborIss_46'),
      why: topicText('laborIss_47'),
      options: [topicText('laborIss_48'), topicText('laborIss_49')],
      read: _laborWorkingRead,
      yesValue: '',
      noValue: '',
      when: const FactAll([FactTouched('event'), FactNot(laborFiredRule)]),
      effect: const TxCond(FactYes('working'), Tx('laborIss_50')),
    ),
    Slot.dsl(
      id: 'months',
      ask: topicText('laborIss_51'),
      why: topicText('laborIss_52'),
      read: _laborMonthsRead,
      readPending: const ReadMonths(min: 1),
      yesValue: '',
      noValue: '',
      effect: const TxConcat([
        Tx('laborSlotMonthsA'),
        TxRaw(' '),
        TxNum('months', fmt: NumFmt.span, defaultZero: true),
        TxRaw(' '),
        Tx('laborSlotMonthsB'),
        TxRaw(' '),
        TxCond(
          FactNumMin('months', 12, missingNull: false),
          Tx('laborSlotMonthsGe12'),
          Tx('laborSlotMonthsLt12'),
        ),
        TxRaw('.'),
      ]),
    ),
    Slot.dsl(
      id: 'salary',
      ask: topicText('laborIss_53'),
      why: topicText('laborIss_54'),
      read: _laborSalaryRead,
      readPending: const ReadAmount(),
      yesValue: '',
      noValue: '',
      effect: _laborMoney,
    ),
    // این دو پرسیده نمی‌شوند؛ فقط یادِ پرونده می‌مانند. «اتفاق اصلی» با هر
    // حرف تازه عوض می‌شود، ولی اخراج و حقوقِ نگرفته نباید با آمدنِ حرفِ
    // بیمه از یاد بروند؛ هر کدام ادعای خودش را روی میز نگه می‌دارد.
    Slot.dsl(
      id: 'fired',
      ask: '',
      why: '',
      read: const ReadCases([ReadCase(_laborFiredRe, 'yes')]),
      yesValue: '',
      noValue: '',
    ),
    Slot.dsl(
      id: 'owed',
      ask: '',
      why: '',
      read: const ReadCases([ReadCase(_laborUnpaid, 'yes')]),
      yesValue: '',
      noValue: '',
    ),
  ],
  opening: const Tx('laborIss_55'),
  issues: [
    Issue.dsl(
      id: 'sanavat',
      chip: topicText('laborIss_56'),
      cues: 'سنوات|پایان کار|مزایای پایان',
      body: const TxConcat([
        Tx('laborIss_57'),
        TxCond(
          FactAll([FactHasNum('months'), FactHasNum('salary')]),
          TxConcat([
            TxRaw('\n'),
            Tx('laborSanavatCalcA'),
            TxRaw(' '),
            TxNum('months', fmt: NumFmt.span),
            TxRaw(' '),
            Tx('laborSanavatCalcB'),
            TxRaw(' '),
            TxNum('salary'),
            Tx('laborSanavatCalcC'),
            TxRaw(' '),
            TxScaleMul('salary', 'months', 1.0),
            TxRaw(' '),
            Tx('laborSanavatCalcD'),
          ]),
          TxCond(
            FactHasNum('months'),
            TxConcat([
              TxRaw('\n'),
              Tx('laborSanavatNoSalA'),
              TxRaw(' '),
              TxNum('months', fmt: NumFmt.span),
              TxRaw(' '),
              Tx('laborSanavatNoSalB'),
            ]),
          ),
        ),
      ]),
      covers: const {'months'},
    ),
    Issue.dsl(
      id: 'howmuch',
      chip: topicText('laborIss_58'),
      cues:
          'چقدر (?:میشه|بهم|باید بده|طلب|میرسه|گیرم)|حساب کن|چقدر میتونم بگیرم|مبلغش چقدر',
      body: _laborMoney,
      covers: const {'months', 'salary'},
    ),
    Issue.dsl(
      id: 'sign',
      chip: topicText('laborIss_59'),
      cues:
          'استعفا|امضا (?:کنم|بدم|کردم|بزنم)|تسویه ?حساب|رضایت ?نامه|برگه (?:سفید|تسویه)|سفید امضا|انگشت بزن',
      covers: const {'signed'},
      body: const TxCond(
        FactYes('signed'),
        Tx('laborIss_60'),
        Tx('laborIss_61'),
      ),
    ),
    Issue.dsl(
      id: 'insurance',
      chip: topicText('laborIss_62'),
      cues: 'بیمه',
      body: const TxConcat([
        TxCond(
          FactAny([FactYes('insured'), FactNo('insured')]),
          TxRaw(''),
          TxConcat([Tx('laborInsIssuePre'), TxRaw('\n')]),
        ),
        Tx('laborInsIssueBody'),
      ]),
      covers: const {'insured', 'event'},
    ),
    Issue.dsl(
      id: 'wage',
      chip: topicText('laborIss_63'),
      cues: 'حقوق[^ ]* (?:رو |را )?(?:نمید|نداد|عقب)|معوق|دستمزد|عیدی|اضافه ?کار|مرخصی',
      body: const Tx('laborIss_64'),
      covers: const {'event'},
    ),
  ],
  follow: {
    'next': _laborPlan,
    'where': const Tx('laborIss_65'),
    'cost': const Tx('laborIss_66'),
    'time': const Tx('laborIss_67'),
    'deadline': const Tx('laborIss_68'),
    'chance': _laborChance,
    'evidence': const Tx('laborIss_69'),
    'refuse': const Tx('laborIss_70'),
    'lawyer': const Tx('laborIss_71'),
  },
  drafts: const DraftRule.fixed(['formal_notice']),
);
