import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/privacy.dart';

/// یک نظر کاربر دربارهٔ یک پاسخ. فقط روی همین گوشی (به‌صورت رمزنگاری‌شده) ذخیره می‌شود.
class FeedbackEntry {
  final String q;
  final String a;
  final int vote; // +1 مفید، -1 نامفید
  final int at;

  FeedbackEntry(this.q, this.a, this.vote, this.at);

  Map<String, dynamic> toJson() => {'q': q, 'a': a, 'v': vote, 't': at};

  factory FeedbackEntry.fromJson(Map<String, dynamic> j) {
    final rawTime = j['t'];
    return FeedbackEntry(
      (j['q'] ?? '').toString(),
      (j['a'] ?? '').toString(),
      j['v'] == -1 ? -1 : 1,
      rawTime is int ? rawTime : (rawTime is num ? rawTime.toInt() : 0),
    );
  }
}

class FeedbackStore {
  static const String _key = 'feedback_v1';
  static const int schemaVersion = 1;
  static const int maxEntries = 300;
  static final RegExp _spacesRe = RegExp(r'\s+');

  /// علت آخرین خطای خواندن، نوشتن یا پاک‌کردن بازخوردها (در صورت موفقیت `null`).
  static String? lastError;

  static String _flat(String s) => s.replaceAll(_spacesRe, ' ').trim();

  /// خلاصهٔ کوتاه پاسخ (برای شناسایی، نه ذخیرهٔ کل متن)
  static String snippet(String a) {
    final s = _flat(a);
    return PersianText.truncate(s, 120);
  }

  static Future<List<FeedbackEntry>> all() async {
    lastError = null;
    try {
      final p = await SharedPreferences.getInstance();
      final stored = p.getString(_key);
      if (stored == null || stored.isEmpty) return [];
      final wasPlain = !PrivacyService.isEncrypted(stored);
      final raw = await PrivacyService.open(stored);
      if (raw == null || raw.isEmpty) {
        // کلید موقت اجرای پیشین (`encf1:`) از میان رفته؛ نگهداشتن رکورد
        // بیفایده است و دوباره نوشتنش همان وعدهٔ دروغین را تکرار میکند.
        if (stored.startsWith(PrivacyService.fallbackPrefix)) {
          await p.remove(_key);
        } else {
          lastError = PrivacyService.lastError ?? 'بازگشایی بازخوردها ممکن نشد.';
        }
        return [];
      }
      final decoded = jsonDecode(raw);
      final List<dynamic> rawEntries;
      var needsMigration = false;
      if (decoded is List) {
        rawEntries = decoded;
        needsMigration = true;
      } else if (decoded is Map) {
        final v = decoded['v'];
        if (v is int && v > schemaVersion) return [];
        final entries = decoded['entries'];
        if (entries is! List) {
          lastError = 'ساختار فهرست بازخوردها معتبر نیست.';
          return [];
        }
        rawEntries = entries;
        needsMigration = v != schemaVersion;
      } else {
        lastError = 'قالب بازخورد ذخیره‌شده معتبر نیست.';
        return [];
      }
      final list = rawEntries
          .whereType<Map>()
          .map((e) => FeedbackEntry.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.q.isNotEmpty)
          .toList();
      if ((wasPlain || needsMigration) && list.isNotEmpty) {
        await _save(list);
      }
      return list;
    } catch (e) {
      lastError = 'خواندن بازخوردها: $e';
      return [];
    }
  }

  static Future<bool> _save(List<FeedbackEntry> list) async {
    if (!PrivacyService.persistenceAllowed) {
      lastError = 'ذخیرهٔ بازخورد غیرفعال است: رمزنگاری بومی دردسترس نیست.';
      return false;
    }
    try {
      final p = await SharedPreferences.getInstance();
      final raw = jsonEncode({
        'v': schemaVersion,
        'entries': list.map((e) => e.toJson()).toList(),
      });
      final sealed = await PrivacyService.seal(raw);
      if (sealed.isEmpty) {
        lastError = PrivacyService.lastError ?? 'رمزنگاری بازخوردها انجام نشد.';
        return false;
      }
      final ok = await p.setString(_key, sealed);
      if (!ok) {
        lastError = 'نوشتن بازخوردها روی حافظه انجام نشد.';
      }
      return ok;
    } catch (e) {
      lastError = 'ذخیرهٔ بازخوردها: $e';
      return false;
    }
  }

  static Future<bool> add(String question, String answer, int vote) async {
    final q = _flat(question);
    if (q.isEmpty) return false;
    final a = snippet(answer);
    final list = await all();
    list.removeWhere((e) => e.q == q && e.a == a);
    list.add(FeedbackEntry(q, a, vote, DateTime.now().millisecondsSinceEpoch));
    if (list.length > maxEntries) {
      list.removeRange(0, list.length - maxEntries);
    }
    return _save(list);
  }

  static Future<bool> clear() async {
    lastError = null;
    try {
      final p = await SharedPreferences.getInstance();
      final ok = await p.remove(_key);
      if (!ok) {
        lastError = 'حذف بازخوردها از حافظه انجام نشد.';
      }
      return ok;
    } catch (e) {
      lastError = 'پاک‌کردن بازخوردها: $e';
      return false;
    }
  }

  /// متنی که می‌شود مستقیم کنار eval*.txt گذاشت:
  /// هر خطِ بدون # یک سطر ارزیابی است («پرسش | قانون | ماده»).
  static String exportText(List<FeedbackEntry> list) {
    final b = StringBuffer();
    b.writeln('# نظرات ذخیره‌شده روی همین گوشی.');
    b.writeln('# هر خط بدون # یک پرسش است؛ به‌جای ؟ قانون و ماده‌ی درست را بنویسید.');
    for (final e in list.where((e) => e.vote < 0)) {
      final q = e.q.replaceAll('|', ' ');
      b.writeln('# 👎 پاسخ برنامه: ${e.a}');
      b.writeln('$q | ؟ | ؟');
    }
    final good = list.where((e) => e.vote > 0).toList();
    if (good.isNotEmpty) {
      b.writeln('# --- پاسخ‌های مفید ---');
      for (final e in good) {
        final q = e.q.replaceAll('|', ' ');
        b.writeln('# 👍 $q ← ${e.a}');
      }
    }
    return b.toString();
  }
}
