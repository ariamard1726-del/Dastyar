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

  factory FeedbackEntry.fromJson(Map<String, dynamic> j) => FeedbackEntry(
        (j['q'] ?? '').toString(),
        (j['a'] ?? '').toString(),
        j['v'] == -1 ? -1 : 1,
        (j['t'] ?? 0) as int,
      );
}

class FeedbackStore {
  static const String _key = 'feedback_v1';
  static const int maxEntries = 300;
  static final RegExp _spacesRe = RegExp(r'\s+');

  static String _flat(String s) => s.replaceAll(_spacesRe, ' ').trim();

  /// خلاصهٔ کوتاه پاسخ (برای شناسایی، نه ذخیرهٔ کل متن)
  static String snippet(String a) {
    final s = _flat(a);
    return PersianText.truncate(s, 120);
  }

  static Future<List<FeedbackEntry>> all() async {
    try {
      final p = await SharedPreferences.getInstance();
      final stored = p.getString(_key);
      if (stored == null || stored.isEmpty) return [];
      final wasPlain = !PrivacyService.isEncrypted(stored);
      final raw = await PrivacyService.open(stored);
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List)
          .map((e) => FeedbackEntry.fromJson(e as Map<String, dynamic>))
          .where((e) => e.q.isNotEmpty)
          .toList();
      if (wasPlain && list.isNotEmpty) {
        await _save(list);
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  static Future<bool> _save(List<FeedbackEntry> list) async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = jsonEncode(list.map((e) => e.toJson()).toList());
      final sealed = await PrivacyService.seal(raw);
      return await p.setString(_key, sealed);
    } catch (_) {
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

  static Future<void> clear() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.remove(_key);
    } catch (_) {}
  }

  /// متنی که می‌شود مستقیم کنار brain/eval*.txt گذاشت:
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
