import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// پاک‌سازی یک‌بارهٔ ردّ قابلیت‌هایی که از برنامه حذف شده‌اند.
///
/// نسخه‌های قبلی می‌توانستند یک مدل زبانی (فایلی چندصد مگابایتی) روی گوشی
/// نصب کنند و مشاورهٔ نیمه‌کاره را رمزنگاری‌شده نگه دارند. حالا که هیچ‌کدام
/// در برنامه نیست، آن فایل و آن داده نباید بی‌صدا روی گوشی کاربر بماند.
class LegacyCleanup {
  LegacyCleanup._();

  /// نشانهٔ «پاک‌سازی انجام شد» تا در هر اجرا تکرار نشود.
  static const String doneKey = 'legacy_cleanup_v1';

  /// کلیدهای تنظیماتی که دیگر خوانده نمی‌شوند.
  static const List<String> staleKeys = [
    'llm_model_id',
    'llm_model_path',
    'llm_model_template',
    'useLocalLlm',
    'active_counsel_v1',
  ];

  static const MethodChannel _channel =
      MethodChannel('com.ariabod.dastyar/model');

  /// `true` یعنی کار تمام است و بار بعد لازم نیست تکرار شود.
  static Future<bool> run() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(doneKey) ?? false) return true;
      var filesGone = true;
      try {
        // پوشهٔ مدل را خودِ اندروید پاک می‌کند (فقط `files/models` برنامه).
        filesGone = await _channel.invokeMethod<bool>('purgeModels') ?? false;
      } on MissingPluginException {
        // سکویی که هرگز مدل نصب نمی‌کرده؛ فایلی برای پاک‌کردن نیست.
      }
      for (final k in staleKeys) {
        await p.remove(k);
      }
      if (filesGone) await p.setBool(doneKey, true);
      return filesGone;
    } catch (_) {
      // پاک‌سازی نباید جلوی بالاآمدن برنامه را بگیرد؛ بار بعد دوباره تلاش می‌شود.
      return false;
    }
  }
}
