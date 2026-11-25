import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/domain/understanding/topic_guess.dart';
import 'package:dastyar/ui/chat_models.dart';
import 'package:dastyar/ui/draft_flow.dart';

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
  bool _disposed = false;

  /// شمارهٔ نسل گفتگو؛ با هر «گفتگوی جدید» یا بازکردن گفتگوی دیگر یکی
  /// زیاد می‌شود تا پیام‌های در صف به گفتگوی تازه نچسبند.
  int _generation = 0;

  /// خطاهای زمان اجرا (فقط روی همین گوشی، برای عیب‌یابی).
  final List<String> problems = [];

  /// وکیل بدون مدل: فهم محاوره، حافظهٔ پرونده و تحلیل مستند به متن قانون.
  late final Advocate advocate;

  /// جریانِ نوشتن سند؛ فرم و پیش‌نویسِ ناتمام کارِ اوست، نه کنترلرِ گفتگو.
  late final DraftFlow draftFlow;

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
      save: () => unawaited(_saveSession()),
      isAlive: () => !_disposed,
    );
    if (loadError != null && loadError.isNotEmpty) {
      messages.add(ChatMessage(loadError, false, sensitive: true));
    }
    if (initialDraft != null && !initialDraft.done) {
      draftFlow.resume(initialDraft);
    }
  }

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String get sessionId => _sessionId;

  /// سندِ در دستِ تنظیم (اگر باشد).
  DraftSession? get draft => draftFlow.draft;
  bool get isDrafting => draftFlow.isDrafting;
  List<LegalTemplate> get pendingChoices => draftFlow.pendingChoices;

  /// دکمهٔ پذیرشِ متن پیشنهادی؛ برای صفحه، همان ثابتِ [DraftFlow].
  static const String useSuggestion = DraftFlow.useSuggestion;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _requestScroll() {
    if (!_disposed) onScrollRequested?.call();
  }

  void _resetFlow() {
    draftFlow.reset();
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
    if (draftFlow.isDrafting) {
      // «انصراف» یا «می‌خواهم از این بحث بیرون بیایم» در فرم هم کار کند؛
      // وگرنه کاربر در فرم گیر می‌افتد.
      draftFlow.step(DraftWords.isLeave(text) ? DraftCmd.cancel : text);
      return;
    }
    if (draftFlow.handle(text)) return;
    // «بله» به پیشنهادِ «می‌خواهید فلان متن را برایتان بنویسم؟».
    final offered = advocate.offeredDraft;
    if (offered != null && DraftWords.isYes(text)) {
      final t = draftFlow.templateFor(offered);
      if (t != null) {
        advocate.clearOffer();
        draftFlow.start(text, t);
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
    // پاسخسازی و بازیابی مواد همگاماند و روی رشتهٔ رابط کاربری اجرا میشوند.
    // یک چرخهٔ event به رابط فرصت میدهد پیام کاربر و حالت «در حال خواندن» را
    // قبل از شروع محاسبه رسم کند؛ محاسبه همچنان همگام است ولی چشمک نمیزند.
    await Future<void>.delayed(Duration.zero);
    if (_disposed || gen != _generation) return;
    final r = advocate.respond(text, guess: guess);
    if (!shown) messages.add(ChatMessage(text, true));
    messages.add(ChatMessage(r.text, false, chips: r.chips, laws: r.laws));
    unawaited(_saveSession());
    _notify();
    _requestScroll();
  }

  Future<void> _saveSession() async {
    if (!settings.saveHistory || _disposed) return;
    final stored = messages
        .where((m) => !m.sensitive && !m.isDoc)
        .map((m) => StoredMsg(m.text, m.fromUser, chips: m.chips))
        .toList();
    final users = stored.where((m) => m.fromUser).toList();
    if (users.isEmpty) return;
    await history.upsert(
      ChatSession(
        id: _sessionId,
        title: HistoryStore.makeTitle(users.first.text),
        updated: DateTime.now().millisecondsSinceEpoch,
        messages: stored,
        // پروندهٔ گفتگو هم ذخیره می‌شود تا بازکردن دوباره، پیام‌ها را از نو
        // پردازش نکند و «بله/نه/نمی‌دانم»ها با گذشت زمان جابه‌جا نشوند.
        caseJson: advocate.file.hasContent ? advocate.file.toJson() : null,
      ),
    );
  }

  /// ذخیرهٔ صریح وضعیت پیش‌نویس ناتمام (رمزنگاری‌شده).
  Future<bool> saveDraftCheckpoint() => draftFlow.saveCheckpoint();

  /// بازیابی پیش‌نویس ناتمام ذخیره‌شده.
  Future<bool> restoreDraftCheckpoint() => draftFlow.restoreCheckpoint();

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
        s.messages.map((m) => ChatMessage(
              m.text,
              m.fromUser,
              // دکمه‌های پیشنهادی همان‌جا که بودند برمی‌گردند؛ وگرنه گفتگوی
              // بازیابی‌شده راه ادامه ندارد.
              chips: m.chips,
              revealed: true,
            )),
      );
    final saved = s.caseJson;
    if (saved != null) {
      // پرونده همان‌طور که بود برمی‌گردد؛ هیچ پیامی دوباره پردازش نمی‌شود.
      advocate.restoreCase(saved);
    } else {
      // گفتگوی ذخیره‌شدهٔ قدیمی: پرونده از روی پیام‌های خودِ کاربر ساخته می‌شود.
      advocate.replay([
        for (final m in s.messages)
          if (m.fromUser) m.text,
      ]);
    }
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
