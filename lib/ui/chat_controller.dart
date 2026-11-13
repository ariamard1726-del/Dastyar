import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/chat_models.dart';

/// کنترلر گفتگو: تنها یک مسیر دارد.
///
/// هر پیام کاربر یا پاسخِ یک فیلدِ پیش‌نویس است (وقتی سندی در حال تنظیم
/// است) یا به [Advocate] می‌رود؛ وکیلِ قاعده‌محور که هیچ مدل زبانی در آن
/// نیست. کنترلر فقط همین دو را به هم وصل می‌کند و تاریخچه را ذخیره می‌کند؛
/// هیچ منطق حقوقی‌ای اینجا نیست.
class ChatController extends ChangeNotifier {
  final KnowledgeEngine engine;
  final TemplateRepository repo;
  final HistoryStore history;
  final AppSettings settings;
  final VoidCallback? onScrollRequested;

  final List<ChatMessage> messages = [];
  String _sessionId = _newId();
  DraftSession? _draft;
  bool _disposed = false;

  /// قالب‌هایی که از کاربر پرسیده‌ام «کدام را می‌خواهید؟».
  List<LegalTemplate> _pendingList = [];

  /// وکیل بدون مدل: فهم محاوره، حافظهٔ پرونده و تحلیل مستند به متن قانون.
  late final Advocate advocate;

  ChatController({
    required this.engine,
    required this.repo,
    required this.history,
    required this.settings,
    String? loadError,
    DraftSession? initialDraft,
    IntentNet? intentNet,
    this.onScrollRequested,
  }) {
    advocate = Advocate(
      engine,
      draftTitles: {for (final t in repo.templates) t.id: t.title},
      intentNet: intentNet,
    );
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

  String get sessionId => _sessionId;
  DraftSession? get draft => _draft;
  bool get isDrafting => _draft != null;
  List<LegalTemplate> get pendingChoices => List.unmodifiable(_pendingList);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _requestScroll() {
    if (!_disposed) onScrollRequested?.call();
  }

  void _resetFlow() {
    _draft = null;
    _pendingList = [];
    advocate.reset();
  }

  Future<void> submit(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _disposed) return;
    for (final m in messages) {
      m.chips = const [];
    }
    if (_draft != null) {
      _draftStep(text);
      return;
    }
    if (_draftRequest(text)) return;
    final r = advocate.respond(text);
    messages.add(ChatMessage(text, true));
    messages.add(ChatMessage(r.text, false, chips: r.chips, laws: r.laws));
    unawaited(_saveSession());
    _notify();
    _requestScroll();
  }

  /// آیا این پیام درخواست نوشتن یک سند است؟ اگر بله، همان را شروع می‌کند
  /// (یا می‌پرسد کدام سند) و `true` برمی‌گرداند.
  bool _draftRequest(String text) {
    // لمس دکمه‌ای که عنوان دقیق یک قالب است.
    final key = KnowledgeEngine.normalize(text).trim();
    for (final t in repo.templates) {
      if (KnowledgeEngine.normalize(t.title).trim() == key) {
        _pendingList = [];
        _startDraft(text, t);
        return true;
      }
    }
    // پاسخ به «کدام متن را می‌خواهید؟».
    if (_pendingList.isNotEmpty) {
      final list = _pendingList;
      _pendingList = [];
      final picked = Drafting.pickChoice(text, list);
      if (picked != null) {
        _startDraft(text, picked);
        return true;
      }
      if (text == DraftCmd.cancel || Drafting.isNo(text)) {
        _reply(
          text,
          'باشد، فعلاً متنی نمی‌نویسم. هر وقت خواستید بگویید.',
          chips: advocate.idleChips,
        );
        return true;
      }
    }
    if (!Advocate.wantsDraft(text)) return false;
    // «یک دادخواست مطالبهٔ وجه بنویس»: خودِ کاربر سند را نام برده است.
    final intent = Drafting.detect(text, repo.templates);
    final direct = intent.template;
    if (direct != null) {
      _startDraft(text, direct);
      return true;
    }
    // «برام بنویسش»: سندی که به پروندهٔ جاری می‌خورد.
    for (final id in advocate.draftIds) {
      final t = _templateFor(id);
      if (t != null) {
        _startDraft(text, t);
        return true;
      }
    }
    if (intent.choices.isNotEmpty) {
      _pendingList = intent.choices;
      messages.add(ChatMessage(text, true, sensitive: true));
      messages.add(
        ChatMessage(
          Drafting.chooseText,
          false,
          sensitive: true,
          chips: [...intent.choices.map((t) => t.title), DraftCmd.cancel],
        ),
      );
      _notify();
      _requestScroll();
      return true;
    }
    return false;
  }

  void _reply(String userText, String botText,
      {List<String> chips = const []}) {
    messages.add(ChatMessage(userText, true));
    messages.add(ChatMessage(botText, false, chips: chips));
    unawaited(_saveSession());
    _notify();
    _requestScroll();
  }

  LegalTemplate? _templateFor(String id) {
    for (final t in repo.templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<void> _saveSession() async {
    if (!settings.saveHistory || _disposed) return;
    final stored = messages
        .where((m) => !m.sensitive && !m.isDoc)
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

  // ------------------------------------------------------------ پیش‌نویس

  /// مبلغی که کاربر در گفتگو گفته، به‌عنوان دکمهٔ پیشنهادی برای فیلد مبلغِ
  /// سند. تنها منبعش پروندهٔ وکیل است (مبلغ‌ها آنجا به تومان‌اند و فیلدهای
  /// قالب به ریال).
  DraftReply _withAmountChip(DraftReply r, DraftSession s) {
    if (r.ended || r.isDocument) return r;
    final f = s.current;
    if (f == null || f.id != 'amount' || f.type != 'number') return r;
    if (s.values.containsKey(f.id)) return r;
    final toman = advocate.file.n('amount');
    if (toman == null || toman <= 0) return r;
    final v = PersianText.toFaDigits((toman * 10).toString());
    if (r.chips.contains(v)) return r;
    return DraftReply(r.text, chips: [v, ...r.chips], note: r.note);
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
    final r = _withAmountChip(Drafting.start(s), s);
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
    final r = _withAmountChip(Drafting.answer(s, text), s);
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
    if (_disposed) return false;
    final restored = await DraftCheckpointStore.load(repo.templates);
    if (restored == null || _disposed) return false;
    _draft = restored;
    final r = Drafting.resumePrompt(restored);
    messages.add(_botFromReply(r, restored.template));
    _notify();
    _requestScroll();
    return true;
  }

  // ------------------------------------------------------------- گفتگوها

  void newChat() {
    _sessionId = _newId();
    _resetFlow();
    if (settings.saveDraftProgress) {
      unawaited(DraftCheckpointStore.clear());
    }
    messages.clear();
    _notify();
  }

  void loadSession(ChatSession s) {
    _sessionId = s.id;
    _resetFlow();
    if (settings.saveDraftProgress) {
      unawaited(DraftCheckpointStore.clear());
    }
    messages
      ..clear()
      ..addAll(
        s.messages.map((m) => ChatMessage(m.text, m.fromUser, revealed: true)),
      );
    // حافظهٔ پرونده از روی پیام‌های خودِ کاربر دوباره ساخته می‌شود.
    advocate.replay([
      for (final m in s.messages)
        if (m.fromUser) m.text,
    ]);
    _notify();
    _requestScroll();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
