import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// یک نظر کاربر دربارهٔ یک پاسخ. فقط روی همین گوشی ذخیره می‌شود.
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

  static String _flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  /// خلاصهٔ کوتاه پاسخ (برای شناسایی، نه ذخیرهٔ کل متن)
  static String snippet(String a) {
    final s = _flat(a);
    return s.length > 120 ? s.substring(0, 120) : s;
  }

  static Future<List<FeedbackEntry>> all() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      return (jsonDecode(raw) as List)
          .map((e) => FeedbackEntry.fromJson(e as Map<String, dynamic>))
          .where((e) => e.q.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<bool> _save(List<FeedbackEntry> list) async {
    try {
      final p = await SharedPreferences.getInstance();
      return await p.setString(
        _key,
        jsonEncode(list.map((e) => e.toJson()).toList()),
      );
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

/// دکمه‌های 👍/👎 و منوی صدور/پاک‌کردن نظرها، زیر پاسخ‌های عادی.
class FeedbackBar extends StatefulWidget {
  final String question;
  final String answer;

  const FeedbackBar({super.key, required this.question, required this.answer});

  @override
  State<FeedbackBar> createState() => _FeedbackBarState();
}

class _FeedbackBarState extends State<FeedbackBar> {
  int _vote = 0;

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _set(int v) async {
    setState(() => _vote = v);
    final ok = await FeedbackStore.add(widget.question, widget.answer, v);
    _snack(ok ? 'نظر شما فقط روی همین گوشی ذخیره شد' : 'ذخیره نشد');
  }

  Future<void> _export() async {
    final list = await FeedbackStore.all();
    if (list.isEmpty) {
      _snack('هنوز نظری ثبت نشده است');
      return;
    }
    final text = FeedbackStore.exportText(list);
    try {
      await Share.share(text, subject: 'نظرات دستیار');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      _snack('اشتراک‌گذاری انجام نشد؛ متن کپی شد');
    }
  }

  Future<void> _clear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const Text('همهٔ نظرهای ذخیره‌شده پاک شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('پاک شود'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await FeedbackStore.clear();
      _snack('نظرها پاک شد');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.question.trim().isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'مفید بود',
          icon: Icon(
            _vote > 0 ? Icons.thumb_up : Icons.thumb_up_outlined,
            size: 18,
          ),
          onPressed: () => _set(1),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'مفید نبود',
          icon: Icon(
            _vote < 0 ? Icons.thumb_down : Icons.thumb_down_outlined,
            size: 18,
          ),
          onPressed: () => _set(-1),
        ),
        PopupMenuButton<String>(
          tooltip: 'نظرها',
          padding: EdgeInsets.zero,
          icon: const Icon(Icons.more_vert, size: 18),
          onSelected: (v) {
            if (v == 'export') {
              _export();
            } else {
              _clear();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'export', child: Text('صدور نظرها')),
            PopupMenuItem(value: 'clear', child: Text('پاک‌کردن نظرها')),
          ],
        ),
      ],
    );
  }
}
