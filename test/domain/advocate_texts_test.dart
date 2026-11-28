import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/advocate/advocate_texts_loader.dart';

/// متنهای عمومی وکیل (واژه‌نامه، عبارت‌های چرخشی، ایمنی، راهنما، پاسخ‌های
/// گفت‌وگو و جمله‌بندی استدلال) مرجع داده دارند؛ نگهبان معادل‌بودن در
/// `tests/python/test_advocate_text_equivalence.py` است. این آزمون قرارداد
/// بارگذاری، قالب‌بندی تک‌گذره و خطای صریح نبود متن را قفل می‌کند.
void main() {
  test('متنهای عمومی وکیل از فایل دارایی نصب می‌شوند', () async {
    final keys = await loadAdvocateTexts();
    // ۱۸ بخش، ۴۷۶ متن.
    expect(keys.length, 476);
    expect(loadedAdvocateTexts.containsKey('term_esar_text'), isTrue);
    expect(loadedAdvocateTexts.containsKey('say_disclaimer'), isTrue);
    expect(loadedAdvocateTexts.containsKey('safetySelfHarmText'), isTrue);
    expect(loadedAdvocateTexts.containsKey('argueManySummaryLead'), isTrue);
    expect(loadedAdvocateTexts.containsKey('guardObjectionBody'), isTrue);

    expect(advocateText('term_dadkhast_title'), 'دادخواست');
    expect(advocateText('say_disclaimer').contains('وکیل دادگستری'), isTrue);
    expect(advocateText('voiceAskDropped').contains('دو بار'), isTrue);
    expect(advocateTextSeq('constReplyChip', 4).length, 4);
    expect(
      advocateFormat('argueCorrection', {'old': '{now}', 'now': 'ب'}),
      'برداشتم را اصلاح کردم: قبلاً نوشته بودم «{now}»؛ حالا «ب».',
    );
  });

  test('شناسهٔ ناشناخته بی‌صدا جایگزین نمی‌شود', () {
    expect(() => advocateText('not_an_advocate_text'), throwsStateError);
  });

  test('دادهٔ ناقص، متنهای نصبشده را خراب نمی‌کند', () {
    final before = Map<String, String>.from(loadedAdvocateTexts);
    expect(
      () => parseAdvocateTexts('{"v": 1, "glossary": {"x": "متن"}}'),
      throwsStateError,
    );
    expect(loadedAdvocateTexts, equals(before));
  });

  test('نسخهٔ ناشناخته داده رد می‌شود', () {
    expect(
      () => parseAdvocateTexts('{"v": 99, "glossary": {"x": "متن"}}'),
      throwsStateError,
    );
  });
}
