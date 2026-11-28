part of 'family.dart';

// برداشتِ وکیل و خواندنِ پاسخ‌ها از متن.

const FactExpr _famIsWife = FactEq('role', 'wife');
const FactExpr _famIsHusband = FactEq('role', 'husband');
const FactExpr _famNotHusband = FactNot(_famIsHusband);

const String _famYearRe = 'سال';
const String _famCoinsRe = 'سکه';

const List<RecapItem> _familyRecap = [
  RecapItem(when: _famIsWife, text: Tx('familyPat_0')),
  RecapItem(when: _famIsHusband, text: Tx('familyPat_1')),
  RecapItem(when: FactYes('violence'), text: Tx('familyPat_2')),
  RecapItem(when: FactEq('proofV', 'medical'), text: Tx('familyPat_3')),
  RecapItem(when: FactEq('proofV', 'witness'), text: Tx('familyPat_4')),
  RecapItem(when: FactEq('proofV', 'none'), text: Tx('familyPat_5')),
  RecapItem(
    when: FactHasNum('childAge'),
    text: TxConcat([
      Tx('familyRecapChildA'),
      TxRaw(' '),
      TxNum('childAge', fmt: NumFmt.fa),
      TxRaw(' '),
      Tx('familyRecapChildB'),
    ]),
  ),
  RecapItem(
    when: FactHasNum('coins'),
    text: TxConcat([
      Tx('familyRecapCoinsA'),
      TxRaw(' '),
      TxNum('coins', fmt: NumFmt.fa),
      TxRaw(' '),
      Tx('familyRecapCoinsB'),
    ]),
  ),
  RecapItem(when: FactYes('agrees'), text: Tx('familyPat_6')),
  RecapItem(when: FactNo('agrees'), text: Tx('familyPat_7')),
];

const ReadRule _famRoleRead = ReadCases([
  ReadCase(
      'من شوهر|شوهرشم|شوهرش هستم|من مرد|زوج (?:ام|هستم)', 'husband'),
  ReadCase(
    'شوهر|آقامون|مهریه ?(?:ام|م|مو) |مهریم|مهریه من|نفقه ?(?:ام|م|مو) |نفقه من|زوجه (?:ام|هستم)|من زن|خانم هستم|مادرشوهر|خواستگار|نامزدم (?:[^ ]+ ){0,5}مهریه',
    'wife',
  ),
  ReadCase(
    'زنم|خانمم|همسرم (?:[^ ]+ ){0,4}(?:مهریه|اجرا|قهر|رفته خونه|تمکین)|مهریه[^ ]* (?:رو |را )?(?:اجرا گذاشت|گذاشته اجرا)|زوج (?:ام|هستم)|من مرد|من شوهر|مادرزن',
    'husband',
  ),
]);

const ReadRule _famViolenceRead = ReadCases([
  ReadCase(
    'کتک|میزنه|منو زد|زد(?:ه)? منو|دست بزن|ضرب و شتم|کبود|خشونت|کتکم|میزندم|کتک میخورم',
    'yes',
  ),
]);

const ReadRule _famChildAgeRead = ReadGuard(
  'بچه|فرزند|پسر|دختر|طفل',
  ReadSeq([
    ReadNumBefore(_famYearRe, min: null, max: 18),
    ReadCases([ReadCase('شیرخوار|نوزاد|چند ماهه', '1')]),
  ]),
);

const ReadRule _famCoinsRead =
    ReadNumBefore(_famCoinsRe, min: null, max: null);
