import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/assistant.dart';
import 'package:dastyar/engine.dart';

Hit _hit(String title, String body) => Hit(
      Chunk('civil', 'قانون مدنی', '', title, body, false, {}, {}, {}, 10),
      1.0,
    );

void main() {
  test('شمارهٔ ماده‌ای که در متن‌ها هست پذیرفته می‌شود', () {
    final ctx = [_hit('ماده ۱۰', 'قراردادهای خصوصی نافذ است')];
    expect(Assistant.isGrounded('طبق ماده ۱۰ نافذ است', ctx), isTrue);
  });

  test('شمارهٔ مادهٔ ساختگی رد می‌شود', () {
    final ctx = [_hit('ماده ۱۰', 'قراردادهای خصوصی نافذ است')];
    expect(Assistant.isGrounded('طبق ماده ۹۹۹ نافذ است', ctx), isFalse);
  });

  test('پاسخ بدون شمارهٔ ماده مشکلی ندارد', () {
    final ctx = [_hit('ماده ۱۰', 'متن')];
    expect(Assistant.isGrounded('در دانش من نیست', ctx), isTrue);
  });
}
