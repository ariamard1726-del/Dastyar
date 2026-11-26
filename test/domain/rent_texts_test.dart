import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/advocate/topics/rent_texts_loader.dart';

/// متنِ اجاره مرجعِ داده دارد؛ نگهبانِ معادل بودن در
/// `tests/python/test_rent_text_equivalence.py` است. این آزمون فقط قراردادِ
/// بارگذاری و خطای صریحِ نبودِ متن را قفل میکند.
void main() {
  test('متنها از فایلِ دارایی نصب میشوند', () async {
    final keys = await loadRentTexts();
    expect(keys.length, 42);
    expect(loadedRentTexts.containsKey('rentPeace'), isTrue);
    expect(loadedRentTexts.containsKey('rentLandlordPaidBody'), isTrue);
    expect(rentText('rentPeace').contains('دادگاه صلح'), isTrue);
  });

  test('شناسهٔ ناشناخته بیصدا جایگزین نمیشود', () {
    expect(() => rentText('not_a_rent_text'), throwsStateError);
  });

  test('نسخهٔ ناشناخته داده رد میشود', () {
    expect(
      () => parseRentTexts('{"v": 99, "texts": {"x": "متن"}}'),
      throwsStateError,
    );
  });
}
