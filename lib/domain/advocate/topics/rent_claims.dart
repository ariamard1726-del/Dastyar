part of 'rent.dart';

// ادعاهای حقوقیِ این موضوع: ارکان، شرط و نتیجه.

final List<Claim> rentClaims = [
  Claim.dsl(
    goal: rentText('claim0_goal'),
    when: _aUnpaid,
    cues: 'اجاره|کرایه|طلب|پول',
    uses: const ['due'],
    elements: [
      Element.dsl(
        rentText('claim0_e0_text'),
        const FactTri('contract'),
        needs: const ['contract'],
        because: const TxRent('claim0_e0_because'),
        ifNo: rentText('claim0_e0_ifNo'),
      ),
    ],
    win: const TxRent('claim0_win'),
    counter: const TxRent('claim0_counter'),
  ),
  Claim.dsl(
    goal: rentText('claim1_goal'),
    when: _aDamage,
    cues: 'خسارت|خراب|تعمیر',
    uses: const ['due'],
    elements: [
      Element.dsl(
        rentText('claim1_e0_text'),
        const FactTri('proof'),
        needs: const ['proof'],
        because: const TxRent('claim1_e0_because'),
        ifNo: rentText('claim1_e0_ifNo'),
      ),
    ],
    win: const TxRent('claim1_win'),
    counter: const TxRent('claim1_counter'),
  ),
  Claim.dsl(
    goal: rentText('claim2_goal'),
    when: _aBreach,
    cues: 'فسخ|تخلیه|بلند|بیرون',
    elements: [
      Element.dsl(
        rentText('claim2_e0_text'),
        const FactTri('clause'),
        needs: const ['clause'],
        because: const TxRent('claim2_e0_because'),
        ifNo: rentText('claim2_e0_ifNo'),
      ),
      Element.dsl(
        rentText('claim2_e1_text'),
        const FactTri('proof'),
        needs: const ['proof'],
        because: const TxRent('claim2_e1_because'),
        ifNo: rentText('claim2_e1_ifNo'),
      ),
    ],
    win: const TxRent('claim2_win'),
    counter: const TxRent('claim2_counter'),
  ),
  Claim.dsl(
    goal: rentText('claim3_goal'),
    when: const FactAll([_evicting, FactNo('ended')]),
    cues: 'تخلیه|بیرون(?:ش)? کنم|بلند(?:ش)? کنم|خالی (?:کنه|کند|بشه)|فسخ',
    elements: [
      Element.dsl(
        rentText('claim3_e0_text'),
        const FactTri('clause'),
        needs: const ['clause'],
        because: const TxRent('claim3_e0_because'),
        ifNo: rentText('claim3_e0_ifNo'),
      ),
      Element.dsl(
        rentText('claim3_e1_text'),
        const FactTri('contract'),
        needs: const ['contract'],
        because: const TxRent('claim3_e1_because'),
        ifNo: rentText('claim3_e1_ifNo'),
      ),
    ],
    win: const TxRent('claim3_win'),
    counter: const TxRent('claim3_counter'),
  ),
  Claim.dsl(
    goal: rentText('claim4_goal'),
    when: _landlordSide,
    cues: 'تخلیه|بیرون(?:ش)? کنم|بلند(?:ش)? کنم|خالی (?:کنه|کند|بشه)',
    elements: [
      Element.dsl(
        rentText('claim4_e0_text'),
        const FactTri('ended'),
        needs: const ['ended'],
        because: const TxRent('claim4_e0_because'),
        ifNo: rentText('claim4_e0_ifNo'),
      ),
      Element.dsl(
        rentText('claim4_e1_text'),
        const FactTri('contract'),
        needs: const ['contract'],
        because: const TxRent('claim4_e1_because'),
        ifNo: rentText('claim4_e1_ifNo'),
      ),
      Element.dsl(
        rentText('claim4_e2_text'),
        const FactTriWhen(
          FactNo('contract'),
          FactConst(false),
          FactTri('witness'),
        ),
        needs: const ['witness'],
        because: const TxRent('claim4_e2_because'),
        ifNo: rentText('claim4_e2_ifNo'),
      ),
    ],
    win: const TxRent('claim4_win'),
    counter: const TxRent('claim4_counter'),
  ),
  Claim.dsl(
    goal: rentText('claim5_goal'),
    when: const FactAny([FactNot(FactHas('matter')), FactEq('matter', 'deposit')]),
    cues: 'ودیعه|پول پیش|رهن|پولم',
    uses: const ['amount'],
    elements: [
      Element.dsl(
        rentText('claim5_e0_text'),
        const FactTri('ended'),
        needs: const ['ended'],
        because: const TxRent('claim5_e0_because'),
        ifNo: rentText('claim5_e0_ifNo'),
      ),
      Element.dsl(
        rentText('claim5_e1_text'),
        const FactTri('vacated'),
        needs: const ['vacated'],
        because: const TxRent('claim5_e1_because'),
        ifNo: rentText('claim5_e1_ifNo'),
      ),
      Element.dsl(
        rentText('claim5_e2_text'),
        const FactTri('contract'),
        needs: const ['contract'],
        because: const TxRent('claim5_e2_because'),
        ifNo: rentText('claim5_e2_ifNo'),
      ),
    ],
    win: const TxRent('claim5_win'),
    counter: const TxRent('claim5_counter'),
  ),
  Claim.dsl(
    goal: rentText('claim6_goal'),
    when: const FactEq('matter', 'raise'),
    cues: 'اجاره|کرایه|زیاد|گرون|بالا|افزایش',
    elements: [
      Element.dsl(
        rentText('claim6_e0_text'),
        _running,
        needs: const ['ended'],
        because: const TxRent('claim6_e0_because'),
        ifNo: rentText('claim6_e0_ifNo'),
      ),
      Element.dsl(
        rentText('claim6_e1_text'),
        const FactTri('contract'),
        needs: const ['contract'],
        because: const TxRent('claim6_e1_because'),
        ifNo: rentText('claim6_e1_ifNo'),
      ),
    ],
    win: const TxRent('claim6_win'),
    counter: const TxRent('claim6_counter'),
  ),
  Claim.dsl(
    goal: rentText('claim7_goal'),
    when: const FactIn('matter', ['evict', 'order']),
    cues: 'بیرون|بلند|تخلیه|بمونم|بمانم|خالی',
    elements: [
      Element.dsl(
        rentText('claim7_e0_text'),
        _running,
        needs: const ['ended'],
        because: const TxRent('claim7_e0_because'),
        ifNo: rentText('claim7_e0_ifNo'),
      ),
      Element.dsl(
        rentText('claim7_e1_text'),
        const FactTriCases([
          FactCase(FactEq('matter', 'order'), FactConst(false)),
          FactCase(FactNo('official'), FactConst(true)),
          FactCase(FactYes('official'), FactConst(false)),
        ]),
        needs: const ['official'],
        because: const TxRent('claim7_e1_because'),
        ifNo: rentText('claim7_e1_ifNo'),
      ),
    ],
    win: const TxRent('claim7_win'),
    counter: const TxRent('claim7_counter'),
  ),
  Claim.dsl(
    goal: rentText('claim8_goal'),
    when: const FactEq('matter', 'repair'),
    cues: 'تعمیر|درست(?:ش)? کن|خراب',
    elements: [
      Element.dsl(
        rentText('claim8_e0_text'),
        const FactTri('told'),
        needs: const ['told'],
        because: const TxRent('claim8_e0_because'),
        ifNo: rentText('claim8_e0_ifNo'),
      ),
      Element.dsl(
        rentText('claim8_e1_text'),
        const FactTri('contract'),
        needs: const ['contract'],
        because: const TxRent('claim8_e1_because'),
        ifNo: rentText('claim8_e1_ifNo'),
      ),
    ],
    win: const TxRent('claim8_win'),
    counter: const TxRent('claim8_counter'),
  ),
  Claim.dsl(
    goal: rentText('claim9_goal'),
    when: const FactEq('matter', 'leave'),
    cues: 'فسخ|بلند|برم|بروم|تخلیه|زودتر',
    elements: [
      Element.dsl(
        rentText('claim9_e0_text'),
        const FactTri('consent'),
        needs: const ['consent'],
        because: const TxRent('claim9_e0_because'),
        ifNo: rentText('claim9_e0_ifNo'),
      ),
    ],
    win: const TxRent('claim9_win'),
    counter: const TxRent('claim9_counter'),
  ),
];

// ============================================================== سندها

const FilingRule _rentFiling0 = FilingSpec(
  'demand_money',
  TxRent('filing0_chip'),
  TxRent('filing0_name'),
);

const FilingRule _rentFiling9 = FilingSpec(
  'defense_brief',
  TxRent('filing9_chip'),
  TxRent('filing9_name'),
);

/// دادخواست (یا نخستین نوشتهٔ رسمی) که به همین وضعیت می‌خورد.
const FilingRule _rentPetition = FilingCases([
  FilingCase(_aUnpaid, _rentFiling0),
  FilingCase(
    _aDamage,
    FilingSpec('demand_money', TxRent('filing1_chip'), TxRent('filing1_name')),
  ),
  FilingCase(
    FactAll([_landlordSide, FactIn('aim', ['evict', 'breach']), _noGround, FactYes('owes')]),
    _rentFiling0,
  ),
  FilingCase(
    FactAll([_landlordSide, FactIn('aim', ['evict', 'breach']), _noGround]),
    null,
  ),
  FilingCase(
    FactAll([_landlordSide, FactIn('aim', ['evict', 'breach'])]),
    FilingSpec('eviction', TxRent('filing2_chip'), TxRent('filing2_name')),
  ),
  FilingCase(
    _mDeposit,
    FilingSpec('demand_money', TxRent('filing3_chip'), TxRent('filing3_name')),
  ),
  FilingCase(
    _mRepair,
    FilingSpec('formal_notice', TxRent('filing4_chip'), TxRent('filing4_name')),
  ),
  FilingCase(
    _mRaise,
    FilingSpec('formal_notice', TxRent('filing5_chip'), TxRent('filing5_name')),
  ),
  FilingCase(
    _mLeave,
    FilingSpec('formal_notice', TxRent('filing6_chip'), TxRent('filing6_name')),
  ),
  FilingCase(
    _mDeliver,
    FilingSpec('formal_notice', TxRent('filing7_chip'), TxRent('filing7_name')),
  ),
  FilingCase(FactAll([_mEvict, FactYes('official')]), null),
  FilingCase(
    _mEvict,
    FilingSpec('formal_notice', TxRent('filing8_chip'), TxRent('filing8_name')),
  ),
]);

/// لایحه‌ای که در پروندهٔ همین دعوا به کار می‌آید.
const FilingRule _rentBrief = FilingCases([
  FilingCase(FactAll([_landlordSide, _noGround, FactYes('owes')]), _rentFiling9),
  FilingCase(FactAll([_landlordSide, _noGround]), null),
  FilingCase(_aUnpaid, _rentFiling9),
  FilingCase(
    _aDamage,
    FilingSpec('defense_brief', TxRent('filing10_chip'), TxRent('filing10_name')),
  ),
  FilingCase(
    _aBreach,
    FilingSpec('defense_brief', TxRent('filing11_chip'), TxRent('filing11_name')),
  ),
  FilingCase(
    _aEvict,
    FilingSpec('defense_brief', TxRent('filing12_chip'), TxRent('filing12_name')),
  ),
  FilingCase(
    FactAll([_isTenantRole, _ordered]),
    FilingSpec('defense_brief', TxRent('filing13_chip'), TxRent('filing13_name')),
  ),
  FilingCase(
    FactAll([_mDeposit, FactCovered('damage')]),
    FilingSpec('defense_brief', TxRent('filing14_chip'), TxRent('filing14_name')),
  ),
  FilingCase(
    _mDeposit,
    FilingSpec('defense_brief', TxRent('filing15_chip'), TxRent('filing15_name')),
  ),
]);
