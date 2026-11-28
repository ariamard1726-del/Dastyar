part of 'family.dart';

// متنِ پاسخ‌ها: ایمنی، مهریه، حضانت و طلاق.

const TextExpr _famSafety = TxConcat([
  Tx('familySafetyTopA'),
  TxCond(
    FactHas('childAge'),
    TxConcat([TxRaw(' '), Tx('familySafetyChild')]),
  ),
  TxRaw(' '),
  Tx('familySafetyTopB'),
  TxRaw('\n'),
  Tx('familySafetyRest'),
]);

const TextExpr _famMehr = TxCond(
  _famIsHusband,
  Tx('familyBod_0'),
  TxConcat([
    Tx('familyBod_1'),
    TxCond(
      FactHasNum('coins'),
      TxCond(
        FactNumMin('coins', 111, missingNull: false),
        TxConcat([
          TxRaw('\n'),
          Tx('familyMehrOverA'),
          TxRaw(' '),
          TxNum('coins', fmt: NumFmt.fa),
          TxRaw(' '),
          Tx('familyMehrOverB'),
          TxRaw(' '),
          TxNumOffset('coins', -110),
          TxRaw(' '),
          Tx('familyMehrOverC'),
        ]),
        TxConcat([
          TxRaw('\n'),
          Tx('familyMehrUnderA'),
          TxRaw(' '),
          TxNum('coins', fmt: NumFmt.fa),
          TxRaw(' '),
          Tx('familyMehrUnderB'),
        ]),
      ),
    ),
  ]),
);

const TextExpr _famCustody = TxConcat([
  TxCases(
    [
      TextCase(
        FactAll([FactHasNum('childAge'), FactNumMax('childAge', 6)]),
        TxConcat([
          Tx('familyCustYoungA'),
          TxRaw(' '),
          TxNum('childAge', fmt: NumFmt.fa),
          TxRaw(' '),
          Tx('familyCustYoungB'),
          TxRaw(' '),
          TxCond(_famIsHusband, Tx('familyCustMother'), Tx('familyCustYou')),
          TxRaw(' '),
          Tx('familyCustEst'),
        ]),
      ),
      TextCase(
        FactHasNum('childAge'),
        TxConcat([
          Tx('familyCustYoungA'),
          TxRaw(' '),
          TxNum('childAge', fmt: NumFmt.fa),
          TxRaw(' '),
          Tx('familyCustOldB'),
        ]),
      ),
    ],
    fallback: Tx('familyBod_2'),
  ),
  Tx('familyBod_3'),
  TxCond(
    FactAll([FactYes('violence'), _famNotHusband]),
    Tx('familyBod_4'),
  ),
]);

const TextExpr _famDivorce = TxCond(
  _famIsHusband,
  Tx('familyBod_5'),
  TxConcat([
    Tx('familyDivorceWays'),
    TxRaw('\n'),
    TxCond(
      FactYes('violence'),
      Tx('familyDivorceVYes'),
      Tx('familyDivorceVNo'),
    ),
  ]),
);
