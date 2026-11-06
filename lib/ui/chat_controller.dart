import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/ui/chat_models.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/router.dart' show HybridIntentRouter, RoutingSource;
import 'package:dastyar/domain/dialogue/conversation_memory.dart'
    show DialogueStateManager;
import 'package:dastyar/domain/dialogue/dialogue_planner.dart'
    show ClarificationKind, ClarificationPrompt, ClarificationPromptGenerator;
import 'package:dastyar/domain/dialogue/response_composer.dart'
    show DynamicResponseComposer, UserMood;
import 'package:dastyar/domain/search/retrieval_pipeline.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/dialogue/small_talk_layer.dart';
import 'package:dastyar/domain/lawyer/lawyer_voice.dart';
import 'package:dastyar/domain/lawyer/phrase_variator.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';

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

  /// موضوع آخرین جلسهٔ مشاوره (برای «ادامهٔ مشاوره» پس از جمع‌بندی).
  String? _lastCounselTopic;

  /// شبکهٔ عصبی تشخیص نیت (اختیاری). اگر null باشد، مسیر نمادین قدیمی
  /// بدون هیچ تغییر رفتاری استفاده می‌شود.
  final IntentNet? _intentNet;

  /// منبع تصادف برای انتخاب قالب‌های متنوع پاسخ (تست‌ها نسخهٔ دانه‌دار
  /// می‌دهند تا خروجی قطعی بماند).
  final Random? _rnd;

  // پیشنهاد در انتظار تصمیم کاربر
  String? _pendingText;
  List<LegalTemplate> _pendingList = [];
  final Set<String> _declined = {};

  /// یادآوری «جای وکیل را نمی‌گیرد» فقط یک‌بار در هر گفتگو نمایش داده می‌شود.
  bool _disclaimerShown = false;
  static const SmallTalkLayer _smallTalk = SmallTalkLayer();

  /// مسیریاب ترکیبی (عبارت قطعی + کلیدواژهٔ وزن‌دار + شبکهٔ عصبی) برای
  /// انتخاب قالب سند در پیشنهاد ضمنی.
  final HybridIntentRouter _router = HybridIntentRouter();

  /// پرسش شفاف‌سازی «۱ یا ۲» وقتی دو قالب تقریباً هم‌وزن‌اند (شمارنده‌دار،
  /// بدون Random).
  final ClarificationPromptGenerator _clarifier =
      ClarificationPromptGenerator();
  ClarificationPrompt? _pendingClarification;

  /// اسلات‌هایی که کاربر در گفتگو گفته (مبلغ، تاریخ، مدرک، …)؛ هنگام
  /// تکمیل پیش‌نویس، به‌صورت دکمهٔ پیشنهادی همان فیلد نشان داده می‌شوند.
  final DialogueStateManager _slots = DialogueStateManager();

  /// همدلی متناسب با حال کاربر (شمارنده‌دار برای تنوع قطعی).
  final DynamicResponseComposer _composer = DynamicResponseComposer();

  /// چرخش قطعی جمله‌های آغاز/پایان پاسخ تا پاسخ‌ها کلیشه‌ای و تکراری نشوند.
  final PhraseVariator _phrases;

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
    IntentNet? intentNet,
    Random? random,
    CounselingSession? initialCounsel,
    this.onScrollRequested,
    int phraseSeed = 0,
  }) : _intentNet = intentNet,
       _rnd = random,
       _phrases = PhraseVariator(seed: phraseSeed) {
    if (loadError != null && loadError.isNotEmpty) {
      messages.add(ChatMessage(loadError, false, sensitive: true));
    }
    if (initialDraft != null && !initialDraft.done) {
      _draft = initialDraft;
      final r = Drafting.resumePrompt(initialDraft);
      messages.add(_botFromReply(r, initialDraft.template));
    }
    // بازیابی گفتگوی مشاورهٔ ناتمام از اجرای قبلی برنامه
    if (initialCounsel != null && !initialCounsel.concluded) {
      _counsel = initialCounsel;
      _lastCounselTopic = initialCounsel.topicId;
      final t = LegalCounselor.pendingTurn(
        initialCounsel,
        replies: engine.replies,
        rnd: _rnd,
      );
      if (t != null) {
        messages.add(ChatMessage(t.text, false, chips: t.chips));
      }
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
    _lastCounselTopic = null;
    _memory.clear();
    _pendingText = null;
    _pendingList = [];
    _declined.clear();
    _pendingClarification = null;
    _slots.reset();
    _slots.setIntent(null);
  }

  /// همگام‌سازی نقطهٔ بازیابی مشاورهٔ ناتمام (رمزنگاری‌شده) با وضعیت جلسه.
  void _syncCounselCheckpoint() {
    if (!settings.saveDraftProgress || _disposed) return;
    final s = _counsel;
    if (s == null || s.concluded) {
      unawaited(CounselCheckpointStore.clear());
    } else {
      unawaited(CounselCheckpointStore.save(s));
    }
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
    _slots.extractAndUpdate(text);
    if (_counsel != null) {
      if (_handleActiveCounsel(text)) return;
    }
    if (_pendingList.isNotEmpty) {
      if (await _handlePendingList(text)) return;
    }
    if (_handleResumeCounsel(text)) return;
    if (_handleExplicitDraft(text)) return;
    if (_handleSmallTalk(text)) return;
    if (_handleStrictCriminalPhrase(text)) return;
    if (await _handleLawyerGuide(text)) return;
    if (_handleImplicitDraftSuggestion(text)) return;
    if (await _handleStartCounsel(text)) return;

    final (greeted, core) = LawyerVoice.splitLeadingGreeting(text);
    await _ask(text, query: greeted ? core : null, greeted: greeted);
  }

  /// احوال‌پرسی، تشکر، خداحافظی و ابراز ناراحتیِ بدون موضوع حقوقی: پاسخ
  /// گرم و انسانی، به‌جای جست‌وجوی بی‌ربط در متن قوانین.
  bool _handleSmallTalk(String text) {
    final reply = _smallTalk.tryHandle(text, rnd: _rnd);
    if (reply == null) return false;
    messages.add(ChatMessage(text, true));
    messages.add(ChatMessage(reply.text, false, chips: reply.chips));
    unawaited(_saveSession());
    _notify();
    _requestScroll();
    return true;
  }

  /// مسائل رایج حقوقی با پاسخ وکیل‌مانند: همدلی، توضیح منطقی، قدم‌های عملی،
  /// مبنای قانونی از متن رسمی و پرسش پیگیری. اگر کاربر ماجرای شخصی خود را
  /// تعریف کرده (نه پرسش)، همان مقدمه گفته می‌شود و مشاورهٔ گام‌به‌گام شروع
  /// می‌شود تا پاسخ‌های بعدی کاربر گم نشود.
  Future<bool> _handleLawyerGuide(String text) async {
    if (text == LegalCounselor.startCounselCmd ||
        text == DraftCmd.offerCounsel) {
      return false;
    }
    final (greeted, core) = LawyerVoice.splitLeadingGreeting(text);
    final guide = LawyerVoice.matchGuide(core);
    if (guide == null) return false;
    final personal = LawyerVoice.isPersonal(core) ||
        LegalCounselor.shouldStartCounseling(core, net: _intentNet);

    // ماجرای شخصی (حتی همراه با «چه کار کنم؟») به مشاورهٔ گام‌به‌گام می‌رود
    // تا پاسخ‌های بعدی کاربر در همان پرونده جمع شود؛ پرسش عمومی پاسخ کامل
    // راهنما را می‌گیرد.
    final narrative =
        LegalCounselor.shouldStartCounseling(core, net: _intentNet);
    if (narrative) {
      final started = LegalCounselor.start(
        core,
        engine,
        repo.templates,
        net: _intentNet,
        replies: engine.replies,
        rnd: _rnd,
      );
      if (started != null &&
          started.$1.topicId != 'general_intake' &&
          LawyerVoice.counselTopicFits(guide, started.$1.topicId)) {
        _counsel = started.$1;
        _lastCounselTopic = started.$1.topicId;
        final preface = LawyerVoice.counselPreface(guide, core);
        messages.add(ChatMessage(text, true, sensitive: true));
        messages.add(
          ChatMessage(
            '$preface\n\n${started.$2.text}',
            false,
            sensitive: true,
            chips: started.$2.chips,
          ),
        );
        _memory.recordTurn(core, engine.query(core, maxAlternatives: 0));
        _syncCounselCheckpoint();
        await _saveSession();
        _notify();
        _requestScroll();
        return true;
      }
    }

    final reply = LawyerVoice.composeGuide(
      guide,
      core,
      engine,
      templates: repo.templates,
      greeted: greeted,
      includeDisclaimer: !_disclaimerShown,
      counselChip: LegalCounselor.startCounselCmd,
      rnd: _rnd,
      variator: _phrases,
    );
    _disclaimerShown = true;
    _memory.recordTurn(core, engine.query(core, maxAlternatives: 0));
    messages.add(ChatMessage(text, true, sensitive: personal));
    messages.add(
      ChatMessage(reply.text, false, sensitive: personal, chips: reply.chips),
    );
    await _saveSession();
    _notify();
    _requestScroll();
    return true;
  }

  bool _handleActiveCounsel(String text) {
    final counsel = _counsel;
    if (counsel == null) return false;

    // «ادامهٔ مشاوره» پس از جمع‌بندی جلسه → بازگشایی همان موضوع
    if (counsel.concluded && LegalCounselor.wantsResume(text)) {
      final resumed = LegalCounselor.resumeTopic(
        counsel.topicId,
        text,
        engine,
        repo.templates,
        replies: engine.replies,
        rnd: _rnd,
      );
      if (resumed != null) {
        _counsel = resumed.$1;
        _lastCounselTopic = resumed.$1.topicId;
        messages.add(ChatMessage(text, true));
        messages.add(
          ChatMessage(resumed.$2.text, false, chips: resumed.$2.chips),
        );
        _syncCounselCheckpoint();
        unawaited(_saveSession());
        _notify();
        _requestScroll();
        return true;
      }
    }

    // حافظهٔ گفتگو: ارجاع‌های مبهم («ماده بعدی‌اش چی؟») پیش از ورود به
    // درخت تصمیم با موضوع قبلی بازنویسی می‌شوند (پیام کاربر دست‌نخورده
    // نمایش داده می‌شود).
    final turn = LegalCounselor.step(
      counsel,
      _memory.resolveFollowUp(text),
      engine,
      repo.templates,
      net: _intentNet,
      replies: engine.replies,
      rnd: _rnd,
    );

    if (turn.cancelled) {
      _counsel = null;
      messages.add(ChatMessage(text, true));
      messages.add(ChatMessage(turn.text, false));
      _syncCounselCheckpoint();
      unawaited(_saveSession());
      _notify();
      _requestScroll();
      return true;
    }

    if (turn.startTemplate != null) {
      _counsel = null;
      _syncCounselCheckpoint();
      _startDraft(text, turn.startTemplate!);
      return true;
    }

    if (turn.text.isNotEmpty) {
      if (turn.completed && turn.chips.isEmpty) {
        _counsel = null;
      }
      // حافظهٔ گفتگو: اگر پرسش حقوقی میانهٔ مشاوره با RAG پاسخ گرفت،
      // موضوعش ثبت می‌شود تا «بعدی‌اش چی؟» به همان قانون ارجاع بدهد.
      if (turn.ragQuery != null && turn.ragReply != null) {
        _memory.recordTurn(turn.ragQuery!, turn.ragReply!);
      }
      messages.add(ChatMessage(text, true));
      messages.add(ChatMessage(turn.text, false, chips: turn.chips));
      _syncCounselCheckpoint();
      unawaited(_saveSession());
      _notify();
      _requestScroll();
      return true;
    }

    // اگر مشاوره قبلاً جمع‌بندی شده و کاربر اکنون پرسش جدیدی مطرح کرده است:
    _counsel = null;
    _syncCounselCheckpoint();
    return false;
  }

  Future<bool> _handlePendingList(String text) async {
    final clar = _pendingClarification;
    _pendingClarification = null;
    if (clar != null) {
      final chosen = clar.resolveChoice(text);
      if (chosen != null) {
        final tpl = _templateFor(chosen);
        if (tpl != null) {
          _pendingText = null;
          _pendingList = [];
          _startDraft(text, tpl);
          return true;
        }
      }
    }
    final pt = _pendingText;
    final list = _pendingList;

    if (text == DraftCmd.offerCounsel ||
        text == LegalCounselor.startCounselCmd) {
      _pendingText = null;
      _pendingList = [];
      final started = LegalCounselor.start(
        pt ?? text,
        engine,
        repo.templates,
        net: _intentNet,
        replies: engine.replies,
        rnd: _rnd,
      );
      if (started != null) {
        _counsel = started.$1;
        _lastCounselTopic = started.$1.topicId;
        messages.add(ChatMessage(text, true));
        messages.add(
          ChatMessage(started.$2.text, false, chips: started.$2.chips),
        );
        _syncCounselCheckpoint();
        unawaited(_saveSession());
        _notify();
        _requestScroll();
        return true;
      }
    }

    final isDecline =
        text == DraftCmd.offerNo ||
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
      return true;
    }

    final isAccept = text == DraftCmd.offerYes || Drafting.isYes(text);
    if (isAccept) {
      if (list.length == 1) {
        _pendingText = null;
        _pendingList = [];
        _startDraft(text, list.first);
        return true;
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
      return true;
    }

    // پیشنهاد ضمنیِ تک‌قالب: فقط «بله»/«خیر» یا عنوان دقیق قالب پاسخ آن است.
    // هر پیام دیگری (مثل «طلبکار هستم») پیام تازهٔ کاربر است و نباید به‌اشتباه
    // پذیرش پیشنهاد تلقی شود.
    if (pt != null && list.length == 1) {
      _pendingText = null;
      _pendingList = [];
      final n = KnowledgeEngine.normalize(text).trim();
      if (KnowledgeEngine.normalize(list.first.title).trim() == n) {
        _startDraft(text, list.first);
        return true;
      }
      return false;
    }

    final picked = Drafting.pickChoice(text, list);
    _pendingText = null;
    _pendingList = [];
    if (picked != null) {
      _startDraft(text, picked);
      return true;
    }
    return false;
  }

  bool _handleResumeCounsel(String text) {
    if (_counsel != null) return false;
    if (_lastCounselTopic == null) return false;
    if (!LegalCounselor.wantsResume(text)) return false;

    final resumed = LegalCounselor.resumeTopic(
      _lastCounselTopic!,
      text,
      engine,
      repo.templates,
      replies: engine.replies,
      rnd: _rnd,
    );
    if (resumed == null) return false;

    _counsel = resumed.$1;
    messages.add(ChatMessage(text, true));
    messages.add(ChatMessage(resumed.$2.text, false, chips: resumed.$2.chips));
    _syncCounselCheckpoint();
    unawaited(_saveSession());
    _notify();
    _requestScroll();
    return true;
  }

  bool _handleExplicitDraft(String text) {
    final intent = Drafting.detect(text, repo.templates);
    final directTpl = intent.template;
    if (directTpl != null) {
      _startDraft(text, directTpl);
      return true;
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
          chips: [...intent.choices.map((t) => t.title), DraftCmd.cancel],
        ),
      );
      _notify();
      _requestScroll();
      return true;
    }
    return false;
  }

  /// برچسب‌های موضوعی شبکهٔ قصد → شناسهٔ قالب سندِ متناظر (برای ورودی
  /// احتمالاتیِ مسیریاب ترکیبی). موضوعی که قالب مستقیم ندارد «none» است.
  static const Map<String, String> _topicToTemplateIntent = {
    'debt': 'demand_money',
    'cheque': 'demand_money',
    'criminal_harm': 'complaint',
    'fraud_cyber': 'complaint',
    'litigation_defense': 'defense_brief',
  };

  LegalTemplate? _templateFor(String intent) {
    for (final t in repo.templates) {
      if (t.id == intent) return t;
    }
    return null;
  }

  /// توزیع احتمال شبکهٔ عصبی در فضای قصدهای قالب؛ بدون شبکه null.
  Map<String, double>? _templateIntentProbs(String text) {
    final net = _intentNet;
    if (net == null) return null;
    final out = <String, double>{};
    for (final s in net.top(text, k: 16)) {
      final key =
          _topicToTemplateIntent[s.label] ?? HybridIntentRouter.noneIntent;
      out[key] = (out[key] ?? 0) + s.score;
    }
    return out;
  }

  /// متن پیشنهاد قالب، به‌همراه یادآوری اطلاعاتی که کاربر تا اینجا گفته.
  String _offerTextWithSlots(LegalTemplate t) {
    final base = Drafting.offerText(t);
    final noted = <String>[
      for (final e in _slots.slots.entries)
        if (e.value.raw != 'none' &&
            e.value.raw != 'unknown' &&
            _fieldForSlot(t, e.key) != null)
          '${DialogueStateManager.slotLabels[e.key] ?? e.key}: ${e.value.display}',
    ];
    if (noted.isEmpty) return base;
    return '$base\n\nاین موارد را از صحبت شما یادداشت کردم و هنگام تکمیل متن '
        'به‌صورت پیشنهاد نشان می‌دهم: ${noted.join('، ')}.';
  }

  /// فیلد قالب متناظر با یک اسلات گفتگو (اگر قالب چنین فیلدی داشته باشد).
  static const Map<String, List<String>> _slotFields = {
    DialogueStateManager.amount: ['amount'],
    DialogueStateManager.date: ['cheque_date', 'event_date'],
    DialogueStateManager.incidentType: ['charge'],
    DialogueStateManager.proof: ['evidence'],
    DialogueStateManager.incomeStatus: ['income_state'],
  };

  TemplateField? _fieldForSlot(LegalTemplate t, String slot) {
    final ids = _slotFields[slot] ?? const <String>[];
    for (final f in t.fields) {
      if (ids.contains(f.id)) return f;
    }
    return null;
  }

  /// مقدار پیشنهادی برای فیلد جاری پیش‌نویس از اسلات‌های گفتگو.
  String? _slotSuggestionFor(DraftSession s) {
    final f = s.current;
    if (f == null || s.values.containsKey(f.id)) return null;
    for (final e in _slotFields.entries) {
      if (!e.value.contains(f.id)) continue;
      final v = _slots.slot(e.key);
      if (v == null || v.raw == 'none' || v.raw == 'unknown') return null;
      if (f.type == 'number') {
        // فیلدهای مبلغ قالب‌ها به ریال‌اند؛ اسلات مبلغ به تومان ذخیره می‌شود.
        final toman = v.value;
        if (toman == null || toman <= 0) return null;
        final rial = (toman * 10).round();
        return PersianText.toFaDigits(rial.toString());
      }
      if (f.type == 'choice' || f.type == 'check') return null;
      return v.display;
    }
    return null;
  }

  void _offerTemplate(String text, LegalTemplate t) {
    _pendingText = text;
    _pendingList = [t];
    messages.add(ChatMessage(text, true, sensitive: true));
    messages.add(
      ChatMessage(
        _offerTextWithSlots(t),
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
  }

  /// عبارت‌های قطعیِ کیفری (مثل «سرقت چک» یا «جعل امضا») حتی پیش از
  /// راهنماهای عمومی بررسی می‌شوند تا مثلاً سرقت چک با چک برگشتی یا
  /// موضوع دیگری اشتباه نشود.
  bool _handleStrictCriminalPhrase(String text) {
    final strict = _router.matchStrict(text);
    if (strict == null || strict.intent != 'complaint') return false;
    if (_declined.contains(strict.intent)) return false;
    final t = _templateFor(strict.intent);
    if (t == null) return false;
    _slots.setIntent(t.id);
    _offerTemplate(text, t);
    return true;
  }

  bool _handleImplicitDraftSuggestion(String text) {
    final avail = repo.templates
        .where((t) => !_declined.contains(t.id))
        .toList();
    final availIds = {for (final t in avail) t.id};
    final decision = _router.route(
      text,
      networkProbabilities: _templateIntentProbs(text),
    );

    // ۱. عبارت قطعی (مثل «سرقت چک» → شکایت کیفری) بر حدس‌های دیگر مقدم است.
    if (decision.source == RoutingSource.strictPhrase &&
        availIds.contains(decision.intent)) {
      final t = _templateFor(decision.intent)!;
      _slots.setIntent(t.id);
      _offerTemplate(text, t);
      return true;
    }

    final sug = Drafting.suggest(text, avail);
    final sugTpl = sug.template;
    if (sugTpl != null) {
      _slots.setIntent(sugTpl.id);
      _pendingText = text;
      _pendingList = [sugTpl];
      messages.add(ChatMessage(text, true, sensitive: true));
      messages.add(
        ChatMessage(
          _offerTextWithSlots(sugTpl),
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
      return true;
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
      return true;
    }

    // ۲. دو قالب تقریباً هم‌وزن: به‌جای حدس، پرسش شفاف‌سازی «۱ یا ۲».
    // فقط برای روایت (نه پرسش) و با شاهد کلیدواژه‌ای کافی.
    if (!LawyerVoice.isQuestion(text) &&
        decision.keywordScores.totalEvidence >=
            _router.config.minKeywordEvidence) {
      final probs = {
        for (final e in decision.probabilities.entries)
          if (availIds.contains(e.key)) e.key: e.value,
      };
      final clar = _clarifier.next(text, probs);
      if (clar != null &&
          clar.kind == ClarificationKind.choice &&
          clar.options.length == 2) {
        final tpls = [
          for (final o in clar.options)
            if (_templateFor(o) != null) _templateFor(o)!,
        ];
        if (tpls.length == 2) {
          _pendingText = text;
          _pendingList = tpls;
          _pendingClarification = clar;
          messages.add(ChatMessage(text, true, sensitive: true));
          messages.add(
            ChatMessage(
              clar.text,
              false,
              sensitive: true,
              chips: [
                ...tpls.map((t) => t.title),
                DraftCmd.offerCounsel,
                DraftCmd.offerNo,
              ],
            ),
          );
          _notify();
          _requestScroll();
          return true;
        }
      }
    }
    return false;
  }

  Future<bool> _handleStartCounsel(String text) async {
    if (!LegalCounselor.shouldStartCounseling(text, net: _intentNet)) {
      return false;
    }
    final seed =
        (text == LegalCounselor.startCounselCmd &&
            _memory.lastTopicQuery.isNotEmpty)
        ? _memory.lastTopicQuery
        : text;
    final started = LegalCounselor.start(
      seed,
      engine,
      repo.templates,
      net: _intentNet,
      replies: engine.replies,
      rnd: _rnd,
    );
    if (started == null) return false;
    _counsel = started.$1;
    _lastCounselTopic = started.$1.topicId;
    messages.add(ChatMessage(text, true));
    messages.add(ChatMessage(started.$2.text, false, chips: started.$2.chips));
    _syncCounselCheckpoint();
    await _saveSession();
    _notify();
    _requestScroll();
    return true;
  }

  Future<void> _ask(
    String text, {
    bool addUser = true,
    bool sensitive = false,
    String? query,
    bool greeted = false,
  }) async {
    final resolvedQuery = _memory.resolveFollowUp(query ?? text);
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

    _sub = assistant
        .askWithAlternatives(resolvedQuery)
        .listen(
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
    final baseReply = engine.query(resolvedQuery, maxAlternatives: 0);
    _memory.recordTurn(resolvedQuery, baseReply);
    // لحن وکیل: متن ماده دست‌نخورده می‌ماند، اما با مقدمه و جمع‌بندی انسانی
    // ارائه می‌شود؛ و «پیدا نکردم» به پاسخی صادقانه و راهگشا تبدیل می‌شود.
    final userText = query ?? text;
    final notFoundRaw = engine.replies.get('not_found');
    final wasNotFound = bot.text.trim() == notFoundRaw.trim();

    // همدلی متناسب با حال کاربر (نگران/عصبانی).
    var mood = DynamicResponseComposer.detectMood(userText);
    if (mood == UserMood.neutral && LawyerVoice.expressesDistress(userText)) {
      mood = UserMood.anxious;
    }
    final empathy = _composer.empathyFor(mood);

    // افت تدریجی: شباهت = بیشترین پوشش واژه‌های پرسش در مواد بازیابی‌شده.
    String? notFoundOverride;
    String? bridge;
    final topicHint =
        LegalCounselor.detectTopicHint(resolvedQuery, net: _intentNet);
    if (wasNotFound) {
      notFoundOverride = RetrievalPipeline.handleLowConfidenceRetrieval(
        userText,
        similarity: _retrievalSimilarity(resolvedQuery, baseReply),
        candidateTopic: topicHint,
      );
    } else if (baseReply.contextHits.isNotEmpty &&
        !LawyerVoice.isDirectArticleRef(userText)) {
      final sim = _retrievalSimilarity(resolvedQuery, baseReply);
      if (sim >= RetrievalPipeline.refuseBelow &&
          sim < RetrievalPipeline.bridgeBelow) {
        bridge = RetrievalPipeline.handleLowConfidenceRetrieval(
          userText,
          similarity: sim,
          candidateTopic: topicHint,
        );
      }
    }

    final framed = LawyerVoice.frameEngineAnswer(
      userText,
      baseReply,
      bot.text,
      notFoundRaw: notFoundRaw,
      greeted: greeted,
      rnd: _rnd,
      empathy: empathy,
      notFoundOverride: notFoundOverride,
      bridge: bridge,
      variator: _phrases,
    );
    if (framed != null) bot.text = framed;
    if (wasNotFound && alts.isEmpty) alts = LawyerVoice.notFoundChips;
    final mergedChips = <String>[
      ...alts,
      if (!sensitive && topicHint != null)
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

  /// شباهت بازیابی در بازهٔ ۰ تا ۱: بیشترین پوشش واژه‌های پرسش در چند
  /// مادهٔ برتر. بدون ماده NaN (یعنی «اطلاعات مطمئن نیست»).
  double _retrievalSimilarity(String question, EngineReply reply) {
    if (reply.contextHits.isEmpty) return double.nan;
    var best = 0.0;
    for (final h in reply.contextHits.take(4)) {
      final c = engine.coverage(question, h.chunk);
      if (c > best) best = c;
    }
    return best;
  }

  /// افزودن دکمهٔ «مقدار پیشنهادی» از اسلات‌های گفتگو به پرسش فیلد جاری.
  DraftReply _withSlotChip(DraftReply r, DraftSession s) {
    if (r.ended || r.isDocument) return r;
    final v = _slotSuggestionFor(s);
    if (v == null || r.chips.contains(v)) return r;
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
    if (_slots.intent != t.id) _slots.setIntent(t.id);
    final r = _withSlotChip(Drafting.start(s), s);
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
    final r = _withSlotChip(Drafting.answer(s, text), s);
    messages.add(ChatMessage(text, true, sensitive: true));
    messages.add(_botFromReply(r, s.template));
    if (r.ended) {
      _draft = null;
      _slots.reset();
      _slots.setIntent(null);
    }
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

  /// ذخیرهٔ صریح جلسهٔ مشاورهٔ ناتمام به‌صورت رمزنگاری‌شده.
  Future<bool> saveCounselCheckpoint() async {
    final s = _counsel;
    if (s == null || s.concluded) {
      await CounselCheckpointStore.clear();
      return false;
    }
    return CounselCheckpointStore.save(s);
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
      unawaited(CounselCheckpointStore.clear());
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
      unawaited(CounselCheckpointStore.clear());
    }
    messages
      ..clear()
      ..addAll(
        s.messages.map((m) => ChatMessage(m.text, m.fromUser, revealed: true)),
      );
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
