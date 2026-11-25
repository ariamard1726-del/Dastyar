// نگهبان نگاشت طبقه‌بند نیت (IntentNet) به موضوع‌های وکیل.
// اگر برچسب مدل یا شناسهٔ موضوع تغییر کند و نگاشت به‌روز نشود، این تست شکست می‌خورد.
import 'dart:convert';
import 'dart:io';

import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final modelFile = File('assets/brain/intent_model.json');
  final labels = (jsonDecode(modelFile.readAsStringSync())['labels'] as List)
      .cast<String>()
      .toSet();

  test('هر موضوع نگاشت‌شده شناسهٔ واقعی یکی از موضوع‌های وکیل است', () {
    final ids = Advocate.topics.map((t) => t.id).toSet();
    for (final entry in netTopics.entries) {
      expect(ids, contains(entry.value),
          reason: 'برچسب «${entry.key}» به موضوع ناموجود «${entry.value}» نگاشت شده');
    }
  });

  test('هر برچسب نگاشت‌شده در فایل مدل نیت وجود دارد', () {
    for (final key in netTopics.keys) {
      expect(labels, contains(key), reason: 'برچسب «$key» در مدل نیست');
    }
  });

  test('هر برچسب موضوعی در مدل، یا نگاشت دارد یا عمداً بی‌موضوع است', () {
    const noTopic = {
      'article_lookup', 'cancel', 'chitchat', 'counsel_answer',
      'criminal_harm', 'draft_request', 'general_intake', 'legal_question',
      'litigation_defense', 'out_of_scope',
    };
    final unmapped = labels.difference({...netTopics.keys, ...noTopic});
    expect(unmapped, isEmpty,
        reason: 'برچسب‌های بی‌نگاشت ولی بی‌موضوع‌نشده: $unmapped');
  });

  test('آستانهٔ نظر دوم در بازهٔ معقول است', () {
    expect(netMin, inInclusiveRange(0.5, 0.9));
  });
}
