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
import 'package:dastyar/domain/understanding/topic_guess.dart';
import 'package:dastyar/ui/chat_models.dart';

/// کنترلر گفتگو: تنها یک مسیر دارد.
///
/// هر پیام کاربر یا پاسخِ یک فیلدِ پیش‌نویس است (وقتی سندی در حال تنظیم
/// است) یا به [Advocate] می‌رود؛ وکیلِ قاعده‌محور که متن پاسخ را خودش
/// می‌سازد. اگر قاعده‌ها موضوع پیام را نشناسند و خوانندهٔ موضوع ([guesser])
/// در دسترس باشد، حدسِ آن هم همراه پیام به وکیل داده می‌شود. کنترلر فقط
/// این‌ها را به هم وصل می‌کند و تاریخچه را ذخیره می‌کند؛ هیچ منطق
/// حقوقی‌ای اینجا نیست.
class ChatController extends ChangeNotifier {
  final KnowledgeEngine engine;
  final TemplateRepository repo;
  final HistoryStore history;
  final AppSettings settings;
  final VoidCallback? onScrollRequested;

  /// خوانندهٔ موضوع (مدل برداری روی گوشی)؛ `null` یعنی فقط قاعده‌ها.
  final Future<TopicGuess?> Function(String text)? guesser;

  /// در حال خواندن پیام با مدل هستم (برای نشان‌دادن در صفحه).
  bool thinking = false;

  /// آخرین حدسِ مدل، برای صفحهٔ «درباره».
  TopicGuess? lastGuess;

  /// پیام‌ها به ترتیب رسیدن پردازش می‌شوند، حتی اگر یکی منتظر مدل باشد.
  Future<void> _queue = Future<void>.value();

  final List<ChatMessage> messages = [];

  /// کل گفتگو به‌صورت متن ساده، برای کپی یک‌جا.
  String transcript() {
    final sb = StringBuffer();
    for (final m in messages) {
      final body = m.text.trim();
      if (body.isEmpty) continue;
      sb.writeln(m.fromUser ? 'شما:' : 'دستیار:');
      sb.writeln(body);
      sb.writeln();
    }
    return sb.toString().trim();
  }

  /// اگر در گفتگو پیام حساس (مثلاً متن سند) باشد، کپی هم حساس می‌شود.
  bool get hasSensitive => messages.any((m) => m.sensitive);
  String _sessionId = _newId();
  DraftSession? _draft;
  bool _disposed = false;

  /// شمارهٔ نسل گفتگو؛ با هر «گفتگوی جدید» یا بازکردن گفتگوی دیگر یکی
  /// زیاد می‌شود تا پیام‌های در صف به گفتگوی تازه نچسبند.
  int _generation = 0;

  /// خطاهای زمان اجرا (فقط روی همین گوشی، برای عیب‌یابی).
  final List<String> problems = [];

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
    this.guesser,
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

  Future<void> submit(String rawText) {
    // نسلِ گفتگو در لحظهٔ ارسال قفل می‌شود. اگر کاربر پیش از پردازش،
    // «گفتگوی جدید» بزند یا گفتگوی دیگری باز کند، این پیام دیگر به گفتگوی
    // تازه نمی‌چسبد.
    final gen = _generation;
    final next = _queue.then((_) => _submit(rawText, gen));
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _submit(String rawText, int gen) async {
    final text = rawText.trim();
    if (text.isEmpty || _disposed || gen != _generation) return;
    for (final m in messages) {
      m.chips = const [];
    }
    final before = messages.length;
    try {
      await _process(text, gen);
    } catch (e) {
      _reportFailure(text, before, e);
    }
  }

  /// خطای پردازش را به کاربر نشان می‌دهد؛ پیام بی‌توضیح گم نمی‌شود.
  void _reportFailure(String text, int before, Object e) {
    if (_disposed) return;
    thinking = false;
    problems.add('$e');
    if (problems.length > 20) problems.removeAt(0);
    if (messages.length == before) {
      messages.add(ChatMessage(text, true));
    }
    messages.add(ChatMessage(
      'این پیام را نتوانستم درست پردازش کنم. اگر دوباره بفرستید یا کمی ساده‌تر '
      'بنویسید، از نو امتحان می‌کنم. اگر تکرار شد، از منوی «اطلاعات و وضعیت '
      'داده‌ها» وضعیت بارگذاری را ببینید.',
      false,
    ));
    _notify();
    _requestScroll();
  }

  Future<void> _process(String text, int gen) async {
    if (_draft != null) {
      // «انصراف» یا «می‌خواهم از این بحث بیرون بیایم» در فرم هم کار کند؛
      // وگرنه کاربر در فرم گیر می‌افتد.
      _draftStep(Drafting.isLeave(text) ? DraftCmd.cancel : text);
      return;
    }
    if (_draftRequest(text)) return;
    // «بله» به پیشنهادِ «می‌خواهید فلان متن را برایتان بنویسم؟».
    final offered = advocate.offeredDraft;
    if (offered != null && Drafting.isYes(text)) {
      final t = _templateFor(offered);
      if (t != null) {
        advocate.clearOffer();
        _startDraft(text, t);
        return;
      }
    }
    TopicGuess? guess;
    var shown = false;
    final read = guesser;
    if (read != null && advocate.wantsGuess(text)) {
      // خواندن جمله با مدل روی گوشی کمی طول می‌کشد؛ پیام کاربر همان لحظه
      // نشان داده می‌شود و جواب بعد از آن می‌آید.
      messages.add(ChatMessage(text, true));
      shown = true;
      thinking = true;
      _notify();
      _requestScroll();
      try {
        guess = await read(text);
      } catch (e) {
        problems.add('خواندن موضوع: $e');
        guess = null;
      }
      thinking = false;
      if (_disposed) return;
      if (gen != _generation) {
        // در این فاصله گفتگو عوض شده است؛ این پیام دیگر جایی ندارد.
        _notify();
        return;
      }
      lastGuess = guess ?? lastGuess;
    }
    final r = advocate.respond(text, guess: guess);
    if (!shown) messages.add(ChatMessage(text, true));
    messages.add(ChatMessage(r.text, false, chips: r.chips, laws: r.laws));
    unawaited(_saveSession());
    _notify();
    _requestScroll();
  }

  /// آیا این پیام درخواست نوشتن یک سند است؟ اگر بله، همان را شروع می‌کند
  /// (یا می‌پرسد کدام سند) و `true` برمی‌گرداند.
  bool _draftRequest(String text) {
    // لمس «تنظیم دادخواست …» یا «تنظیم لایحه …»: سندِ همین پرونده.
    final filing = advocate.filingFor(text);
    if (filing != null) {
      final t = _templateFor(filing.template);
      if (t != null) {
        _pendingList = [];
        advocate.clearOffer();
        _startDraft(text, t);
        return true;
      }
    }
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
      // «نه» باید پیش از جست‌وجوی عنوان بررسی شود؛ وگرنه همین دو حرف درون
      // عنوان یک قالب («هزینه») پیدا می‌شود و سندی ناخواسته شروع می‌شود.
      if (text == DraftCmd.cancel || Drafting.isNo(text)) {
        _reply(
          text,
          'باشد، فعلاً متنی نمی‌نویسم. هر وقت خواستید بگویید.',
          chips: advocate.idleChips,
        );
        return true;
      }
      final picked = Drafting.pickChoice(text, list);
      if (picked != null) {
        _startDraft(text, picked);
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

  /// دکمه‌ای که متنِ پیشنهادیِ وکیل را برای فیلد جاری می‌پذیرد.
  static const String useSuggestion = 'همین متن پیشنهادی';

  /// متن پیشنهادی برای فیلدی که الان پرسیده شده (خالی = پیشنهادی نیست).
  String _suggested = '';

  /// پرسشِ فیلد را با آنچه از گفتگو می‌دانیم همراه می‌کند: گزینهٔ درست جلو
  /// می‌آید، عدد به‌صورت دکمه پیشنهاد می‌شود و برای فیلدهای متنی، متنِ
  /// پیشنهادیِ وکیل زیر پرسش می‌آید تا با یک لمس پذیرفته شود.
  DraftReply _withCaseHelp(DraftReply raw, DraftSession s) {
    _suggested = '';
    final r = _withAmountChip(raw, s);
    if (r.ended || r.isDocument || s.done || s.pickingEdit) return r;
    final f = s.current;
    if (f == null || s.values.containsKey(f.id)) return r;
    final v = (advocate.fillFor(s.template.id)[f.id] ?? '').trim();
    if (v.isEmpty) return r;
    switch (f.type) {
      case 'choice':
        if (!r.chips.contains(v) || r.chips.first == v) return r;
        return DraftReply(
          r.text,
          chips: [v, ...r.chips.where((c) => c != v)],
          note: r.note,
        );
      case 'number':
        final n = PersianText.toFaDigits(v);
        if (r.chips.contains(n)) return r;
        return DraftReply(r.text, chips: [n, ...r.chips], note: r.note);
      case 'text':
      case 'multiline':
        _suggested = v;
        return DraftReply(
          '${r.text}\n\nپیشنهاد من از روی گفتگویمان:\n«$v»',
          chips: [useSuggestion, ...r.chips],
          note: r.note,
        );
    }
    return r;
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
    final r = _withCaseHelp(Drafting.start(s), s);
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
    var answer = text;
    if (text == useSuggestion) {
      // پذیرفتنِ متن پیشنهادی: همان متن به‌جای جواب می‌نشیند.
      final f = s.current;
      final v = _suggested.isNotEmpty
          ? _suggested
          : (f == null ? '' : (advocate.fillFor(s.template.id)[f.id] ?? ''));
      if (v.isNotEmpty) answer = v;
    }
    final r = _withCaseHelp(Drafting.answer(s, answer), s);
    messages.add(ChatMessage(answer, true, sensitive: true));
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
    _generation++;
    _sessionId = _newId();
    _resetFlow();
    if (settings.saveDraftProgress) {
      unawaited(DraftCheckpointStore.clear());
    }
    messages.clear();
    _notify();
  }

  void loadSession(ChatSession s) {
    _generation++;
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
    // نوشتن‌های در صف تاریخچه تا آخرین پیام ادامه یابند.
    unawaited(history.flush());
    super.dispose();
  }
}
