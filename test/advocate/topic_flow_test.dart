import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/topic_flow.dart';

/// همتای tests/python/test_topic_flow.py: مسیر تصمیم چک در دارت باید با
/// پایتون یکسان باشد (همان نمونه‌ها، همان برگ‌ها).
void main() {
  final flow = jsonDecode(File('assets/brain/topics/cheque.json').readAsStringSync())
      as Map<String, dynamic>;

  test('مسیر چک: نمونه‌های توسعه همه درست‌اند', () {
    final gold = (jsonDecode(File('tests/topics/cheque_gold.json').readAsStringSync()) as List)
        .cast<Map<String, dynamic>>();
    final bad = [
      for (final g in gold)
        if (TopicFlow.route(flow, g['q'] as String) != g['leaf']) g['q'],
    ];
    expect(bad, isEmpty, reason: bad.join(' | '));
  });

  test('تشخیص پیام دربارهٔ چک', () {
    expect(TopicFlow.mentionsCheque('چکم برگشت خورده'), isTrue);
    expect(TopicFlow.mentionsCheque('چک من'), isTrue);
    expect(TopicFlow.mentionsCheque('سلام'), isFalse);
    expect(TopicFlow.mentionsCheque('کفیل شدم'), isFalse);
  });

  test('پاسخ برگ دارنده شامل مادهٔ ۴ و ۱۱ و ۲۳ است', () {
    expect(TopicFlow.route(flow, 'چکم برگشت خورد'), 'returned_holder');
    final leaves = flow['leaves'] as Map<String, dynamic>;
    final refs = [for (final a in (leaves['returned_holder']['articles'] as List)) a['title']];
    expect(refs, containsAll(['ماده 4', 'ماده 11', 'ماده 23']));
  });
}
