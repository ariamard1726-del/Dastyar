import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// قرارداد خط لوله: `assets/pipeline.json` تنها منبع حقیقت است و کد Dart
/// باید دقیقاً همان ترتیب و همان آستانه‌ها را داشته باشد.
///
/// پیش از این، ترتیب مسیرها فقط در `Advocate.pipelineOrder` بود و آستانه‌ها
/// عدد جادویی وسط کد؛ هر تغییر بی‌هماهنگ بی‌صدا رفتار را عوض می‌کرد.
void main() {
  late Map<String, dynamic> pipeline;

  setUpAll(() {
    final raw = File('assets/pipeline.json').readAsStringSync();
    pipeline = jsonDecode(raw) as Map<String, dynamic>;
  });

  test('فایل خط لوله در دسترس و دارای order است', () {
    expect(pipeline['order'], isA<List>());
    expect((pipeline['order'] as List), isNotEmpty);
  });

  test('ترتیب Dart با pipeline.json یکی است', () {
    final want = [for (final s in pipeline['order'] as List) '$s'];
    final got = [for (final s in Advocate.pipelineOrder) s.name];
    expect(got, want);
  });

  test('netMin در Dart با pipeline.json یکی است', () {
    final th = pipeline['thresholds'] as Map<String, dynamic>;
    expect(Advocate.netMin, (th['netMin'] as num).toDouble());
  });

  test('هر مسیر pipeline.json به یک مقدار AnswerSource نگاشت می‌شود', () {
    final values = AnswerSource.values.map((s) => s.name).toSet();
    for (final s in pipeline['order'] as List) {
      expect(values.contains('$s'), isTrue, reason: 'مسیر ناشناخته: $s');
    }
  });
}
