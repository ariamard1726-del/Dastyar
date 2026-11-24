part of 'advocate.dart';

/// خلاصهٔ پرونده به زبان خودِ وکیل: فهرستِ جمله‌هایی که از واقعیت‌های گفته‌شده
/// ساخته می‌شود.
///
/// پیش‌تر `Advocate._recap` بود و هر جا لازم می‌شد، از راهِ وکیل صدایش
/// می‌زدند. حالا یک تابعِ خالص است که فقط موضوع و پرونده را می‌خواهد؛
/// `CaseArgument` هم همین را می‌گیرد، نه خودِ وکیل را.
List<String> recapOf(Topic t, CaseFile f) {
  final r = t.recap;
  if (r == null) return const [];
  return [
    for (final x in r(f))
      if (x.trim().isNotEmpty) x.trim(),
  ];
}
