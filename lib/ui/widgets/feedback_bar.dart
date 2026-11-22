import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/domain/feedback.dart';

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
      await PrivacyService.copyText(text, sensitive: true);
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
