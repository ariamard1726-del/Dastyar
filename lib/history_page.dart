import 'package:flutter/material.dart';

import 'history.dart';
import 'templates.dart';

class HistoryPage extends StatefulWidget {
  final HistoryStore history;
  const HistoryPage({super.key, required this.history});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  Future<void> _delete(ChatSession s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف گفتگو'),
        content: Text('«${s.title}» حذف شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.history.delete(s.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.history.sessions;
    return Scaffold(
      appBar: AppBar(title: const Text('تاریخچه')),
      body: SafeArea(
        child: list.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'هنوز گفتگویی ذخیره نشده است.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final s = list[i];
                  return ListTile(
                    leading: const Icon(Icons.chat_bubble_outline),
                    title: Text(
                      s.title.isEmpty ? 'گفتگو' : s.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${TemplateRenderer.toFa(s.messages.length.toString())} پیام',
                    ),
                    trailing: IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(s),
                    ),
                    onTap: () => Navigator.of(context).pop(s),
                  );
                },
              ),
      ),
    );
  }
}
