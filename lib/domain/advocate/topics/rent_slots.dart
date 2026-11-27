part of 'rent.dart';

// واقعیت‌هایی که وکیل در موضوعِ اجاره می‌پرسد یا از حرفِ کاربر می‌خواند.
//
// هر `Slot` یک پرسش، الگوی خواندنش و اثرِ حقوقی‌اش را کنارِ هم دارد؛ این فهرست
// «چه می‌دانیم» است، نه «چه می‌گوییم».

final List<Slot> _rentSlots = [
  Slot(
    id: 'role',
    first: true,
    // نقش با اشارهٔ گذرا یا نقلِ حرفِ طرف مقابل عوض نمی‌شود؛ فقط با حرفِ
    // صریحِ خودِ کاربر.
    sticky: true,
    readSure: _rentRoleSaid,
    ask: rentText('slotRoleAsk'),
    why: rentText('slotRoleWhy'),
    options: [rentText('slotRoleOpt0'), rentText('slotRoleOpt1')],
    read: _rentRole,
    readPending: (n) => Sense.has(n, 'موجر|صاحب|مالک')
        ? 'landlord'
        : (Sense.has(n, 'مستاجر') ? 'tenant' : null),
    yesValue: '',
    noValue: '',
  ),
  Slot(
    id: 'matter',
    first: true,
    sticky: true,
    priority: const ['order'],
    ask: rentText('slotMatterAsk'),
    why: rentText('slotMatterWhy'),
    options: [
      rentText('slotMatterOpt0'),
      rentText('slotMatterOpt1'),
      rentText('slotMatterOpt2'),
      rentText('slotMatterOpt3'),
      rentText('slotMatterOpt4'),
      rentText('slotMatterOpt5'),
    ],
    read: _rentMatter,
    yesValue: '',
    noValue: '',
    when: (f) => f.eq('role', 'tenant'),
    effect: (f) => _matter(f, 'deposit') ? _rentDepositLaw() : '',
  ),
  Slot(
    id: 'aim',
    first: true,
    sticky: true,
    priority: const ['evict', 'breach', 'unpaid', 'damage'],
    ask: rentText('slotAimAsk'),
    why: rentText('slotAimWhy'),
    options: [
      rentText('slotAimOpt0'),
      rentText('slotAimOpt1'),
      rentText('slotAimOpt2'),
      rentText('slotAimOpt3'),
    ],
    read: _rentAim,
    yesValue: '',
    noValue: '',
    when: (f) => f.eq('role', 'landlord'),
    effect: _aimEffect,
  ),
  Slot(
    id: 'official',
    ask: rentText('slotOfficialAsk'),
    why: rentText('slotOfficialWhy'),
    options: [rentText('slotOfficialOpt0'), rentText('slotOfficialOpt1')],
    read: _rentOfficial,
    readPending: (n) => Sense.has(n, 'خودش|حرف|نیومده|نیامده|نه هنوز')
        ? 'no'
        : (Sense.has(n, 'اومده|آمده|رسیده|ابلاغ شد') ? 'yes' : null),
    when: (f) => _matter(f, 'evict'),
    effect: (f) {
      if (!_matter(f, 'evict')) return '';
      return f.yes('official')
          ? _rentOrderBody(f)
          : rentText('effectSlotOfficialNo');
    },
  ),
  Slot(
    id: 'vacated',
    ask: rentText('slotVacatedAsk'),
    why: rentText('slotVacatedWhy'),
    options: [rentText('slotVacatedOpt0'), rentText('slotVacatedOpt1')],
    read: _rentVacated,
    readPending: (n) => Sense.has(n, 'نکرد|هنوز| نه |ندادم|دست (?:خودمه|منه)')
        ? 'no'
        : (Sense.has(n, 'کردم|کرده ام|دادم| آره | اره | بله ') ? 'yes' : null),
    when: _rentDeposit,
    effect: (f) => f.yes('vacated')
        ? rentText('effectSlotVacatedYes')
        : rentText('effectSlotVacatedNo'),
  ),
  Slot(
    id: 'ended',
    ask: rentText('slotEndedAsk'),
    why: rentText('slotEndedWhy'),
    options: [rentText('slotEndedOpt0'), rentText('slotEndedOpt1')],
    read: _rentEnded,
    when: _needsEnded,
    effect: _endedEffect,
  ),
  Slot(
    id: 'contract',
    ask: rentText('slotContractAsk'),
    why: rentText('slotContractWhy'),
    options: [rentText('slotContractOpt0'), rentText('slotContractOpt1')],
    read: _rentContract,
    when: _needsContract,
    effect: _contractEffect,
  ),
  Slot(
    id: 'witness',
    ask: rentText('slotWitnessAsk'),
    why: rentText('slotWitnessWhy'),
    options: [rentText('slotWitnessOpt0'), rentText('slotWitnessOpt1')],
    read: _rentWitness,
    when: (f) => _evicting(f) && f.yes('contract') && !f.no('ended'),
    effect: (f) {
      if (!f.eq('role', 'landlord')) return '';
      return f.yes('witness')
          ? rentText('effectSlotWitnessYes')
          : rentText('effectSlotWitnessNo');
    },
  ),
  Slot(
    id: 'clause',
    ask: rentText('slotClauseAsk'),
    why: rentText('slotClauseWhy'),
    options: [rentText('slotClauseOpt0'), rentText('slotClauseOpt1')],
    read: _rentClause,
    when: (f) => (_evicting(f) && f.no('ended')) || _aim(f, 'breach'),
    effect: (f) {
      if (!f.eq('role', 'landlord')) return '';
      return f.yes('clause')
          ? rentText('effectSlotClauseYes')
          : rentText('effectSlotClauseNo');
    },
  ),
  Slot(
    id: 'proof',
    ask: rentText('slotProofAsk'),
    why: rentText('slotProofWhy'),
    options: [rentText('slotProofOpt0'), rentText('slotProofOpt1')],
    read: _rentProof,
    when: (f) => _aim(f, 'damage') || _aim(f, 'breach'),
    effect: (f) {
      if (!_aim(f, 'damage') && !_aim(f, 'breach')) return '';
      return f.yes('proof')
          ? rentText('effectSlotProofYes')
          : rentText('effectSlotProofNo');
    },
  ),
  Slot(
    id: 'told',
    ask: rentText('slotToldAsk'),
    why: rentText('slotToldWhy'),
    options: [rentText('slotToldOpt0'), rentText('slotToldOpt1')],
    read: _rentTold,
    when: (f) => _matter(f, 'repair'),
    effect: (f) {
      if (!_matter(f, 'repair')) return '';
      return f.yes('told')
          ? rentText('effectSlotToldYes')
          : rentText('effectSlotToldNo');
    },
  ),
  Slot(
    id: 'consent',
    ask: rentText('slotConsentAsk'),
    why: rentText('slotConsentWhy'),
    options: [rentText('slotConsentOpt0'), rentText('slotConsentOpt1')],
    read: _rentConsent,
    when: (f) => _matter(f, 'leave'),
    effect: (f) {
      if (!_matter(f, 'leave')) return '';
      return f.yes('consent')
          ? rentText('effectSlotConsentYes')
          : rentText('effectSlotConsentNo');
    },
  ),
  Slot(
    id: 'amount',
    ask: rentText('slotAmountAsk'),
    why: rentText('slotAmountWhy'),
    read: (n) => Sense.amount(n)?.toString(),
    readPending: (n) => Sense.looseAmount(n)?.toString(),
    yesValue: '',
    noValue: '',
    when: _rentDeposit,
    effect: (f) => _rentDeposit(f) ? moneyForum(f.n('amount')) : '',
  ),
  Slot(
    id: 'due',
    ask: rentText('slotDueAsk'),
    why: rentText('slotDueWhy'),
    read: (n) => Sense.amount(n)?.toString(),
    readPending: (n) => Sense.looseAmount(n)?.toString(),
    yesValue: '',
    noValue: '',
    when: (f) => _aim(f, 'unpaid') || _aim(f, 'damage'),
    effect: (f) => _aim(f, 'unpaid') || _aim(f, 'damage')
        ? moneyForum(f.n('due'))
        : '',
  ),
  // واقعیت‌هایی که فقط از حرف کاربر خوانده می‌شوند و پرسیده نمی‌شوند.
  Slot(
    id: 'place',
    ask: '',
    why: '',
    read: (n) => Sense.has(n,
            'مغازه|تجاری|دکان|دکون|محل کسب|سرقفلی|حق کسب|پاساژ|دفتر کار|کارگاه')
        ? 'shop'
        : null,
    yesValue: '',
    noValue: '',
  ),
  Slot(
    id: 'owes',
    ask: '',
    why: '',
    read: (n) => Sense.has(n, _cUnpaid) ? 'yes' : null,
    yesValue: '',
    noValue: '',
  ),
];
