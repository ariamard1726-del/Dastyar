import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

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
  static const String _fallbackKeyPref = '__dastyar_local_key_v1';

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
    } on MissingPluginException {
      // محیط تست واحد یا سکوی فاقد کانال اندروید
    } on PlatformException {
      // در صورت خطای کانال بومی از رمزنگاری جایگزین استفاده می‌شود
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
      } catch (_) {
        return null;
      }
    }
    if (payload.startsWith(fallbackPrefix)) {
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
  static Future<void> setSecureScreen(bool enabled) async {
    try {
      await channel.invokeMethod<bool>(
        'setSecureScreen',
        <String, Object?>{'enabled': enabled},
      );
    } catch (_) {}
  }

  // ---------- رمزنگاری احرازهویت‌شدهٔ جایگزین (HMAC-SHA256 + CTR) ----------

  static Future<Uint8List> _getOrCreateFallbackKey() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_fallbackKeyPref);
    if (existing != null && existing.isNotEmpty) {
      try {
        final decoded = base64Decode(existing);
        if (decoded.length == 32) return decoded;
      } catch (_) {}
    }
    final rnd = _secureOrFallbackRandom();
    final key = Uint8List.fromList(
      List<int>.generate(32, (_) => rnd.nextInt(256)),
    );
    await prefs.setString(_fallbackKeyPref, base64Encode(key));
    return key;
  }

  static Random _secureOrFallbackRandom() {
    try {
      return Random.secure();
    } catch (_) {
      return Random();
    }
  }

  static Future<String> _fallbackSeal(String plain) async {
    final masterKey = await _getOrCreateFallbackKey();
    final encKey = hmacSha256(masterKey, utf8.encode('enc'));
    final macKey = hmacSha256(masterKey, utf8.encode('mac'));

    final rnd = _secureOrFallbackRandom();
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
    try {
      final raw = base64Decode(payload.substring(fallbackPrefix.length));
      if (raw.length < 48) return null;
      final nonce = Uint8List.sublistView(raw, 0, 16);
      final tag = Uint8List.sublistView(raw, 16, 48);
      final ct = Uint8List.sublistView(raw, 48);

      final masterKey = await _getOrCreateFallbackKey();
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

      final pt = _xorKeystream(encKey, nonce, ct);
      return utf8.decode(pt);
    } catch (_) {
      return null;
    }
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

  // ---------- پیاده‌سازی استاندارد SHA-256 و HMAC-SHA256 (FIPS 180-4 / RFC 2104) ----------

  static const List<int> _k256 = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static int _rotr32(int x, int n) =>
      ((x & 0xFFFFFFFF) >>> n) | ((x << (32 - n)) & 0xFFFFFFFF);

  static Uint8List sha256(List<int> message) {
    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    final msgLen = message.length;
    final bitLen = msgLen * 8;
    final padLen = ((56 - (msgLen + 1) % 64) + 64) % 64;
    final totalLen = msgLen + 1 + padLen + 8;
    final padded = Uint8List(totalLen);
    padded.setRange(0, msgLen, message);
    padded[msgLen] = 0x80;

    final bd = ByteData.sublistView(padded);
    bd.setUint32(totalLen - 8, (bitLen ~/ 0x100000000) & 0xFFFFFFFF);
    bd.setUint32(totalLen - 4, bitLen & 0xFFFFFFFF);

    final w = Uint32List(64);
    for (var chunk = 0; chunk < totalLen; chunk += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = bd.getUint32(chunk + i * 4);
      }
      for (var i = 16; i < 64; i++) {
        final s0 =
            _rotr32(w[i - 15], 7) ^ _rotr32(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        final s1 =
            _rotr32(w[i - 2], 17) ^ _rotr32(w[i - 2], 19) ^ (w[i - 2] >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xFFFFFFFF;
      }

      var a = h0;
      var b = h1;
      var c = h2;
      var d = h3;
      var e = h4;
      var f = h5;
      var g = h6;
      var h = h7;

      for (var i = 0; i < 64; i++) {
        final s1 = _rotr32(e, 6) ^ _rotr32(e, 11) ^ _rotr32(e, 25);
        final ch = (e & f) ^ ((~e & 0xFFFFFFFF) & g);
        final temp1 = (h + s1 + ch + _k256[i] + w[i]) & 0xFFFFFFFF;
        final s0 = _rotr32(a, 2) ^ _rotr32(a, 13) ^ _rotr32(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xFFFFFFFF;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xFFFFFFFF;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xFFFFFFFF;
      }

      h0 = (h0 + a) & 0xFFFFFFFF;
      h1 = (h1 + b) & 0xFFFFFFFF;
      h2 = (h2 + c) & 0xFFFFFFFF;
      h3 = (h3 + d) & 0xFFFFFFFF;
      h4 = (h4 + e) & 0xFFFFFFFF;
      h5 = (h5 + f) & 0xFFFFFFFF;
      h6 = (h6 + g) & 0xFFFFFFFF;
      h7 = (h7 + h) & 0xFFFFFFFF;
    }

    final out = Uint8List(32);
    final outBd = ByteData.sublistView(out);
    outBd.setUint32(0, h0);
    outBd.setUint32(4, h1);
    outBd.setUint32(8, h2);
    outBd.setUint32(12, h3);
    outBd.setUint32(16, h4);
    outBd.setUint32(20, h5);
    outBd.setUint32(24, h6);
    outBd.setUint32(28, h7);
    return out;
  }

  static Uint8List hmacSha256(List<int> key, List<int> data) {
    final k = key.length > 64 ? sha256(key) : key;
    final keyBlock = Uint8List(64);
    keyBlock.setRange(0, k.length, k);

    final inner = Uint8List(64 + data.length);
    final outer = Uint8List(64 + 32);
    for (var i = 0; i < 64; i++) {
      inner[i] = keyBlock[i] ^ 0x36;
      outer[i] = keyBlock[i] ^ 0x5c;
    }
    inner.setRange(64, 64 + data.length, data);
    final innerHash = sha256(inner);
    outer.setRange(64, 96, innerHash);
    return sha256(outer);
  }
}
