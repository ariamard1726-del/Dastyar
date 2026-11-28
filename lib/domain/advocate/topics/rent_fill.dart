part of 'rent.dart';

// متنِ پیشنهادی برای فیلدهای دادخواست و لایحه.
// گزینه‌های فیلدهای انتخابی باید نویسه‌به‌نویسه با قالب یکی باشد.

const List<RecapItem> _fillPapers = [
  RecapItem(when: FactYes('contract'), text: TxRent('fillPaperContract')),
  RecapItem(when: FactYes('witness'), text: TxRent('fillPaperWitness')),
];

const FactExpr _fillBreach = FactAny([
  FactEq('aim', 'breach'),
  FactAll([FactNo('ended'), FactYes('clause')]),
]);

const FactExpr _fillDbMoney = FactAny([
  FactAll([
    _landlordSide,
    FactAny([_noGround, FactEq('aim', 'unpaid'), FactEq('aim', 'damage')]),
  ]),
  FactAll([FactNot(_landlordSide), FactEq('matter', 'deposit')]),
]);

const FillRule _rentFill = FillRule({
  'demand_money': [
    FillAssign(
      'basis',
      TxCond(
        FactYes('contract'),
        TxRent('optDmBasisContract'),
        TxRent('optDmBasisOther'),
      ),
      when: FactHas('contract'),
    ),
    FillAssign(
      'basis_detail',
      TxCases(
        [
          TextCase(_aDamage, TxRent('fillDmDamageDetail')),
          TextCase(_landlordSide, TxRent('fillDmUnpaidDetail')),
        ],
        fallback: TxConcat([
          TxRent('fillDmDepositLead'),
          TxCond(FactYes('ended'), TxRent('fillDmDepositEnded')),
          TxCond(
            FactYes('vacated'),
            TxRent('fillDmDepositVacated'),
            TxCond(FactNo('vacated'), TxRent('fillDmDepositNotVacated')),
          ),
          TxRent('fillDmDepositTail'),
        ]),
      ),
    ),
    FillAssign(
      'evidence',
      TxCases(
        [
          TextCase(
            _aDamage,
            TxListJoin(
              separator: TxRaw('، '),
              items: [
                ..._fillPapers,
                RecapItem(text: TxRent('fillDmDamageEv0')),
                RecapItem(text: TxRent('fillDmDamageEv1')),
                RecapItem(text: TxRent('fillDmDamageEv2')),
              ],
            ),
          ),
          TextCase(
            _landlordSide,
            TxListJoin(
              separator: TxRaw('، '),
              items: [
                ..._fillPapers,
                RecapItem(text: TxRent('fillDmUnpaidEv0')),
                RecapItem(text: TxRent('fillDmUnpaidEv1')),
              ],
            ),
          ),
        ],
        fallback: TxListJoin(
          separator: TxRaw('، '),
          items: [
            ..._fillPapers,
            RecapItem(text: TxRent('fillDmDepositEv0')),
            RecapItem(
              when: FactYes('vacated'),
              text: TxRent('fillDmDepositEv1'),
            ),
            RecapItem(text: TxRent('fillDmDepositEv2')),
          ],
        ),
      ),
    ),
  ],
  'eviction': [
    FillAssign(
      'contract_kind',
      TxCases([
        TextCase(FactNo('contract'), TxRent('optEvKindOral')),
        TextCase(FactYes('witness'), TxRent('optEvKindWitness')),
        TextCase(FactNo('witness'), TxRent('optEvKindNoWitness')),
      ]),
    ),
    FillAssign(
      'ground',
      TxCond(
        _fillBreach,
        TxRent('optEvGroundBreach'),
        TxRent('optEvGroundEnded'),
      ),
    ),
    FillAssign(
      'ground_detail',
      TxCases([
        TextCase(_fillBreach, TxRent('fillEvBreachDetail')),
        TextCase(FactYes('owes'), TxRent('fillEvOwesDetail')),
      ]),
    ),
    FillAssign(
      'evidence',
      TxListJoin(
        separator: TxRaw('، '),
        items: [
          ..._fillPapers,
          RecapItem(text: TxRent('fillEvEv0')),
          RecapItem(when: _fillBreach, text: TxRent('fillEvEv1')),
        ],
      ),
    ),
  ],
  'defense_brief': [
    FillAssign(
      'authority_type',
      TxCond(
        FactAll([_fillDbMoney, _rentSumBig]),
        TxRent('optDbAuthGeneral'),
        TxRent('optDbAuthPeace'),
      ),
    ),
    FillAssign(
      'sender_role',
      TxCond(
        FactAll([
          FactNot(_landlordSide),
          FactAny([_ordered, FactCovered('damage')]),
        ]),
        TxRent('optDbRoleDefendant'),
        TxRent('optDbRolePlaintiff'),
      ),
    ),
    FillAssign(
      'subject',
      TxCases(
        [
          TextCase(
            FactAll([_landlordSide, FactAny([_noGround, FactEq('aim', 'unpaid')])]),
            TxRent('fillDbUnpaidSubject'),
          ),
          TextCase(_aDamage, TxRent('fillDbDamageSubject')),
          TextCase(_aBreach, TxRent('fillDbBreachSubject')),
          TextCase(_landlordSide, TxRent('fillDbEvictSubject')),
          TextCase(_ordered, TxRent('fillDbOrderedSubject')),
          TextCase(FactCovered('damage'), TxRent('fillDbCovDamageSubject')),
        ],
        fallback: TxRent('fillDbDepositSubject'),
      ),
    ),
    FillAssign(
      'merits_defense',
      TxCases(
        [
          TextCase(
            FactAll([_landlordSide, FactAny([_noGround, FactEq('aim', 'unpaid')])]),
            TxRent('fillDbUnpaidDefense'),
          ),
          TextCase(_aDamage, TxRent('fillDbDamageDefense')),
          TextCase(_aBreach, TxRent('fillDbBreachDefense')),
          TextCase(_landlordSide, TxRent('fillDbEvictDefense')),
          TextCase(
            _ordered,
            TxConcat([
              TxCond(FactNo('ended'), TxRent('fillDbOrderedNotEnded')),
              TxRent('fillDbOrderedTail'),
            ]),
          ),
          TextCase(FactCovered('damage'), TxRent('fillDbCovDamageDefense')),
        ],
        fallback: TxConcat([
          TxCond(FactYes('ended'), TxRent('fillDbDepositEnded')),
          TxCond(FactYes('vacated'), TxRent('fillDbDepositVacated')),
          TxRent('fillDbDepositTail'),
        ]),
      ),
    ),
    FillAssign(
      'attachments',
      TxListJoin(
        separator: TxRaw('، '),
        items: [
          ..._fillPapers,
          RecapItem(
            when: FactNot(_landlordSide),
            text: TxRent('fillDbAttDeposit'),
          ),
          RecapItem(when: _ordered, text: TxRent('fillDbAttOrdered')),
        ],
      ),
    ),
  ],
  'formal_notice': [
    FillAssign('deadline_days', TxRaw('7')),
    FillAssign(
      'topic',
      TxCond(
        _landlordSide,
        TxCond(
          FactIn('aim', ['unpaid', 'damage']),
          TxRent('optFnTopicMoney'),
          TxRent('optFnTopicDeposit'),
        ),
        TxCond(
          FactIn('matter', ['deposit', 'leave']),
          TxRent('optFnTopicDeposit'),
          TxRent('optFnTopicOther'),
        ),
      ),
    ),
    FillAssign(
      'statement_body',
      TxCond(
        _landlordSide,
        TxSwitch(
          'aim',
          {
            'unpaid': TxRent('fillFnUnpaid'),
            'breach': TxRent('fillFnBreach'),
            'damage': TxRent('fillFnDamage'),
          },
          fallback: TxRent('fillFnDefault'),
        ),
        TxSwitch(
          'matter',
          {
            'repair': TxRent('fillFnRepair'),
            'raise': TxRent('fillFnRaise'),
            'leave': TxRent('fillFnLeave'),
            'deliver': TxRent('fillFnDeliver'),
            'evict': TxRent('fillFnEvict'),
          },
          fallback: TxCond(
            FactYes('vacated'),
            TxRent('fillFnDepVacated'),
            TxRent('fillFnDepNotVacated'),
          ),
        ),
      ),
    ),
  ],
});
