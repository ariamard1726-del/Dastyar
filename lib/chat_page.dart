import 'package:flutter/material.dart';

import 'assistant.dart';
import 'engine.dart';
import 'templates.dart';
import 'templates_page.dart';

class _Msg {
  String text;
  final bool fromUser;
  _Msg(this.text, this.fromUser);
}

class ChatPage extends StatefulWidget {
  final KnowledgeEngine engine;
  final Assistant assistant;
  final TemplateRepository repo;
  final String? loadError;

  const ChatPage({
    super.key,
    required this.engine,
    required this.assistant,
    required this.repo,
    this.loadError,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _busy = false;

  static const String _welcome =
      'سلام! من دستیار هستم و بدون اینترنت کار می‌کنم. هر چه می‌خواهید بپرسید، یا از دکمهٔ «تهیه متن حقوقی» برای ساخت دادخواست و نامه استفاده کنید.';

  @override
  void initState() {
    super.initState();
    _msgs.add(_Msg(widget.loadError ?? _welcome, false));
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _busy) return;
    final bot = _Msg('...', false);
    setState(() {
      _busy = true;
      _msgs.add(_Msg(text, true));
      _msgs.add(bot);
    });
    _ctrl.clear();
    _scrollDown();
    try {
      await for (final t in widget.assistant.ask(text)) {
        if (!mounted) return;
        setState(() => bot.text = t);
        _scrollDown();
      }
    } catch (_) {
      if (mounted) {
        setState(() => bot.text = 'در پردازش این پرسش خطایی رخ داد. دوباره تلاش کنید.');
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openTemplates() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TemplatesPage(repo: widget.repo)),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('پاک کردن گفتگو'),
        content: const Text('همهٔ پیام‌ها پاک شود؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('پاک شود'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        _msgs
          ..clear()
          ..add(_Msg(_welcome, false));
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('دستیار'),
            Text(
              '${widget.engine.size} بخش دانش بارگذاری شد',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'تهیه متن حقوقی',
            onPressed: _openTemplates,
            icon: const Icon(Icons.description_outlined),
          ),
          IconButton(
            tooltip: 'پاک کردن گفتگو',
            onPressed: _busy ? null : _confirmClear,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(12),
                itemCount: _msgs.length,
                itemBuilder: (context, i) {
                  final m = _msgs[i];
                  return Align(
                    alignment: m.fromUser
                        ? AlignmentDirectional.centerStart
                        : AlignmentDirectional.centerEnd,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.82,
                      ),
                      decoration: BoxDecoration(
                        color: m.fromUser
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SelectableText(
                        m.text,
                        style: const TextStyle(fontSize: 16, height: 1.6),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ActionChip(
                  avatar: const Icon(Icons.description_outlined, size: 18),
                  label: const Text('تهیه متن حقوقی'),
                  onPressed: _openTemplates,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'پرسش خود را بنویسید...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
