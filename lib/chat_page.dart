import 'package:flutter/material.dart';

import 'about_page.dart';
import 'app_drawer.dart';
import 'assistant.dart';
import 'engine.dart';
import 'history.dart';
import 'history_page.dart';
import 'settings.dart';
import 'settings_page.dart';
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
  final HistoryStore history;
  final AppSettings settings;
  final String? loadError;

  const ChatPage({
    super.key,
    required this.engine,
    required this.assistant,
    required this.repo,
    required this.history,
    required this.settings,
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
  String _sessionId = _newId();

  static const String _welcome =
      'سلام! من دستیار هستم و بدون اینترنت کار می‌کنم. هر چه می‌خواهید بپرسید، یا از منوی کناری «تهیه متن حقوقی» را برای ساخت دادخواست و نامه باز کنید.';

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    _msgs.add(_Msg(widget.loadError ?? _welcome, false));
  }

  Future<void> _saveSession() async {
    if (!widget.settings.saveHistory) return;
    final stored = _msgs
        .skip(1)
        .where((m) => m.text != '...')
        .map((m) => StoredMsg(m.text, m.fromUser))
        .toList();
    final users = stored.where((m) => m.fromUser).toList();
    if (users.isEmpty) return;
    await widget.history.upsert(
      ChatSession(
        id: _sessionId,
        title: HistoryStore.makeTitle(users.first.text),
        updated: DateTime.now().millisecondsSinceEpoch,
        messages: stored,
      ),
    );
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
    await _saveSession();
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

  void _newChat() {
    if (_busy) return;
    setState(() {
      _sessionId = _newId();
      _msgs
        ..clear()
        ..add(_Msg(_welcome, false));
    });
  }

  Future<void> _openHistory() async {
    if (_busy) return;
    final s = await Navigator.of(context).push<ChatSession>(
      MaterialPageRoute(builder: (_) => HistoryPage(history: widget.history)),
    );
    if (s == null || !mounted) return;
    setState(() {
      _sessionId = s.id;
      _msgs
        ..clear()
        ..add(_Msg(_welcome, false))
        ..addAll(s.messages.map((m) => _Msg(m.text, m.fromUser)));
    });
    _scrollDown();
  }

  void _openTemplates() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TemplatesPage(
          repo: widget.repo,
          engine: widget.engine,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          settings: widget.settings,
          history: widget.history,
        ),
      ),
    );
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AboutPage(
          engine: widget.engine,
          repo: widget.repo,
        ),
      ),
    );
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
      drawer: AppDrawer(
        onNewChat: _newChat,
        onHistory: _openHistory,
        onTemplates: _openTemplates,
        onSettings: _openSettings,
        onAbout: _openAbout,
      ),
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
