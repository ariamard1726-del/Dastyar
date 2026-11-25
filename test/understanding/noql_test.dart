import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/understanding/noql_tokenizer.dart';
import 'package:dastyar/domain/understanding/topic_reader.dart';

/// کدِ Dart مدل Noql باید همان چیزی را بدهد که هستهٔ مرجع پایتون
/// (`brain/noql/core.py`) داده و در `noql_ref.json` ثبت شده است. خودِ آن
/// هسته روی CI با کتابخانه‌های اصلی مدل مقایسه می‌شود
/// (`reports/noql_export.md`).
void main() {
  late TopicReader reader;
  late Map<String, dynamic> ref;

  setUpAll(() {
    reader = TopicReader.fromAssets(
      File('assets/brain/noql.bin').readAsBytesSync(),
      File('assets/brain/noql_vocab.json').readAsStringSync(),
      File('assets/brain/noql_head.json').readAsStringSync(),
    );
    ref = jsonDecode(File('test/understanding/noql_ref.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  test('توکن‌ساز برای همهٔ متن‌های مرجع همان شناسه‌ها را می‌دهد', () {
    final cases = (ref['tokens'] as List).cast<Map<String, dynamic>>();
    expect(cases.length, greaterThan(100));
    for (final c in cases) {
      final text = c['text'] as String;
      final ids = reader.tokenizer.encode(NoqlTokenizer.prepare(text));
      expect(ids, (c['ids'] as List).cast<int>(), reason: text);
    }
  });

  test('توکن‌ساز: فاصله‌های گوناگون، نیم‌فاصله و سقف طول', () {
    final t = reader.tokenizer;
    expect(t.encode(''), [NoqlTokenizer.cls, NoqlTokenizer.sep]);
    expect(t.encode(' \t\n '), [NoqlTokenizer.cls, NoqlTokenizer.sep]);
    expect(t.encode('سلام   دنیا'), t.encode(' سلام\u00a0دنیا\n'));
    // نیم‌فاصله فاصله نیست؛ خودش یک توکن است.
    expect(t.encode('می‌خواهم'), isNot(t.encode('می خواهم')));
    final long = t.encode(List.filled(200, 'صاحبخانه پول نمی‌دهد').join(' '));
    expect(long.length, 64);
    expect(long.first, NoqlTokenizer.cls);
    expect(long.last, NoqlTokenizer.sep);
    for (final id in t.encode('😀 ي ك ﷲ xyz')) {
      expect(id, inInclusiveRange(0, t.vocabSize - 1));
    }
  });

  test('بردار جمله با مرجع یکی است', () {
    final cases = (ref['embeds'] as List).cast<Map<String, dynamic>>();
    expect(cases, isNotEmpty);
    for (final c in cases) {
      final text = c['text'] as String;
      final want = Float32List.fromList(
          [for (final v in c['vec'] as List) (v as num).toDouble()]);
      final got = reader.embed(text);
      expect(got.length, want.length);
      var dot = 0.0;
      var norm = 0.0;
      var worst = 0.0;
      for (var i = 0; i < got.length; i++) {
        dot += got[i] * want[i];
        norm += got[i] * got[i];
        worst = math.max(worst, (got[i] - want[i]).abs());
      }
      expect(norm, closeTo(1.0, 1e-3), reason: text);
      expect(dot, greaterThan(0.9999), reason: text);
      expect(worst, lessThan(2e-3), reason: text);
    }
  });

  test('روی جمله‌های محک همان دسته و همان اطمینانِ مرجع را می‌دهد', () {
    final cases = (ref['probe'] as List).cast<Map<String, dynamic>>();
    expect(cases.length, greaterThanOrEqualTo(39));
    var millis = 0;
    var tokens = 0;
    for (final c in cases) {
      final text = c['text'] as String;
      final g = reader.read(text);
      millis += g.millis;
      tokens += g.tokens;
      expect(g.label, c['label'], reason: text);
      expect(g.score, closeTo((c['score'] as num).toDouble(), 0.01),
          reason: text);
      expect(g.confident, c['confident'] ?? g.score >= reader.open,
          reason: text);
      expect(g.plausible, c['plausible'] ?? g.score >= reader.ask,
          reason: text);
      if (g.confident) {
        expect(g.score - g.secondScore, greaterThanOrEqualTo(reader.margin));
      }
      expect(g.second, isNot(g.label));
    }
    // زمانِ Dart (JIT روی ماشین تست) برای گزارش؛ روی گوشی فرق می‌کند.
    final line =
        'NOQL-DART ${cases.length} sentences, $tokens tokens, $millis ms total, '
        '${(millis / cases.length).round()} ms per sentence\n';
    File('reports/noql_dart_speed.txt').writeAsStringSync(line);
  });

  test('آستانه‌ها معنادارند', () {
    expect(reader.ask, greaterThan(0));
    expect(reader.open, greaterThanOrEqualTo(reader.ask));
    expect(reader.open, lessThan(1));
    expect(reader.margin, inInclusiveRange(0, 0.5));
    expect(reader.labels.length, 19);
  });
}
