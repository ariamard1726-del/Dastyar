import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/contradiction.dart';

/// تناقض‌یابی محتوایی (فاز ۴): نفیِ صریحِ شرط در همان جملهٔ خودش دیده می‌شود؛
/// نفیِ یک موضوع به موضوعِ همسایه نمی‌چسبد.
void main() {
  test('نفی صریح شرط شناسایی می‌شود', () {
    expect(Contradiction.negates('قرارداد کتبی ندارم', 'قرارداد کتبی'), isTrue);
    expect(Contradiction.negates('بیمه ام را نمی کنند', 'بیمه'), isTrue);
    expect(Contradiction.negates('شاهدی ندارم', 'شاهد'), isTrue);
  });

  test('وجود شرط تناقض نیست', () {
    expect(Contradiction.negates('قرارداد کتبی دارم', 'قرارداد کتبی'), isFalse);
    expect(Contradiction.negates('بیمه ام را می کنند', 'بیمه'), isFalse);
    expect(Contradiction.negates('قرارداد کتبی امضا شد', 'قرارداد کتبی'), isFalse);
  });

  test('نفی در جملهٔ همسایه شرط را رد نمی‌کند', () {
    expect(
      Contradiction.negates('شاهدی ندارم. قرارداد کتبی دارم', 'قرارداد کتبی'),
      isFalse,
    );
    expect(
      Contradiction.negates('قرارداد کتبی دارم. شاهدی ندارم', 'شاهد'),
      isTrue,
    );
  });

  test('negatedCues فهرست شرط‌های نفی‌شده را برمی‌گرداند', () {
    expect(
      Contradiction.negatedCues('قرارداد کتبی ندارم و شاهدم نیست',
          ['قرارداد کتبی', 'شاهد', 'رسید']),
      ['قرارداد کتبی', 'شاهد'],
    );
  });
}
