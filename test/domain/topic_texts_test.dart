import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

/// متنِ موضوعهای غیرِاجاره مرجعِ داده دارد؛ نگهبانِ معادلبودن در
/// `tests/python/test_topic_text_equivalence.py` است. این آزمون قراردادِ
/// بارگذاری و خطای صریحِ نبودِ متن را قفل میکند.
void main() {
  test('متنهای مشترک، کار و خانواده از فایلِ دارایی نصب میشوند', () async {
    final keys = await loadTopicTexts();
    // ۹ (shared) + ۱۸۲ (labor) + ۹۹ (family) = ۲۹۰ متن.
    expect(keys.length, 290);
    expect(loadedTopicTexts.containsKey('sharedForumTail'), isTrue);
    expect(loadedTopicTexts.containsKey('shared_0'), isTrue);
    expect(loadedTopicTexts.containsKey('laborIss_0'), isTrue);
    expect(loadedTopicTexts.containsKey('laborClaimFiredLabel'), isTrue);
    expect(loadedTopicTexts.containsKey('laborPlanS2'), isTrue);
    expect(loadedTopicTexts.containsKey('familyIss_0'), isTrue);
    expect(loadedTopicTexts.containsKey('familySafetyTopA'), isTrue);
    expect(topicText('shared_0').contains('هزینهٔ دادرسی'), isTrue);
    expect(topicText('shared_2').contains('وکیل'), isTrue);
    expect(topicText('laborIss_0'), 'کار و کارفرما');
    expect(topicText('laborClaimFiredLabel'), 'اخراج');
    expect(topicText('laborPlanS2').contains('هیئت تشخیص'), isTrue);
    expect(topicText('familyIss_0'), 'خانواده');
    expect(topicText('familySafetyTopA').contains('امنیت'), isTrue);
  });

  test('شناسهٔ ناشناخته بیصدا جایگزین نمیشود', () {
    expect(() => topicText('not_a_topic_text'), throwsStateError);
  });

  test('دادهٔ ناقص، متنهای نصبشده را خراب نمیکند', () {
    final before = Map<String, String>.from(loadedTopicTexts);
    expect(
      () => parseTopicTexts('{"v": 1, "shared": {"x": "متن"}}'),
      throwsStateError,
    );
    expect(loadedTopicTexts, equals(before));
  });

  test('نسخهٔ ناشناخته داده رد میشود', () {
    expect(
      () => parseTopicTexts('{"v": 99, "shared": {"x": "متن"}}'),
      throwsStateError,
    );
  });
}
