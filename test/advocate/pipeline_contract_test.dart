import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// قرارداد خط لوله: `assets/pipeline.json` تنها منبع حقیقت است و کد Dart
/// باید دقیقاً همان ترتیب و همان آستانه‌ها را داشته باشد.
///
/// پیش از این، ترتیب مسیرها فقط در `pipelineOrder` بود و آستانه‌ها
/// عدد جادویی وسط کد؛ هر تغییر بی‌هماهنگ بی‌صدا رفتار را عوض می‌کرد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, dynamic> pipeline;

  setUpAll(() {
    final raw = File('assets/pipeline.json').readAsStringSync();
    pipeline = jsonDecode(raw) as Map<String, dynamic>;
  });

  test('KnowledgeEngine.load تنظیمات خط لوله را زنده از assets/pipeline.json می‌خواند', () async {
    final engine = KnowledgeEngine();
    await engine.load();
    final cfg = engine.pipeline;
    expect(cfg, isNotNull);
    expect(resolvePipelineOrder(cfg), pipelineOrder);
    expect(resolveNetMin(cfg), netMin);
    expect(resolveTopicOpenMin(cfg), topicOpenMin);
    expect(resolveTopicStrongMin(cfg), topicStrongMin);
    expect(resolveTopicDominantMin(cfg), topicDominantMin);
  });

  test('فایل خط لوله در دسترس و دارای order است', () {
    expect(pipeline['order'], isA<List>());
    expect((pipeline['order'] as List), isNotEmpty);
  });

  test('ترتیب Dart با pipeline.json یکی است', () {
    final want = [for (final s in pipeline['order'] as List) '$s'];
    final got = [for (final s in pipelineOrder) s.name];
    expect(got, want);
  });

  test('آستانه‌های pipeline.json با Dart یکی است', () {
    final th = pipeline['thresholds'] as Map<String, dynamic>;
    expect(netMin, (th['netMin'] as num).toDouble());
    expect(topicOpenMin, th['topicOpen']);
    expect(topicStrongMin, th['topicStrong']);
    expect(topicDominantMin, th['topicDominant']);
  });

  test('هر مسیر pipeline.json به یک مقدار AnswerSource نگاشت می‌شود', () {
    final values = AnswerSource.values.map((s) => s.name).toSet();
    for (final s in pipeline['order'] as List) {
      expect(values.contains('$s'), isTrue, reason: 'مسیر ناشناخته: $s');
    }
  });
}
