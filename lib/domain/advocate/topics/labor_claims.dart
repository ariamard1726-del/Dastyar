part of 'labor.dart';

// ادعاهای حقوقیِ کار و کارفرما: ارکان، شرط و نتیجه.

final Element _laborRel = Element.dsl(
  topicText('laborClm_0'),
  const FactTriCases([
    FactCase(
      FactAny([FactYes('contract'), FactYes('insured'), FactYes('proof')]),
      FactConst(true),
    ),
    FactCase(
      FactAll([FactNo('contract'), FactNo('insured'), FactNo('proof')]),
      FactConst(false),
    ),
  ]),
  needs: const ['contract', 'insured', 'proof'],
  because: const TxCases([
    TextCase(FactYes('contract'), Tx('laborClm_1')),
    TextCase(FactYes('insured'), Tx('laborClm_2')),
    TextCase(FactYes('proof'), Tx('laborClm_3')),
  ]),
  ifNo: topicText('laborClm_4'),
);

const FactExpr _laborUnsignedTest = FactTriCases([
  FactCase(FactNo('signed'), FactConst(true)),
  FactCase(FactYes('signed'), FactConst(false)),
]);

/// ادعاهای کارگر، به ترتیب اهمیت. هر کدام فقط وقتی روی میز می‌آید که
/// واقعیت‌های پرونده آن را پیش کشیده باشد؛ یک ماجرا می‌تواند چند ادعا داشته
/// باشد (اخراج + حقوق معوق + سنوات + بیمه).
final List<Claim> laborClaims = [
  Claim.dsl(
    label: topicText('laborClaimFiredLabel'),
    goal: topicText('laborClm_6'),
    cues:
        'برگرد(?:م|ی)? سر کار|برمیگرد(?:م|ی)? سر کار|بازگشت به کار|اخراج(?:م|ش)? (?:[^ ]+ ){0,2}(?:قانونی|غیر ?قانونی|درست|ناموجه|موجه)|حق (?:داشت|داره|دارد|داشته) (?:[^ ]+ ){0,2}اخراج|میتون(?:ه|ست|د) (?:[^ ]+ ){0,2}اخراج|خسارت اخراج',
    when: laborFiredRule,
    uses: const ['months', 'salary'],
    elements: [
      _laborRel,
      Element.dsl(
        topicText('laborClm_7'),
        _laborUnsignedTest,
        needs: const ['signed'],
        because: const Tx('laborClm_5'),
        ifNo: topicText('laborClm_8'),
      ),
      Element.dsl(
        topicText('laborClm_9'),
        const FactTriCases([
          FactCase(
            FactAny([FactNo('contract'), FactNo('expired')]),
            FactConst(true),
          ),
          FactCase(FactYes('expired'), FactConst(false)),
        ]),
        needs: const ['contract', 'expired'],
        because: const TxCond(
          FactNo('expired'),
          Tx('laborClm_10'),
          Tx('laborClm_11'),
        ),
        ifNo: topicText('laborClm_12'),
      ),
      Element.dsl(
        topicText('laborClm_13'),
        const FactTriCases([
          FactCase(FactNo('warned'), FactConst(true)),
          FactCase(FactYes('warned'), FactConst(false)),
        ]),
        needs: const ['warned'],
        because: const Tx('laborClm_14'),
        ifNo: topicText('laborClm_15'),
      ),
    ],
    win: const Tx('laborClm_16'),
    counter: const Tx('laborClm_17'),
  ),
  Claim.dsl(
    label: topicText('laborClm_18'),
    goal: topicText('laborClm_19'),
    cues: 'حقوق[^ ]* (?:[^ ]+ ){0,3}(?:بگیرم|میگیرم|گرفت|وصول|میرسه|میدن)',
    when: const FactAny([FactEq('event', 'unpaid'), FactYes('owed')]),
    uses: const ['salary'],
    elements: [
      _laborRel,
      Element.dsl(
        topicText('laborClm_20'),
        _laborUnsignedTest,
        needs: const ['signed'],
        because: const Tx('laborClm_5'),
        ifNo: topicText('laborClm_21'),
      ),
    ],
    win: const Tx('laborClm_22'),
    counter: const Tx('laborClm_23'),
  ),
  Claim.dsl(
    label: topicText('laborClm_24'),
    goal: topicText('laborClm_25'),
    cues: 'سنوات|مزایای پایان کار',
    uses: const ['salary'],
    elements: [
      _laborRel,
      Element.dsl(
        topicText('laborClm_26'),
        const FactTriCases([
          FactCase(
            FactAny([laborFiredRule, FactNo('working')]),
            FactConst(true),
          ),
          FactCase(FactYes('working'), FactConst(false)),
        ]),
        needs: const ['working'],
        because: const Tx('laborClm_27'),
        ifNo: topicText('laborClm_28'),
      ),
      Element.dsl(
        topicText('laborClm_29'),
        const FactNumMin('months', 12),
        needs: const ['months'],
        because: const TxConcat([
          TxNum('months', fmt: NumFmt.span, defaultZero: true),
          TxRaw(' '),
          Tx('laborClaimMonthsBecause'),
        ]),
        ifNo: topicText('laborClm_30'),
      ),
    ],
    win: const Tx('laborClm_31'),
    counter: const Tx('laborClm_32'),
  ),
  Claim.dsl(
    label: topicText('laborClm_33'),
    goal: topicText('laborClm_34'),
    cues: 'بیمه',
    when: const FactNot(FactYes('insured')),
    elements: [
      _laborRel,
      Element.dsl(
        topicText('laborClm_35'),
        const FactTriIf(
          FactAny([FactNo('insured'), FactEq('event', 'insurance')]),
          true,
        ),
        needs: const ['insured'],
        because: const Tx('laborClm_36'),
      ),
    ],
    win: const Tx('laborClm_37'),
    counter: const Tx('laborClm_38'),
  ),
];
