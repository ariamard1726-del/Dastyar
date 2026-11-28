part of 'family.dart';

// پرسش‌ها و خودِ تعریفِ موضوعِ خانواده.

const TextExpr _famCoinsEffect = TxCond(
  _famIsHusband,
  TxCond(
    FactNumMin('coins', 111, missingNull: false),
    TxConcat([
      Tx('familySlotCoinsHOverA'),
      TxRaw(' '),
      TxNum('coins', fmt: NumFmt.fa, defaultZero: true),
      TxRaw(' '),
      Tx('familySlotCoinsHOverB'),
      TxRaw(' '),
      TxNumOffset('coins', -110),
      TxRaw(' '),
      Tx('familySlotCoinsHOverC'),
    ]),
    TxConcat([
      Tx('familySlotCoinsHUnderA'),
      TxRaw(' '),
      TxNum('coins', fmt: NumFmt.fa, defaultZero: true),
      TxRaw(' '),
      Tx('familySlotCoinsHUnderB'),
    ]),
  ),
  TxCond(
    FactNumMin('coins', 111, missingNull: false),
    TxConcat([
      Tx('familySlotCoinsWOverA'),
      TxRaw(' '),
      TxNum('coins', fmt: NumFmt.fa, defaultZero: true),
      TxRaw(' '),
      Tx('familySlotCoinsWOverB'),
      TxRaw(' '),
      TxNumOffset('coins', -110),
      TxRaw(' '),
      Tx('familySlotCoinsWOverC'),
    ]),
    TxConcat([
      Tx('familySlotCoinsWUnderA'),
      TxRaw(' '),
      TxNum('coins', fmt: NumFmt.fa, defaultZero: true),
      TxRaw(' '),
      Tx('familySlotCoinsWUnderB'),
    ]),
  ),
);

final Topic familyTopic = Topic.dsl(
  id: 'family',
  title: topicText('familyIss_0'),
  claims: familyClaims,
  recap: _familyRecap,
  cues: const {
    'ملاقات (?:با )?(?:فرزند|بچه|دختر|پسر)|(?:بچه|فرزند)[^ ]* (?:[^ ]+ ){0,3}ببینم|ترک انفاق|شروط ضمن عقد|دادگاه خانواده|ممنوع ?الخروج':
        3,
    'طلاق|مهریه|مهریم|نفقه|حضانت|جهیزیه|تمکین|جدا (?:شم|بشم|شیم|بشیم)': 3,
    'شوهر|زنم|خانمم|همسر': 2,
    'کتک|میزنه|دست بزن|ازدواج|عقد(?: |م)|نامزد|خرجی|مادرشوهر': 1,
    'منو زد|زد(?:ه)? منو|بیرونم کرد|از خونه بیرون|قهر کرد|خیانت|معتاد|رفته خونه (?:باباش|پدرش|مادرش)':
        1,
  },
  slots: [
    Slot.dsl(
      id: 'role',
      first: true,
      ask: topicText('familyIss_1'),
      why: topicText('familyIss_2'),
      options: [topicText('familyIss_3'), topicText('familyIss_4')],
      read: _famRoleRead,
      readPending: const ReadCases([
        ReadCase('زن|خانم|زوجه', 'wife'),
        ReadCase('شوهر|مرد|آقا|زوج', 'husband'),
      ]),
      yesValue: '',
      noValue: '',
    ),
    Slot.dsl(
      id: 'violence',
      ask: '',
      why: '',
      read: _famViolenceRead,
      when: const FactConst(false),
    ),
    Slot.dsl(
      id: 'childAge',
      ask: '',
      why: '',
      read: _famChildAgeRead,
      when: const FactConst(false),
      effect: _famCustody,
    ),
    Slot.dsl(
      id: 'coins',
      ask: '',
      why: '',
      read: _famCoinsRead,
      when: const FactConst(false),
      effect: _famCoinsEffect,
    ),
    Slot.dsl(
      id: 'proofV',
      ask: topicText('familyIss_5'),
      why: topicText('familyIss_6'),
      options: [
        topicText('familyIss_7'),
        topicText('familyIss_8'),
        topicText('familyIss_9'),
      ],
      read: const ReadCases([
        ReadCase('پزشکی قانونی|طول درمان|گواهی پزشک|نامه پزشک', 'medical'),
        ReadCase('هیچ مدرک|مدرک(?:ی)? ندارم|شاهد(?:ی)? ندارم', 'none'),
        ReadCase(
          'عکس دارم|فیلم دارم|شاهد دارم|همسایه ها (?:دیدن|شنیدن)|شاهد هست',
          'witness',
        ),
      ]),
      readPending: const ReadCases([
        ReadCase('عکس|فیلم|شاهد|همسایه|مادرم|خواهرم', 'witness'),
      ]),
      yesValue: 'witness',
      noValue: 'none',
      when: const FactAll([FactYes('violence'), _famNotHusband]),
      effect: const TxSwitch(
        'proofV',
        {
          'medical': Tx('familyIss_10'),
          'witness': Tx('familyIss_11'),
        },
        fallback: Tx('familyIss_12'),
      ),
    ),
    Slot.dsl(
      id: 'agrees',
      ask: topicText('familyIss_13'),
      why: topicText('familyIss_14'),
      options: [topicText('familyIss_15'), topicText('familyIss_16')],
      read: const ReadYn(
        'توافقی|راضیه|راضی است|راضی هست|قبول داره|اونم میخواد|خودش هم میخواد',
        'راضی (?:نیست|نمیش)|طلاق[^ ]* نمیده|قبول نمیکنه|نمیذاره|مخالف',
      ),
      when: const FactAll([_famIsWife, FactCovered('divorce')]),
      effect: const TxCond(
        FactYes('agrees'),
        Tx('familyIss_17'),
        Tx('familyIss_18'),
      ),
    ),
  ],
  opening: const TxCond(
    FactAll([FactYes('violence'), _famNotHusband]),
    _famSafety,
    Tx('familyIss_19'),
  ),
  issues: [
    Issue.dsl(
      id: 'cantpay',
      chip: topicText('familyIss_20'),
      cues:
          'ندارم (?:که )?بدم|توان(?:ش رو| پرداخت)? ندارم|پول(?:ی)? ندارم|از کجا بیارم|نمیتونم بدم|وسعم نمیرسه|قسطی|تقسیط|اعسار|زندان(?:ی)? (?:میشم|میرم|میکنن)|حبس',
      body: const Tx('familyIss_21'),
      when: _famIsHusband,
    ),
    Issue.dsl(
      id: 'leave',
      chip: topicText('familyIss_22'),
      cues:
          'از خونه (?:برم|رفتم|زدم بیرون)|خونه (?:بابام|پدرم|مادرم)|قهر|ترک (?:منزل|خونه)|برگردم خونه|تمکین|نشوز|ناشزه',
      body: const Tx('familyIss_23'),
      when: _famNotHusband,
    ),
    Issue.dsl(
      id: 'mehr',
      chip: topicText('familyIss_24'),
      cues: 'مهریه|مهریم|سکه',
      body: _famMehr,
      covers: const {'coins'},
    ),
    Issue.dsl(
      id: 'custody',
      chip: topicText('familyIss_25'),
      cues:
          'حضانت|بچه[^ ]* (?:رو |را )?(?:با کیه|پیش کی|میگیره|ازم میگیر|میدن به|نگه دارم|ببینم|نمیده ببینم)|ملاقات|سرپرستی',
      body: _famCustody,
    ),
    Issue.dsl(
      id: 'nafaqe',
      chip: topicText('familyIss_26'),
      cues: 'نفقه|خرجی|خرج خونه(?: رو)? نمیده|پول نمیده',
      body: const TxCond(_famIsHusband, Tx('familyIss_27'), Tx('familyIss_28')),
    ),
    Issue.dsl(
      id: 'divorce',
      chip: topicText('familyIss_29'),
      cues: 'طلاق|جدا (?:شم|بشم|شیم|بشیم)|جدایی',
      body: _famDivorce,
    ),
    Issue.dsl(
      id: 'violence',
      chip: topicText('familyIss_30'),
      cues:
          'کتک|میزنه|دست بزن|ضرب|کبود|خشونت|تهدید[^ ]* میکنه|پزشکی قانونی|دیه',
      body: _famSafety,
      when: _famNotHusband,
    ),
  ],
  follow: const {
    'next': TxCond(
      _famIsHusband,
      Tx('familyIss_31'),
      TxConcat([
        Tx('familyNextLead'),
        TxRaw('\n'),
        TxCond(
          FactYes('violence'),
          Tx('familyIss_32'),
          Tx('familyIss_33'),
        ),
        Tx('familyNextRest'),
      ]),
    ),
    'where': Tx('familyIss_34'),
    'cost': Tx('familyIss_35'),
    'time': Tx('familyIss_36'),
    'chance': TxCond(
      FactYes('violence'),
      TxCond(
        FactEq('proofV', 'medical'),
        Tx('familyIss_37'),
        Tx('familyIss_38'),
      ),
      Tx('familyIss_39'),
    ),
    'evidence': Tx('familyIss_40'),
    'refuse': Tx('familyIss_41'),
  },
  drafts: const DraftRule.fixed(['legal_aid']),
);
