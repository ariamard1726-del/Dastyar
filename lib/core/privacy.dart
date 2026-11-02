import 'package:flutter/services.dart';

/// خطای در دسترس نبودن Keystore. پرتاب آن یعنی ذخیرهٔ دادهٔ حساس باید متوقف شود؛
/// هیچ کلید جایگزینی ساخته یا در کنار داده نوشته نمی‌شود.
class KeystoreUnavailableException implements Exception {
  final String message;

  const KeystoreUnavailableException(this.message);

  @override
  String toString() => 'KeystoreUnavailableException: $message';
}

/// لایهٔ حریم خصوصی و رمزنگاری محلی داده‌های حساس (تاریخچه و بازخوردها).
///
/// تنها مسیر مجاز، کلید سخت‌افزاری Android Keystore با AES-256-GCM است
/// (پیشوند `enc1:`). رمزنگاری جایگزینِ مبتنی بر کلید ذخیره‌شده در
/// SharedPreferences به‌طور کامل حذف شده است؛ اگر کانال بومی در دسترس
/// نباشد یا خطا بدهد، [seal] استثنا پرتاب می‌کند و ذخیره‌سازی متوقف
/// می‌شود. هیچ متن رمزنشده یا کلیدی کنار داده نوشته نمی‌شود.
class PrivacyService {
  PrivacyService._();

  static const MethodChannel channel =
      MethodChannel('com.ariabod.dastyar/privacy');

  static const String nativePrefix = 'enc1:';

  static bool isEncrypted(String payload) => payload.startsWith(nativePrefix);

  /// رمزنگاری رشتهٔ متنی پیش از ذخیره در حافظهٔ محلی.
  /// در صورت نبود/خطای Keystore، [KeystoreUnavailableException] پرتاب می‌کند.
  static Future<String> seal(String plain) async {
    final String? res;
    try {
      res = await channel.invokeMethod<String>('seal', <String, Object?>{
        'text': plain,
      });
    } catch (_) {
      throw const KeystoreUnavailableException(
        'کانال Keystore در دسترس نیست یا خطا داد',
      );
    }
    if (res == null || res.isEmpty || !res.startsWith(nativePrefix)) {
      throw const KeystoreUnavailableException(
        'پاسخ معتبری از Keystore دریافت نشد؛ از ذخیرهٔ داده صرف‌نظر شد.',
      );
    }
    return res;
  }

  /// رمزگشایی رشتهٔ ذخیره‌شده. دادهٔ قدیمیِ رمزنشده همان را برمی‌گرداند
  /// تا مهاجرت (فقط در صورت در دسترس بودن Keystore) انجام شود.
  /// payloadهای مربوط به رمزنگاری جایگزین حذف‌شده قابل‌بازیابی نیستند.
  static Future<String?> open(String payload) async {
    if (payload.isEmpty) return '';
    if (!payload.startsWith(nativePrefix)) {
      // payloadهای رمزنگاری جایگزین حذف‌شده (encf1:) قابل‌بازیابی نیستند و
      // هرگز به‌صورت متن آزاد برگردانده نمی‌شوند.
      if (payload.startsWith('encf1:')) return null;
      return payload;
    }
    try {
      final res = await channel.invokeMethod<String>('open', <String, Object?>{
        'payload': payload,
      });
      return (res == null || res.isEmpty) ? null : res;
    } catch (_) {
      return null;
    }
  }

  /// کپی متن در کلیپ‌بورد؛ برای پیش‌نویس‌های حقوقی حاوی اطلاعات شخصی،
  /// در اندروید ۱۳+ پرچم EXTRA_IS_SENSITIVE ثبت می‌شود.
  static Future<void> copyText(String text, {bool sensitive = false}) async {
    if (sensitive) {
      try {
        final ok = await channel.invokeMethod<bool>(
          'copySensitive',
          <String, Object?>{'text': text, 'sensitive': true},
        );
        if (ok == true) return;
      } catch (_) {}
    }
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// فعال یا غیرفعال کردن FLAG_SECURE برای جلوگیری از اسکرین‌شات.
  static Future<void> setSecureScreen(bool enabled) async {
    try {
      await channel.invokeMethod<bool>(
        'setSecureScreen',
        <String, Object?>{'enabled': enabled},
      );
    } catch (_) {}
  }
}
