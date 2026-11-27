part of 'rent.dart';

// متن‌های سمتِ موجر: تخلیه، سرقفلی، فروشِ ملک، فوتِ موجر، تغییرِ کاربری و…

const TextExpr _rentSubletBody = TxCond(
  _landlordSide,
  TxRent('bodySubletLandlord'),
  TxRent('bodySubletTenant'),
);

const TextExpr _rentSoldBody = TxCond(
  _landlordSide,
  TxRent('bodySoldLandlord'),
  TxRent('bodySoldTenant'),
);

const TextExpr _rentDeathBody = TxConcat([
  TxRent('bodyDeathBase'),
  TxCond(
    _landlordSide,
    TxRent('bodyDeathLandlord'),
    TxRent('bodyDeathTenant'),
  ),
]);

const TextExpr _rentGoodwillBody = TxRent('rentGoodwillBody');

const TextExpr _rentUsageBody = TxConcat([
  TxRent('bodyUsageBase'),
  TxCond(
    _landlordSide,
    TxRent('bodyUsageLandlord'),
    TxRent('bodyUsageTenant'),
  ),
]);

const TextExpr _rentCodeBody = TxRent('rentCodeBody');
const TextExpr _rentSelfHelpBody = TxRent('rentSelfHelpBody');
const TextExpr _rentLandlordDepositBody = TxRent('rentLandlordDepositBody');
const TextExpr _rentLandlordDamageBody = TxRent('rentLandlordDamageBody');
const TextExpr _rentLandlordRaiseBody = TxRent('rentLandlordRaiseBody');
const TextExpr _rentLandlordBillsBody = TxRent('rentLandlordBillsBody');
const TextExpr _rentMisuseBody = TxRent('rentMisuseBody');
const TextExpr _rentObjectBody = TxRent('rentObjectBody');
const TextExpr _rentWaitNewBody = TxRent('rentWaitNewBody');

const TextExpr _rentSilentBody = TxCond(
  _landlordSide,
  TxConcat([
    TxRent('bodySilentLandlordA'),
    TxCond(FactNo('ended'), TxRaw(''), TxRent('bodySilentLandlordOrder')),
    TxRent('bodySilentLandlordB'),
  ]),
  TxConcat([
    TxRent('bodySilentTenantA'),
    TxCond(FactNo('vacated'), TxRent('bodySilentTenantKey')),
    TxRent('bodySilentTenantB'),
  ]),
);

const TextExpr _rentOwnUseBody = TxCases(
  [
    TextCase(
      FactNo('ended'),
      TxConcat([
        TxRent('bodyOwnUseLead'),
        TxRaw(' '),
        _rentBeforeEnd,
        TxRaw('\n'),
        TxRent('bodyOwnUseDeal'),
      ]),
    ),
    TextCase(
      FactYes('ended'),
      TxConcat([TxRent('bodyOwnUseEnded'), _rentAfterEnd]),
    ),
  ],
  fallback: TxConcat([
    TxRent('bodyOwnUseLead'),
    TxRent('bodyOwnUseMid1'),
    _rentBeforeEnd,
    TxRent('bodyOwnUseMid2'),
    _rentAfterEnd,
    TxRaw('\n'),
    TxRent('bodyOwnUseDeal'),
  ]),
);

const TextExpr _rentNoReasonBody = TxCases(
  [
    TextCase(
      FactNo('ended'),
      TxConcat([
        TxRent('bodyNoReasonBefore'),
        _rentBeforeEnd,
        TxRaw('\n'),
        TxRent('bodyNoReasonAsk'),
      ]),
    ),
    TextCase(
      FactYes('ended'),
      TxConcat([TxRent('bodyNoReasonEnded'), _rentAfterEnd]),
    ),
  ],
  fallback: TxConcat([
    TxRent('bodyNoReasonMid1'),
    _rentBeforeEnd,
    TxRent('bodyNoReasonMid2'),
    _rentAfterEnd,
    TxRaw('\n'),
    TxRent('bodyNoReasonAsk'),
  ]),
);

const TextExpr _rentNoTermBody = TxConcat([
  TxRent('bodyNoTermBase'),
  TxCond(
    _landlordSide,
    TxRent('bodyNoTermLandlord'),
    TxRent('bodyNoTermTenant'),
  ),
]);

const TextExpr _rentLandlordNoPlaceBody = TxCond(
  FactNo('ended'),
  TxRent('bodyLandlordNoPlaceNotEnded'),
  TxRent('bodyLandlordNoPlaceEnded'),
);

const TextExpr _rentLandlordDepFirstBody = TxRent('rentLandlordDepFirstBody');
const TextExpr _rentLandlordOffsetBody = TxRent('rentLandlordOffsetBody');
const TextExpr _rentLandlordRenewedBody = TxRent('rentLandlordRenewedBody');
const TextExpr _rentLandlordWearBody = TxRent('rentLandlordWearBody');
const TextExpr _rentLandlordCantPayBody = TxRent('rentLandlordCantPayBody');
const TextExpr _rentLandlordPaidBody = TxRent('rentLandlordPaidBody');
const TextExpr _rentLandlordBuiltBody = TxRent('rentLandlordBuiltBody');
const TextExpr _rentLandlordGuarantorBody =
    TxRent('rentLandlordGuarantorBody');
