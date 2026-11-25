import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/privacy.dart';

/// نتیجهٔ مهاجرتِ یکبارۀ کلید/دادههای نسخهٔ پیشین.
class PrivacyMigrationReport {
  const PrivacyMigrationReport({
    this.migrated = 0,
    this.dropped = 0,
    this.badKey = false,
  });

  final int migrated;
  final int dropped;
  final bool badKey;

  bool get isEmpty => migrated == 0 && dropped == 0 && !badKey;

  @override
  String toString() => 'migrated=$migrated dropped=$dropped badKey=$badKey';
}

/// لایهٔ مهاجرتِ آپگرید.
///
/// نسخههای پیشین کلید `encf1:` را در SharedPreferences می نوشتند. این لایه
/// یکبار آن کلید را میخواند، متنها را با همان کلید باز میکند و دوباره با
/// Keystore بومی مهروموم میکند. اگر Keystore دردسترس نبود یا متن خراب بود،
/// رکورد **حذف** میشود (fail-closed) تا دادهٔ ناامن روی دستگاه نماند. در هر
/// حالت کلید قدیمی پاک میشود و اپ خاموش نمیشود.
class PrivacyMigration {
  PrivacyMigration._();

  static Future<PrivacyMigrationReport> run() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawKey = prefs.getString(PrivacyService.legacyFallbackKeyPref);
      if (rawKey == null) return const PrivacyMigrationReport();

      List<int>? key;
      try {
        final decoded = base64Decode(rawKey);
        if (decoded.length == 32) key = decoded;
      } catch (_) {}

      if (key == null) {
        await prefs.remove(PrivacyService.legacyFallbackKeyPref);
        return const PrivacyMigrationReport(badKey: true);
      }

      var migrated = 0;
      var dropped = 0;
      for (final k in prefs.getKeys().toList()) {
        final value = prefs.getString(k);
        if (value == null || !value.startsWith(PrivacyService.fallbackPrefix)) {
          continue;
        }
        final plain = PrivacyService.openLegacyPayload(value, key);
        if (plain == null) {
          await prefs.remove(k);
          dropped++;
          continue;
        }
        // `seal` روی اندروید Keystore میدهد؛ جایی که نیست، اپ یک کلید
        // موقت میسازد و ما آن رکورد را حذف میکنیم تا با کلید ضعیف باقی نماند.
        final sealed = await PrivacyService.seal(plain);
        if (sealed.startsWith(PrivacyService.fallbackPrefix)) {
          await prefs.remove(k);
          dropped++;
        } else {
          await prefs.setString(k, sealed);
          migrated++;
        }
      }
      await prefs.remove(PrivacyService.legacyFallbackKeyPref);
      return PrivacyMigrationReport(migrated: migrated, dropped: dropped);
    } catch (_) {
      // مهاجرت نباید جلوی بالاآمدن اپ بگیرد؛ پرچم fallback همانجا دیده میشود.
      return const PrivacyMigrationReport(badKey: true);
    }
  }
}
