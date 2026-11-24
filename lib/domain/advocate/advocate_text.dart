part of 'advocate.dart';

// بریدن و کوتاه‌کردن متن قانون و پاسخ.

final RegExp _sentEnd = RegExp(r'(?<=[.؟!])\s+|\n+');

String _strip(String s) => s.replaceAll(refRun, '');

List<String> _sentences(String s) => [
      for (final p in s.split(_sentEnd))
        if (p.trim().isNotEmpty) p.trim(),
    ];

/// از یک توضیح بلند، جمله‌ای که به حرف کاربر می‌خورد.
String _relevant(String answer, String n) {
  final sents = _sentences(answer);
  if (sents.isEmpty) return answer;
  final keys = [
    for (final w in n.trim().split(' '))
      if (w.length >= 5) w.substring(0, 5),
  ];
  for (final s in sents) {
    final sn = Sense.norm(s);
    if (keys.any(sn.contains)) return s;
  }
  return sents.first;
}

String _brief(String line) {
  if (line.length <= 24) return line;
  var cut = line.length;
  for (final mark in const ['؛', '. ']) {
    final i = line.indexOf(mark, 18);
    if (i > 0 && i < cut) cut = i;
  }
  // «عنوان: توضیح» فقط وقتی کوتاه می‌شود که خودِ عنوان گویا باشد.
  final colon = line.indexOf(':', 40);
  if (colon > 0 && colon < cut) cut = colon;
  final out = line.substring(0, cut).trim();
  return out.endsWith('.') ? out : '$out.';
}

/// متنِ ماده، از حاشیه‌های غیرقانونیِ بانک پاک‌شده و بی‌برش (برای «متن
/// قانون را ببینم» که کاربر خودِ متن را می‌خواهد، نه چکیده).
String _lawBody(String body) {
  var b = body.trim();
  final nl = b.indexOf('\n');
  if (b.startsWith('(') && nl > 0 && nl < 60) b = b.substring(nl + 1);
  b = b.replaceAll(RegExp(r'\s+'), ' ').trim();
  // حاشیه‌های غیرقانونیِ بانک (مثل «نظر مجلس») جزو متن ماده نیست.
  final note = b.indexOf('نظر مجلس');
  if (note > 20) b = b.substring(0, note).trim();
  return Sense.fa(b);
}



