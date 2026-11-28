part of 'rent.dart';

// اثرِ حقوقیِ واقعیت‌ها در موضوعِ اجاره: چه چیزی از این حرف‌ها نتیجه می‌شود.

const TextExpr _aimEffect = TxCond(
  _landlordSide,
  TxSwitch('aim', {
    'evict': TxRent('effectAimEvict'),
    'unpaid': TxRent('effectAimUnpaid'),
    'damage': TxRent('effectAimDamage'),
    'breach': TxRent('effectAimBreach'),
  }),
);

const TextExpr _endedEffect = TxCases(
  [
    TextCase(
      _ordered,
      TxCond(
        FactYes('ended'),
        TxRent('effectEndedOrderedYes'),
        TxRent('effectEndedOrderedNo'),
      ),
    ),
    TextCase(
      FactYes('ended'),
      TxCases(
        [
          TextCase(_landlordSide, TxRent('effectEndedYesLandlord')),
          TextCase(_rentOtherMatter, TxRent('effectEndedYesOther')),
        ],
        fallback: TxRent('effectEndedYesDeposit'),
      ),
    ),
  ],
  fallback: TxCases(
    [
      TextCase(_landlordSide, TxRent('effectEndedNoLandlord')),
      TextCase(_rentOtherMatter, TxRent('effectEndedNoOther')),
    ],
    fallback: TxRent('effectEndedNoDeposit'),
  ),
);

const TextExpr _contractEffect = TxCond(
  FactYes('contract'),
  TxCond(
    _landlordSide,
    TxCond(
      _evicting,
      TxConcat([
        TxRent('effectContractYesEvict'),
        TxCond(FactYes('ended'), TxRent('effectContractYesEvictReady')),
      ]),
      TxRent('effectContractYesNotEvict'),
    ),
    TxCond(
      _rentDeposit,
      TxRent('effectContractYesTenantDep'),
      TxRent('effectContractYesTenantOther'),
    ),
  ),
  TxCond(
    _landlordSide,
    TxRent('effectContractNoLandlord'),
    TxCond(
      _rentOtherMatter,
      TxRent('effectContractNoTenantOther'),
      TxRent('effectContractNoTenantDep'),
    ),
  ),
);
