import 'engine.dart';

/// ساخت متن درخواست برای مدل زبانی از مواد بازیابی‌شده.
/// جدا از Assistant است تا قالب و محدودیت طول بدون دست زدن به منطق پاسخ عوض شود.
class PromptBuilder {
  final int maxBody;
  final int maxTotal;

  const PromptBuilder({this.maxBody = 1200, this.maxTotal = 3500});

  String build(String question, List<Hit> ctx) {
    final sb = StringBuffer();
    sb.writeln('تو یک دستیار فارسی هستی. فقط بر اساس متن‌های زیر پاسخ بده.');
    sb.writeln('اگر پاسخ در متن‌ها نیست، بگو «در دانش من نیست».');
    sb.writeln('چیزی از خودت اضافه نکن و در صورت وجود شمارهٔ ماده و نام قانون را بیاور.');
    sb.writeln();
    var used = 0;
    var i = 1;
    for (final h in ctx) {
      var body = h.chunk.body;
      if (body.length > maxBody) body = body.substring(0, maxBody);
      if (used + body.length > maxTotal) break;
      used += body.length;
      final src = h.chunk.source.isEmpty ? '' : '${h.chunk.source} - ';
      sb.writeln('[$i] $src${h.chunk.title}');
      sb.writeln(body);
      sb.writeln();
      i++;
    }
    sb.writeln('پرسش: $question');
    sb.writeln('پاسخ:');
    return sb.toString();
  }
}
