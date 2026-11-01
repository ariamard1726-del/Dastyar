import 'package:flutter/material.dart';

import 'history.dart';
import 'persian_text.dart';

class HistoryPage extends StatefulWidget {
  final HistoryStore history;
  const HistoryPage({super.key, required this.history});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static String _formatTime(int millis) {
    if (millis <= 0) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return PersianText.toFaDigits('$y/$mo/$d - $h:$mi');
  }

  List<ChatSession> _filteredSessions() {
    final all = widget.history.sessions;
    final q = PersianText.collapse(PersianText.normalize(_query));
    if (q.isEmpty) return all;
    return all.where((s) {
      final normTitle = PersianText.collapse(PersianText.normalize(s.title));
      if (normTitle.contains(q)) return true;
      for (final m in s.messages) {
        final normMsg = PersianText.collapse(PersianText.normalize(m.text));
        if (normMsg.contains(q)) return true;
      }
      return false;
    }).toList();
  }

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
    final all = widget.history.sessions;
    final list = _filteredSessions();
    return Scaffold(
      appBar: AppBar(title: const Text('تاریخچه')),
      body: SafeArea(
        child: all.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'هنوز گفتگویی ذخیره نشده است.',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'جست‌وجو در گفتگوها...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'پاک کردن جست‌وجو',
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _query = '');
                                },
                              ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        isDense: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'موردی با این عبارت پیدا نشد.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(8),
                            itemCount: list.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final s = list[i];
                              final msgCount = PersianText.toFaDigits(
                                s.messages.length.toString(),
                              );
                              final ts = _formatTime(s.updated);
                              final subtitle = ts.isEmpty
                                  ? '$msgCount پیام'
                                  : '$msgCount پیام • $ts';
                              return ListTile(
                                leading: const Icon(Icons.chat_bubble_outline),
                                title: Text(
                                  s.title.isEmpty ? 'گفتگو' : s.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(subtitle),
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
                ],
              ),
      ),
    );
  }
}
