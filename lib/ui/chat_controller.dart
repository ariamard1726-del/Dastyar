import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/ui/app_settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/domain/understanding/topic_guess.dart';
import 'package:dastyar/ui/chat_models.dart';
import 'package:dastyar/ui/draft_flow.dart';
import 'package:dastyar/ui/guess_flow.dart';
import 'package:dastyar/ui/reply_flow.dart';

/// کنترلر گفتگو: سیم‌کشیِ بین سه جریانِ [DraftFlow]، [GuessFlow] و [ReplyFlow].
class ChatController extends ChangeNotifier {
  final KnowledgeEngine engine;
  final TemplateRepository repo;
  final HistoryStore history;
  final AppSettings settings;
  final VoidCallback? onScrollRequested;

  /// خوانندهٔ موضوع (مدل برداری روی گوشی)؛ `null` یعنی فقط قاعده‌ها.
  final Future<TopicGuess?> Function(String text)? guesser;

  final List<ChatMessage> messages = [];
  bool _disposed = false;

  late final Advocate advocate;
  late final DraftFlow draftFlow;
  late final GuessFlow guessFlow;
  late final ReplyFlow replyFlow;

  ChatController({
    required this.engine,
    required this.repo,
    required this.history,
    required this.settings,
    String? loadError,
    DraftSession? initialDraft,
    IntentNet? intentNet,
    this.guesser,
    this.onScrollRequested,
  }) {
    advocate = Advocate(
      engine,
      draftTitles: {for (final t in repo.templates) t.id: t.title},
      intentNet: intentNet,
    );
    draftFlow = DraftFlow(
      engine: engine,
      repo: repo,
      advocate: advocate,
      settings: settings,
      post: messages.add,
      changed: _notify,
      scrollToEnd: _requestScroll,
      save: () => unawaited(replyFlow.saveSession()),
      isAlive: _isAlive,
    );
    guessFlow = GuessFlow(
      advocate: advocate,
      guesser: guesser,
      post: messages.add,
      changed: _notify,
      scrollToEnd: _requestScroll,
      isAlive: _isAlive,
      onProblem: (msg) => replyFlow.addProblem(msg),
    );
    replyFlow = ReplyFlow(
      engine: engine,
      history: history,
      settings: settings,
      advocate: advocate,
      draftFlow: draftFlow,
      guessFlow: guessFlow,
      messages: messages,
      changed: _notify,
      scrollToEnd: _requestScroll,
      isAlive: _isAlive,
    );
    if (loadError != null && loadError.isNotEmpty) {
      messages.add(ChatMessage(loadError, false, sensitive: true));
    }
    if (initialDraft != null && !initialDraft.done) {
      draftFlow.resume(initialDraft);
    }
  }

  bool _isAlive() => !_disposed;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _requestScroll() {
    if (!_disposed) onScrollRequested?.call();
  }

  bool get thinking => guessFlow.thinking;
  TopicGuess? get lastGuess => guessFlow.lastGuess;
  List<String> get problems => replyFlow.problems;
  String get sessionId => replyFlow.sessionId;
  String transcript() => replyFlow.transcript();
  bool get hasSensitive => replyFlow.hasSensitive;

  DraftSession? get draft => draftFlow.draft;
  bool get isDrafting => draftFlow.isDrafting;
  List<LegalTemplate> get pendingChoices => draftFlow.pendingChoices;
  static const String useSuggestion = DraftFlow.useSuggestion;

  Future<void> submit(String rawText) => replyFlow.submit(rawText);
  Future<bool> saveDraftCheckpoint() => draftFlow.saveCheckpoint();
  Future<bool> restoreDraftCheckpoint() => draftFlow.restoreCheckpoint();

  /// پس از «پاک کردن همهٔ تاریخچه»، گفتگوی باز هم باید پاک شود؛ وگرنه نخستین
  /// پیام بعدی همان محتوا را دوباره روی دیس می‌نویسد.
  void resetAfterHistoryClear() => newChat();
  void newChat() => replyFlow.newChat();
  void loadSession(ChatSession s) => replyFlow.loadSession(s);

  @override
  void dispose() {
    _disposed = true;
    unawaited(history.flush());
    super.dispose();
  }
}
