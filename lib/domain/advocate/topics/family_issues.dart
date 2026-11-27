part of 'family.dart';

// پرسش‌ها و خودِ تعریفِ موضوعِ خانواده.

final Topic familyTopic = Topic(
  id: 'family',
  title: topicText('familyIss_0'),
  claims: familyClaims,
  recap: familyRecap,
  cues: {
    'ملاقات (?:با )?(?:فرزند|بچه|دختر|پسر)|(?:بچه|فرزند)[^ ]* (?:[^ ]+ ){0,3}ببینم|ترک انفاق|شروط ضمن عقد|دادگاه خانواده|ممنوع ?الخروج': 3,
    'طلاق|مهریه|مهریم|نفقه|حضانت|جهیزیه|تمکین|جدا (?:شم|بشم|شیم|بشیم)': 3,
    'شوهر|زنم|خانمم|همسر': 2,
    'کتک|میزنه|دست بزن|ازدواج|عقد(?: |م)|نامزد|خرجی|مادرشوهر': 1,
    'منو زد|زد(?:ه)? منو|بیرونم کرد|از خونه بیرون|قهر کرد|خیانت|معتاد|رفته خونه (?:باباش|پدرش|مادرش)': 1,
  },
  slots: [
    Slot(
      id: 'role',
      first: true,
      ask: topicText('familyIss_1'),
      why: topicText('familyIss_2'),
      options: [topicText('familyIss_3'), topicText('familyIss_4')],
      read: _famRole,
      readPending: (n) => Sense.has(n, 'زن|خانم|زوجه')
          ? 'wife'
          : (Sense.has(n, 'شوهر|مرد|آقا|زوج') ? 'husband' : null),
      yesValue: '',
      noValue: '',
    ),
    Slot(
      id: 'violence',
      ask: '',
      why: '',
      read: _famViolence,
      when: (f) => false,
    ),
    Slot(
      id: 'childAge',
      ask: '',
      why: '',
      read: _famChildAge,
      when: (f) => false,
      effect: _famCustody,
    ),
    Slot(
      id: 'coins',
      ask: '',
      why: '',
      read: (n) => Sense.numberBefore(n, 'سکه')?.toString(),
      when: (f) => false,
      effect: (f) {
        final c = f.n('coins') ?? 0;
        if (f.eq('role', 'husband')) {
          return c > 110
              ? topicText('familySlotCoinsHOverA') + ' ' + Sense.fa(c) + ' ' + topicText('familySlotCoinsHOverB') + ' ' + Sense.fa(c - 110) + ' ' + topicText('familySlotCoinsHOverC')
              : topicText('familySlotCoinsHUnderA') + ' ' + Sense.fa(c) + ' ' + topicText('familySlotCoinsHUnderB');
        }
        return c > 110
            ? topicText('familySlotCoinsWOverA') + ' ' + Sense.fa(c) + ' ' + topicText('familySlotCoinsWOverB') + ' ' + Sense.fa(c - 110) + ' ' + topicText('familySlotCoinsWOverC')
            : topicText('familySlotCoinsWUnderA') + ' ' + Sense.fa(c) + ' ' + topicText('familySlotCoinsWUnderB');
      },
    ),
    Slot(
      id: 'proofV',
      ask: topicText('familyIss_5'),
      why: topicText('familyIss_6'),
      options: [topicText('familyIss_7'), topicText('familyIss_8'), topicText('familyIss_9')],
      read: (n) {
        if (Sense.has(n, 'پزشکی قانونی|طول درمان|گواهی پزشک|نامه پزشک')) return 'medical';
        if (Sense.has(n, 'هیچ مدرک|مدرک(?:ی)? ندارم|شاهد(?:ی)? ندارم')) return 'none';
        if (Sense.has(n, 'عکس دارم|فیلم دارم|شاهد دارم|همسایه ها (?:دیدن|شنیدن)|شاهد هست')) return 'witness';
        return null;
      },
      readPending: (n) => Sense.has(n, 'عکس|فیلم|شاهد|همسایه|مادرم|خواهرم')
          ? 'witness'
          : null,
      yesValue: 'witness',
      noValue: 'none',
      when: (f) => f.yes('violence') && !f.eq('role', 'husband'),
      effect: (f) {
        switch (f.get('proofV')) {
          case 'medical':
            return topicText('familyIss_10');
          case 'witness':
            return topicText('familyIss_11');
          default:
            return topicText('familyIss_12');
        }
      },
    ),
    Slot(
      id: 'agrees',
      ask: topicText('familyIss_13'),
      why: topicText('familyIss_14'),
      options: [topicText('familyIss_15'), topicText('familyIss_16')],
      read: (n) => Sense.yn(
        n,
        'توافقی|راضیه|راضی است|راضی هست|قبول داره|اونم میخواد|خودش هم میخواد',
        'راضی (?:نیست|نمیش)|طلاق[^ ]* نمیده|قبول نمیکنه|نمیذاره|مخالف',
      ),
      when: (f) => f.eq('role', 'wife') && f.covered.contains('divorce'),
      effect: (f) => f.yes('agrees')
          ? topicText('familyIss_17')
          : topicText('familyIss_18'),
    ),
  ],
  opening: (f) {
    if (f.yes('violence') && !f.eq('role', 'husband')) return _famSafety(f);
    return topicText('familyIss_19');
  },
  issues: [
    Issue(
      id: 'cantpay',
      chip: topicText('familyIss_20'),
      cues: 'ندارم (?:که )?بدم|توان(?:ش رو| پرداخت)? ندارم|پول(?:ی)? ندارم|از کجا بیارم|نمیتونم بدم|وسعم نمیرسه|قسطی|تقسیط|اعسار|زندان(?:ی)? (?:میشم|میرم|میکنن)|حبس',
      body: (f) =>
          topicText('familyIss_21'),
      when: (f) => f.eq('role', 'husband'),
    ),
    Issue(
      id: 'leave',
      chip: topicText('familyIss_22'),
      cues: 'از خونه (?:برم|رفتم|زدم بیرون)|خونه (?:بابام|پدرم|مادرم)|قهر|ترک (?:منزل|خونه)|برگردم خونه|تمکین|نشوز|ناشزه',
      body: (f) =>
          topicText('familyIss_23'),
      when: (f) => !f.eq('role', 'husband'),
    ),
    Issue(
      id: 'mehr',
      chip: topicText('familyIss_24'),
      cues: 'مهریه|مهریم|سکه',
      body: _famMehr,
      covers: const {'coins'},
    ),
    Issue(
      id: 'custody',
      chip: topicText('familyIss_25'),
      cues: 'حضانت|بچه[^ ]* (?:رو |را )?(?:با کیه|پیش کی|میگیره|ازم میگیر|میدن به|نگه دارم|ببینم|نمیده ببینم)|ملاقات|سرپرستی',
      body: _famCustody,
    ),
    Issue(
      id: 'nafaqe',
      chip: topicText('familyIss_26'),
      cues: 'نفقه|خرجی|خرج خونه(?: رو)? نمیده|پول نمیده',
      body: (f) => f.eq('role', 'husband')
          ? topicText('familyIss_27')
          : topicText('familyIss_28'),
    ),
    Issue(
      id: 'divorce',
      chip: topicText('familyIss_29'),
      cues: 'طلاق|جدا (?:شم|بشم|شیم|بشیم)|جدایی',
      body: _famDivorce,
    ),
    Issue(
      id: 'violence',
      chip: topicText('familyIss_30'),
      cues: 'کتک|میزنه|دست بزن|ضرب|کبود|خشونت|تهدید[^ ]* میکنه|پزشکی قانونی|دیه',
      body: _famSafety,
      when: (f) => !f.eq('role', 'husband'),
    ),
  ],
  follow: {
    'next': (f) {
      if (f.eq('role', 'husband')) {
        return topicText('familyIss_31');
      }
      final v = f.yes('violence')
          ? topicText('familyIss_32')
          : topicText('familyIss_33');
      return topicText('familyNextLead') + '\n' + v + topicText('familyNextRest');
    },
    'where': (f) =>
        topicText('familyIss_34'),
    'cost': (f) =>
        topicText('familyIss_35'),
    'time': (f) =>
        topicText('familyIss_36'),
    'chance': (f) {
      if (f.yes('violence')) {
        final p = f.get('proofV');
        return p == 'medical'
            ? topicText('familyIss_37')
            : topicText('familyIss_38');
      }
      return topicText('familyIss_39');
    },
    'evidence': (f) =>
        topicText('familyIss_40'),
    'refuse': (f) =>
        topicText('familyIss_41'),
  },
  drafts: (f) => const ['legal_aid'],
);
