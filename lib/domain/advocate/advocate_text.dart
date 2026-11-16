part of 'advocate.dart';

// بریدن و کوتاه‌کردن متن قانون و پاسخ.

final RegExp _refRun =
    RegExp(r'(?:\s*\[\[[a-z_0-9]+:[0-9]+m?\]\])+');

final RegExp _refOne = RegExp(r'\[\[([a-z_0-9]+):([0-9]+)(m?)\]\]');

final RegExp _sentEnd = RegExp(r'(?<=[.؟!])\s+|\n+');

String _strip(String s) => s.replaceAll(_refRun, '');

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

/// نام کوتاه و رایج قانون‌های پرتکرار، برای اینکه متن پاسخ سنگین نشود.
String _shortLaw(String source) {
  if (source.contains('آیین دادرسی دادگاه') && source.contains('مدنی')) {
    return 'قانون آیین دادرسی مدنی';
  }
  final paren = source.indexOf(' (');
  if (paren > 8 && source.startsWith('قانون مجازات اسلامی')) {
    return source.contains('تعزیرات')
        ? 'قانون مجازات اسلامی (تعزیرات)'
        : source.substring(0, paren);
  }
  return source;
}

String _snippet(String body) {
  var b = body.trim();
  final nl = b.indexOf('\n');
  if (b.startsWith('(') && nl > 0 && nl < 60) b = b.substring(nl + 1);
  b = b.replaceAll(RegExp(r'\s+'), ' ').trim();
  // حاشیه‌های غیرقانونیِ بانک (مثل «نظر مجلس») جزو متن ماده نیست.
  final note = b.indexOf('نظر مجلس');
  if (note > 20) b = b.substring(0, note).trim();
  if (b.length > 190) {
    var cut = b.lastIndexOf(' ', 190);
    if (cut < 90) cut = 190;
    b = '${b.substring(0, cut).trim()}…';
  }
  return Sense.fa(b);
}

final RegExp _cutAt = RegExp(r'[.؟!]\s+|\n+');

final RegExp _listItem = RegExp(r'^(?:[۰-۹0-9]+\)|•)');

/// متن را در مرزِ جمله به دو بخش می‌کند: آنچه الان گفته می‌شود و باقی.
List<String> _cut(String body, int budget) {
  if (body.length <= budget + 60) return [body, ''];
  final ends = <int>[];
  for (final m in _cutAt.allMatches(body)) {
    if (m.end >= body.length) break;
    final head = body.substring(0, m.start + 1).trimRight();
    if (head.endsWith(':') || head.endsWith('،')) continue;
    ends.add(m.end);
  }
  if (ends.isEmpty) return [body, ''];
  var k = 0;
  while (k + 1 < ends.length && ends[k + 1] <= budget) {
    k++;
  }
  // فهرستِ شماره‌دار را وسطش نمی‌بُرم، اگر باقی‌اش جا شود.
  while (k + 1 < ends.length &&
      ends[k + 1] <= budget + 280 &&
      _listItem.hasMatch(body.substring(ends[k]))) {
    k++;
  }
  final pick = ends[k];
  if (body.length - pick < 60) return [body, ''];
  if (body.length <= budget + 280 &&
      _listItem.hasMatch(body.substring(pick))) {
    return [body, ''];
  }
  return [body.substring(0, pick).trimRight(), body.substring(pick).trim()];
}

