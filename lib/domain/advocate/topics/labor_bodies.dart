part of 'labor.dart';

// متنِ پاسخ‌ها: پول، خواسته‌ها، طرحِ دعوا و شانس.

const TextExpr _laborMoney = TxCond(
  FactAll([FactHasNum('months'), FactHasNum('salary')]),
  TxConcat([
    Tx('laborMoneySumA'),
    TxRaw(' '),
    TxNum('months', fmt: NumFmt.span),
    TxRaw(' '),
    Tx('laborMoneySumB'),
    TxRaw(' '),
    TxNum('salary'),
    Tx('laborMoneySumC'),
    TxRaw('\n'),
    Tx('laborMoneySumD'),
    TxRaw(' '),
    TxScaleMul('salary', 'months', 1.0, divideFirst: true),
    TxRaw(' '),
    Tx('laborMoneySumE'),
    TxCond(
      laborFiredRule,
      TxConcat([
        TxRaw('\n'),
        Tx('laborMoneyFiredA'),
        TxRaw(' '),
        TxScaleMul('salary', 'months', 1.5, divideFirst: true),
        TxRaw(' '),
        Tx('laborMoneyFiredB'),
        TxRaw('\n'),
        Tx('laborMoneyFiredC'),
      ]),
    ),
    TxRaw('\n'),
    Tx('laborMoneyTail'),
  ]),
  TxConcat([
    Tx('laborMoneyAskA'),
    TxRaw(' '),
    TxCases(
      [
        TextCase(
          FactAll([
            FactNot(FactHasNum('months')),
            FactNot(FactHasNum('salary')),
          ]),
          Tx('laborBod_0'),
        ),
        TextCase(FactNot(FactHasNum('months')), Tx('laborBod_1')),
      ],
      fallback: Tx('laborBod_2'),
    ),
    TxRaw(' '),
    Tx('laborMoneyAskB'),
  ]),
);

final TextExpr _laborPlan = TxConcat([
  const Tx('laborPlanLead'),
  const TxRaw('\n'),
  const TxCond(laborFiredRule, Tx('laborBod_5'), Tx('laborBod_6')),
  const Tx('laborPlanS2'),
  const TxRaw('\n'),
  const Tx('laborPlanS3A'),
  const TxRaw(' '),
  TxAssessDemands(
    claims: laborClaims,
    replaceLabel: const Tx('laborClaimFiredLabel'),
    replacedText: const Tx('laborBod_3'),
    extra: const Tx('laborBod_4'),
    separator: const Tx('laborDemandsSep'),
  ),
  const TxRaw('.\n'),
  const Tx('laborPlanS4'),
  const TxRaw('\n'),
  const Tx('laborPlanS5'),
]);

const TextExpr _laborChance = TxConcat([
  Tx('laborBod_11'),
  TxListJoin(
    prefix: TxConcat([TxRaw('\n'), Tx('laborChancePlusLead'), TxRaw(' ')]),
    separator: Tx('laborChancePlusSep'),
    suffix: TxRaw('.'),
    items: [
      RecapItem(
        when: FactNumMin('months', 12),
        text: TxConcat([
          Tx('laborChanceSpanA'),
          TxRaw(' '),
          TxNum('months', fmt: NumFmt.span),
          TxRaw(' '),
          Tx('laborChanceSpanB'),
        ]),
      ),
      RecapItem(when: FactYes('contract'), text: Tx('laborBod_7')),
      RecapItem(when: FactYes('insured'), text: Tx('laborBod_8')),
    ],
  ),
  TxListJoin(
    prefix: TxConcat([TxRaw('\n'), Tx('laborChanceMinusLead'), TxRaw(' ')]),
    separator: Tx('laborChanceMinusSep'),
    suffix: Tx('laborChanceMinusTail'),
    items: [
      RecapItem(when: FactNo('contract'), text: Tx('laborBod_9')),
      RecapItem(when: FactNo('insured'), text: Tx('laborBod_10')),
    ],
  ),
  TxRaw('\n'),
  Tx('laborChanceTail'),
]);
