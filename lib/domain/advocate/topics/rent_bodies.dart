part of 'rent.dart';

// متنِ پاسخِ موضوع‌های اجاره — سمتِ مستأجر و متن‌های مشترک.

const TextExpr _rentPeace = TxRent('rentPeace');
const TextExpr _rentDepositLaw = TxRent('rentDepositLaw');

const TextExpr _rentRaiseBody = TxCases(
  [
    TextCase(
      FactNo('ended'),
      TxConcat([TxRent('bodyRaiseBase'), TxRent('bodyRaiseRet00')]),
    ),
    TextCase(
      FactYes('ended'),
      TxConcat([
        TxRent('bodyRaiseRet10'),
        TxRent('bodyRaiseAfter'),
        TxRent('bodyRaiseRet11'),
      ]),
    ),
  ],
  fallback: TxConcat([
    TxRent('bodyRaiseBase'),
    TxRent('bodyRaiseRet20'),
    TxRent('bodyRaiseAfter'),
  ]),
);

const TextExpr _rentRepairBody = TxRent('rentRepairBody');

const TextExpr _rentDamageBody = TxConcat([
  TxRent('bodyDamageRet0'),
  TxCond(
    FactYes('vacated'),
    TxRent('bodyDamageVacated'),
    TxRent('bodyDamageAccess'),
  ),
]);

const TextExpr _rentEvictBody = TxRent('rentEvictBody');

const TextExpr _rentOrderBody = TxConcat([
  TxCond(
    FactNo('ended'),
    TxRent('bodyOrderNotEnded'),
    TxRent('bodyOrderEnded'),
  ),
  TxRent('bodyOrderRet0'),
]);

const TextExpr _rentOrderDepositBody = TxRent('rentOrderDepositBody');
const TextExpr _rentAccessBody = TxRent('rentAccessBody');
const TextExpr _rentSelfRepairBody = TxRent('rentSelfRepairBody');
const TextExpr _rentDefectBody = TxRent('rentDefectBody');
const TextExpr _rentGuaranteeBody = TxRent('rentGuaranteeBody');
const TextExpr _rentBillsBody = TxRent('rentBillsBody');
const TextExpr _rentLateBody = TxRent('rentLateBody');
const TextExpr _rentLeaveBody = TxRent('rentLeaveBody');
const TextExpr _rentRenewBody = TxRent('rentRenewBody');
const TextExpr _rentHandoverBody = TxRent('rentHandoverBody');

const TextExpr _rentUnpaidBody = TxCond(
  FactEq('aim', 'evict'),
  TxRent('bodyUnpaidEvict'),
  TxRent('bodyUnpaidOther'),
);

const TextExpr _rentEarlyBody = TxRent('rentEarlyBody');
const TextExpr _rentGoneBody = TxRent('rentGoneBody');

const TextExpr _rentNoMoneyBody = TxConcat([
  TxRent('bodyNoMoneyLead'),
  TxCond(FactYes('vacated'), TxRaw(''), TxRent('bodyNoMoneyKey')),
]);

const TextExpr _rentBeforeEnd = TxRent('rentBeforeEnd');
const TextExpr _rentAfterEnd = TxRent('rentAfterEnd');
const TextExpr _rentFixSelfBody = TxRent('rentFixSelfBody');
const TextExpr _rentBlameBody = TxRent('rentBlameBody');
const TextExpr _rentImproveBody = TxRent('rentImproveBody');
const TextExpr _rentPartialBody = TxRent('rentPartialBody');
const TextExpr _rentDeliverBody = TxRent('rentDeliverBody');
const TextExpr _rentThirdBody = TxRent('rentThirdBody');

const TextExpr _rentPenaltyBody = TxConcat([
  TxRent('bodyPenaltyBase'),
  TxCond(
    _landlordSide,
    TxRent('bodyPenaltyLandlord'),
    TxRent('bodyPenaltyTenant'),
  ),
  TxRent('bodyPenaltyNone'),
]);

const PromptRule _rentAskReply = PromptCases([
  PromptCase(_ordered, PromptNone()),
  PromptCase(
    FactAll([_isTenantRole, FactEq('matter', 'deposit')]),
    PromptSpec(
      TxRent('promptTenantDepositQ'),
      [
        TxRent('promptTenantDepositC0'),
        TxRent('promptTenantDepositC1'),
        TxRent('promptTenantDepositC2'),
        TxRent('promptTenantDepositC3'),
      ],
    ),
  ),
  PromptCase(
    FactAll([_isTenantRole, FactEq('matter', 'evict')]),
    PromptSpec(
      TxRent('promptTenantEvictQ'),
      [
        TxRent('promptTenantEvictC0'),
        TxRent('promptTenantEvictC1'),
        TxRent('promptTenantEvictC2'),
        TxRent('promptTenantEvictC3'),
      ],
    ),
  ),
  PromptCase(
    FactAll([_isTenantRole, FactEq('matter', 'repair')]),
    PromptSpec(
      TxRent('promptTenantRepairQ'),
      [
        TxRent('promptTenantRepairC0'),
        TxRent('promptTenantRepairC1'),
        TxRent('promptTenantRepairC2'),
      ],
    ),
  ),
  PromptCase(
    FactAll([_isTenantRole, FactIn('matter', ['raise', 'leave'])]),
    PromptNone(),
  ),
  PromptCase(_isTenantRole, null),
  PromptCase(
    FactEq('aim', 'evict'),
    PromptSpec(
      TxRent('promptLandlordEvictQ'),
      [
        TxRent('promptLandlordEvictC0'),
        TxRent('promptLandlordEvictC1'),
        TxRent('promptLandlordEvictC2'),
        TxRent('promptLandlordEvictC3'),
      ],
    ),
  ),
  PromptCase(
    FactEq('aim', 'unpaid'),
    PromptSpec(
      TxRent('promptLandlordUnpaidQ'),
      [
        TxRent('promptLandlordUnpaidC0'),
        TxRent('promptLandlordUnpaidC1'),
        TxRent('promptLandlordUnpaidC2'),
        TxRent('promptLandlordUnpaidC3'),
      ],
    ),
  ),
  PromptCase(
    FactEq('aim', 'damage'),
    PromptSpec(
      TxRent('promptLandlordDamageQ'),
      [
        TxRent('promptLandlordDamageC0'),
        TxRent('promptLandlordDamageC1'),
        TxRent('promptLandlordDamageC2'),
      ],
    ),
  ),
]);
