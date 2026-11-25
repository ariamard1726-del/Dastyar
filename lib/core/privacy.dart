import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// لایهٔ حریم خصوصی و رمزنگاری محلی داده‌های حساس (تاریخچه و بازخوردها).
///
/// در اندروید از کلید سخت‌افزاری Android Keystore با الگوریتم AES-256-GCM استفاده می‌کند
/// (`enc1:...`) و در محیط تست یا سکوهای فاقد کانال بومی به رمزنگاری احرازهویت‌شدهٔ
/// محلی (Encrypt-then-MAC با HMAC-SHA256، پیشوند `encf1:...`) برمی‌گردد.
class PrivacyService {
  PrivacyService._();

  static const MethodChannel channel =
      MethodChannel('com.ariabod.dastyar/privacy');

  static const String nativePrefix = 'enc1:';
  static const String fallbackPrefix = 'encf1:';
  static const String legacyFallbackKeyPref = '__dastyar_local_key_v1';

  /// مسیر جایگزین به کار افتاد؟ فراخوانندهها (صفحهٔ وضعیت) حق دارند بدانند
  /// که «رمزنگاری سختافزاری» تنها یک شعار نماند.
  static bool fallbackUsed = false;

  /// علت آخرین استفاده از مسیر جایگزین (یا شکست کانال بومی).
  static String? lastError;

  static void _markFallback(Object? error) {
    fallbackUsed = true;
    lastError = error == null
        ? 'رمزنگاری سختافزاری در دسترس نبود؛ از رمزنگاری جایگزین روی همین '
            'دستگاه استفاده شد. کلید جایگزین فقط در حافظهٔ همین اجرای برنامه '
            'است و دادهها پس از بستهشدن برنامه قابل خواندن نخواهند بود.'
        : 'رمزنگاری سختافزاری خطا داد ($error)؛ از مسیر جایگزین استفاده شد.';
  }

  static bool isEncrypted(String payload) =>
      payload.startsWith(nativePrefix) || payload.startsWith(fallbackPrefix);

  /// رمزنگاری رشتهٔ متنی پیش از ذخیره در حافظهٔ محلی.
  static Future<String> seal(String plain) async {
    try {
      final res =
          await channel.invokeMethod<String>('seal', <String, Object?>{
        'text': plain,
      });
      if (res != null && res.isNotEmpty) return res;
    } on MissingPluginException catch (e) {
      // محیط تست واحد یا سکوی فاقد کانال اندروید
      _markFallback(e);
    } on PlatformException catch (e) {
      // در صورت خطای کانال بومی از رمزنگاری جایگزین استفاده می‌شود
      _markFallback(e);
    }
    return _fallbackSeal(plain);
  }

  /// رمزگشایی رشتهٔ ذخیره‌شده؛ اگر متن قدیمیِ رمزنشده باشد همان را برمی‌گرداند
  /// تا به‌صورت خودکار به قالب رمزنگاری‌شده مهاجرت داده شود.
  static Future<String?> open(String payload) async {
    if (payload.isEmpty) return '';
    if (payload.startsWith(nativePrefix)) {
      try {
        return await channel.invokeMethod<String>('open', <String, Object?>{
          'payload': payload,
        });
      } catch (e) {
        _markFallback(e);
        return null;
      }
    }
    if (payload.startsWith(fallbackPrefix)) {
      _markFallback(null);
      return _fallbackOpen(payload);
    }
    // دادهٔ قدیمیِ رمزنشده (مهاجرت شفاف)
    return payload;
  }

  /// کپی متن در کلیپ‌بورد؛ برای پیش‌نویس‌های حقوقی حاوی اطلاعات شخصی، در اندروید ۱۳+
  /// پرچم EXTRA_IS_SENSITIVE ثبت می‌شود تا پیش‌نمایش و تاریخچهٔ کیبورد مخفی بماند.
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

  /// فعال یا غیرفعال کردن FLAG_SECURE برای جلوگیری از اسکرین‌شات و مخفی‌سازی در اپ‌های اخیر.
  /// روشن/خاموش کردن محافظت صفحه.
  ///
  /// خروجی `false` یعنی کانال بومی خطا داد یا اجازه نداد؛ پیش‌تر خطا بلعیده
  /// می‌شد و تیکِ «محافظت از صفحه» دروغ می‌گفت.
  static Future<bool> setSecureScreen(bool enabled) async {
    try {
      final ok = await channel.invokeMethod<bool>(
        'setSecureScreen',
        <String, Object?>{'enabled': enabled},
      );
      return ok == true;
    } catch (_) {
      return false;
    }
  }

  // ---------- رمزنگاری احرازهویت‌شدهٔ جایگزین (HMAC-SHA256 + CTR) ----------

  /// کلید تنها در حافظهٔ همین isolate زندگی میکند: نه در SharedPreferences،
  /// نه در دیسک. [Random.secure] در صورت نبود منبع تصادفی خطا میدهد و رمزنگاری
  /// متوقف میشود؛ تولید کلید قابلپیشبینی راه حل نیست.
  static Uint8List? _ephemeralKey;

  static Uint8List _fallbackKey() {
    if (_ephemeralKey != null) return _ephemeralKey!;
    final rnd = Random.secure();
    return _ephemeralKey = Uint8List.fromList(
      List<int>.generate(32, (_) => rnd.nextInt(256)),
    );
  }

  /// شبیهسازِ «برنامه بسته و دوباره باز شد» در آزمونها. data-های مهرومومشدهٔ
  /// اجرای قبل دیگر باز نمیشوند (fail-closed).
  static void resetEphemeralKeyForTesting() => _ephemeralKey = null;

  /// شبیهسازیِ کلیدِ نسخهٔ قدیمی برای آزمون مهاجرت.
  static void setEphemeralKeyForTesting(List<int> key) =>
      _ephemeralKey = Uint8List.fromList(key);

  /// باز کردن payload قدیمی `encf1:` با کلیدی که نسخهٔ قبل در prefs میگذاشت.
  /// فقط توسط لایهٔ مهاجرت یکبار خوانده میشود؛ مسیر عادی [open] هرگز از کلید
  /// ذخیرهشده استفاده نمیکند.
  static String? openLegacyPayload(String payload, List<int> masterKey) {
    if (!payload.startsWith(fallbackPrefix)) return null;
    final raw0 = _decodeFallback(payload);
    if (raw0 == null) return null;
    return _openWithKey(raw0, masterKey);
  }

  static List<int>? _decodeFallback(String payload) {
    try {
      final raw = base64Decode(payload.substring(fallbackPrefix.length));
      return raw.length >= 48 ? raw : null;
    } catch (_) {
      return null;
    }
  }

  static String? _openWithKey(List<int> raw, List<int> masterKey) {
    try {
      final nonce = Uint8List.sublistView(raw, 0, 16);
      final tag = Uint8List.sublistView(raw, 16, 48);
      final ct = Uint8List.sublistView(raw, 48);
      final encKey = hmacSha256(masterKey, utf8.encode('enc'));
      final macKey = hmacSha256(masterKey, utf8.encode('mac'));
      final macInput = Uint8List(nonce.length + ct.length)
        ..setRange(0, nonce.length, nonce)
        ..setRange(nonce.length, nonce.length + ct.length, ct);
      final expectedTag = hmacSha256(macKey, macInput);
      var diff = 0;
      for (var i = 0; i < 32; i++) {
        diff |= tag[i] ^ expectedTag[i];
      }
      if (diff != 0) return null;
      return utf8.decode(_xorKeystream(encKey, nonce, ct));
    } catch (_) {
      return null;
    }
  }

  /// پاک کردن کلید قدیمی که نسخههای پیشین در SharedPreferences می نوشتند.
  /// خواندن آن کلید دوباره رواج نمیدهد؛ فقط اثر امنیتی آن را حذف میکند.
  static Future<void> discardLegacyKey() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(legacyFallbackKeyPref)) {
      await prefs.remove(legacyFallbackKeyPref);
    }
  }

  static Future<String> _fallbackSeal(String plain) async {
    final masterKey = _fallbackKey();
    final encKey = hmacSha256(masterKey, utf8.encode('enc'));
    final macKey = hmacSha256(masterKey, utf8.encode('mac'));

    final rnd = Random.secure();
    final nonce = Uint8List.fromList(
      List<int>.generate(16, (_) => rnd.nextInt(256)),
    );
    final pt = Uint8List.fromList(utf8.encode(plain));
    final ct = _xorKeystream(encKey, nonce, pt);

    final macInput = Uint8List(nonce.length + ct.length)
      ..setRange(0, nonce.length, nonce)
      ..setRange(nonce.length, nonce.length + ct.length, ct);
    final tag = hmacSha256(macKey, macInput);

    final packed = Uint8List(nonce.length + tag.length + ct.length)
      ..setRange(0, 16, nonce)
      ..setRange(16, 48, tag)
      ..setRange(48, 48 + ct.length, ct);
    return '$fallbackPrefix${base64Encode(packed)}';
  }

  static Future<String?> _fallbackOpen(String payload) async {
    final raw = _decodeFallback(payload);
    return raw == null ? null : _openWithKey(raw, _fallbackKey());
  }

  static Uint8List _xorKeystream(
    Uint8List encKey,
    Uint8List nonce,
    Uint8List data,
  ) {
    final out = Uint8List(data.length);
    final blockInput = Uint8List(20)..setRange(0, 16, nonce);
    var offset = 0;
    var counter = 0;
    while (offset < data.length) {
      blockInput[16] = (counter >>> 24) & 0xFF;
      blockInput[17] = (counter >>> 16) & 0xFF;
      blockInput[18] = (counter >>> 8) & 0xFF;
      blockInput[19] = counter & 0xFF;
      final stream = hmacSha256(encKey, blockInput);
      final take = min(32, data.length - offset);
      for (var i = 0; i < take; i++) {
        out[offset + i] = data[offset + i] ^ stream[i];
      }
      offset += take;
      counter++;
    }
    return out;
  }

  // ---------- SHA-256 و HMAC-SHA256 ----------
  //
  // پیش‌تر این دو تابع دست‌نویس بودند (۳۰۰ خط). رمزنگاری دست‌نویس، هرقدر
  // هم درست، یک ریسک است: یک اشتباه در پدینگ یا چرخش بیت، خروجی را بی‌آنکه
  // کسی بفهمد عوض می‌کند. اکنون از بستهٔ رسمی `crypto` استفاده می‌شود و
  // بردارهای آزمون RFC در `test/core/privacy_crypto_test.dart` قفل‌اند.

  static Uint8List sha256(List<int> message) =>
      Uint8List.fromList(crypto.sha256.convert(message).bytes);

  static Uint8List hmacSha256(List<int> key, List<int> data) =>
      Uint8List.fromList(crypto.Hmac(crypto.sha256, key).convert(data).bytes);
}
