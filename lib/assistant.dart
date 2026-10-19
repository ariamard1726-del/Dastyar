import 'engine.dart';
import 'llm.dart';

class Assistant {
  final KnowledgeEngine engine;
  final LlmBackend llm;

  Assistant(this.engine, {LlmBackend? llm}) : llm = llm ?? NoLlm();

  static const int _maxBody = 1200;
  static const int _maxTotal = 3500;

  /// هر بار متن کامل‌شدهٔ فعلی پاسخ را برمی‌گرداند.
  Stream<String> ask(String question) async* {
    final fallback = engine.answer(question);

    bool ready = false;
    try {
      ready = await llm.isReady();
    } catch (_) {}
    if (!ready) {
      yield fallback;
      return;
    }

    final r = engine.rank(question, k: 4);
    final ctx = r.hits.where((h) => h.score >= 0.3).toList();
    if (ctx.isEmpty) {
      yield fallback;
      return;
    }

    final prompt = buildPrompt(question, ctx);
    var acc = '';
    try {
      await for (final t in llm.generate(prompt)) {
        acc += t;
        yield acc;
      }
    } catch (_) {
      yield fallback;
      return;
    }
    if (acc.trim().isEmpty) {
      yield fallback;
      return;
    }

    final seen = <String>{};
    final srcs = <String>[];
    for (final h in ctx) {
      final c = h.chunk;
      final label = c.source.isEmpty ? c.title : '${c.source} — ${c.title}';
      if (seen.add(label)) srcs.add(label);
    }
    yield '$acc\n\nمنبع: ${srcs.join('، ')}';
  }

  String buildPrompt(String question, List<Hit> ctx) {
    final sb = StringBuffer();
    sb.writeln('تو یک دستیار فارسی هستی. فقط بر اساس متن‌های زیر پاسخ بده.');
    sb.writeln('اگر پاسخ در متن‌ها نیست، بگو «در دانش من نیست».');
    sb.writeln('چیزی از خودت اضافه نکن و در صورت وجود شمارهٔ ماده و نام قانون را بیاور.');
    sb.writeln();
    var used = 0;
    var i = 1;
    for (final h in ctx) {
      var body = h.chunk.body;
      if (body.length > _maxBody) body = body.substring(0, _maxBody);
      if (used + body.length > _maxTotal) break;
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
