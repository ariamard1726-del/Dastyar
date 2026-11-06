import 'dart:math';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:dastyar/ui/about_page.dart';
import 'package:dastyar/ui/app_drawer.dart';
import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/ui/chat_controller.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/ui/history_page.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/ui/settings_page.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/widgets/chat_bubbles.dart';

class ChatPage extends StatefulWidget {
  final KnowledgeEngine engine;
  final Assistant assistant;
  final TemplateRepository repo;
  final HistoryStore history;
  final AppSettings settings;
  final String? loadError;
  final DraftSession? initialDraft;

  /// شبکهٔ عصبی آفلاین تشخیص نیت (اختیاری؛ در نبودِ آن مسیر نمادین فعال است).
  final IntentNet? intentNet;

  /// گفتگوی مشاورهٔ ناتمام بازیابی‌شده از اجرای قبلی.
  final CounselingSession? initialCounsel;

  const ChatPage({
    super.key,
    required this.engine,
    required this.assistant,
    required this.repo,
    required this.history,
    required this.settings,
    this.loadError,
    this.initialDraft,
    this.intentNet,
    this.initialCounsel,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _ctrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  late final ChatController _chat;

  @override
  void initState() {
    super.initState();
    _chat = ChatController(
      engine: widget.engine,
      assistant: widget.assistant,
      repo: widget.repo,
      history: widget.history,
      settings: widget.settings,
      loadError: widget.loadError,
      initialDraft: widget.initialDraft,
      intentNet: widget.intentNet,
      initialCounsel: widget.initialCounsel,
      onScrollRequested: _scrollDown,
      // پاسخ‌های کوچک (سلام، همدلی، ...) با هر بار اجرای اپ از میان
      // گزینه‌های موجود تصادفی انتخاب می‌شوند تا گفتگو یکنواخت نباشد.
      random: Random(),
    );
  }

  @override
  void dispose() {
    _chat.dispose();
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _submit([String? override]) async {
    final text = (override ?? _ctrl.text).trim();
    if (text.isEmpty || _chat.busy) return;
    _ctrl.clear();
    await _chat.submit(text);
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

  Future<void> _openHistory() async {
    if (_chat.busy) return;
    final s = await Navigator.of(context).push<ChatSession>(
      MaterialPageRoute(builder: (_) => HistoryPage(history: widget.history)),
    );
    if (s == null || !mounted) return;
    _chat.loadSession(s);
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

  Future<void> _copy(String text, {bool sensitive = false}) async {
    await PrivacyService.copyText(text, sensitive: sensitive);
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
        const SnackBar(
          content: Text('اشتراک‌گذاری انجام نشد. از کپی استفاده کنید.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _chat,
      builder: (context, _) {
        final msgs = _chat.messages;
        return Scaffold(
          drawer: AppDrawer(
            onNewChat: _chat.newChat,
            onHistory: _openHistory,
            onSettings: _openSettings,
            onAbout: _openAbout,
          ),
          appBar: AppBar(
            title: const Text('دستیار'),
            actions: [
              IconButton(
                tooltip: 'گفتگوی جدید',
                onPressed: _chat.busy ? null : _chat.newChat,
                icon: const Icon(Icons.add_comment_outlined),
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: msgs.isEmpty
                      ? ChatEmptyState(
                          templates: widget.repo.templates,
                          onSelectTemplate: _submit,
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: msgs.length,
                          itemBuilder: (context, i) {
                            final m = msgs[i];
                            if (m.fromUser) {
                              return UserMessageBubble(message: m);
                            }
                            if (m.isDoc) {
                              return DraftDocumentCard(
                                message: m,
                                onCopySensitive: (t) =>
                                    _copy(t, sensitive: true),
                                onShare: _share,
                              );
                            }
                            final question = (i > 0 && msgs[i - 1].fromUser)
                                ? msgs[i - 1].text
                                : '';
                            return BotMessageView(
                              message: m,
                              question: question,
                              onCopy: _copy,
                              onShare: (t) => _share(t),
                            );
                          },
                        ),
                ),
                ChatChipsBar(
                  busy: _chat.busy,
                  messages: msgs,
                  onSelectChip: _submit,
                ),
                ChatInputBar(
                  controller: _ctrl,
                  busy: _chat.busy,
                  isDrafting: _chat.isDrafting,
                  isCounseling: _chat.isCounseling,
                  onSend: _submit,
                  onStop: _chat.cancelActiveAsk,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
