import 'dart:async';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/ui/chat_models.dart';
import 'package:dastyar/ui/draft_flow.dart';
import 'package:dastyar/ui/guess_flow.dart';

/// جریانِ صفِ پیام، پردازش نوبت، خطاهای زمان اجرا و ذخیره/بازیابی نشست.
///
/// پیش‌تر همهٔ این‌ها کنار تنظیم سند و حدسِ مدل درون [ChatController] بود.
/// این همکار صفِ ترتیبی ([submit])، قفلِ نسل گفتگو ([_generation])،
/// هماهنگی با [DraftFlow] و [GuessFlow]، و خواندن/نوشتنِ تاریخچه را نگه
/// می‌دارد تا [ChatController] فقط یک پوستهٔ سیم‌کشی بماند.
class ReplyFlow {
  ReplyFlow({
    required this.engine,
    required this.history,
    required this.settings,
    required this.advocate,
    required this.draftFlow,
    required this.guessFlow,
    required this.messages,
    required this.changed,
    required this.scrollToEnd,
    required this.isAlive,
  });

  final KnowledgeEngine engine;
  final HistoryStore history;
  final AppSettings settings;
  final Advocate advocate;
  final DraftFlow draftFlow;
  final GuessFlow guessFlow;
  final List<ChatMessage> messages;
  final void Function() changed;
  final void Function() scrollToEnd;
  final bool Function() isAlive;

  /// خطاهای زمان اجرا (فقط روی همین گوشی، برای عیب‌یابی).
  final List<String> problems = [];

  /// پیام‌ها به ترتیب رسیدن پردازش می‌شوند، حتی اگر یکی منتظر مدل باشد.
  Future<void> _queue = Future<void>.value();

  String _sessionId = _newId();

  /// شمارهٔ نسل گفتگو؛ با هر «گفتگوی جدید» یا بازکردن گفتگوی دیگر یکی
  /// زیاد می‌شود تا پیام‌های در صف به گفتگوی تازه نچسبند.
  int _generation = 0;

  static String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  String get sessionId => _sessionId;

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

  void addProblem(String message) {
    problems.add(message);
    if (problems.length > 20) problems.removeAt(0);
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
    if (text.isEmpty || !isAlive() || gen != _generation) return;
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
    if (!isAlive()) return;
    guessFlow.reset();
    addProblem('$e');
    if (messages.length == before) {
      messages.add(ChatMessage(text, true));
    }
    messages.add(ChatMessage(
      'این پیام را نتوانستم درست پردازش کنم. اگر دوباره بفرستید یا کمی ساده‌تر '
      'بنویسید، از نو امتحان می‌کنم. اگر تکرار شد، از منوی «اطلاعات و وضعیت '
      'داده‌ها» وضعیت بارگذاری را ببینید.',
      false,
    ));
    changed();
    scrollToEnd();
  }

  Future<void> _process(String text, int gen) async {
    if (_handleDraft(text)) return;
    final guessed = await guessFlow.read(
      text,
      isCurrent: () => gen == _generation,
    );
    if (guessed.stale) return;
    // worker بازیابی و رتبهبندی مواد در isolate موتور انجام میشود؛
    // رابط تنها جواب آماده را میگیرد. اگر worker نبود یا خطا داد، وکیل همان
    // مسیر همگام پیشین را میگیرد.
    await Future<void>.delayed(Duration.zero);
    if (!isAlive() || gen != _generation) return;
    final prepared = await _prepare(text);
    if (!isAlive() || gen != _generation) return;
    final r = advocate.respond(
      text,
      guess: guessed.guess,
      engineReply: prepared,
    );
    if (!guessed.shown) messages.add(ChatMessage(text, true));
    messages.add(ChatMessage(r.text, false, chips: r.chips, laws: r.laws));
    unawaited(saveSession());
    changed();
    scrollToEnd();
  }

  bool _handleDraft(String text) {
    if (draftFlow.isDrafting) {
      // «انصراف» یا «می‌خواهم از این بحث بیرون بیایم» در فرم هم کار کند؛
      // وگرنه کاربر در فرم گیر می‌افتد.
      draftFlow.step(DraftWords.isLeave(text) ? DraftCmd.cancel : text);
      return true;
    }
    if (draftFlow.handle(text)) return true;
    // «بله» به پیشنهادِ «می‌خواهید فلان متن را برایتان بنویسم؟».
    final offered = advocate.offeredDraft;
    if (offered != null && DraftWords.isYes(text)) {
      final t = draftFlow.templateFor(offered);
      if (t != null) {
        advocate.clearOffer();
        draftFlow.start(text, t);
        return true;
      }
    }
    return false;
  }

  Future<EngineReply?> _prepare(String text) async {
    try {
      return await engine.prepareQuery(text);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession() async {
    if (!settings.saveHistory ||
        !settings.localPersistenceAvailable ||
        !isAlive()) return;
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
        dialogueJson: advocate.dialog.toJson(),
      ),
    );
  }

  void _resetFlow() {
    draftFlow.reset();
    guessFlow.reset();
    advocate.reset();
    if (settings.saveDraftProgress) {
      unawaited(DraftCheckpointStore.clear());
    }
  }

  void newChat() {
    _generation++;
    _sessionId = _newId();
    _resetFlow();
    messages.clear();
    changed();
  }

  void loadSession(ChatSession s) {
    _generation++;
    _sessionId = s.id;
    _resetFlow();
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
      advocate.restoreCase(saved, dialogue: s.dialogueJson);
    } else {
      // گفتگوی ذخیره‌شدهٔ قدیمی: پرونده از روی پیام‌های خودِ کاربر ساخته می‌شود.
      advocate.replay([
        for (final m in s.messages)
          if (m.fromUser) m.text,
      ]);
    }
    changed();
    scrollToEnd();
  }
}
