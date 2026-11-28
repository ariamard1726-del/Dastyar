import 'package:dastyar/core/local_store.dart';
import 'package:dastyar/core/privacy.dart';

/// گزارش مهاجرت یک‌باره از انبار کلید-مقدار پیشین به انبار هدف.
class StorageMigrationReport {
  const StorageMigrationReport({
    this.copied = 0,
    this.skippedEphemeral = 0,
    this.removedFromSource = 0,
    this.alreadyMigrated = false,
    this.error,
  });

  final int copied;
  final int skippedEphemeral;
  final int removedFromSource;
  final bool alreadyMigrated;
  final String? error;

  bool get ok => error == null;
}

/// مهاجرت یک‌بارهٔ داده‌های حساس برنامه بین دو [KeyValueStore].
///
/// کلیدهای تاریخچه (`history_v1` و `history_v1:m:*`)، پیش‌نویس ناتمام
/// (`active_draft_v1`) و بازخوردها (`feedback_v1`) را به‌صورت یکتا و بدون
/// بازنویسیِ مجدد (idempotent) به انبار تازه منتقل می‌کند و محموله‌های
/// کلید موقت (`encf1:`) را بدون انتقالِ ناامن رد می‌کند.
class StorageMigration {
  StorageMigration._();

  static const String doneKey = 'storage_migrated_v1';
  static const String historyIndexKey = 'history_v1';
  static const String historyItemPrefix = 'history_v1:m:';
  static const String draftKey = 'active_draft_v1';
  static const String feedbackKey = 'feedback_v1';

  static bool isManagedKey(String key) =>
      key == historyIndexKey ||
      key.startsWith(historyItemPrefix) ||
      key == draftKey ||
      key == feedbackKey;

  static Future<StorageMigrationReport> migrateOneShot({
    required KeyValueStore from,
    required KeyValueStore to,
    bool removeFromSource = false,
  }) async {
    try {
      return await to.runTransaction((tx) async {
        if (await tx.getString(doneKey) == '1') {
          return const StorageMigrationReport(alreadyMigrated: true);
        }

        final keys = (await from.getKeys())
            .where(isManagedKey)
            .toList()
          ..sort();

        var copied = 0;
        var skippedEphemeral = 0;
        final cleanup = <String>[];

        for (final key in keys) {
          final value = await from.getString(key);
          if (value == null || value.isEmpty) continue;
          if (value.startsWith(PrivacyService.fallbackPrefix)) {
            skippedEphemeral++;
            cleanup.add(key);
            continue;
          }
          final existing = await tx.getString(key);
          if (existing == null || existing.isEmpty) {
            final wrote = await tx.setString(key, value);
            if (!wrote) {
              return StorageMigrationReport(
                copied: copied,
                skippedEphemeral: skippedEphemeral,
                error: 'نوشتن کلید $key در انبار مقصد انجام نشد.',
              );
            }
            copied++;
          }
          cleanup.add(key);
        }

        final marked = await tx.setString(doneKey, '1');
        if (!marked) {
          return StorageMigrationReport(
            copied: copied,
            skippedEphemeral: skippedEphemeral,
            error: 'ثبت نشانهٔ اتمام مهاجرت انجام نشد.',
          );
        }

        var removed = 0;
        if (removeFromSource) {
          for (final key in cleanup) {
            if (await from.remove(key)) removed++;
          }
        }
        return StorageMigrationReport(
          copied: copied,
          skippedEphemeral: skippedEphemeral,
          removedFromSource: removed,
        );
      });
    } catch (e) {
      return StorageMigrationReport(error: 'خطای مهاجرت انبار: $e');
    }
  }
}
