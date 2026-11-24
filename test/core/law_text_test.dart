import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/law_text.dart';
import 'package:dastyar/core/models.dart';
import 'package:dastyar/core/replies.dart';

/// نوشتنِ متنِ ماده هیچ تصمیمی نمی‌گیرد؛ پس نباید برای آزمودنش کلِ بانک
/// بالا بیاید.
void main() {
  final text = LawText(
    meta: {
      'labor': {'date': '1403/01/02', 'status': 'verified'},
    },
    replies: Replies(),
    catalog: [
      CatalogLaw('labor', 'قانون کار', 'c', 1, const []),
      CatalogLaw('penal', 'قانون مجازات', 'c', 1, const []),
    ],
    lawCountOf: (id) => id == 'labor' ? 2 : 0,
  );

  const chunk = Chunk('labor', 'قانون کار', 'فصل اول', 'ماده ۱', 'متن ماده',
      false, {}, {}, {}, 3);

  test('ماده با منبع و تاریخ نوشته می‌شود', () {
    final s = text.format(chunk);
    expect(s, contains('ماده ۱'));
    expect(s, contains('منبع: قانون کار'));
    expect(s, contains('تاریخ دریافت متن'));
    expect(s, isNot(contains('تطبیق داده نشده')));
  });

  test('نوشتهٔ ناتأیید اعلام می‌شود', () {
    const raw = Chunk('penal', 'قانون مجازات', '', 'ماده ۲', 'متن', false, {}, {},
        {}, 2);
    expect(text.format(raw), contains('تطبیق داده نشده'));
  });

  test('فهرستِ قوانین فقط متن‌های موجود را می‌شمارد', () {
    final s = text.lawList();
    expect(s, contains('قانون کار'));
    expect(s, isNot(contains('قانون مجازات')));
    expect(s, contains('قانون دیگر در فهرست'));
  });
}
