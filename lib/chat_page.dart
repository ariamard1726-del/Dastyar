import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

import 'about_page.dart';
import 'app_drawer.dart';
import 'assistant.dart';
import 'drafting.dart';
import 'engine.dart';
import 'history.dart';
import 'history_page.dart';
import 'settings.dart';
import 'settings_page.dart';
import 'templates.dart';

const String _docDisclaimer =
    'این متن فقط پیش‌نویس است و جایگزین مشاورهٔ وکیل نیست. پیش از ثبت، آن را با یک کارشناس حقوقی یا مرکز مشاورهٔ رایگان بررسی کنید و به مهلت‌های قانونی دقت کنید.';

class _Msg {
  String text;
  final bool fromUser;
  final bool sensitive;
  final bool isDoc;
  final String docTitle;
  final bool docReviewed;
  final String docReviewNote;
  final String note;
  final List<LawText> laws;
  final int lawRefsTotal;
  List<String> chips;

  _Msg(
    this.text,
    this.fromUser, {
    this.sensitive = false,
    this.isDoc = false,
    this.docTitle = '',
    this.docReviewed = true,
    this.docReviewNote = '',
    this.note = '',
    this.laws = const [],
    this.lawRefsTotal = 0,
    this.chips = const [],
  });
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
  DraftSession? _draft;

  // پیشنهاد در انتظار تصمیم کاربر
  String? _pendingText;
  List<LegalTemplate> _pendingList = [];
  final Set<String> _declined = {};

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    if (widget.loadError != null) {
      _msgs.add(_Msg(widget.loadError!, false, sensitive: true));
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _resetFlow() {
    _draft = null;
    _pendingText = null;
    _pendingList = [];
    _declined.clear();
  }

  // ---------- ذخیرهٔ تاریخچه ----------

  Future<void> _saveSession() async {
    if (!widget.settings.saveHistory) return;
    final stored = _msgs
        .where((m) => !m.sensitive && !m.isDoc && m.text != '...')
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

  // ---------- ارسال پیام ----------

  Future<void> _submit([String? override]) async {
    final text = (override ?? _ctrl.text).trim();
    if (text.isEmpty || _busy) return;
    _ctrl.clear();
    for (final m in _msgs) {
      m.chips = const [];
    }

    if (_draft != null) {
      _draftStep(text);
      return;
    }

    // پاسخ به پیشنهادی که قبلاً داده شده
    if (_pendingText != null) {
      final pt = _pendingText!;
      final list = _pendingList;
      _pendingText = null;
      _pendingList = [];
      if (text == DraftCmd.offerNo) {
        for (final t in list) {
          _declined.add(t.id);
        }
        setState(() => _msgs.add(_Msg(text, true, sensitive: true)));
        await _ask(pt, addUser: false, sensitive: true);
        return;
      }
      if (text == DraftCmd.offerYes && list.length == 1) {
        _startDraft(text, list.first);
        return;
      }
    }

    // درخواست صریح تهیهٔ متن
    final intent = Drafting.detect(text, widget.repo.templates);
    if (intent.template != null) {
      _startDraft(text, intent.template!);
      return;
    }
    if (intent.choices.isNotEmpty) {
      setState(() {
        _msgs.add(_Msg(text, true, sensitive: true));
        _msgs.add(
          _Msg(
            Drafting.chooseText,
            false,
            sensitive: true,
            chips: intent.choices.map((t) => t.title).toList(),
          ),
        );
      });
      _scrollDown();
      return;
    }

    // توصیف وضعیت بدون درخواست صریح: فقط پیشنهاد
    final avail =
        widget.repo.templates.where((t) => !_declined.contains(t.id)).toList();
    final sug = Drafting.suggest(text, avail);
    if (sug.template != null) {
      setState(() {
        _pendingText = text;
        _pendingList = [sug.template!];
        _msgs.add(_Msg(text, true, sensitive: true));
        _msgs.add(
          _Msg(
            Drafting.offerText(sug.template!),
            false,
            sensitive: true,
            chips: const [DraftCmd.offerYes, DraftCmd.offerNo],
          ),
        );
      });
      _scrollDown();
      return;
    }
    if (sug.choices.isNotEmpty) {
      setState(() {
        _pendingText = text;
        _pendingList = sug.choices;
        _msgs.add(_Msg(text, true, sensitive: true));
        _msgs.add(
          _Msg(
            Drafting.suggestChooseText,
            false,
            sensitive: true,
            chips: [
              ...sug.choices.map((t) => t.title),
              DraftCmd.offerNo,
            ],
          ),
        );
      });
      _scrollDown();
      return;
    }

    await _ask(text);
  }

  Future<void> _ask(
    String text, {
    bool addUser = true,
    bool sensitive = false,
  }) async {
    final bot = _Msg('...', false, sensitive: sensitive);
    setState(() {
      _busy = true;
      if (addUser) _msgs.add(_Msg(text, true, sensitive: sensitive));
      _msgs.add(bot);
    });
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

  // ---------- تهیهٔ متن حقوقی داخل گفتگو ----------

  _Msg _botFromReply(DraftReply r, LegalTemplate t) {
    if (r.isDocument) {
      return _Msg(
        r.text,
        false,
        sensitive: true,
        isDoc: true,
        docTitle: t.title,
        docReviewed: t.reviewed,
        docReviewNote: t.reviewNote,
        note: r.note,
        laws: Drafting.lawTexts(widget.engine, t),
        lawRefsTotal: t.lawRefs.length,
        chips: r.chips,
      );
    }
    return _Msg(r.text, false, sensitive: true, chips: r.chips);
  }

  void _startDraft(String userText, LegalTemplate t) {
    final s = DraftSession(t);
    final r = Drafting.start(s);
    setState(() {
      _draft = s;
      _msgs.add(_Msg(userText, true, sensitive: true));
      _msgs.add(_botFromReply(r, t));
    });
    _scrollDown();
  }

  void _draftStep(String text) {
    final s = _draft!;
    final r = Drafting.answer(s, text);
    setState(() {
      _msgs.add(_Msg(text, true, sensitive: true));
      _msgs.add(_botFromReply(r, s.template));
      if (r.ended) _draft = null;
    });
    _scrollDown();
  }

  // ---------- ناوبری ----------

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
      _resetFlow();
      _msgs.clear();
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
      _resetFlow();
      _msgs
        ..clear()
        ..addAll(s.messages.map((m) => _Msg(m.text, m.fromUser)));
    });
    _scrollDown();
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

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('کپی شد')),
    );
  }

  Future<void> _share(String text, {String? subject}) async {
    try {
      await Share.share(text, subject: subject);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اشتراک‌گذاری انجام نشد. از کپی استفاده کنید.')),
      );
    }
  }

  // ---------- ظاهر ----------

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Widget _userBubble(_Msg m) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: _dark ? const Color(0xFF3A3A37) : const Color(0xFFEFEDE6),
          borderRadius: BorderRadius.circular(18),
        ),
        child: SelectableText(
          m.text,
          style: const TextStyle(fontSize: 16, height: 1.7),
        ),
      ),
    );
  }

  Widget _botText(_Msg m) {
    final canAct = !m.sensitive && m.text != '...';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            m.text,
            style: const TextStyle(fontSize: 16, height: 1.9),
          ),
          if (canAct)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'کپی',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () => _copy(m.text),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'اشتراک‌گذاری',
                  icon: const Icon(Icons.share_outlined, size: 18),
                  onPressed: () => _share(m.text),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _docCard(_Msg m) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'پیش‌نویس: ${m.docTitle}',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (!m.docReviewed) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    m.docReviewNote.isEmpty
                        ? 'این قالب هنوز بازبینی نشده است.'
                        : m.docReviewNote,
                    style: TextStyle(color: cs.onErrorContainer, height: 1.6),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SelectableText(
                m.text,
                style: const TextStyle(fontSize: 16, height: 1.9),
              ),
              if (m.note.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(m.note, style: TextStyle(color: cs.error, height: 1.6)),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => _copy(m.text),
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('کپی متن'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _share(m.text, subject: m.docTitle),
                    icon: const Icon(Icons.share_outlined, size: 18),
                    label: const Text('اشتراک‌گذاری'),
                  ),
                ],
              ),
              if (m.laws.isNotEmpty || m.lawRefsTotal > 0) ...[
                const Divider(height: 28),
                Text('مواد قانونی مرتبط', style: tt.titleSmall),
                const SizedBox(height: 8),
                if (m.laws.isEmpty)
                  const Text('متن رسمی مواد مرتبط هنوز در برنامه نیست.'),
                for (final l in m.laws) ...[
                  Text(
                    '${l.source} — ${l.title}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (l.note.isNotEmpty) Text(l.note),
                  const SizedBox(height: 4),
                  SelectableText(
                    l.body,
                    style: const TextStyle(fontSize: 15, height: 1.8),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
              const SizedBox(height: 10),
              Text(
                _docDisclaimer,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.balance, size: 40, color: cs.primary),
            const SizedBox(height: 16),
            const Text(
              'سلام، چه کمکی از من برمی‌آید؟',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'بدون اینترنت کار می‌کنم. می‌توانید سؤال بپرسید، مشکل خود را شرح دهید، یا بنویسید «می‌خواهم دادخواست بنویسم».',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, height: 1.7),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in widget.repo.templates)
                  ActionChip(
                    avatar: const Icon(Icons.description_outlined, size: 18),
                    label: Text(t.title),
                    onPressed: () => _submit(t.title),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipsBar() {
    if (_busy || _msgs.isEmpty) return const SizedBox.shrink();
    final last = _msgs.last;
    if (last.fromUser || last.chips.isEmpty) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 150),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in last.chips)
                ActionChip(label: Text(c), onPressed: () => _submit(c)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 6, 4),
        decoration: BoxDecoration(
          color: _dark ? const Color(0xFF30302E) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 5,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: _draft != null
                      ? 'پاسخ خود را بنویسید...'
                      : 'پیام خود را بنویسید...',
                ),
              ),
            ),
            IconButton.filled(
              onPressed: _busy ? null : () => _submit(),
              icon: const Icon(Icons.arrow_upward),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        onNewChat: _newChat,
        onHistory: _openHistory,
        onSettings: _openSettings,
        onAbout: _openAbout,
      ),
      appBar: AppBar(
        title: const Text('دستیار'),
        actions: [
          IconButton(
            tooltip: 'گفتگوی جدید',
            onPressed: _busy ? null : _newChat,
            icon: const Icon(Icons.add_comment_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _msgs.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      itemCount: _msgs.length,
                      itemBuilder: (context, i) {
                        final m = _msgs[i];
                        if (m.fromUser) return _userBubble(m);
                        if (m.isDoc) return _docCard(m);
                        return _botText(m);
                      },
                    ),
            ),
            _chipsBar(),
            _inputBar(),
          ],
        ),
      ),
    );
  }
}
