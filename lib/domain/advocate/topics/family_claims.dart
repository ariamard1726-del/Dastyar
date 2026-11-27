part of 'family.dart';

// ادعاهای حقوقیِ خانواده: ارکان، شرط و نتیجه.

final List<Claim> familyClaims = [
  Claim(
    goal: topicText('familyClm_0'),
    when: (f) => f.eq('role', 'wife') && !f.yes('agrees'),
    elements: [
      Element(
        topicText('familyClm_1'),
        (f) => f.yes('violence') ? true : null,
        needs: const ['violence'],
        because: (f) => topicText('familyClm_2'),
      ),
      Element(
        topicText('familyClm_3'),
        (f) => f.has('proofV') ? !f.eq('proofV', 'none') : null,
        needs: const ['proofV'],
        because: (f) => f.eq('proofV', 'medical')
            ? topicText('familyClm_4')
            : topicText('familyClm_5'),
        ifNo:
            topicText('familyClm_6'),
      ),
    ],
    win: (f) =>
        topicText('familyClm_7'),
    counter: (f) =>
        topicText('familyClm_8'),
  ),
];
