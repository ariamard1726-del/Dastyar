import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/intent_net.dart';

/// طبقه‌بند سبک نیت (`assets/brain/intent_model.json`) فقط «نظر دوم» می‌دهد:
/// جایی که قاعده‌های وکیل موضوع را شناخته‌اند هیچ اثری ندارد، و جایی که
/// نشناخته‌اند فقط می‌تواند پروندهٔ یکی از موضوع‌های هم‌معنا را باز کند.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  late IntentNet net;
  late List<String> samples;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
    net = IntentNet.fromJson(
      jsonDecode(File('assets/brain/intent_model.json').readAsStringSync())
          as Map<String, dynamic>,
    );
    samples = [
      for (final line
          in File('brain/eval/intent_eval.txt').readAsLinesSync())
        if (!line.startsWith('#') && line.indexOf('|') > 0)
          line.substring(line.indexOf('|') + 1).trim(),
    ];
  });

  test('برچسب‌های نگاشت‌شده هم در طبقه‌بند هست و هم در موضوع‌های وکیل', () {
    final ids = Advocate.topics.map((t) => t.id).toSet();
    Advocate.netTopics.forEach((label, id) {
      expect(net.labels, contains(label));
      expect(ids, contains(id));
    });
  });

  test('جایی که قاعده‌ها موضوع را شناخته‌اند، طبقه‌بند هیچ چیز را عوض نمی‌کند',
      () {
    expect(samples.length, greaterThan(100));
    for (final text in samples) {
      final plain = Advocate(engine);
      final hinted = Advocate(engine, intentNet: net);
      plain.respond(text);
      hinted.respond(text);
      if (plain.file.topic.isEmpty) continue;
      expect(hinted.file.topic, plain.file.topic, reason: text);
    }
  });

  test('نظر طبقه‌بند فقط با اطمینان بالا و فقط برای موضوع هم‌معنا پذیرفته می‌شود',
      () {
    for (final text in samples) {
      final plain = Advocate(engine);
      final hinted = Advocate(engine, intentNet: net);
      plain.respond(text);
      hinted.respond(text);
      if (plain.file.topic.isNotEmpty || hinted.file.topic.isEmpty) continue;
      final top = net.classify(text);
      expect(top.score, greaterThanOrEqualTo(Advocate.netMin), reason: text);
      expect(hinted.file.topic, Advocate.netTopics[top.label], reason: text);
    }
  });

  test('ارجاع مستقیم به ماده و پیام‌های کوتاه هرگز با طبقه‌بند پرونده باز نمی‌کنند',
      () {
    for (final text in [
      'ماده ۱۰ قانون مدنی',
      'اصل ۲۲ قانون اساسی چه می‌گوید',
      'سلام',
      'ممنون',
      'چی؟',
    ]) {
      final a = Advocate(engine, intentNet: net);
      a.respond(text);
      expect(a.file.topic, isEmpty, reason: text);
    }
  });

  test('بدون طبقه‌بند هم وکیل کامل کار می‌کند', () {
    final a = Advocate(engine);
    expect(a.intentNet, isNull);
    final r = a.respond('چکم برگشت خورده');
    expect(a.file.topic, 'cheque');
    expect(r.text.trim(), isNotEmpty);
  });
}
