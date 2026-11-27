import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/advocate/topics/rent_texts_loader.dart';

/// متنِ اجاره مرجعِ داده دارد؛ نگهبانِ معادل بودن در
/// `tests/python/test_rent_text_equivalence.py` است. این آزمون فقط قراردادِ
/// بارگذاری و خطای صریحِ نبودِ متن را قفل میکند.
void main() {
  test('متنها از فایلِ دارایی نصب میشوند', () async {
    final keys = await loadRentTexts();
    // ۴۲+۸۷+۳۲+۳۶+۵۱ = ۲۴۸ متن در پنج جدول. نبودِ یکی خطای صریح است.
    expect(keys.length, 248);
    expect(loadedRentTexts.containsKey('rentPeace'), isTrue);
    expect(loadedRentTexts.containsKey('rentLandlordPaidBody'), isTrue);
    expect(loadedRentTexts.containsKey('claim0_goal'), isTrue);
    expect(loadedRentTexts.containsKey('claim9_counter'), isTrue);
    expect(loadedRentTexts.containsKey('filing0_chip'), isTrue);
    expect(loadedRentTexts.containsKey('filing15_name'), isTrue);
    expect(loadedRentTexts.containsKey('plan0'), isTrue);
    expect(loadedRentTexts.containsKey('plan12'), isTrue);
    expect(loadedRentTexts.containsKey('plan18'), isTrue);
    expect(loadedRentTexts.containsKey('planLead'), isTrue);
    expect(loadedRentTexts.containsKey('plan28'), isTrue);
    expect(loadedRentTexts.containsKey('plan30'), isTrue);
    expect(loadedRentTexts.containsKey('plan34_a'), isTrue);
    expect(loadedRentTexts.containsKey('plan34_b'), isTrue);
    expect(loadedRentTexts.containsKey('bodyRaiseBase'), isTrue);
    expect(loadedRentTexts.containsKey('bodyOrderRet0'), isTrue);
    expect(loadedRentTexts.containsKey('bodyUnpaidEvict'), isTrue);
    expect(loadedRentTexts.containsKey('bodyPenaltyNone'), isTrue);
    expect(loadedRentTexts.containsKey('bodySubletLandlord'), isTrue);
    expect(loadedRentTexts.containsKey('bodyLandlordNoPlaceEnded'), isTrue);
    expect(rentText('rentPeace').contains('دادگاه صلح'), isTrue);
    expect(rentText('filing0_chip').startsWith('تنظیم'), isTrue);
    expect(rentText('filing15_name').contains('لایحه'), isTrue);
    expect(rentText('plan0').contains('اظهارنامه'), isTrue);
    expect(rentText('planLead').contains('ارزیابی'), isTrue);
    expect(rentText('bodyRaiseBase').contains('اجاره'), isTrue);
    expect(rentText('bodyDeathBase').contains('فوت'), isTrue);
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
