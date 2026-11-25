part of 'family.dart';

// برداشتِ وکیل و خواندنِ پاسخ‌ها از متن.

// ---- برداشت وکیل و ادعاها

List<String> familyRecap(CaseFile f) => [
      if (f.eq('role', 'wife')) 'زنِ این زندگی هستید',
      if (f.eq('role', 'husband')) 'شوهر هستید',
      if (f.yes('violence')) 'کتک و آزار در کار بوده',
      if (f.eq('proofV', 'medical')) 'گواهی پزشکی قانونی دارید',
      if (f.eq('proofV', 'witness')) 'عکس یا شاهد دارید',
      if (f.eq('proofV', 'none')) 'برای آن مدرکی ندارید',
      if (f.n('childAge') != null) 'فرزند ${Sense.fa(f.n('childAge')!)} ساله دارید',
      if (f.n('coins') != null) 'مهریه ${Sense.fa(f.n('coins')!)} سکه است',
      if (f.yes('agrees')) 'طرف مقابل به طلاق راضی است',
      if (f.no('agrees')) 'طرف مقابل به طلاق راضی نیست',
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
