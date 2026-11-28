part of 'family.dart';

// ادعاهای حقوقیِ خانواده: ارکان، شرط و نتیجه.

final List<Claim> familyClaims = [
  Claim.dsl(
    goal: topicText('familyClm_0'),
    when: const FactAll([_famIsWife, FactNot(FactYes('agrees'))]),
    elements: [
      Element.dsl(
        topicText('familyClm_1'),
        const FactTriIf(FactYes('violence'), true),
        needs: const ['violence'],
        because: const Tx('familyClm_2'),
      ),
      Element.dsl(
        topicText('familyClm_3'),
        const FactTriWhen(
          FactHas('proofV'),
          FactNot(FactEq('proofV', 'none')),
        ),
        needs: const ['proofV'],
        because: const TxCond(
          FactEq('proofV', 'medical'),
          Tx('familyClm_4'),
          Tx('familyClm_5'),
        ),
        ifNo: topicText('familyClm_6'),
      ),
    ],
    win: const Tx('familyClm_7'),
    counter: const Tx('familyClm_8'),
  ),
];
