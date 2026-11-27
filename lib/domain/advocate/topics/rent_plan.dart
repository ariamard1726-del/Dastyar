part of 'rent.dart';

// نقشهٔ راه: طرحِ دعوا، مدرک، شانس، مهلت و جمع‌بندی.

const TextExpr _rentPlan = TxCases(
  [
    TextCase(_aUnpaid, TxConcat([TxRent('plan0'), _rentSumForum])),
    TextCase(_aDamage, TxConcat([TxRent('plan1'), _rentSumForum])),
    TextCase(_aBreach, TxRent('plan2')),
    TextCase(FactAll([_landlordSide, FactNo('ended')]), TxRent('plan3')),
    TextCase(_landlordSide, TxRent('plan4')),
    TextCase(FactEq('matter', 'raise'), TxRent('plan5')),
    TextCase(_ordered, TxRent('plan6')),
    TextCase(FactEq('matter', 'evict'), TxRent('plan7')),
    TextCase(
      FactEq('matter', 'deliver'),
      TxConcat([TxRent('plan8'), _rentPeace]),
    ),
    TextCase(FactEq('matter', 'repair'), TxRent('plan9')),
    TextCase(FactEq('matter', 'leave'), TxRent('plan10')),
    TextCase(FactNo('vacated'), TxRent('plan11')),
  ],
  fallback: TxConcat([TxRent('plan12'), _rentSumForum]),
);

const TextExpr _rentEvidence = TxCases(
  [
    TextCase(_landlordSide, TxRent('plan30')),
    TextCase(FactNot(_rentDeposit), TxRent('plan31')),
  ],
  fallback: TxConcat([
    TxRent('plan32'),
    TxCond(FactConst(false), TxRent('plan33')),
  ]),
);

const FactExpr _chanceHasPlus = FactAny([
  FactYes('vacated'),
  FactYes('ended'),
  FactYes('contract'),
]);

const FactExpr _chanceHasMinus = FactAny([
  FactNo('contract'),
  FactNo('ended'),
  FactCovered('damage'),
]);

const TextExpr _rentChance = TxCases(
  [
    TextCase(_aUnpaid, TxConcat([TxRent('planLead'), TxRent('plan19')])),
    TextCase(_aDamage, TxConcat([TxRent('planLead'), TxRent('plan20')])),
    TextCase(_aBreach, TxConcat([TxRent('planLead'), TxRent('plan21')])),
    TextCase(_landlordSide, TxConcat([TxRent('planLead'), TxRent('plan22')])),
    TextCase(
      FactEq('matter', 'raise'),
      TxConcat([TxRent('planLead'), TxRent('plan23')]),
    ),
    TextCase(_ordered, TxConcat([TxRent('planLead'), TxRent('plan24')])),
    TextCase(
      FactEq('matter', 'evict'),
      TxConcat([TxRent('planLead'), TxRent('plan25')]),
    ),
    TextCase(
      FactEq('matter', 'deliver'),
      TxConcat([TxRent('planLead'), TxRent('plan26')]),
    ),
    TextCase(
      FactEq('matter', 'repair'),
      TxConcat([TxRent('planLead'), TxRent('plan27')]),
    ),
    TextCase(
      FactEq('matter', 'leave'),
      TxConcat([TxRent('planLead'), TxRent('plan28')]),
    ),
  ],
  fallback: TxConcat([
    TxRent('recapChanceBase'),
    TxListJoin(
      prefix: TxConcat([TxRaw('\n'), TxRent('recapChancePlus'), TxRaw(' ')]),
      separator: TxRent('recapChanceSep'),
      suffix: TxRaw('.'),
      items: [
        RecapItem(
          when: FactYes('vacated'),
          text: TxRent('recapChanceVacated'),
        ),
        RecapItem(when: FactYes('ended'), text: TxRent('recapChanceEnded')),
        RecapItem(
          when: FactYes('contract'),
          text: TxRent('recapChanceContract'),
        ),
      ],
    ),
    TxListJoin(
      prefix: TxConcat([TxRaw('\n'), TxRent('recapChanceMinus'), TxRaw(' ')]),
      separator: TxRent('recapChanceSep'),
      suffix: TxRaw('.'),
      items: [
        RecapItem(
          when: FactNo('contract'),
          text: TxRent('recapChanceNoContract'),
        ),
        RecapItem(
          when: FactNo('ended'),
          text: TxRent('recapChanceNotEnded'),
        ),
        RecapItem(
          when: FactCovered('damage'),
          text: TxRent('recapChanceDamage'),
        ),
      ],
    ),
    TxCond(
      FactAll([FactNot(_chanceHasPlus), FactNot(_chanceHasMinus)]),
      TxConcat([TxRaw('\n'), TxRent('recapChanceNeutral')]),
    ),
  ]),
);

const TextExpr _rentWhere = TxCases(
  [
    TextCase(FactAny([_aUnpaid, _aDamage]), _rentSumForum),
    TextCase(_landlordSide, TxRent('recapWhereLandlordEvict')),
    TextCase(
      FactAll([_shop, FactCovered('goodwill')]),
      TxRent('recapWhereGoodwill'),
    ),
  ],
  fallback: TxCond(_rentDeposit, TxForum('amount'), _rentPeace),
);

const TextExpr _rentDeadline = TxCases(
  [
    TextCase(_ordered, TxRent('plan13')),
    TextCase(_landlordSide, TxRent('plan14')),
  ],
  fallback: TxRent('plan15'),
);

const TextExpr _rentRefuse = TxCases(
  [
    TextCase(FactAny([_aUnpaid, _aDamage]), TxRent('plan16')),
    TextCase(_landlordSide, TxRent('plan17')),
    TextCase(
      FactNot(_rentDeposit),
      TxConcat([TxRent('plan34_a'), _rentPeace, TxRent('plan34_b')]),
    ),
  ],
  fallback: TxRent('plan18'),
);

// ============================================================ برداشت وکیل

const List<RecapItem> _rentRecap = [
  RecapItem(when: _landlordSide, text: TxRent('recapLandlord')),
  RecapItem(when: _isTenantRole, text: TxRent('recapTenant')),
  RecapItem(when: _shop, text: TxRent('recapShop')),
  RecapItem(when: _mDeposit, text: TxRent('recapMatterDeposit')),
  RecapItem(when: _mRaise, text: TxRent('recapMatterRaise')),
  RecapItem(when: _mEvict, text: TxRent('recapMatterEvict')),
  RecapItem(when: _mOrder, text: TxRent('recapMatterOrder')),
  RecapItem(when: _mRepair, text: TxRent('recapMatterRepair')),
  RecapItem(when: _mLeave, text: TxRent('recapMatterLeave')),
  RecapItem(when: _mDeliver, text: TxRent('recapMatterDeliver')),
  RecapItem(
    when: FactAll([_mEvict, FactYes('official')]),
    text: TxRent('recapOfficialYes'),
  ),
  RecapItem(
    when: FactAll([_mEvict, FactNo('official')]),
    text: TxRent('recapOfficialNo'),
  ),
  RecapItem(when: _aEvict, text: TxRent('recapAimEvict')),
  RecapItem(
    when: FactAll([_aEvict, FactYes('owes')]),
    text: TxRent('recapAimEvictOwes'),
  ),
  RecapItem(when: _aUnpaid, text: TxRent('recapAimUnpaid')),
  RecapItem(when: _aDamage, text: TxRent('recapAimDamage')),
  RecapItem(when: _aBreach, text: TxRent('recapAimBreach')),
  RecapItem(when: FactYes('ended'), text: TxRent('recapEndedYes')),
  RecapItem(when: FactNo('ended'), text: TxRent('recapEndedNo')),
  RecapItem(
    when: FactAll([FactNot(_landlordSide), FactYes('vacated')]),
    text: TxRent('recapVacatedYes'),
  ),
  RecapItem(
    when: FactAll([FactNot(_landlordSide), FactNo('vacated')]),
    text: TxRent('recapVacatedNo'),
  ),
  RecapItem(
    when: FactAll([FactNot(_landlordSide), FactHasNum('amount')]),
    text: TxConcat([
      TxRent('recapAmountPrefix'),
      TxRaw(' '),
      TxNum('amount'),
      TxRaw(' '),
      TxRent('recapAmountSuffix'),
    ]),
  ),
  RecapItem(
    when: FactAll([
      _landlordSide,
      FactAny([FactHasNum('due'), FactHasNum('amount')]),
    ]),
    text: TxConcat([
      TxRent('recapSumPrefix'),
      TxRaw(' '),
      TxCond(FactHasNum('due'), TxNum('due'), TxNum('amount')),
      TxRaw(' '),
      TxRent('recapSumSuffix'),
    ]),
  ),
  RecapItem(when: FactYes('contract'), text: TxRent('recapContractYes')),
  RecapItem(when: FactNo('contract'), text: TxRent('recapContractNo')),
  RecapItem(
    when: FactAll([_landlordSide, FactYes('witness')]),
    text: TxRent('recapWitnessYes'),
  ),
  RecapItem(
    when: FactAll([_landlordSide, FactNo('witness')]),
    text: TxRent('recapWitnessNo'),
  ),
  RecapItem(
    when: FactAll([_landlordSide, FactYes('clause')]),
    text: TxRent('recapClauseYes'),
  ),
  RecapItem(
    when: FactAll([_landlordSide, FactNo('clause')]),
    text: TxRent('recapClauseNo'),
  ),
  RecapItem(
    when: FactAll([_landlordSide, FactHas('aim'), FactYes('proof')]),
    text: TxRent('recapProofYes'),
  ),
  RecapItem(
    when: FactAll([_landlordSide, FactHas('aim'), FactNo('proof')]),
    text: TxRent('recapProofNo'),
  ),
  RecapItem(
    when: FactAll([_mRepair, FactYes('told')]),
    text: TxRent('recapToldYes'),
  ),
  RecapItem(
    when: FactAll([_mRepair, FactNo('told')]),
    text: TxRent('recapToldNo'),
  ),
  RecapItem(
    when: FactAll([_mLeave, FactYes('consent')]),
    text: TxRent('recapConsentYes'),
  ),
  RecapItem(
    when: FactAll([_mLeave, FactNo('consent')]),
    text: TxRent('recapConsentNo'),
  ),
];
