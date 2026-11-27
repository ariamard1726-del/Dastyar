part of 'rent.dart';

// واقعیت‌هایی که وکیل در موضوعِ اجاره می‌پرسد یا از حرفِ کاربر می‌خواند.

const FactExpr _needsContract = FactAny([
  FactAll([
    _landlordSide,
    FactAny([FactNot(FactHas('aim')), FactEq('aim', 'evict'), FactEq('aim', 'unpaid')]),
  ]),
  FactAll([
    _tenantSide,
    FactAny([
      FactNot(FactHas('matter')),
      FactIn('matter', ['deposit', 'raise', 'repair', 'deliver']),
    ]),
  ]),
]);

const FactExpr _needsEnded = FactAny([
  FactAll([
    _landlordSide,
    FactAny([FactNot(FactHas('aim')), FactEq('aim', 'evict')]),
  ]),
  FactAll([
    _tenantSide,
    FactNot(FactIn('matter', ['repair', 'leave', 'deliver'])),
  ]),
]);

final List<Slot> _rentSlots = [
  Slot.dsl(
    id: 'role',
    first: true,
    // نقش با اشارهٔ گذرا یا نقلِ حرفِ طرف مقابل عوض نمی‌شود؛ فقط با حرفِ
    // صریحِ خودِ کاربر.
    sticky: true,
    readSure: _rentRoleSaidRead,
    ask: rentText('slotRoleAsk'),
    why: rentText('slotRoleWhy'),
    options: [rentText('slotRoleOpt0'), rentText('slotRoleOpt1')],
    read: _rentRoleRead,
    readPending: const ReadCases([
      ReadCase('موجر|صاحب|مالک', 'landlord'),
      ReadCase('مستاجر', 'tenant'),
    ]),
    yesValue: '',
    noValue: '',
  ),
  Slot.dsl(
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
    read: _rentMatterRead,
    yesValue: '',
    noValue: '',
    when: _isTenantRole,
    effect: const TxCond(_mDeposit, _rentDepositLaw),
  ),
  Slot.dsl(
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
    read: _rentAimRead,
    yesValue: '',
    noValue: '',
    when: _landlordSide,
    effect: _aimEffect,
  ),
  Slot.dsl(
    id: 'official',
    ask: rentText('slotOfficialAsk'),
    why: rentText('slotOfficialWhy'),
    options: [rentText('slotOfficialOpt0'), rentText('slotOfficialOpt1')],
    read: _rentOfficialRead,
    readPending: const ReadCases([
      ReadCase('خودش|حرف|نیومده|نیامده|نه هنوز', 'no'),
      ReadCase('اومده|آمده|رسیده|ابلاغ شد', 'yes'),
    ]),
    when: _mEvict,
    effect: const TxCond(
      _mEvict,
      TxCond(
        FactYes('official'),
        _rentOrderBody,
        TxRent('effectSlotOfficialNo'),
      ),
    ),
  ),
  Slot.dsl(
    id: 'vacated',
    ask: rentText('slotVacatedAsk'),
    why: rentText('slotVacatedWhy'),
    options: [rentText('slotVacatedOpt0'), rentText('slotVacatedOpt1')],
    read: _rentVacatedRead,
    readPending: const ReadCases([
      ReadCase('نکرد|هنوز| نه |ندادم|دست (?:خودمه|منه)', 'no'),
      ReadCase('کردم|کرده ام|دادم| آره | اره | بله ', 'yes'),
    ]),
    when: _rentDeposit,
    effect: const TxCond(
      FactYes('vacated'),
      TxRent('effectSlotVacatedYes'),
      TxRent('effectSlotVacatedNo'),
    ),
  ),
  Slot.dsl(
    id: 'ended',
    ask: rentText('slotEndedAsk'),
    why: rentText('slotEndedWhy'),
    options: [rentText('slotEndedOpt0'), rentText('slotEndedOpt1')],
    read: _rentEndedRead,
    when: _needsEnded,
    effect: _endedEffect,
  ),
  Slot.dsl(
    id: 'contract',
    ask: rentText('slotContractAsk'),
    why: rentText('slotContractWhy'),
    options: [rentText('slotContractOpt0'), rentText('slotContractOpt1')],
    read: _rentContractRead,
    when: _needsContract,
    effect: _contractEffect,
  ),
  Slot.dsl(
    id: 'witness',
    ask: rentText('slotWitnessAsk'),
    why: rentText('slotWitnessWhy'),
    options: [rentText('slotWitnessOpt0'), rentText('slotWitnessOpt1')],
    read: _rentWitnessRead,
    when: const FactAll([_evicting, FactYes('contract'), FactNot(FactNo('ended'))]),
    effect: const TxCond(
      _landlordSide,
      TxCond(
        FactYes('witness'),
        TxRent('effectSlotWitnessYes'),
        TxRent('effectSlotWitnessNo'),
      ),
    ),
  ),
  Slot.dsl(
    id: 'clause',
    ask: rentText('slotClauseAsk'),
    why: rentText('slotClauseWhy'),
    options: [rentText('slotClauseOpt0'), rentText('slotClauseOpt1')],
    read: _rentClauseRead,
    when: const FactAny([
      FactAll([_evicting, FactNo('ended')]),
      _aBreach,
    ]),
    effect: const TxCond(
      _landlordSide,
      TxCond(
        FactYes('clause'),
        TxRent('effectSlotClauseYes'),
        TxRent('effectSlotClauseNo'),
      ),
    ),
  ),
  Slot.dsl(
    id: 'proof',
    ask: rentText('slotProofAsk'),
    why: rentText('slotProofWhy'),
    options: [rentText('slotProofOpt0'), rentText('slotProofOpt1')],
    read: _rentProofRead,
    when: const FactAny([_aDamage, _aBreach]),
    effect: const TxCond(
      FactAny([_aDamage, _aBreach]),
      TxCond(
        FactYes('proof'),
        TxRent('effectSlotProofYes'),
        TxRent('effectSlotProofNo'),
      ),
    ),
  ),
  Slot.dsl(
    id: 'told',
    ask: rentText('slotToldAsk'),
    why: rentText('slotToldWhy'),
    options: [rentText('slotToldOpt0'), rentText('slotToldOpt1')],
    read: _rentToldRead,
    when: _mRepair,
    effect: const TxCond(
      _mRepair,
      TxCond(
        FactYes('told'),
        TxRent('effectSlotToldYes'),
        TxRent('effectSlotToldNo'),
      ),
    ),
  ),
  Slot.dsl(
    id: 'consent',
    ask: rentText('slotConsentAsk'),
    why: rentText('slotConsentWhy'),
    options: [rentText('slotConsentOpt0'), rentText('slotConsentOpt1')],
    read: _rentConsentRead,
    when: _mLeave,
    effect: const TxCond(
      _mLeave,
      TxCond(
        FactYes('consent'),
        TxRent('effectSlotConsentYes'),
        TxRent('effectSlotConsentNo'),
      ),
    ),
  ),
  Slot.dsl(
    id: 'amount',
    ask: rentText('slotAmountAsk'),
    why: rentText('slotAmountWhy'),
    read: const ReadAmount(),
    readPending: const ReadAmount(loose: true),
    yesValue: '',
    noValue: '',
    when: _rentDeposit,
    effect: const TxCond(_rentDeposit, TxForum('amount')),
  ),
  Slot.dsl(
    id: 'due',
    ask: rentText('slotDueAsk'),
    why: rentText('slotDueWhy'),
    read: const ReadAmount(),
    readPending: const ReadAmount(loose: true),
    yesValue: '',
    noValue: '',
    when: const FactAny([_aUnpaid, _aDamage]),
    effect: const TxCond(FactAny([_aUnpaid, _aDamage]), TxForum('due')),
  ),
  // واقعیت‌هایی که فقط از حرف کاربر خوانده می‌شوند و پرسیده نمی‌شوند.
  Slot.dsl(
    id: 'place',
    ask: '',
    why: '',
    read: const ReadCases([
      ReadCase(
        'مغازه|تجاری|دکان|دکون|محل کسب|سرقفلی|حق کسب|پاساژ|دفتر کار|کارگاه',
        'shop',
      ),
    ]),
    yesValue: '',
    noValue: '',
  ),
  Slot.dsl(
    id: 'owes',
    ask: '',
    why: '',
    read: const ReadCases([ReadCase(_cUnpaid, 'yes')]),
    yesValue: '',
    noValue: '',
  ),
];
