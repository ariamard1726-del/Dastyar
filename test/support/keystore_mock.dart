import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/privacy.dart';

/// شبیه‌ساز کانال بومی Android Keystore برای تست‌ها.
///
/// لایهٔ رمزنگاری جایگزین حذف شده است؛ بدون این شبیه‌ساز،
/// `PrivacyService.seal` عمداً خطا می‌دهد و هیچ داده‌ای ذخیره نمی‌شود.
void mockKeystore({bool fail = false}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(PrivacyService.channel, (call) async {
    if (fail) {
      throw PlatformException(
        code: 'KEYSTORE_UNAVAILABLE',
        message: 'Keystore در دسترس نیست',
      );
    }
    switch (call.method) {
      case 'seal':
        final text = (call.arguments as Map)['text'] as String;
        return '${PrivacyService.nativePrefix}'
            '${base64Encode(utf8.encode(text))}';
      case 'open':
        final payload = (call.arguments as Map)['payload'] as String;
        if (!payload.startsWith(PrivacyService.nativePrefix)) return null;
        return utf8.decode(base64Decode(
          payload.substring(PrivacyService.nativePrefix.length),
        ));
      case 'copySensitive':
      case 'setSecureScreen':
        return true;
      default:
        return null;
    }
  });
}

/// حذف شبیه‌ساز (برای تست‌هایی که خودشان کانال را تنظیم می‌کنند).
void clearKeystoreMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(PrivacyService.channel, null);
}
