import 'dart:async';

import 'package:flutter/foundation.dart';

import 'assistant.dart';
import 'chat_models.dart';
import 'drafting.dart';
import 'engine.dart';
import 'history.dart';
import 'legal_counselor.dart';
import 'settings.dart';
import 'templates.dart';

/// کنترلر مستقل منطق گفتگو، مدیریت وضعیت پیش‌نویس، پیشنهادهای معوق و استریم پاسخ.
///
/// جداسازی این لایه از ویجت‌ها باعث می‌شود ماشین حالت گفتگو، لغو استریم در میانهٔ
/// تولید و ذخیره‌سازی تاریخچه بدون وابستگی به درخت ویجت قابل تست و نگهداری باشد.
class ChatController extends ChangeNotifier {
  final KnowledgeEngine engine;
  final Assistant assistant;
  final TemplateRepository repo;
  final HistoryStore history;
  final AppSettings settings;
  final VoidCallback? onScrollRequested;

  final List<ChatMessage> messages = [];
  bool _busy = false;
  String _sessionId = _newId();
  DraftSession? _draft;
  CounselingSession? _counsel;
  final ConversationMemory _memory = ConversationMemory();

  // پیشنهاد در انتظار تصمیم کاربر
  String? _pendingText;
  List<LegalTemplate> _pendingList = [];
  final Set<String> _declined = {};

  StreamSubscription<AssistantTurn>? _sub;
  Completer<void>? _askDone;
  int _askEpoch = 0;
  bool _disposed = false;

  ChatController({
    required this.engine,
    required this.assistant,
    required this.repo,
    required this.history,
    required this.settings,
    String? loadError,
    DraftSession? initialDraft,
    this.onScrollRequested,
  }) {
    if (loadError != null && loadError.isNotEmpty) {
      messages.add(ChatMessage(loadError, false, sensitive: true));
    }
    if (initialDraft != null && !initialDraft.done) {
      _draft = initialDraft;
      final r = Drafting.resumePrompt(initialDraft);
      messages.add(_botFromReply(r, initialDraft.template));
    }
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  bool get busy => _busy;
  String get sessionId => _sessionId;
  DraftSession? get draft => _draft;
  bool get isDrafting => _draft != null;
  bool get isCounseling => _counsel != null && !_counsel!.concluded;
  List<LegalTemplate> get pendingChoices => List.unmodifiable(_pendingList);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _requestScroll() {
    if (!_disposed) onScrollRequested?.call();
  }

  void _resetFlow() {
    _draft = null;
    _counsel = null;
    _memory.clear();
    _pendingText = null;
    _pendingList = [];
    _declined.clear();
  }

  void _detachStream() {
    unawaited(_sub?.cancel());
    _sub = null;
    final done = _askDone;
    _askDone = null;
    if (done != null && !done.isCompleted) {
      done.complete();
    }
  }

  /// لغو ایمن پاسخ در حال تولید و آزادسازی فوری اشتراک استریم و مدل زبانی.
  void cancelActiveAsk() {
    if (!_busy) return;
    _askEpoch++;
    _detachStream();
    try {
      assistant.llm.cancel();
    } catch (_) {}
    _busy = false;
    if (messages.isNotEmpty &&
        !messages.last.fromUser &&
        messages.last.text == '...') {
      messages.last.text = 'پاسخ متوقف شد.';
    }
    _notify();
  }

  Future<void> _saveSession() async {
    if (!settings.saveHistory || _disposed) return;
    final stored = messages
        .where((m) => !m.sensitive && !m.isDoc && m.text != '...')
        .map((m) => StoredMsg(m.text, m.fromUser))
        .toList();
    final users = stored.where((m) => m.fromUser).toList();
    if (users.isEmpty) return;
    await history.upsert(
      ChatSession(
        id: _sessionId,
        title: HistoryStore.makeTitle(users.first.text),
        updated: DateTime.now().millisecondsSinceEpoch,
        messages: stored,
      ),
    );
  }

  Future<void> submit(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _busy || _disposed) return;
    for (final m in messages) {
      m.chips = const [];
    }

    if (_draft != null) {
      _draftStep(text);
      return;
    }

    // ادامهٔ گفتگوی تشخیصی و استدلالی دوطرفه (مشاور حقوقی)
    if (_counsel != null) {
      final turn =
          LegalCounselor.step(_counsel!, text, engine, repo.templates);
      if (turn.cancelled) {
        _counsel = null;
        messages.add(ChatMessage(text, true));
        messages.add(ChatMessage(turn.text, false));
        unawaited(_saveSession());
        _notify();
        _requestScroll();
        return;
      }
      if (turn.startTemplate != null) {
        _counsel = null;
        _startDraft(text, turn.startTemplate!);
        return;
      }
      if (turn.text.isNotEmpty) {
        if (turn.completed && turn.chips.isEmpty) {
          _counsel = null;
        }
        messages.add(ChatMessage(text, true));
        messages.add(ChatMessage(turn.text, false, chips: turn.chips));
        unawaited(_saveSession());
        _notify();
        _requestScroll();
        return;
      }
      // اگر مشاوره قبلاً جمع‌بندی شده و کاربر اکنون پرسش جدیدی مطرح کرده است:
      _counsel = null;
    }

    // پاسخ به پیشنهاد یا فهرست انتخاب قالب که قبلاً نمایش داده شده
    if (_pendingList.isNotEmpty) {
      final pt = _pendingText;
      final list = _pendingList;

      if (text == DraftCmd.offerCounsel ||
          text == LegalCounselor.startCounselCmd) {
        _pendingText = null;
        _pendingList = [];
        final started =
            LegalCounselor.start(pt ?? text, engine, repo.templates);
        if (started != null) {
          _counsel = started.$1;
          messages.add(ChatMessage(text, true));
          messages.add(
            ChatMessage(started.$2.text, false, chips: started.$2.chips),
          );
          unawaited(_saveSession());
          _notify();
          _requestScroll();
          return;
        }
      }

      final isDecline = text == DraftCmd.offerNo ||
          text == DraftCmd.cancel ||
          Drafting.isNo(text);
      if (isDecline) {
        _pendingText = null;
        _pendingList = [];
        if (pt != null) {
          for (final t in list) {
            _declined.add(t.id);
          }
          messages.add(ChatMessage(text, true, sensitive: true));
          _notify();
          await _ask(pt, addUser: false, sensitive: true);
        } else {
          messages.add(ChatMessage(text, true, sensitive: true));
          messages.add(
            ChatMessage(
              'تهیهٔ متن لغو شد. هر سؤالی دارید بپرسید.',
              false,
              sensitive: true,
            ),
          );
          _notify();
          _requestScroll();
        }
        return;
      }

      final isAccept = text == DraftCmd.offerYes || Drafting.isYes(text);
      if (isAccept) {
        if (list.length == 1) {
          _pendingText = null;
          _pendingList = [];
          _startDraft(text, list.first);
          return;
        }
        messages.add(ChatMessage(text, true, sensitive: true));
        messages.add(
          ChatMessage(
            'لطفاً مشخص کنید کدام‌یک از این قالب‌ها را آماده کنم:',
            false,
            sensitive: true,
            chips: [
              ...list.map((t) => t.title),
              if (pt != null) DraftCmd.offerNo else DraftCmd.cancel,
            ],
          ),
        );
        _notify();
        _requestScroll();
        return;
      }

      final picked = Drafting.pickChoice(text, list);
      _pendingText = null;
      _pendingList = [];
      if (picked != null) {
        _startDraft(text, picked);
        return;
      }
    }

    // درخواست صریح تهیهٔ متن
    final intent = Drafting.detect(text, repo.templates);
    final directTpl = intent.template;
    if (directTpl != null) {
      _startDraft(text, directTpl);
      return;
    }
    if (intent.choices.isNotEmpty) {
      _pendingText = null;
      _pendingList = intent.choices;
      messages.add(ChatMessage(text, true, sensitive: true));
      messages.add(
        ChatMessage(
          Drafting.chooseText,
          false,
          sensitive: true,
          chips: [
            ...intent.choices.map((t) => t.title),
            DraftCmd.cancel,
          ],
        ),
      );
      _notify();
      _requestScroll();
      return;
    }

    // توصیف وضعیت بدون درخواست صریح: فقط پیشنهاد
    final avail =
        repo.templates.where((t) => !_declined.contains(t.id)).toList();
    final sug = Drafting.suggest(text, avail);
    final sugTpl = sug.template;
    if (sugTpl != null) {
      _pendingText = text;
      _pendingList = [sugTpl];
      messages.add(ChatMessage(text, true, sensitive: true));
      messages.add(
        ChatMessage(
          Drafting.offerText(sugTpl),
          false,
          sensitive: true,
          chips: const [
            DraftCmd.offerYes,
            DraftCmd.offerCounsel,
            DraftCmd.offerNo,
          ],
        ),
      );
      _notify();
      _requestScroll();
      return;
    }
    if (sug.choices.isNotEmpty) {
      _pendingText = text;
      _pendingList = sug.choices;
      messages.add(ChatMessage(text, true, sensitive: true));
      messages.add(
        ChatMessage(
          Drafting.suggestChooseText,
          false,
          sensitive: true,
          chips: [
            ...sug.choices.map((t) => t.title),
            DraftCmd.offerCounsel,
            DraftCmd.offerNo,
          ],
        ),
      );
      _notify();
      _requestScroll();
      return;
    }

    // حالت گفتگوی دوطرفه و پرسشگری تشخیصی برای مسائل و مشکلات حقوقی کاربر
    if (LegalCounselor.shouldStartCounseling(text)) {
      final seed = (text == LegalCounselor.startCounselCmd &&
              _memory.lastTopicQuery.isNotEmpty)
          ? _memory.lastTopicQuery
          : text;
      final started = LegalCounselor.start(seed, engine, repo.templates);
      if (started != null) {
        _counsel = started.$1;
        messages.add(ChatMessage(text, true));
        messages.add(
          ChatMessage(started.$2.text, false, chips: started.$2.chips),
        );
        await _saveSession();
        _notify();
        _requestScroll();
        return;
      }
    }

    await _ask(text);
  }

  Future<void> _ask(
    String text, {
    bool addUser = true,
    bool sensitive = false,
  }) async {
    final resolvedQuery = _memory.resolveFollowUp(text);
    final myEpoch = ++_askEpoch;
    final bot = ChatMessage('...', false, sensitive: sensitive);
    _busy = true;
    if (addUser) messages.add(ChatMessage(text, true, sensitive: sensitive));
    messages.add(bot);
    _notify();
    _requestScroll();

    final done = Completer<void>();
    _askDone = done;
    var alts = const <String>[];

    _sub = assistant.askWithAlternatives(resolvedQuery).listen(
      (turn) {
        if (_disposed || myEpoch != _askEpoch) return;
        alts = turn.alternatives;
        bot.text = turn.text;
        bot.conflictChains = turn.conflictChains;
        _notify();
        _requestScroll();
      },
      onError: (_) {
        if (!_disposed && myEpoch == _askEpoch) {
          bot.text = 'در پردازش این پرسش خطایی رخ داد. دوباره تلاش کنید.';
          _notify();
        }
        if (!done.isCompleted) done.complete();
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
      cancelOnError: true,
    );

    await done.future;
    if (identical(_askDone, done)) _askDone = null;
    final activeSub = _sub;
    if (activeSub != null && myEpoch == _askEpoch) {
      _sub = null;
      await activeSub.cancel();
    }

    if (_disposed || myEpoch != _askEpoch) return;
    _memory.recordTurn(
      resolvedQuery,
      engine.query(resolvedQuery, maxAlternatives: 0),
    );
    final mergedChips = <String>[
      ...alts,
      if (!sensitive && LegalCounselor.detectTopic(resolvedQuery) != null)
        LegalCounselor.startCounselCmd,
    ];
    if (mergedChips.isNotEmpty) {
      bot.chips = mergedChips;
    }
    await _saveSession();
    if (_disposed || myEpoch != _askEpoch) return;
    _busy = false;
    _notify();
  }

  ChatMessage _botFromReply(DraftReply r, LegalTemplate t) {
    if (r.isDocument) {
      return ChatMessage(
        r.text,
        false,
        sensitive: true,
        isDoc: true,
        docTitle: t.title,
        docReviewed: t.reviewed,
        docReviewNote: t.reviewNote,
        note: r.note,
        laws: Drafting.lawTexts(engine, t),
        lawRefsTotal: t.lawRefs.length,
        chips: r.chips,
      );
    }
    return ChatMessage(r.text, false, sensitive: true, chips: r.chips);
  }

  void _startDraft(String userText, LegalTemplate t) {
    final s = DraftSession(t);
    final r = Drafting.start(s);
    _draft = r.ended ? null : s;
    messages.add(ChatMessage(userText, true, sensitive: true));
    messages.add(_botFromReply(r, t));
    _syncDraftCheckpoint();
    _notify();
    _requestScroll();
  }

  void _draftStep(String text) {
    final s = _draft;
    if (s == null) return;
    final r = Drafting.answer(s, text);
    messages.add(ChatMessage(text, true, sensitive: true));
    messages.add(_botFromReply(r, s.template));
    if (r.ended) _draft = null;
    _syncDraftCheckpoint();
    _notify();
    _requestScroll();
  }

  void _syncDraftCheckpoint() {
    if (!settings.saveDraftProgress || _disposed) return;
    final s = _draft;
    if (s == null || s.done) {
      unawaited(DraftCheckpointStore.clear());
    } else {
      unawaited(DraftCheckpointStore.save(s));
    }
  }

  /// ذخیرهٔ صریح وضعیت پیش‌نویس ناتمام به‌صورت رمزنگاری‌شده.
  Future<bool> saveDraftCheckpoint() async {
    final s = _draft;
    if (s == null || s.done) {
      await DraftCheckpointStore.clear();
      return false;
    }
    return DraftCheckpointStore.save(s);
  }

  /// بازیابی پیش‌نویس ناتمام ذخیره‌شده و نمایش پرسش جاری در گفتگو.
  Future<bool> restoreDraftCheckpoint() async {
    if (_busy || _disposed) return false;
    final restored = await DraftCheckpointStore.load(repo.templates);
    if (restored == null || _disposed) return false;
    _draft = restored;
    final r = Drafting.resumePrompt(restored);
    messages.add(_botFromReply(r, restored.template));
    _notify();
    _requestScroll();
    return true;
  }

  void newChat({bool force = false}) {
    if (_busy) {
      if (!force) return;
      cancelActiveAsk();
    }
    _sessionId = _newId();
    _resetFlow();
    if (settings.saveDraftProgress) {
      unawaited(DraftCheckpointStore.clear());
    }
    messages.clear();
    _notify();
  }

  void loadSession(ChatSession s) {
    if (_busy) return;
    _sessionId = s.id;
    _resetFlow();
    if (settings.saveDraftProgress) {
      unawaited(DraftCheckpointStore.clear());
    }
    messages
      ..clear()
      ..addAll(s.messages.map((m) => ChatMessage(m.text, m.fromUser)));
    _notify();
    _requestScroll();
  }

  @override
  void dispose() {
    _disposed = true;
    _askEpoch++;
    unawaited(_sub?.cancel());
    _sub = null;
    final done = _askDone;
    _askDone = null;
    if (done != null && !done.isCompleted) {
      done.complete();
    }
    if (_busy) {
      try {
        assistant.llm.cancel();
      } catch (_) {}
    }
    super.dispose();
  }
}
