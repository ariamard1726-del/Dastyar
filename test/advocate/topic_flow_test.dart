import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/topic_flow.dart';

/// همتای tests/python/test_topic_flow.py: مسیر تصمیم چک در دارت باید با
/// پایتون یکسان باشد (همان نمونه‌ها، همان برگ‌ها).
void main() {
  final flow = jsonDecode(File('assets/brain/topics/cheque.json').readAsStringSync())
      as Map<String, dynamic>;

  test('همهٔ موضوعات: نمونه‌های توسعه همه درست‌اند', () {
    final index = jsonDecode(File('assets/brain/topics/index.json').readAsStringSync())
        as Map<String, dynamic>;
    for (final name in (index['topics'] as List).cast<String>()) {
      final topic = jsonDecode(File('assets/brain/topics/$name').readAsStringSync())
          as Map<String, dynamic>;
      final stem = name.replaceAll('.json', '');
      final gold = (jsonDecode(File('tests/topics/${stem}_gold.json').readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      final bad = [
        for (final g in gold)
          if (TopicFlow.route(topic, g['q'] as String) != g['leaf']) '[$stem] ${g['q']}',
      ];
      expect(bad, isEmpty, reason: bad.join(' | '));
    }
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

  test('دادهٔ ناقص یا بدشکل در جریان موضوعی بدون کرش به ask می‌رود', () {
    expect(TopicFlow.route(<String, dynamic>{}, 'چکم برگشت خورد'), 'ask');
    expect(
      TopicFlow.route(<String, dynamic>{
        'gate': <Object?>[123, null],
        'rules': <Object?>[
          'bad',
          <String, Object?>{'any': <Object?>['چک']},
          <String, Object?>{'any': <Object?>[42], 'leaf': 'x'},
          <String, Object?>{'all_groups': <Object?>['bad'], 'leaf': 'x'},
        ],
      }, 'چکم برگشت خورد'),
      'ask',
    );
  });
}
