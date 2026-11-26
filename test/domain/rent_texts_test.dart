import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/advocate/topics/rent_texts_loader.dart';

/// متنِ اجاره مرجعِ داده دارد؛ نگهبانِ معادل بودن در
/// `tests/python/test_rent_text_equivalence.py` است. این آزمون فقط قراردادِ
/// بارگذاری و خطای صریحِ نبودِ متن را قفل میکند.
void main() {
  test('متنها از فایلِ دارایی نصب میشوند', () async {
    final keys = await loadRentTexts();
    // ۴۲ متنِ پاسخ + ۸۷ متنِ ادعا. نبودِ یکی از جدولها خطای صریح است.
    expect(keys.length, 129);
    expect(loadedRentTexts.containsKey('rentPeace'), isTrue);
    expect(loadedRentTexts.containsKey('rentLandlordPaidBody'), isTrue);
    expect(loadedRentTexts.containsKey('claim0_goal'), isTrue);
    expect(loadedRentTexts.containsKey('claim9_counter'), isTrue);
    expect(rentText('rentPeace').contains('دادگاه صلح'), isTrue);
  });

  test('شناسهٔ ناشناخته بیصدا جایگزین نمیشود', () {
    expect(() => rentText('not_a_rent_text'), throwsStateError);
  });

  test('دادهٔ ناقص، متنهای نصبشده را خراب نمیکند', () {
    final before = Map<String, String>.from(loadedRentTexts);
    expect(
      () => parseRentTexts('{"v": 1, "texts": {"x": "متن"}}'),
      throwsStateError,
    );
    expect(loadedRentTexts, equals(before));
  });

  test('نسخهٔ ناشناخته داده رد میشود', () {
    expect(
      () => parseRentTexts('{"v": 99, "texts": {"x": "متن"}}'),
      throwsStateError,
    );
  });
}
