import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/core/privacy_migration.dart';

/// سناریوی آپگرید: کاربری که نسخهٔ قبلش کلید را در SharedPreferences ذخیره
/// میکرد. مهاجرت نباید کرش کند، کلید قدیمی باید پاک شود و داده یا به Keystore
/// منتقل میشود یا fail-closed حذف میشود.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const secret = 'متن محرمانهٔ پروندهٔ چک';
  const key = 'history_v1:m:old';

  final legacyKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PrivacyService.resetEphemeralKeyForTesting();
    messenger.setMockMethodCallHandler(PrivacyService.channel, null);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(PrivacyService.channel, null);
    PrivacyService.resetEphemeralKeyForTesting();
  });

  Future<void> seedOldPayload() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        PrivacyService.legacyFallbackKeyPref, base64Encode(legacyKey));
    PrivacyService.setEphemeralKeyForTesting(legacyKey);
    final old = await PrivacyService.seal(secret);
    expect(old, startsWith(PrivacyService.fallbackPrefix));
    await prefs.setString(key, old);
    PrivacyService.resetEphemeralKeyForTesting();
  }

  test('آپگرید با Keystore: داده دوباره مهروموم و کلید قدیمی پاک میشود', () async {
    await seedOldPayload();
    messenger.setMockMethodCallHandler(PrivacyService.channel, (call) async {
      if (call.method == 'seal') return 'enc1:sealed';
      if (call.method == 'open') return secret;
      return null;
    });

    final report = await PrivacyMigration.run();
    expect(report.migrated, 1);
    expect(report.dropped, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(key), 'enc1:sealed');
    expect(prefs.containsKey(PrivacyService.legacyFallbackKeyPref), isFalse);
    expect(await PrivacyService.open(prefs.getString(key)!), secret);
  });

  test('آپگرید بدون Keystore fail-closed: رکورد حذف میشود، کرش نیست', () async {
    await seedOldPayload();
    final report = await PrivacyMigration.run();
    expect(report.dropped, 1);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.containsKey(key), isFalse);
    expect(prefs.containsKey(PrivacyService.legacyFallbackKeyPref), isFalse);
    expect(await PrivacyService.open('encf1:broken'), isNull);
  });

  test('کلید خراب یا بدنیاز هم اپ را متوقف نمیکند', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(PrivacyService.legacyFallbackKeyPref, 'not-base64!!!');
    await prefs.setString(key, 'encf1:old');
    final report = await PrivacyMigration.run();
    expect(report.badKey, isTrue);
    expect(prefs.containsKey(PrivacyService.legacyFallbackKeyPref), isFalse);
    expect(report.isEmpty, isFalse);
  });
}
