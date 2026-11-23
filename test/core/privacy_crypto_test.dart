import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/privacy.dart';

/// بردارهای آزمون استاندارد برای SHA-256 و HMAC-SHA256.
///
/// رمزنگاری جایگزین (وقتی Keystore در دسترس نیست) بر همین دو تابع سوار است؛
/// اگر روزی پیاده‌سازی عوض شود، این بردارها تفاوت را نشان می‌دهند.
String hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // مسیر جایگزین (بدون Keystore) کلیدش را در تنظیمات محلی می‌گذارد.
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('SHA-256 بردارهای FIPS 180-4', () {
    expect(
      hex(PrivacyService.sha256(utf8.encode('abc'))),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      hex(PrivacyService.sha256(const [])),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      hex(PrivacyService.sha256(utf8.encode('متن فارسی برای آزمون'))).length,
      64,
    );
  });

  test('HMAC-SHA256 بردار RFC 4231 (مورد ۲)', () {
    expect(
      hex(PrivacyService.hmacSha256(
        utf8.encode('Jefe'),
        utf8.encode('what do ya want for nothing?'),
      )),
      '5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843',
    );
  });

  test('کلید بلندتر از بلوک، اول هش می‌شود (RFC 2104)', () {
    final longKey = List<int>.filled(80, 0xAA);
    final viaHmac = PrivacyService.hmacSha256(longKey, utf8.encode('x'));
    final shortKey = PrivacyService.sha256(longKey);
    expect(
      viaHmac,
      PrivacyService.hmacSha256(shortKey, utf8.encode('x')),
    );
  });

  test('هر دو مسیر رمزنگاری، رفت‌وبرگشت سالم دارند', () async {
    const secret = 'متن محرمانهٔ پروندهٔ چک ۱۲۳۴۵۶';
    final sealed = await PrivacyService.seal(secret);
    expect(PrivacyService.isEncrypted(sealed), isTrue);
    expect(await PrivacyService.open(sealed), secret);
    // داده‌ی دست‌کاری‌شده باز نمی‌شود (احراز اصالت).
    final tampered = sealed.substring(0, sealed.length - 4) + 'AAAA';
    expect(await PrivacyService.open(tampered), isNull);
  });
}
