part of 'family.dart';

// برداشتِ وکیل و خواندنِ پاسخ‌ها از متن.

// ---- برداشت وکیل و ادعاها

List<String> familyRecap(CaseFile f) => [
      if (f.eq('role', 'wife')) topicText('familyPat_0'),
      if (f.eq('role', 'husband')) topicText('familyPat_1'),
      if (f.yes('violence')) topicText('familyPat_2'),
      if (f.eq('proofV', 'medical')) topicText('familyPat_3'),
      if (f.eq('proofV', 'witness')) topicText('familyPat_4'),
      if (f.eq('proofV', 'none')) topicText('familyPat_5'),
      if (f.n('childAge') != null) topicText('familyRecapChildA') + ' ' + Sense.fa(f.n('childAge')!) + ' ' + topicText('familyRecapChildB'),
      if (f.n('coins') != null) topicText('familyRecapCoinsA') + ' ' + Sense.fa(f.n('coins')!) + ' ' + topicText('familyRecapCoinsB'),
      if (f.yes('agrees')) topicText('familyPat_6'),
      if (f.no('agrees')) topicText('familyPat_7'),
    ];

// متنِ پاسخ‌ها: ایمنی، مهریه، حضانت و طلاق.

// ---- پرسش‌ها و پاسخ‌ها

String? _famRole(String n) {
  if (Sense.has(n, 'من شوهر|شوهرشم|شوهرش هستم|من مرد|زوج (?:ام|هستم)')) {
    return 'husband';
  }
  if (Sense.has(n,
      'شوهر|آقامون|مهریه ?(?:ام|م|مو) |مهریم|مهریه من|نفقه ?(?:ام|م|مو) |نفقه من|زوجه (?:ام|هستم)|من زن|خانم هستم|مادرشوهر|خواستگار|نامزدم (?:[^ ]+ ){0,5}مهریه')) {
    return 'wife';
  }
  if (Sense.has(n,
      'زنم|خانمم|همسرم (?:[^ ]+ ){0,4}(?:مهریه|اجرا|قهر|رفته خونه|تمکین)|مهریه[^ ]* (?:رو |را )?(?:اجرا گذاشت|گذاشته اجرا)|زوج (?:ام|هستم)|من مرد|من شوهر|مادرزن')) {
    return 'husband';
  }
  return null;
}

String? _famViolence(String n) => Sense.has(n,
        'کتک|میزنه|منو زد|زد(?:ه)? منو|دست بزن|ضرب و شتم|کبود|خشونت|کتکم|میزندم|کتک میخورم')
    ? 'yes'
    : null;

String? _famChildAge(String n) {
  if (!Sense.has(n, 'بچه|فرزند|پسر|دختر|طفل')) return null;
  final a = Sense.numberBefore(n, 'سال');
  if (a != null && a < 19) return a.toString();
  if (Sense.has(n, 'شیرخوار|نوزاد|چند ماهه')) return '1';
  return null;
}
