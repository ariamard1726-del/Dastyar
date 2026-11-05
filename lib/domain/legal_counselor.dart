import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/core/debug_logger.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/core/replies.dart';
import 'package:dastyar/domain/templates.dart';

import 'dialogue/dialogue_state.dart';
import 'dialogue/dialogue_integration.dart';
import 'dialogue/response_composer.dart';
import 'dialogue/small_talk_layer.dart';
import 'dialogue/slots.dart';
export 'dialogue/conversation_memory.dart' show ConversationMemory;

/// پاسخ یک گام از مشاورهٔ دوطرفهٔ حقوقی (بدون هیچ مدل زبانی).
class CounselorTurn {
  final String text;
  final List<String> chips;
  final bool completed;
  final bool cancelled;
  final LegalTemplate? startTemplate;

  final String? ragQuery;
  final EngineReply? ragReply;

  const CounselorTurn({
    required this.text,
    this.chips = const [],
    this.completed = false,
    this.cancelled = false,
    this.startTemplate,
    this.ragQuery,
    this.ragReply,
  });
}

/// مسیرهایی که [LegalCounselor.step] می‌تواند برای یک پیام انتخاب کند.
///
/// این enum فقط برای مشاهده‌پذیری (ابزار ارزیابی و صفحهٔ دیباگ) است و هیچ
/// رفتاری را تغییر نمی‌دهد؛ هر مقدار دقیقاً همان نقطهٔ بازگشتِ مربوط در
/// `step` را توصیف می‌کند.
enum CounselorRoute {
  /// پیام خالی.
  empty,

  /// فرمان پایان/انصراف مشاوره.
  cancel,

  /// انتخاب یک قالبِ تنظیم سند از میان چیپ‌های پاسخ.
  template,

  /// خداحافظی.
  goodbye,

  /// لایهٔ گفتگوی کوتاه (غیرحقوقی).
  smallTalk,

  /// پاسخ به پرسش حقوقی از بانک قوانین (RAG).
  rag,

  /// مرحلهٔ پذیرش اولیه (هنوز دامنهٔ حقوقی مشخص نیست).
  intake,

  /// گام بعدیِ مشاورهٔ موضوعی (پرسش/جمع‌بندی).
  domain,
}

/// نتیجهٔ یک نوبتِ مشاوره به‌همراه ردِ دیباگِ همان نوبت.
class TracedCounselorTurn {
  final CounselorTurn turn;
  final TurnTrace trace;
  final CounselorRoute? route;

  const TracedCounselorTurn({
    required this.turn,
    required this.trace,
    this.route,
  });
}

/// وضعیت فعال یک گفتگوی تشخیصی چندمرحله‌ای با کاربر.
class CounselingSession {
  String topicId;
  final String initialMessage;
  final Map<String, String> facts = {};
  bool concluded = false;

  DialogueState? dialogueState;

  CounselingSession({required this.topicId, required this.initialMessage});

  Map<String, dynamic> toJson() {
    final m = <String, dynamic>{
      'topicId': topicId,
      'initialMessage': initialMessage,
      'facts': Map<String, String>.of(facts),
      'concluded': concluded,
    };
    if (dialogueState != null) {
      m['dialogueState'] = dialogueState!.toJson();
    }
    return m;
  }

  static CounselingSession? fromJson(Map<String, dynamic> j) {
    try {
      final s = CounselingSession(
        topicId: j['topicId'] as String,
        initialMessage: (j['initialMessage'] as String?) ?? '',
      );
      final f = j['facts'];
      if (f is Map) {
        f.forEach((k, v) => s.facts[k.toString()] = v.toString());
      }
      s.concluded = j['concluded'] == true;
      final ds = j['dialogueState'];
      if (ds is Map<String, dynamic>) {
        s.dialogueState = DialogueState.fromJson(ds);
      }
      return s;
    } catch (_) {
      return null;
    }
  }
}

/// حالت پویای هر نشست مشاوره که با [Expando] به خودِ شیءِ نشست متصل میشود.
///
/// `LegalCounselor` کلاسی کاملاً ایستا است (سازندهٔ خصوصی و بدون نمونه)،
/// بنابراین «نمونهٔ مشاور» در عمل همان [CounselingSession] فعالِ هر گفتگوست.
/// برتری [Expando] بر یک `Map` ایستا:
///  * کلیدها به صورت ضعیف (weak) نگه داشته میشوند؛ نشستهای بستهشده نشت
///    حافظه نمیدهند و نیازی به پاکسازی دستی کلیدها نیست؛
///  * هر نشست وضعیت مستقل خود را دارد؛ نشست تازهساخته / بازیافتشده از
///    `fromJson` شمارندههای نشست قبلی را به ارث نمیبرد؛
///  * این حالت پویا هرگز وارد `toJson` و ذخیرهسازی `SharedPreferences`
///    نمیشود، پس قرارداد ذخیرهسازی دستنخورده میماند.
class CounselorSessionState {
  CounselorSessionState._();

  static final Expando<int> _intakeAttempts = Expando<int>('intakeAttempts');
  static final Expando<int> _stallCount = Expando<int>('stallCount');
  static final Expando<bool> _conclusionShown = Expando<bool>('conclusionShown');
  static final Expando<Map<String, Object>> _properties =
      Expando<Map<String, Object>>('properties');

  static int intakeAttempts(CounselingSession s) => _intakeAttempts[s] ?? 0;

  static int bumpIntakeAttempts(CounselingSession s) {
    final next = intakeAttempts(s) + 1;
    _intakeAttempts[s] = next;
    return next;
  }

  static int stallCount(CounselingSession s) => _stallCount[s] ?? 0;

  static int bumpStallCount(CounselingSession s) {
    final next = stallCount(s) + 1;
    _stallCount[s] = next;
    return next;
  }

  static bool conclusionShown(CounselingSession s) => _conclusionShown[s] ?? false;

  static void markConclusionShown(CounselingSession s) =>
      _conclusionShown[s] = true;

  /// خواندن یک ویژگی دلخواه و typed از همان نشست.
  static T? property<T extends Object>(CounselingSession s, String key) {
    final value = _properties[s]?[key];
    return value is T ? value : null;
  }

  /// نوشتن یک ویژگی دلخواه (پویا) روی همان نشست، بدون تغییر مدل داده.
  static void setProperty<T extends Object>(
    CounselingSession s,
    String key,
    T value,
  ) {
    final props = _properties[s] ?? <String, Object>{};
    props[key] = value;
    _properties[s] = props;
  }

  static void clearProperty(CounselingSession s, String key) {
    _properties[s]?.remove(key);
  }

  /// پاک کردن همهٔ شمارندهها و ویژگیها (شروع دوبارهٔ همان نشست).
  static void reset(CounselingSession s) {
    _intakeAttempts[s] = null;
    _stallCount[s] = null;
    _conclusionShown[s] = null;
    _properties[s] = null;
  }

  /// فقط شمارندهٔ «گیر کردن planner» صفر میشود؛ شمارندهٔ پذیرش اولیه و
  /// ویژگیهای دلخواه دستنخورده میمانند.
  static void clearStalls(CounselingSession s) {
    _stallCount[s] = null;
    _conclusionShown[s] = null;
  }
}

class CounselCheckpointStore {
  CounselCheckpointStore._();

  static const String _key = 'active_counsel_v1';

  static Future<bool> save(CounselingSession session) async {
    if (session.concluded) {
      await clear();
      return false;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final sealed = await PrivacyService.seal(jsonEncode(session.toJson()));
      return await prefs.setString(_key, sealed);
    } catch (_) {
      return false;
    }
  }

  static Future<CounselingSession?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_key);
      if (stored == null || stored.isEmpty) return null;
      final raw = await PrivacyService.open(stored);
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final s = CounselingSession.fromJson(decoded);
      if (s == null || s.concluded) return null;
      if (!LegalCounselor.knownTopic(s.topicId)) return null;
      return s;
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}

class _QuestionStep {
  final String slot;
  final String prompt;
  final List<String> options;
  final String? Function(String normText) extractor;

  const _QuestionStep({
    required this.slot,
    required this.prompt,
    required this.options,
    required this.extractor,
  });
}
class LegalCounselor {
  LegalCounselor._();

  static const String startCounselCmd = 'مشاورهٔ حقوقی گام‌به‌گام';
  static const String cancelCounselCmd = 'پایان مشاوره';
  static const String draftPrefix = 'تنظیم ';

  static const Map<String, String> _topicFa = {
    'cheque': 'چک و دعاوی بانکی',
    'labor': 'روابط کار و بیمه',
    'lease': 'اجاره و تخلیهٔ ملک',
    'family': 'خانواده (مهریه، طلاق، حضانت)',
    'fraud_cyber': 'کلاهبرداری و جرایم رایانه‌ای',
    'criminal_harm': 'شکایت کیفری و آسیب',
    'litigation_defense': 'دفاع در دادرسی و اعتراض به رأی',
    'debt': 'طلب و بدهی',
    'general_intake': 'مشاورهٔ حقوقی',
  };

  static String topicTitleFa(String topicId) => _topicFa[topicId] ?? 'مشاورهٔ حقوقی';
  static bool knownTopic(String topicId) => _topicFa.containsKey(topicId);

  static const List<String> _intakeChips = [
    'چک برگشتی یا دفاع در برابر چک',
    'اخراج از کار، حقوق و بیمه',
    'اجارهٔ ملک، تخلیه و پول پیش',
    'مهریه، نفقه، طلاق و حضانت',
    'کلاهبرداری، فیشینگ و خیانت در امانت',
    'ابلاغیه، شکایت علیه من یا اعتراض به رأی',
    'مطالبهٔ طلب، سفته یا اعسار',
    cancelCounselCmd,
  ];

  static const List<String> _intakeRepromptChips = [
    'چک برگشتی یا دفاع در برابر چک',
    'اخراج از کار، حقوق و بیمه',
    'اجارهٔ ملک، تخلیه و پول پیش',
    'مهریه، نفقه، طلاق و حضانت',
    'ابلاغیه، شکایت علیه من یا اعتراض به رأی',
    cancelCounselCmd,
  ];

  static const String _intakeGreetingFallback =
      'سلام و وقت‌به‌خیر؛ با کمال میل همراه شما هستم تا موضوع را دقیق و مستند به قوانین بررسی کنیم.\n\n'
      'لطفاً بفرمایید مسئلهٔ حقوقی شما در کدام‌یک از حوزه‌های زیر است؟ (می‌توانید یکی از گزینه‌ها را بزنید یا شرح ماجرا را به زبان خودتان بنویسید.)';

  static const String _intakeRepromptFallback =
      'برای اینکه دقیق راهنمایی‌تان کنم، لطفاً موضوع اصلی را با یک جمله بفرمایید (مثلاً: «کارفرما اخراجم کرده»، «چک برگشتی دارم»، «مستأجر تخلیه نمی‌کند» یا «ابلاغیهٔ دادگاه برایم آمده»).';

  static const List<String> _resumeMarkers = [
    'ادامه مشاوره',
    'ادامهٔ مشاوره',
    'برگردیم به مشاوره',
    'مشاوره را ادامه',
    'همان موضوع قبلی',
    'همون موضوع قبلی',
  ];

  static bool wantsResume(String rawText) {
    final n = _norm(rawText);
    return n.isNotEmpty && _resumeMarkers.any(n.contains);
  }

  static final RegExp _directArtRe = RegExp(r'(?:ماده|اصل)\s*(?:واحده|\d+)');
  static final RegExp _pureDefRe = RegExp(
    r'^(?:معنی|تعریف|مفهوم)\s+|(?:چیست|چیه|کیست|یعنی چه|یعنی چی)\s*[؟?]*$',
  );

  static String _pick(Replies? r, Random? rnd, String key, String fallback, [Map<String, String> vars = const {}]) {
    if (r == null || !r.has(key)) {
      var t = fallback;
      vars.forEach((k, v) => t = t.replaceAll('{$k}', v));
      return t;
    }
    return r.pick(key, vars: vars, rnd: rnd);
  }

  static String _promptFor(String topicId, _QuestionStep s, Replies? replies, Random? rnd) {
    final key = 'cq_${topicId}_${s.slot}';
    if (replies != null && replies.has(key)) {
      return replies.pick(key, rnd: rnd);
    }
    return s.prompt;
  }

  static const List<String> _personalOrProblemCues = [
    'مشاوره', 'راهنمایی کن', 'کمکم کن', 'چه کار کنم', 'چیکار کنم', 'چکار کنم',
    'مشکل حقوقی', 'از من شکایت', 'علیه من', 'ابلاغیه', 'احضاریه', 'حکم غیابی',
    'رای غیابی', 'کارفرما', 'اخراجم', 'اخراج شدم', 'اخراج کرده', 'بیمه ام را',
    'حقوقم را', 'سنواتم', 'مستاجرم', 'صاحبخانه', 'صاحب خانه', 'تخلیه نمی',
    'پول پیشم', 'ودیعه ام', 'مهریه ام', 'مهریه را اجرا', 'نفقه نمی', 'طلاق بگیرم',
    'حضانت بچه', 'حضانت فرزند', 'ملاقات فرزند', 'از حسابم', 'فیشینگ', 'هک شده',
    'کلاهبرداری شده', 'امانت دادم', 'فروش مال غیر', 'فحاشی کرد', 'تهدیدم کرد',
    'کتکم زد', 'ضرب و جرح', 'چک دادم', 'چک ضمانت', 'چک برگشتی دارم',
  ];

  static String _norm(String s) => PersianText.collapse(PersianText.normalize(s));

  static bool shouldStartCounseling(String rawText, {IntentNet? net}) {
    final n = _norm(rawText);
    if (n.isEmpty) return false;
    if (rawText.trim() == startCounselCmd || rawText.trim() == DraftCmd.offerCounsel || n == 'مشاوره' || n == 'مشاوره حقوقی') {
      return true;
    }
    if (_directArtRe.hasMatch(n)) return false;
    if (net != null) {
      final s = net.classify(rawText);
      if (s.score >= net.topicMin) {
        if (s.label == 'general_intake') return true;
        return IntentNet.topicLabels.contains(s.label);
      }
    }
    if (_pureDefRe.hasMatch(n) && !_personalOrProblemCues.any(n.contains)) {
      return false;
    }
    return _personalOrProblemCues.any(n.contains);
  }

  static String? detectTopic(String rawText, {IntentNet? net}) {
    final n = _norm(rawText);
    if (rawText.trim() == startCounselCmd || n == 'مشاوره' || n == 'مشاوره حقوقی' || n.contains('مشکل حقوقی دارم') || n.contains('یک سوال حقوقی دارم')) {
      return 'general_intake';
    }
    if (net != null) {
      final s = net.classify(rawText);
      if (s.score >= net.topicMin) {
        if (s.label == 'general_intake') return 'general_intake';
        if (IntentNet.topicLabels.contains(s.label)) return s.label;
        return null;
      }
    }
    if (n.contains('چک') || n.contains('صیادی') || n.contains('برگشت خورد')) return 'cheque';
    if (n.contains('کارفرما') || n.contains('اخراج') || n.contains('سنوات') || n.contains('حقوق کارگر') || n.contains('بیمه بیکاری') || n.contains('رد نکردن بیمه') || (n.contains('بیمه') && n.contains('کار'))) return 'labor';
    if (n.contains('مستاجر') || n.contains('موجر') || n.contains('صاحبخانه') || n.contains('صاحب خانه') || n.contains('تخلیه') || n.contains('پول پیش') || n.contains('ودیعه اجاره') || (n.contains('اجاره') && (n.contains('خانه') || n.contains('ملک') || n.contains('مغازه')))) return 'lease';
    if (n.contains('مهریه') || n.contains('نفقه') || n.contains('تمکین') || n.contains('طلاق') || n.contains('حضانت') || n.contains('ملاقات فرزند') || n.contains('اجرت المثل')) return 'family';
    if (n.contains('فیشینگ') || n.contains('اینترنتی') || n.contains('هک') || n.contains('کلاهبرداری') || n.contains('امانت') || n.contains('مال غیر')) return 'fraud_cyber';
    if (n.contains('توهین') || n.contains('فحاشی') || n.contains('فحش') || n.contains('تهدید') || n.contains('ضرب و جرح') || n.contains('کتک') || n.contains('عکس خصوصی') || n.contains('فیلم خصوصی')) return 'criminal_harm';
    if (n.contains('حکم غیابی') || n.contains('رای غیابی') || n.contains('واخواهی') || n.contains('تجدیدنظر') || n.contains('اعتراض به رای') || n.contains('ابلاغیه') || n.contains('احضاریه') || n.contains('از من شکایت') || n.contains('علیه من')) return 'litigation_defense';
    if (n.contains('قرض') || n.contains('طلب') || n.contains('بدهی') || n.contains('بدهکار') || n.contains('سفته') || n.contains('اعسار')) return 'debt';
    if (n.contains('مشاوره') || n.contains('چه کار کنم') || n.contains('چیکار کنم') || n.contains('راهنمایی کن')) return 'general_intake';
    return null;
  }

  static String? detectTopicHint(String rawText, {IntentNet? net}) {
    final direct = detectTopic(rawText, net: net);
    if (direct != null) return direct;
    final symbolic = detectTopic(rawText);
    if (symbolic != null) return symbolic;
    if (net == null) return null;
    for (final s in net.top(rawText, k: 4)) {
      if (IntentNet.topicLabels.contains(s.label) && s.score >= 0.25) {
        return s.label;
      }
    }
    return null;
  }
static (CounselingSession, CounselorTurn)? start(
  String rawText,
  KnowledgeEngine engine,
  List<LegalTemplate> templates, {
  IntentNet? net,
  Replies? replies,
  Random? rnd,
}) {
  final topic = detectTopic(rawText, net: net);
  if (topic == null) return null;
  final session = CounselingSession(topicId: topic, initialMessage: rawText);
  DialogueIntegration.initializeState(session);
  if (topic == 'general_intake') {
    return (session, CounselorTurn(text: _pick(replies, rnd, 'counselor_intake_greeting', _intakeGreetingFallback), chips: _intakeChips));
  }
  _extractAllFacts(session, rawText);
  return (session, _advance(session, engine, templates, firstTurn: true, replies: replies, rnd: rnd));
}

static (CounselingSession, CounselorTurn)? resumeTopic(
  String topicId,
  String initialMessage,
  KnowledgeEngine engine,
  List<LegalTemplate> templates, {
  Replies? replies,
  Random? rnd,
}) {
  if (!knownTopic(topicId)) return null;
  final session = CounselingSession(topicId: topicId, initialMessage: initialMessage);
  DialogueIntegration.initializeState(session);
  if (topicId == 'general_intake') {
    return (session, CounselorTurn(text: _pick(replies, rnd, 'counsel_resumed', 'باشه، برگردیم سر موضوع «{topic}». از اول با چند سؤال کوتاه وضعیت را روشن می‌کنیم:', {'topic': topicTitleFa(topicId)}), chips: _intakeChips));
  }
  _extractAllFacts(session, initialMessage);
  final turn = _advance(session, engine, templates, firstTurn: true, replies: replies, rnd: rnd);
  final lead = _pick(replies, rnd, 'counsel_resumed', 'باشه، برگردیم سر موضوع «{topic}». از اول با چند سؤال کوتاه وضعیت را روشن می‌کنیم:', {'topic': topicTitleFa(topicId)});
  return (session, CounselorTurn(text: '$lead\n\n${turn.text}', chips: turn.chips));
}

static CounselorTurn? pendingTurn(
  CounselingSession session, {
  Replies? replies,
  Random? rnd,
}) {
  if (session.concluded) return null;
  final note = _pick(replies, rnd, 'counsel_resumed_note', 'گفتگوی مشاورهٔ ناتمام دربارهٔ «{topic}» بازیابی شد. می‌توانیم از همان‌جا ادامه دهیم:', {'topic': topicTitleFa(session.topicId)});
  if (session.topicId == 'general_intake') {
    return CounselorTurn(text: '$note\n\n$_intakeRepromptFallback', chips: _intakeRepromptChips);
  }
  final steps = _stepsFor(session.topicId);
  final pending = steps.where((s) => !session.facts.containsKey(s.slot)).firstOrNull;
  if (pending == null) return null;
  return CounselorTurn(text: '$note\n\n${_promptFor(session.topicId, pending, replies, rnd)}', chips: [...pending.options, cancelCounselCmd]);
}

static const SmallTalkLayer _smallTalk = SmallTalkLayer();
static const ResponseComposer _responseComposer = ResponseComposer();

static CounselorTurn step(
  CounselingSession session,
  String rawText,
  KnowledgeEngine engine,
  List<LegalTemplate> templates, {
  IntentNet? net,
  Replies? replies,
  Random? rnd,
  void Function(CounselorRoute route)? onRoute,
}) {
  final trimmed = rawText.trim();
  final n = _norm(trimmed);

  // Terminal commands always win, regardless of the current planner state.
  if (trimmed.isEmpty) {
    return _routed(onRoute, CounselorRoute.empty,
        const CounselorTurn(text: 'بفرمایید، در خدمتم. موضوع حقوقی‌تان را بنویسید.', chips: SmallTalkLayer.defaultIntakeChips));
  }

  if (trimmed == cancelCounselCmd || trimmed == DraftCmd.cancel || n == 'انصراف' || n == 'پایان مشاوره' || n == 'لغو') {
    return _routed(onRoute, CounselorRoute.cancel,
        const CounselorTurn(text: 'مشاورهٔ گام‌به‌گام پایان یافت. هر زمان پرسش دیگری داشتید یا خواستید متنی تنظیم کنیم، در خدمتم.', cancelled: true));
  }
  if (net != null) {
    final s = net.classify(trimmed);
    if (s.label == 'cancel' && s.score >= net.cancelMin) {
      return _routed(onRoute, CounselorRoute.cancel,
          const CounselorTurn(text: 'مشاورهٔ گام‌به‌گام پایان یافت. هر زمان پرسش دیگری داشتید یا خواستید متنی تنظیم کنیم، در خدمتم.', cancelled: true));
    }
  }

  // A conclusion can offer a draft chip. Route that chip before reopening
  // the concluded session or interpreting its title as a slot answer.
  if (trimmed.startsWith(draftPrefix)) {
    final template = _matchTemplateChip(trimmed, templates);
    if (template != null) {
      return _routed(onRoute, CounselorRoute.template, CounselorTurn(text: '', startTemplate: template));
    }
  }

  final isGoodbye = PersianText.wordRe(['خداحافظ', 'خدانگهدار', 'بدرود', 'فعلا']).hasMatch(n);
  if (isGoodbye) {
    session.concluded = true;
    return _routed(onRoute, CounselorRoute.goodbye,
        const CounselorTurn(text: 'خداحافظ. هر وقت به راهنمایی حقوقی نیاز داشتید، همین‌جا در خدمتم.', completed: true));
  }

  if (session.concluded) {
    session.concluded = false;
    CounselorSessionState.reset(session);
  }

  final bool activeContext = session.topicId != 'general_intake';
  // لایهٔ گفتگوی کوتاه کاملاً جاست: پیش از planner/RAG/مدل زبانی، پیام
  // غیرحقوقی را با پاسخی ثابت میگیرد و هیچ تحلیل حقوقی انجام نمیدهد.
  final smallTalk = _smallTalk.tryHandle(trimmed, hasActiveLegalContext: activeContext);
  if (smallTalk != null) {
    return _routed(onRoute, CounselorRoute.smallTalk, CounselorTurn(text: smallTalk.text, chips: smallTalk.chips));
  }

  // Legal questions are answered without mutating the pending slot. Simple
  // declarative answers (amounts, dates, choices, ...) never cross this gate.
  if (_ragEligible(session, trimmed, net: net)) {
    return _routed(onRoute, CounselorRoute.rag, _ragTurn(session, trimmed, engine, replies, rnd));
  }

  if (!activeContext) {
    return _routed(
      onRoute,
      CounselorRoute.intake,
      _handleGeneralIntake(
        session,
        trimmed,
        engine,
        templates,
        net: net,
        replies: replies,
        rnd: rnd,
      ),
    );
  }

  return _routed(
    onRoute,
    CounselorRoute.domain,
    _handleDomainStep(
      session,
      trimmed,
      engine,
      templates,
      net: net,
      replies: replies,
      rnd: rnd,
    ),
  );
}

/// اجرای پاسخ و سپس گزارشِ مسیر انتخاب‌شده به شنوندهٔ اختیاری.
///
/// دلیل وجود این کمک‌تابع: `step` نقطه‌های بازگشتِ متعددی دارد و همهٔ آن‌ها
/// باید مسیر خود را گزارش کنند؛ بدون آن، ابزار ارزیابی نمی‌تواند بگوید
/// «چرا» یک پیام به RAG نرفت یا رفت.
static CounselorTurn _routed(
  void Function(CounselorRoute route)? onRoute,
  CounselorRoute route,
  CounselorTurn turn,
) {
  if (onRoute != null) {
    try {
      onRoute(route);
    } catch (_) {
      // گزارش مسیر هرگز نباید پاسخ کاربر را خراب کند.
    }
  }
  return turn;
}

/// اجرای یک نوبتِ مشاوره همراه با ثبت کاملِ ردِ دیباگ.
///
/// این تابع پوستهٔ نازکی روی [step] است و **هیچ رفتاری را تغییر نمی‌دهد**:
/// همان پاسخ و همان تغییرِ نشست را برمی‌گرداند، اما در کنارش
/// [TracedCounselorTurn.trace] را پر می‌کند تا ابزار ارزیابی بتواند ببیند
/// نیت چه بود، چه اسلات‌هایی پر شد، چه ماده‌هایی بازیابی شد و چه مسیری
/// انتخاب شد. اگر لاگر خاموش باشد، هزینهٔ این wrapper عملاً صفر است.
static TracedCounselorTurn stepTraced(
  CounselingSession session,
  String rawText,
  KnowledgeEngine engine,
  List<LegalTemplate> templates, {
  IntentNet? net,
  Replies? replies,
  Random? rnd,
  DebugLogger? logger,
}) {
  final log = logger ?? DebugLogger.instance;
  final trace = log.start(rawText);

  // مسیر انتخاب‌شده مستقل از روشن‌بودن لاگر ثبت می‌شود؛ ابزار ارزیابی به آن
  // نیاز دارد، حتی وقتی هیچ ردی ذخیره نمی‌شود.
  CounselorRoute? route;

  if (!trace.enabled) {
    final plain = step(
      session,
      rawText,
      engine,
      templates,
      net: net,
      replies: replies,
      rnd: rnd,
      onRoute: (r) => route = r,
    );
    return TracedCounselorTurn(turn: plain, trace: trace, route: route);
  }

  try {
    log.record(trace, TurnStage.input, 'پیام کاربر', <String, Object?>{
      'text': rawText,
      'topic': session.topicId,
      'concluded': session.concluded,
      'facts': Map<String, String>.of(session.facts),
    });
    log.record(
      trace,
      TurnStage.input,
      'متن یکدست‌شده',
      PersianText.collapse(PersianText.normalize(rawText)),
    );

    final topScores = net == null ? const <IntentScore>[] : net.top(rawText, k: 3);
    log.record(trace, TurnStage.intent, 'طبقه‌بندی نیت', <String, Object?>{
      'model': net == null ? 'none' : 'intent_net',
      'label': topScores.isEmpty ? null : topScores.first.label,
      'score': topScores.isEmpty ? null : topScores.first.score,
      'top': topScores.map((s) => s.toString()).toList(),
      'topic': detectTopic(rawText, net: net) ?? detectTopic(rawText),
      'starts_counseling': shouldStartCounseling(rawText, net: net),
      'rag_eligible': _ragEligible(session, rawText, net: net),
    });

    final factsBefore = Map<String, String>.of(session.facts);
    final filledBefore = <String>[];
    final slotsBefore = session.dialogueState?.slots;
    if (slotsBefore != null) {
      slotsBefore.forEach((key, value) {
        final v = value.value;
        if (v != null && v.isNotEmpty) filledBefore.add(key);
      });
    }

    final turn = step(
      session,
      rawText,
      engine,
      templates,
      net: net,
      replies: replies,
      rnd: rnd,
      onRoute: (r) => route = r,
    );

    final extracted = <String, String>{};
    session.facts.forEach((key, value) {
      if (factsBefore[key] != value) extracted[key] = value;
    });
    final requiredSlots = Slots.coreFor(session.topicId);
    log.record(trace, TurnStage.slots, 'اسلات‌های استخراج‌شده', <String, Object?>{
      'topic': session.topicId,
      'extracted': extracted,
      'filled_before': filledBefore,
      'facts': Map<String, String>.of(session.facts),
      'required': requiredSlots,
      'missing': requiredSlots.where((k) => !session.facts.containsKey(k)).toList(),
    });

    final hits = turn.ragReply?.contextHits ?? const <Hit>[];
    log.record(trace, TurnStage.retrieval, 'مواد بازیابی‌شده', <String, Object?>{
      'query': turn.ragQuery,
      'count': hits.length,
      'hits': hits
          .map((h) => <String, Object?>{
                'law': h.chunk.lawId,
                'article': h.chunk.title,
                'source': h.chunk.source,
                'score': h.score,
              })
          .toList(),
    });

    log.record(trace, TurnStage.intent, 'مسیر انتخاب‌شده', <String, Object?>{
      'route': route?.name ?? 'unknown',
    });
    log.record(trace, TurnStage.response, 'پاسخ نهایی', <String, Object?>{
      'text': turn.text,
      'chips': turn.chips,
      'completed': turn.completed,
      'cancelled': turn.cancelled,
      'concluded': session.concluded,
    });

    return TracedCounselorTurn(turn: turn, trace: trace, route: route);
  } catch (e, st) {
    log.record(trace, TurnStage.error, 'خطا در پردازش نوبت', <String, Object?>{
      'error': e.toString(),
      'stack': st.toString(),
    });
    rethrow;
  } finally {
    log.finish(trace);
  }
}

/// Route an initial/uncategorized legal issue into a concrete counseling
/// domain. Unknown input stays in intake and receives a varied reprompt.
static CounselorTurn _handleGeneralIntake(
  CounselingSession session,
  String rawText,
  KnowledgeEngine engine,
  List<LegalTemplate> templates, {
  IntentNet? net,
  Replies? replies,
  Random? rnd,
}) {
  final n = _norm(rawText);
  final detected = _topicFromIntakeChoice(n) ?? detectTopic(rawText, net: net);
  if (detected != null && detected != 'general_intake') {
    session.topicId = detected;
    session.dialogueState = null;
    session.facts.clear();
    CounselorSessionState.reset(session);

    // Extract first, then initialize the planner so its SlotValues and the
    // legacy facts describe the same initial state.
    _extractAllFacts(session, rawText);
    DialogueIntegration.initializeState(session);
    return _advance(session, engine, templates, firstTurn: true, replies: replies, rnd: rnd);
  }

  final attempts = CounselorSessionState.bumpIntakeAttempts(session);
  if (attempts == 1) {
    return const CounselorTurn(text: 'متوجه شدم. برای اینکه بهتر کمک کنم، موضوع شما به کدام دسته نزدیک‌تر است؟', chips: SmallTalkLayer.defaultIntakeChips);
  }
  return const CounselorTurn(text: 'لطفاً در یک جمله ساده بنویسید چه اتفاقی افتاده است تا راهنمایی‌تان کنم.', chips: []);
}

/// Process one turn in a concrete legal domain. A planner result is not a
/// stall merely because [DialogueIntegration.tryStep] returns null: null also
/// means "all slots are ready; let the rich legacy conclusion answer".
static CounselorTurn _handleDomainStep(
  CounselingSession session,
  String rawText,
  KnowledgeEngine engine,
  List<LegalTemplate> templates, {
  IntentNet? net,
  Replies? replies,
  Random? rnd,
}) {
  // Sync restored/existing slots before taking the progress snapshot; only
  // values extracted from this user turn should count as forward progress.
  _syncPlannerFacts(session);
  final factsBefore = Map<String, String>.of(session.facts);
  final plannerTurn = DialogueIntegration.tryStep(session, rawText, engine);
  _syncPlannerFacts(session);

  if (plannerTurn != null) {
    CounselorSessionState.clearStalls(session);
    return plannerTurn;
  }

  if (_factsChanged(factsBefore, session.facts)) {
    CounselorSessionState.clearStalls(session);
    return _advanceAfterAnswer(
      session,
      rawText,
      engine,
      templates,
      replies: replies,
      rnd: rnd,
    );
  }

  final pending = _pendingStep(session);
  if (pending == null) {
    CounselorSessionState.clearStalls(session);
    return _advance(session, engine, templates, firstTurn: false, replies: replies, rnd: rnd);
  }

  final n = _norm(rawText);
  final value = pending.extractor(n);
  if (value != null) {
    session.facts[pending.slot] = value;
    _extractAllFacts(session, rawText);
    CounselorSessionState.clearStalls(session);
    return _advanceAfterAnswer(
      session,
      rawText,
      engine,
      templates,
      replies: replies,
      rnd: rnd,
    );
  }

  // Keep the legacy ability to accept an on-topic narrative as additional
  // detail. In contrast, refusals and unrelated text must never be persisted
  // as if they were valid answers to the pending slot.
  if (_isTopicalNarrative(session, rawText, pending, net: net)) {
    session.facts[pending.slot] = rawText.trim();
    _extractAllFacts(session, rawText);
    CounselorSessionState.clearStalls(session);
    return _advanceAfterAnswer(
      session,
      rawText,
      engine,
      templates,
      replies: replies,
      rnd: rnd,
    );
  }

  return _plannerStallTurn(
    session,
    engine,
    templates,
    replies: replies,
    rnd: rnd,
  );
}

static _QuestionStep? _pendingStep(CounselingSession session) {
  return _stepsFor(session.topicId)
      .where((s) => !session.facts.containsKey(s.slot))
      .firstOrNull;
}

static void _syncPlannerFacts(CounselingSession session) {
  final slots = session.dialogueState?.slots;
  if (slots == null) return;
  for (final entry in slots.entries) {
    final value = entry.value.value?.trim();
    if (value != null && value.isNotEmpty) {
      session.facts[entry.key] = value;
    }
  }
}

static bool _factsChanged(
  Map<String, String> before,
  Map<String, String> after,
) {
  if (before.length != after.length) return true;
  for (final entry in after.entries) {
    if (before[entry.key] != entry.value) return true;
  }
  return false;
}

static CounselorTurn _advanceAfterAnswer(
  CounselingSession session,
  String rawText,
  KnowledgeEngine engine,
  List<LegalTemplate> templates, {
  Replies? replies,
  Random? rnd,
}) {
  final nextStep = _pendingStep(session);
  if (nextStep == null) {
    // No acknowledgement is fabricated after the final slot; go directly to
    // the conclusion and mark the session concluded in exactly one place.
    return _advance(session, engine, templates, firstTurn: false, replies: replies, rnd: rnd);
  }

  final acknowledged = _responseComposer.composeAcknowledged(
    rawText,
    nextStep.slot,
    nextQuestion: _promptFor(session.topicId, nextStep, replies, rnd),
    options: nextStep.options,
    domain: session.topicId,
    state: session.dialogueState,
    turnIndex: session.facts.length,
  );
  return _advance(
    session,
    engine,
    templates,
    firstTurn: false,
    replies: replies,
    rnd: rnd,
    acknowledgment: acknowledged,
  );
}

static final RegExp _refusalRe = RegExp(
  r'(?:نمی\s*خواهم|نمیخواهم).*(?:جواب|پاسخ|بگویم|بگم)|(?:(?:جواب|پاسخ)\s*(?:نمی\s*دهم|ندارم))',
);

/// Whether free-form text is still about the active legal domain. This is
/// deliberately narrower than the old "store every non-empty answer" rule.
static bool _isTopicalNarrative(
  CounselingSession session,
  String rawText,
  _QuestionStep pending, {
  IntentNet? net,
}) {
  final n = _norm(rawText);
  if (n.isEmpty || _refusalRe.hasMatch(n)) return false;

  final detected = detectTopic(rawText) ?? detectTopic(rawText, net: net);
  if (detected != null) return detected == session.topicId;

  const slotCues = <String, Map<String, List<String>>>{
    'cheque': <String, List<String>>{
      Slots.nature: ['بدهی', 'تضمین', 'ضمانت', 'امانت', 'سفید', 'وعده'],
      Slots.certTime: ['گواهی', 'بانک', 'برگشت', 'ماه'],
    },
    'labor': <String, List<String>>{
      Slots.proof: ['مدرک', 'قرارداد', 'حقوق', 'بیمه', 'واریز', 'پیامک'],
      Slots.time: ['اخراج', 'روز', 'ماه', 'کارگاه'],
    },
    'lease': <String, List<String>>{
      Slots.witnesses: ['قرارداد', 'شاهد', 'سند', 'رهگیری'],
    },
    'family': <String, List<String>>{
      Slots.side: ['زوج', 'شوهر', 'خانم', 'آقا'],
      Slots.detail: ['توافق', 'اجرا', 'اعسار', 'توان مالی'],
    },
    'fraud_cyber': <String, List<String>>{
      Slots.evidence: ['رسید', 'بانک', 'اسکرین', 'شاهد', 'سند'],
    },
    'criminal_harm': <String, List<String>>{
      Slots.proof: ['مدرک', 'پزشکی', 'پلیس', 'شاهد', 'پیامک'],
    },
    'litigation_defense': <String, List<String>>{
      Slots.deadline: ['روز', 'ابلاغ', 'ثنا', 'عذر', 'اجرا'],
    },
    'debt': <String, List<String>>{
      Slots.doc: ['رسید', 'سفته', 'قرارداد', 'فیش', 'واریز', 'شهادت'],
    },
  };
  final cues = slotCues[session.topicId]?[pending.slot];
  return cues != null && cues.any(n.contains);
}

static const Map<String, Map<String, List<String>>> _stallPrompts =
    <String, Map<String, List<String>>>{
  'cheque': <String, List<String>>{
    Slots.role: [
      'شما دارندهٔ چک هستید یا صادرکننده/ضامن؟',
      'نقش شما دربارهٔ این چک کدام است: دارنده یا صادرکننده/ضامن؟',
    ],
    Slots.nature: [
      'این چک برای بدهی قطعی بوده یا تضمین/امانت/شرط؟',
      'ماهیت چک کدام است: بدهی قطعی یا تضمینی و مشروط؟',
    ],
    Slots.certTime: [
      'گواهی عدم پرداخت دارید و هنوز در مهلت شش‌ماهه هستید؟',
      'وضعیت گواهی عدم پرداخت و مهلت شش‌ماههٔ شما کدام گزینه است؟',
    ],
  },
  'labor': <String, List<String>>{
    Slots.issue: [
      'مشکل اصلی با کارفرما اخراج است، مطالبات مزدی یا بیمه؟',
      'کدام موضوع کاری برایتان پیش آمده: اخراج، حقوق و سنوات یا بیمه؟',
    ],
    Slots.proof: [
      'برای اثبات رابطهٔ کاری چه مدرکی دارید؟',
      'قرارداد، واریز بانکی، پیامک یا مدرک دیگری از کار دارید؟',
    ],
    Slots.time: [
      'چند روز از اخراج یا قطع همکاری گذشته است؟',
      'هنوز مشغول کارید یا کمتر/بیشتر از سی روز از اخراج گذشته است؟',
    ],
  },
  'lease': <String, List<String>>{
    Slots.role: [
      'در این قرارداد موجر هستید یا مستأجر؟',
      'نقش شما در اجاره کدام است: مالک/موجر یا مستأجر؟',
    ],
    Slots.expired: [
      'مدت قرارداد اجاره تمام شده یا هنوز ادامه دارد؟',
      'قرارداد از نظر زمانی منقضی شده است یا در میانهٔ مدت هستید؟',
    ],
    Slots.witnesses: [
      'قرارداد رسمی است، دو شاهد دارد یا بدون دو شاهد/شفاهی است؟',
      'نوع قرارداد و وضعیت امضای دو شاهد کدام گزینه است؟',
    ],
  },
  'family': <String, List<String>>{
    Slots.subtopic: [
      'موضوع شما مهریه است، نفقه، طلاق یا حضانت؟',
      'کدام مسئلهٔ خانوادگی را پیگیری می‌کنید: مهریه، نفقه، طلاق یا حضانت؟',
    ],
    Slots.side: [
      'از سمت زوجه پیگیر موضوع هستید یا زوج؟',
      'نقش شما در این موضوع خانوادگی زوجه است یا زوج؟',
    ],
    Slots.detail: [
      'بین شما توافق هست، اختلاف، یا حکم و اجرائیه در میان است؟',
      'وضعیت فعلی کدام است: توافق، اختلاف یا مرحلهٔ اجرا و توان مالی؟',
    ],
  },
  'fraud_cyber': <String, List<String>>{
    Slots.kind: [
      'مال با فیشینگ/هک، فریب کلاهبردارانه یا از مسیر امانت از دست رفته است؟',
      'شکل وقوع جرم کدام بوده: اینترنتی، کلاهبرداری، امانت یا فروش مال غیر؟',
    ],
    Slots.evidence: [
      'رسید بانکی، اسکرین‌شات، سند یا شاهد دارید؟',
      'کدام مستندات بانکی، کتبی یا شفاهی در دست دارید؟',
    ],
  },
  'criminal_harm': <String, List<String>>{
    Slots.harmType: [
      'رفتار طرف مقابل ضرب، تهدید، توهین یا انتشار تصویر خصوصی بوده است؟',
      'کدام آسیب رخ داده: ضرب و جرح، تهدید، توهین یا انتشار عکس/فیلم؟',
    ],
    Slots.proof: [
      'گواهی پزشکی، گزارش پلیس، پیامک یا شاهد دارید؟',
      'برای اثبات موضوع چه مدرک یا شاهدی در دست دارید؟',
    ],
  },
  'litigation_defense': <String, List<String>>{
    Slots.stage: [
      'ابلاغیه برای احضار است، حکم غیابی یا رأی حضوری بدوی؟',
      'پرونده در کدام مرحله است: احضاریه، حکم غیابی یا اعتراض به رأی بدوی؟',
    ],
    Slots.deadline: [
      'از ابلاغ کمتر از بیست روز گذشته یا بیشتر؟',
      'وضعیت مهلت بیست‌روزه و عذر موجه شما کدام گزینه است؟',
    ],
  },
  'debt': <String, List<String>>{
    Slots.role: [
      'طلبکار هستید یا بدهکار/خوانده؟',
      'نقش شما در این بدهی کدام است: طلبکار یا بدهکار؟',
    ],
    Slots.doc: [
      'سند کتبی، فیش بانکی یا شاهد برای این طلب/بدهی دارید؟',
      'مدرک این بدهی کدام است: رسید و سفته، واریز بانکی یا شهادت؟',
    ],
  },
};

/// Handle an irrelevant answer, an unclear answer, or a refusal without
/// repeating the exact same prompt. Two varied re-asks are attempted; the
/// existing best-effort conclusion remains the final escape hatch.
static CounselorTurn _plannerStallTurn(
  CounselingSession session,
  KnowledgeEngine engine,
  List<LegalTemplate> templates, {
  Replies? replies,
  Random? rnd,
}) {
  final pending = _pendingStep(session);
  if (pending == null) {
    return _advance(session, engine, templates, firstTurn: false, replies: replies, rnd: rnd);
  }

  final stalls = CounselorSessionState.bumpStallCount(session);
  if (stalls <= 2) {
    final opening = stalls == 1
        ? 'متوجه شدم. برای اینکه دقیق‌تر راهنمایی کنم، هنوز باید به سؤال قبلی پاسخ روشنی برسد؛ بگذارید آن را ساده‌تر بپرسم:'
        : 'باشه، اشکالی ندارد اگر پاسخ کامل را نمی‌دانید. فقط نزدیک‌ترین گزینه را انتخاب کنید یا چند کلمه بگویید:';
    final prompts = _stallPrompts[session.topicId]?[pending.slot];
    final prompt = prompts == null
        ? _promptFor(session.topicId, pending, replies, rnd)
        : prompts[stalls - 1];
    return CounselorTurn(
      text: '$opening\n\n$prompt',
      chips: [...pending.options, cancelCounselCmd],
    );
  }

  if (!CounselorSessionState.conclusionShown(session)) {
    CounselorSessionState.markConclusionShown(session);
    final c = _buildConclusion(session, engine, templates, replies: replies, rnd: rnd);
    return CounselorTurn(
      text: 'خب، بر اساس همین اطلاعات جمع‌بندی می‌کنم: ${c.text}',
      chips: c.chips,
      completed: c.completed,
      cancelled: c.cancelled,
      startTemplate: c.startTemplate,
      ragQuery: c.ragQuery,
      ragReply: c.ragReply,
    );
  }
  return const CounselorTurn(text: 'جمع‌بندی را خدمتتان ارائه کردم. اگر مدرک جدیدی دارید بفرمایید.');
}

/// A semantic gate between slot filling and legal-article retrieval. Direct
/// article references and explicit legal-consequence questions are eligible;
/// declarative slot values, including amounts, are not.
static bool _ragEligible(
  CounselingSession session,
  String rawText, {
  IntentNet? net,
}) {
  final n = _norm(rawText);
  if (n.isEmpty) return false;
  if (_directArtRe.hasMatch(n)) return true;
  if (!_questionGlowRe.hasMatch(n)) return false;

  final hasLegalCue = _lawishCue(n);
  final tokenCount = n.split(' ').where((token) => token.isNotEmpty).length;
  if (tokenCount <= 4 && !hasLegalCue) return false;

  // A short answer phrased with «آیا» can still be a slot value. Strong legal
  // cues override this guard when the user is genuinely asking for the law.
  final pending = _pendingStep(session);
  if (!hasLegalCue && pending != null && pending.extractor(n) != null) {
    return false;
  }

  return _isLegalQuestion(rawText, net);
}

static final RegExp _questionGlowRe = RegExp(r'[؟?]|چیست|چیه|چقدر|چطور|چگونه|کجا|آیا|یعنی|چرا|کدام|کیست|چه می‌گوید|میگه|میگوید|می گوید');

static bool _lawishCue(String n) =>
    n.contains('قانون') ||
    n.contains('ماده') ||
    n.contains('اصل') ||
    n.contains('مجازات') ||
    n.contains('مهلت') ||
    n.contains('شرایط') ||
    n.contains('تعریف') ||
    n.contains('ضمانت اجرا') ||
    n.contains('عواقب') ||
    n.contains('پیامد') ||
    n.contains('مسئولیت') ||
    n.contains('حکم');

static bool _isLegalQuestion(String rawText, IntentNet? net) {
  final n = _norm(rawText);
  if (_directArtRe.hasMatch(n)) return true;
  if (net != null) {
    final s = net.classify(rawText);
    if (s.score >= net.ragMin) {
      return IntentNet.ragLabels.contains(s.label) && _questionGlowRe.hasMatch(n);
    }
  }
  return _questionGlowRe.hasMatch(n) && (_pureDefRe.hasMatch(n) || _lawishCue(n));
}

static CounselorTurn _ragTurn(
  CounselingSession session,
  String rawText,
  KnowledgeEngine engine,
  Replies? replies,
  Random? rnd,
) {
  final reply = engine.query(rawText, maxAlternatives: 0);
  final notFound = reply.text.contains('پیدا نکردم') || reply.text.contains('پیدا نشد') || reply.text.contains('هنوز در برنامه نیست');
  final sb = StringBuffer();
  if (!notFound) {
    sb.writeln(_pick(replies, rnd, 'counselor_rag_intro', 'سؤال خوبی است؛ اجازه بدهید همین را مستقیم از متن رسمی قانون بیاورم:'));
    sb.writeln();
    sb.write(reply.text);
  } else {
    sb.write(_pick(replies, rnd, 'counselor_rag_miss', 'پاسخ دقیقی برای این پرسش در بانک قوانین برنامه پیدا نکردم و بهتر است حدس نزنم. برویم سراغ ادامهٔ بررسی وضعیت خودت:'));
  }

  if (session.topicId == 'general_intake') {
    sb.writeln();
    sb.writeln();
    sb.write(_pick(replies, rnd, 'counselor_intake_reprompt', _intakeRepromptFallback));
    return CounselorTurn(text: sb.toString(), chips: _intakeRepromptChips, ragQuery: notFound ? null : rawText, ragReply: notFound ? null : reply);
  }

  final steps = _stepsFor(session.topicId);
  final pending = steps.where((s) => !session.facts.containsKey(s.slot)).firstOrNull;
  if (pending != null) {
    if (!notFound) {
      sb.writeln();
      sb.writeln();
      sb.writeln(_pick(replies, rnd, 'counselor_resume', 'حالا برگردیم به وضعیت خودت؛ این پرسش هنوز باز است:'));
    }
    sb.writeln();
    sb.write(_promptFor(session.topicId, pending, replies, rnd));
    return CounselorTurn(text: sb.toString(), chips: [...pending.options, cancelCounselCmd], ragQuery: notFound ? null : rawText, ragReply: notFound ? null : reply);
  }
  return CounselorTurn(text: sb.toString(), chips: const [cancelCounselCmd], ragQuery: notFound ? null : rawText, ragReply: notFound ? null : reply);
}

static LegalTemplate? _matchTemplateChip(String text, List<LegalTemplate> templates) {
  final cleaned = text.startsWith(draftPrefix) ? text.substring(draftPrefix.length).trim() : text.trim();
  final cn = _norm(cleaned);
  for (final t in templates) {
    final tn = _norm(t.title);
    if (cn == tn || cn.contains(tn) || tn.contains(cn)) return t;
  }
  return null;
}

static String? _topicFromIntakeChoice(String n) {
  if (n.contains('چک')) return 'cheque';
  if (n.contains('کار') || n.contains('بیمه')) return 'labor';
  if (n.contains('اجاره') || n.contains('تخلیه') || n.contains('پول پیش')) return 'lease';
  if (n.contains('مهریه') || n.contains('نفقه') || n.contains('طلاق') || n.contains('حضانت')) return 'family';
  if (n.contains('کلاهبرداری') || n.contains('فیشینگ') || n.contains('امانت')) return 'fraud_cyber';
  if (n.contains('ابلاغیه') || n.contains('اعتراض به رای') || n.contains('شکایت علیه من')) return 'litigation_defense';
  if (n.contains('طلب') || n.contains('سفته') || n.contains('اعسار')) return 'debt';
  return null;
}

static void _extractAllFacts(CounselingSession s, String rawText) {
  final n = _norm(rawText);
  for (final step in _stepsFor(s.topicId)) {
    if (s.facts.containsKey(step.slot)) continue;
    final v = step.extractor(n);
    if (v != null) s.facts[step.slot] = v;
  }
}

static CounselorTurn _advance(
  CounselingSession session,
  KnowledgeEngine engine,
  List<LegalTemplate> templates, {
  required bool firstTurn,
  Replies? replies,
  Random? rnd,
  ComposedReply? acknowledgment,
}) {
  final steps = _stepsFor(session.topicId);
  final nextStep = steps.where((s) => !session.facts.containsKey(s.slot)).firstOrNull;

  if (nextStep != null) {
    // پاسخ تأییدشدهٔ Phase 3 خودش پرسش بعدی را دارد؛ نباید بالای آن
    // نه lead تازهای بگذاریم و نه همان پرسش را دوباره تکرار کنیم.
    if (acknowledgment != null) {
      return CounselorTurn(
        text: acknowledgment.text,
        chips: [...acknowledgment.chips, cancelCounselCmd],
      );
    }
    final lead = firstTurn ? '${_pick(replies, rnd, 'ci_${session.topicId}', _empathyIntro(session.topicId))}\n\n' : '';
    final prompt = _promptFor(session.topicId, nextStep, replies, rnd);
    return CounselorTurn(text: '$lead$prompt', chips: [...nextStep.options, cancelCounselCmd]);
  }

  session.concluded = true;
  return _buildConclusion(session, engine, templates, replies: replies, rnd: rnd);
}

static String _empathyIntro(String topicId) {
  switch (topicId) {
    case 'cheque': return 'متوجه موضوع چک شما شدم. در دعاوی چک، تفاوت ظریفی بین مسیر «کیفری»، «اجرائیهٔ مستقیم ثبت/دادگاه» و «دعوای حقوقی» وجود دارد؛ اجازه بدهید با دو سؤال کوتاه وضعیت دقیق شما را مشخص کنم.';
    case 'labor': return 'پیگیری حقوق کارگری و بیمه کاملاً حق قانونی شماست و مهلت‌های مهمی دارد. برای اینکه دقیق‌ترین مسیر را پیشنهاد دهم، لطفاً این مورد را مشخص کنید:';
    case 'lease': return 'اختلافات موجر و مستأجر بسته به نوع قرارداد و امضای شهود، مسیر قضایی کاملاً متفاوتی (فوری یا عادی) دارند. بیایید گام‌به‌گام بررسی کنیم:';
    case 'family': return 'مسائل خانواده نیازمند دقت و آرامش است تا حقوق قانونی شما به بهترین شکل حفظ شود. برای ارائهٔ تحلیل دقیق، لطفاً بفرمایید:';
    case 'fraud_cyber': return 'متأسفم که چنین اتفاقی افتاده است. در جرایم مالی و اینترنتی، تشخیص درست عنوان اتهامی (کلاهبرداری، جرم رایانه‌ای یا خیانت در امانت) از رد شدن شکایت در دادسرا جلوگیری می‌کند.';
    case 'criminal_harm': return 'حفظ امنیت و حیثیت شما مورد حمایت کامل قانون است. برای اینکه ببینیم بهترین ادله و عنوان شکایت چیست، لطفاً بفرمایید:';
    case 'litigation_defense': return 'نگران نباشید؛ دریافت ابلاغیه یا صدور رأی به معنای پایان کار نیست و قانون به شما فرصت دفاع و اعتراض داده است. زمان در اینجا بسیار مهم است:';
    case 'debt':
    default: return 'بسیار خوب؛ بیایید وضعیت طلب یا بدهی و مدارک شما را دقیق بررسی کنیم تا بهترین اقدام قانونی مشخص شود:';
  }
}
/// Adapt the legacy question definitions to the same canonical core contract
/// used by [DomainSchema] and [DialoguePlanner]. Fail fast on a missing,
/// duplicated, or unexpected definition instead of deadlocking the dialogue.
static List<_QuestionStep> _stepsFor(String topicId) {
  final coreKeys = Slots.coreFor(topicId);
  if (coreKeys.isEmpty) return const <_QuestionStep>[];

  final defined = _definedStepsFor(topicId);
  final bySlot = <String, _QuestionStep>{
    for (final step in defined) step.slot: step,
  };
  if (defined.length != coreKeys.length || bySlot.length != coreKeys.length) {
    throw StateError('Core slot definitions do not match domain "$topicId"');
  }

  return List<_QuestionStep>.unmodifiable(
    coreKeys.map(
      (key) => bySlot[key] ??
          (throw StateError('Missing legacy slot "$key" in "$topicId"')),
    ),
  );
}

static List<_QuestionStep> _definedStepsFor(String topicId) {
  switch (topicId) {
    case 'cheque':
      return [
        _QuestionStep(
          slot: Slots.role,
          prompt: '۱. نقش شما در مورد این چک چیست؟ (دارندهٔ چک هستید و می‌خواهید وجهش را بگیرید، یا صادرکننده/ضامن هستید که علیه‌تان اقدام شده است؟)',
          options: const ['دارندهٔ چک هستم (طلبکار)', 'صادرکننده یا ضامن چک هستم'],
          extractor: (n) {
            if (n.contains('دارنده') || n.contains('طلبکار') || n.contains('چکم برگشت') || n.contains('چک برگشتی دارم') || n.contains('پولم را بگیرم')) return 'holder';
            if (n.contains('صادرکننده') || n.contains('ضامن') || n.contains('چک دادم') || n.contains('چک کشیدم') || n.contains('بابت ضمانت داده بودم')) return 'issuer';
            return null;
          },
        ),
        _QuestionStep(
          slot: Slots.nature,
          prompt: '۲. آیا چک بابت بدهی قطعی و به تاریخ روز صادر شده، یا بابت تضمین، امانت، معاملهٔ مشروط و سفیدامضا بوده است؟\n(این نکته طبق مادهٔ ۱۳ قانون صدور چک تعیین‌کنندهٔ امکان شکایت کیفری است.)',
          options: const ['بابت بدهی قطعی و تاریخ روز', 'بابت تضمین، امانت، مشروط یا وعده‌دار'],
          extractor: (n) {
            if (n.contains('تضمین') || n.contains('ضمانت') || n.contains('امانت') || n.contains('مشروط') || n.contains('سفید') || n.contains('وعده')) return 'conditional';
            if (n.contains('بدهی قطعی') || n.contains('تاریخ روز')) return 'unconditional';
            return null;
          },
        ),
        _QuestionStep(
          slot: Slots.certTime,
          prompt: '۳. آیا گواهی عدم پرداخت از بانک دریافت شده و کمتر از ۶ ماه از تاریخ چک و گواهی گذشته است؟',
          options: const ['بله، گواهی دارم و زیر ۶ ماه است', 'بیش از ۶ ماه گذشته است', 'هنوز برگشت نزده‌ام / گواهی ندارم'],
          extractor: (n) {
            if (n.contains('هنوز برگشت نزده') || n.contains('گواهی ندارم')) return 'no_cert';
            if (n.contains('بیش از 6 ماه') || n.contains('بیشتر از 6 ماه') || n.contains('یک سال گذشته')) return 'over_6m';
            if (n.contains('زیر 6 ماه') || n.contains('گواهی دارم')) return 'under_6m';
            return null;
          },
        ),
      ];

    case 'labor':
      return [
        _QuestionStep(
          slot: Slots.issue,
          prompt: '۱. مشکل اصلی شما با کارفرما کدام مورد است؟',
          options: const ['اخراج یا عدم تمدید و بازگشت به کار', 'عدم پرداخت حقوق، عیدی یا سنوات', 'رد نکردن حق بیمهٔ تأمین اجتماعی'],
          extractor: (n) {
            if (n.contains('اخراج') || n.contains('بازگشت به کار')) return 'dismissal';
            if (n.contains('بیمه') && !n.contains('حقوق')) return 'insurance';
            if (n.contains('حقوق') || n.contains('سنوات') || n.contains('عیدی')) return 'wages';
            return null;
          },
        ),
        _QuestionStep(
          slot: Slots.proof,
          prompt: '۲. چه مدرکی برای اثبات رابطهٔ کاری دارید؟ (قرارداد کتبی، فیش واریز حقوق، لیست بیمه یا پیامک و شهادت همکاران؟)',
          options: const ['قرارداد کتبی یا سابقهٔ بیمه دارم', 'قرارداد شفاهی ولی واریزی بانکی/پیامک دارم', 'هیچ مدرک کتبی یا بانکی ندارم'],
          extractor: (n) {
            if (n.contains('کتبی') || n.contains('سابقه بیمه')) return 'written';
            if (n.contains('شفاهی') || n.contains('واریزی')) return 'bank_sms';
            if (n.contains('هیچ مدرک')) return 'none';
            return null;
          },
        ),
        _QuestionStep(
          slot: Slots.time,
          prompt: '۳. در حال حاضر مشغول به کار هستید یا قطع همکاری شده؟ اگر اخراج شده‌اید، آیا کمتر از ۳۰ روز از تاریخ اخراج گذشته است؟',
          options: const ['کمتر از ۳۰ روز از اخراج گذشته است', 'بیش از ۳۰ روز از قطع همکاری گذشته', 'هنوز در کارگاه مشغول به کارم'],
          extractor: (n) {
            if (n.contains('کمتر از 30') || n.contains('هفته پیش اخراج')) return 'under_30d';
            if (n.contains('بیش از 30') || n.contains('چند ماه پیش')) return 'over_30d';
            if (n.contains('مشغول به کار')) return 'active';
            return null;
          },
        ),
      ];

    case 'lease':
      return [
        _QuestionStep(
          slot: Slots.role,
          prompt: '۱. در این رابطهٔ اجاره، شما موجر (مالک) هستید یا مستأجر؟',
          options: const ['موجر (مالک) هستم', 'مستأجر هستم'],
          extractor: (n) {
            if (n.contains('مستاجرم') || n.contains('مستاجر من') || n.contains('مالک هستم') || n.contains('موجر هستم')) return 'landlord';
            if (n.contains('صاحبخانه') || n.contains('صاحب خانه') || n.contains('مستاجر هستم') || n.contains('پول پیشم')) return 'tenant';
            return null;
          },
        ),
        _QuestionStep(
          slot: Slots.expired,
          prompt: '۲. آیا مدت قرارداد اجاره به پایان رسیده است؟',
          options: const ['بله، مدت قرارداد تمام شده است', 'خیر، هنوز در میانهٔ مدت قرارداد هستیم'],
          extractor: (n) {
            if (n.contains('تمام شده') || n.contains('منقضی شده') || n.contains('پایان رسیده')) return 'yes';
            if (n.contains('میانه مدت') || n.contains('تمام نشده')) return 'no';
            return null;
          },
        ),
        _QuestionStep(
          slot: Slots.witnesses,
          prompt: '۳. نوع قرارداد اجارهٔ شما چگونه است؟ (سند رسمی، قرارداد عادی با امضای دو شاهد/کد رهگیری، یا دست‌نویس بدون دو شاهد؟)',
          options: const ['قرارداد کتبی با امضای دو شاهد یا سند رسمی', 'قرارداد عادی بدون امضای دو شاهد یا شفاهی'],
          extractor: (n) {
            if (n.contains('دو شاهد') || n.contains('رسمی') || n.contains('کد رهگیری')) return 'two_witnesses';
            if (n.contains('بدون امضای دو شاهد') || n.contains('بدون شاهد') || n.contains('شفاهی')) return 'no_witnesses';
            return null;
          },
        ),
      ];

    case 'family':
      return [
        _QuestionStep(
          slot: Slots.subtopic,
          prompt: '۱. موضوع اصلی پرونده یا پرسش خانوادگی شما کدام است؟',
          options: const ['مطالبه یا تقسیط مهریه', 'نفقه و تمکین', 'درخواست طلاق', 'حضانت و ملاقات فرزند'],
          extractor: (n) {
            if (n.contains('مهریه')) return 'mehrieh';
            if (n.contains('نفقه') || n.contains('تمکین')) return 'nafaqeh';
            if (n.contains('حضانت') || n.contains('ملاقات')) return 'custody';
            if (n.contains('طلاق')) return 'divorce';
            return null;
          },
        ),
        _QuestionStep(
          slot: Slots.side,
          prompt: '۲. شما از طرف زوجه (خانم) پیگیر موضوع هستید یا زوج (آقا)؟',
          options: const ['زوجه (خانم) هستم', 'زوج (آقا) هستم'],
          extractor: (n) {
            if (n.contains('زوجه') || n.contains('شوهرم') || n.contains('خانم هستم')) return 'wife';
            if (n.contains('زوج هستم') || n.contains('آقا هستم') || n.contains('خانمم') || n.contains('مهریه را اجرا گذاشته')) return 'husband';
            return null;
          },
        ),
        _QuestionStep(
          slot: Slots.detail,
          prompt: '۳. کدام وضعیت به شرایط فعلی شما نزدیک‌تر است؟',
          options: const ['توافق نداریم و طرف مقابل همکاری نمی‌کند', 'حکم یا اجرائیه صادر شده و بحث توان مالی/اعسار مطرح است', 'زمینهٔ توافق بین زوجین وجود دارد'],
          extractor: (n) {
            if (n.contains('توان مالی') || n.contains('اعسار') || n.contains('اجرا گذاشته')) return 'enforcement_insolvency';
            if (n.contains('توافق داریم') || n.contains('توافقی')) return 'mutual';
            if (n.contains('توافق نداریم') || n.contains('همکاری نمی')) return 'contested';
            return null;
          },
        ),
      ];

    case 'fraud_cyber':
      return [
        _QuestionStep(
          slot: Slots.kind,
          prompt: '۱. نحوهٔ از دست رفتن مال یا وقوع جرم دقیقاً به چه شکلی بوده است؟',
          options: const ['برداشت اینترنتی، لینک جعلی (فیشینگ) یا هک', 'فریب با مانور متقلبانه و صحنه‌سازی (کلاهبرداری)', 'مالی را به امانت دادم و پس نمی‌دهد', 'ملک یا مال مرا بدون اجازه به دیگری فروخته است'],
          extractor: (n) {
            if (n.contains('فیشینگ') || n.contains('اینترنتی') || n.contains('هک') || n.contains('لینک')) return 'cyber';
            if (n.contains('امانت')) return 'trust_breach';
            if (n.contains('مال غیر') || n.contains('بدون اجازه فروخته')) return 'unauthorized_sale';
            if (n.contains('مانور') || n.contains('صحنه سازی')) return 'classic_fraud';
            return null;
          },
        ),
        _QuestionStep(
          slot: Slots.evidence,
          prompt: '۲. چه مستنداتی در دست دارید؟ (رسید بانکی و شماره حساب مقصد، قرارداد/رسید امانت، پیامک‌ها یا شاهد؟)',
          options: const ['گردش حساب بانکی، اسکرین‌شات یا رسید کتبی دارم', 'فقط شاهد یا مکالمهٔ شفاهی دارم'],
          extractor: (n) {
            if (n.contains('گردش حساب') || n.contains('رسید') || n.contains('اسکرین')) return 'strong';
            if (n.contains('فقط شاهد') || n.contains('شفاهی')) return 'weak';
            return null;
          },
        ),
      ];

    case 'criminal_harm':
      return [
        _QuestionStep(
          slot: Slots.harmType,
          prompt: '۱. چه رفتاری علیه شما رخ داده است؟',
          options: const ['ضرب و جرح و آسیب بدنی', 'تهدید یا اخاذی', 'توهین، فحاشی یا افترا', 'انتشار عکس/فیلم خصوصی در فضای مجازی'],
          extractor: (n) {
            if (n.contains('ضرب') || n.contains('کتک')) return 'assault';
            if (n.contains('عکس خصوصی') || n.contains('فیلم خصوصی')) return 'private_media';
            if (n.contains('تهدید') || n.contains('اخاذی')) return 'threat';
            if (n.contains('توهین') || n.contains('فحاشی') || n.contains('افترا')) return 'insult';
            return null;
          },
        ),
        _QuestionStep(
          slot: Slots.proof,
          prompt: '۲. آیا مدرکی مانند گواهی پزشکی قانونی، گزارش پلیس ۱۱۰، شهادت شهود یا پیامک و صدای ضبط‌شده دارید؟',
          options: const ['گواهی پزشکی قانونی / گزارش پلیس / پیامک دارم', 'فقط شاهد دارم', 'فعلاً مدرکی جمع‌آوری نکرده‌ام'],
          extractor: (n) {
            if (n.contains('پزشکی قانونی') || n.contains('پلیس') || n.contains('پیامک')) return 'documented';
            if (n.contains('شاهد')) return 'witness';
            if (n.contains('فعلا مدرکی')) return 'none';
            return null;
          },
        ),
      ];

    case 'litigation_defense':
      return [
        _QuestionStep(
          slot: Slots.stage,
          prompt: '۱. ابلاغیه‌ای که در سامانهٔ ثنا دریافت کرده‌اید مربوط به کدام مرحله است؟',
          options: const ['ابلاغ وقت رسیدگی یا احضاریه (پرونده در جریان است)', 'حکم غیابی صادر شده است (در جلسات شرکت نکرده‌ام)', 'رأی حضوری بدوی صادر شده و می‌خواهم اعتراض کنم'],
          extractor: (n) {
            if (n.contains('غیابی')) return 'default_judgment';
            if (n.contains('حضوری بدوی') || n.contains('تجدیدنظر')) return 'appeal';
            if (n.contains('وقت رسیدگی') || n.contains('احضاریه')) return 'first_hearing';
            return null;
          },
        ),
        _QuestionStep(
          slot: Slots.deadline,
          prompt: '۲. چند روز از تاریخ درج ابلاغیه در سامانهٔ ثنا گذشته است؟ (برای مقیمان ایران مهلت واخواهی و تجدیدنظر ۲۰ روز است.)',
          options: const ['کمتر از ۲۰ روز گذشته است (مهلت دارم)', 'بیش از ۲۰ روز گذشته ولی عذر موجه (بیماری/عدم اطلاع واقعی) دارم', 'بیش از ۲۰ روز گذشته و رأی به اجرا رفته است'],
          extractor: (n) {
            if (n.contains('کمتر از 20') || n.contains('مهلت دارم')) return 'within_20d';
            if (n.contains('عذر موجه')) return 'excused_late';
            if (n.contains('به اجرا رفته') || n.contains('بیش از 20')) return 'late';
            return null;
          },
        ),
      ];

    case 'debt':
    default:
      return [
        _QuestionStep(
          slot: Slots.role,
          prompt: '۱. شما طلبکار هستید که می‌خواهید پولتان را مطالبه کنید، یا بدهکار/خوانده هستید که علیه‌تان مطالبه شده است؟',
          options: const ['طلبکار هستم و می‌خواهم پولم را بگیرم', 'بدهکار هستم و توان پرداخت یکجای بدهی را ندارم'],
          extractor: (n) {
            if (n.contains('بدهکار هستم') || n.contains('توان پرداخت') || n.contains('اعسار')) return 'debtor';
            if (n.contains('طلبکار') || n.contains('قرض دادم') || n.contains('پولم را بگیرم')) return 'creditor';
            return null;
          },
        ),
        _QuestionStep(
          slot: Slots.doc,
          prompt: '۲. چه مدرکی بابت این بدهی/طلب وجود دارد؟',
          options: const ['رسید کتبی، قرارداد یا سفته', 'فیش واریز بانکی و پیامک‌های اقرار به بدهی', 'فقط شهادت شهود (شفاهی)'],
          extractor: (n) {
            if (n.contains('رسید کتبی') || n.contains('سفته') || n.contains('قرارداد')) return 'written';
            if (n.contains('فیش') || n.contains('واریز')) return 'bank';
            if (n.contains('شفاهی') || n.contains('شهادت')) return 'oral';
            return null;
          },
        ),
      ];
  }
}
  static String _citeSnippet(KnowledgeEngine engine, String lawId, String article) {
    final c = engine.findArticle(lawId, article);
    if (c == null) return '';
    final clean = c.body.trim();
    final excerpt = clean.length > 260 ? '${clean.substring(0, 257)}...' : clean;
    return PersianText.toFaDigits('• ${c.title} ${c.source}: «$excerpt»');
  }

  static List<String> _templateChipsForIds(List<String> ids, List<LegalTemplate> templates) {
    final out = <String>[];
    for (final id in ids) {
      for (final t in templates) {
        if (t.id == id) {
          out.add('$draftPrefix${t.title}');
          break;
        }
      }
    }
    return out;
  }

  static CounselorTurn _buildConclusion(
    CounselingSession s,
    KnowledgeEngine engine,
    List<LegalTemplate> templates, {
    Replies? replies,
    Random? rnd,
  }) {
    final sb = StringBuffer();
    final tplIds = <String>[];
    final refs = <String>[];

    void addRef(String lawId, String art) {
      final sn = _citeSnippet(engine, lawId, art);
      if (sn.isNotEmpty) refs.add(sn);
    }

    switch (s.topicId) {
      case 'cheque':
        final isIssuer = s.facts[Slots.role] == 'issuer';
        final isCond = s.facts[Slots.nature] == 'conditional';
        final time = s.facts[Slots.certTime] ?? 'under_6m';
        sb.writeln('📋 تحلیل و استدلال حقوقی وضعیت چک شما:');
        sb.writeln();
        if (!isIssuer) {
          if (!isCond && time == 'under_6m') {
            sb.writeln(
              '۱. به دلیل اینکه چک بابت بدهی قطعی و به تاریخ روز صادر شده و زیر ۶ ماه از تاریخ صدور و گواهی عدم پرداخت گذشته است، هر سه مسیر قانونی پیش روی شما باز است:\n'
              '• سریع‌ترین مسیر: درخواست «صدور اجرائیهٔ مستقیم چک» از دادگاه حقوقی (طبق مادهٔ ۲۳ اصلاحی قانون صدور چک) بدون نیاز به نوبت دادرسی طولانی، به شرطی که در متن چک شرطی ذکر نشده باشد.\n'
              '• مسیر کیفری: ثبت «شکوائیهٔ صدور چک بلامحل» (طبق مواد ۷ و ۱۱ قانون صدور چک).\n'
              '• مسیر حقوقی: ثبت «دادخواست مطالبهٔ وجه چک» همراه با درخواست قرار تأمین خواسته (توقیف فوری اموال بدون تودیع خسارت احتمالی) و خسارت تأخیر تأدیه از تاریخ چک.',
            );
            addRef('cheque', '23');
            addRef('cheque', '11');
            tplIds.addAll(['cheque_execution', 'cheque_complaint', 'demand_money']);
          } else {
            sb.writeln(
              '۱. با توجه به اینکه چک جنبهٔ تضمینی/مشروط/وعده‌دار داشته یا مهلت ۶ ماههٔ شکایت کیفری منقضی شده است، طبق مواد ۱۱ و ۱۳ قانون صدور چک **تعقیب کیفری مسموع نیست** (در صورت طرح شکایت کیفری، قرار منع تعقیب صادر می‌شود).\n'
              '۲. اما اصل طلب شما کاملاً پابرجاست! بهترین اقدام، طرح «دادخواست حقوقی مطالبهٔ وجه» (و در صورت بدون شرط بودن ظاهر چک، درخواست اجرائیهٔ مادهٔ ۲۳) به همراه تقاضای تأمین خواسته برای توقیف حساب‌های صادرکننده است.',
            );
            addRef('cheque', '13');
            addRef('cheque', '23');
            tplIds.addAll(['demand_money', 'cheque_execution', 'formal_notice']);
          }
        } else {
          sb.writeln(
            '۱. از آنجا که شما صادرکننده یا ضامن چک هستید:\n'
            '• اگر چک بابت تضمین انجام تعهد، امانت، سفیدامضا یا وعده‌دار بوده است، به استناد **مادهٔ ۱۳ قانون صدور چک** جرم کیفری صدور چک بلامحل محقق نمی‌شود و در دادسرا می‌توانید با استشهادیه، قرارداد پایه یا رسید، «لایحهٔ دفاعیه» بدهید و قرار منع تعقیب بگیرید.\n'
            '• اگر دعوای حقوقی یا اجرائیه علیه شما ثبت شده و توان پرداخت یکجای مبلغ را ندارید، ظرف ۳۰ روز از ابلاغ اجرائیه دادخواست «اعسار و تقسیط محکوم‌به» ثبت کنید تا از جلب و مسدودی بیشتر جلوگیری شود.',
          );
          addRef('cheque', '13');
          addRef('financial_sentences', '3');
          tplIds.addAll(['defense_brief', 'insolvency']);
        }
        break;

      case 'labor':
        final issue = s.facts[Slots.issue] ?? 'wages';
        final time = s.facts[Slots.time] ?? 'under_30d';
        sb.writeln('📋 تحلیل و استدلال حقوقی روابط کار و بیمه:');
        sb.writeln();
        if (issue == 'dismissal') {
          sb.writeln(
            time == 'under_30d'
                ? '۱. نکتهٔ حیاتی: طبق مادهٔ ۱۵۷ قانون کار و آیین‌نامهٔ دادرسی کار، برای شکایت از اخراج غیرموجه و درخواست «بازگشت به کار + دریافت حقوق ایام بلاتکلیفی» مهلت بسیار مهمی دارید؛ همین هفته در سامانهٔ جامع روابط کار ثبت‌نام و دادخواست بدوی به «هیأت تشخیص ادارهٔ کار» ثبت کنید.'
                : '۱. اگر بیش از مهلت قانونی از اخراج گذشته و عذر موجهی نباشد، ممکن است خواستهٔ بازگشت به کار با ایراد مواجه شود، اما **اصل مطالبات مزدی، سنوات پایان کار، عیدی و مرخصی ذخیره‌شده مشمول مرور زمان نمی‌شود** و همیشه قابل مطالبه است.',
          );
          addRef('labor', '27');
          addRef('labor', '157');
        } else if (issue == 'insurance') {
          sb.writeln(
            '۱. به موجب **مادهٔ ۱۴۸ قانون کار** و **مادهٔ ۲۸ قانون تأمین اجتماعی**، بیمه کردن کارگر از روز اول کار یک تکلیف آمره است و حتی توافق کتبی کارگر مبنی بر نداشتن بیمه **باطل و بی‌اثر** است.\n'
            '۲. ابتدا در ادارهٔ کار دادخواست الزام کارفرما به واریز حق بیمهٔ ایام کارکرد بدهید؛ با رأی قطعی هیأت تشخیص، شعبهٔ تأمین اجتماعی کارفرما را ملزم به پرداخت اصل حق بیمه و جرایم و ثبت سابقهٔ شما می‌کند.',
          );
          addRef('labor', '148');
          addRef('social_security', '28');
        } else {
          sb.writeln(
            '۱. کارفرما مکلف است مزد، فوق‌العادهٔ اضافه‌کاری، عیدی و سنوات پایان خدمت (معادل یک ماه آخرین حقوق به ازای هر سال سابقه طبق مادهٔ ۲۴ قانون کار) را به‌طور کامل بپردازد.\n'
            '۲. حتی بدون قرارداد کتبی، طبق مادهٔ ۷ قانون کار قرارداد شفاهی نیز معتبر است و با پرینت واریزی‌های بانکی، پیامک‌ها و شهادت همکاران در هیأت تشخیص ادارهٔ کار اثبات می‌شود.',
          );
          addRef('labor', '7');
          addRef('labor', '24');
        }
        tplIds.addAll(['formal_notice', 'defense_brief']);
        break;

      case 'lease':
        final isLandlord = s.facts[Slots.role] == 'landlord';
        final expired = s.facts[Slots.expired] != 'no';
        final twoWit = s.facts[Slots.witnesses] == 'two_witnesses';
        sb.writeln('📋 تحلیل و استدلال حقوقی رابطهٔ استیجاری:');
        sb.writeln();
        if (isLandlord) {
          if (expired && twoWit) {
            sb.writeln(
              '۱. خبر خوب حقوقی: چون مدت اجاره منقضی شده و قرارداد کتبی با امضای دو شاهد (یا سند رسمی) دارید، مشمول **مادهٔ ۳ قانون روابط موجر و مستأجر مصوب ۱۳۷۶** هستید و نیازی به دادرسی طولانی ندارید!\n'
              '۲. می‌توانید از طریق دفتر خدمات قضایی درخواست «دستور تخلیهٔ فوری» از دادگاه صلح / شورای حل اختلاف بخواهید؛ مرجع قضایی با تودیع مبلغ ودیعه (پول پیش) از سوی شما به حساب سپردهٔ دادگستری، ظرف یک هفته دستور تخلیه صادر می‌کند.',
            );
            addRef('landlord_tenant', '3');
          } else {
            sb.writeln(
              '۱. از آنجا که یا مدت قرارداد هنوز منقضی نشده یا قرارداد فاقد امضای دو شاهد است، شرایط صدور «دستور تخلیهٔ فوری» مادهٔ ۳ فراهم نیست.\n'
              '۲. مسیر درست قانونی، ارسال یک «اظهارنامهٔ رسمی» و سپس ثبت «دادخواست صدور حکم تخلیه» در دادگاه صلح به استناد انقضای مدت (مادهٔ ۴۹۴ قانون مدنی) یا تخلف از شروط قرارداد است.',
            );
            addRef('landlord_tenant', '2');
            addRef('civil', '494');
          }
          tplIds.addAll(['formal_notice', 'demand_money']);
        } else {
          sb.writeln(
            '۱. به عنوان مستأجر، طبق مادهٔ ۴ قانون روابط موجر و مستأجر ۱۳۷۶، تخلیهٔ ملک منوط به استرداد هم‌زمان مبلغ قرض‌الحسنه (ودیعه / پول پیش) به شماست.\n'
            '۲. اگر مدت قرارداد تمام شده و مالک پول پیش را پس نمی‌دهد: اولاً بلافاصله یک «اظهارنامهٔ رسمی» مبنی بر آمادگی تحویل کلید در قبال دریافت ودیعه بفرستید (تا به شما اجرت‌المثل ایام تصرف تعلق نگیرد) و ثانیاً «دادخواست مطالبهٔ وجه ودیعه» همراه با تأمین خواسته ثبت کنید.',
          );
          addRef('landlord_tenant', '4');
          addRef('civil_procedure', '156');
          tplIds.addAll(['formal_notice', 'demand_money']);
        }
        break;

      case 'family':
        final sub = s.facts[Slots.subtopic] ?? 'mehrieh';
        final isWife = s.facts[Slots.side] != 'husband';
        sb.writeln('📋 تحلیل و استدلال حقوقی خانواده:');
        sb.writeln();
        if (sub == 'mehrieh') {
          sb.writeln(
            isWife
                ? '۱. به موجب مادهٔ ۱۰۸۲ قانون مدنی، به مجرد عقد، زوجه مالک مهر می‌شود. برای مطالبهٔ مهریه با سند رسمی ازدواج، بهتراست ابتدا از طریق **اجرای ثبت** (دفتر ازدواج و ادارهٔ ثبت) اقدام به توقیف اموال و حساب‌های زوج و ممنوع‌الخروجی نمایید و در صورت عدم شناسایی مال، به دادگاه خانواده دادخواست بدهید.\n'
                      '۲. توجه داشته باشید که طبق **مادهٔ ۲۲ قانون حمایت خانواده**، ضمانت اجرای جلب و حبس تا سقف ۱۱۰ سکهٔ بهار آزادی بدون نیاز به اثبات ملائت زوج اعمال می‌شود و مازاد بر ۱۱۰ سکه منوط به اثبات توانایی مالی زوج است.'
                : '۱. اگر مهریه علیه شما به اجرا گذاشته شده و توان پرداخت یکجا ندارید، بلافاصله دادخواست «اعسار و تقسیط مهریه» به دادگاه خانواده تقدیم کنید و فهرست دقیق درآمد، هزینه‌های زندگی و لیست اموال خود را ضمیمه نمایید.\n'
                      '۲. طبق مادهٔ ۲۲ قانون حمایت خانواده، نسبت به مازاد ۱۱۰ سکه، بار اثبات توانایی مالی شما بر عهدهٔ زوجه است و جلب بابت مازاد ۱۱۰ سکه بدون اثبات ملائت قانونی نیست.',
          );
          addRef('family_protection', '22');
          addRef('civil', '1082');
          tplIds.addAll(isWife ? ['demand_money', 'formal_notice'] : ['insolvency', 'defense_brief']);
        } else if (sub == 'nafaqeh') {
          sb.writeln(
            '۱. طبق مواد ۱۱۰۶ و ۱۱۰۸ قانون مدنی، در عقد دائم نفقهٔ زوجه بر عهدهٔ زوج است، مشروط بر تمکین زوجه (مگر آنکه زوجه عذر موجه قانونی یا حق حبس موضوع مادهٔ ۱۰۸۵ داشته باشد).\n'
            '۲. ترک انفاق با داشتن استطاعت مالی، علاوه بر امکان مطالبهٔ حقوقی، جرم قابل گذشت محسوب می‌شود و عدم پرداخت نفقه به مدت ۶ ماه می‌تواند از موجبات طلاق به درخواست زوجه (مادهٔ ۱۱۲۹ قانون مدنی) گردد.',
          );
          addRef('civil', '1106');
          addRef('civil', '1129');
          tplIds.addAll(isWife ? ['formal_notice', 'complaint'] : ['formal_notice', 'defense_brief']);
        } else if (sub == 'custody') {
          sb.writeln(
            '۱. به استناد **مادهٔ ۱۱۶۹ اصلاحی قانون مدنی**، برای حضانت و نگهداری طفلی که ابوین او جدا از یکدیگر زندگی می‌کنند، مادر تا سن ۷ سالگی (چه دختر چه پسر) اولویت دارد و پس از آن با پدر است؛ مگر آنکه مصلحت طفل خلاف آن را اقتضا کند.\n'
            '۲. هیچ‌یک از والدین حق ندارند طرف دیگر را از ملاقات فرزند محروم کنند (مادهٔ ۱۱۷۴ قانون مدنی و مادهٔ ۲۹ قانون حمایت خانواده).',
          );
          addRef('civil', '1169');
          addRef('family_protection', '29');
          tplIds.addAll(['formal_notice', 'defense_brief']);
        } else {
          sb.writeln(
            '۱. در قوانین ایران، طلاق یا به صورت **توافقی** (با صدور گواهی عدم امکان سازش)، یا به درخواست زوج با پرداخت کلیهٔ حقوق مالی زوجه (مادهٔ ۲۹ قانون حمایت خانواده)، و یا به درخواست زوجه در صورت اثبات **عسر و حرج** (مادهٔ ۱۱۳۰ قانون مدنی) یا تحقق شروط دوازده‌گانهٔ ضمن عقد نکاح انجام می‌شود.\n'
            '۲. طبق مادهٔ ۱۲ قانون حمایت خانواده، زوجه می‌تواند در دادگاه محل اقامت خودش نیز طرح دعوای خانوادگی نماید.',
          );
          addRef('civil', '1130');
          addRef('family_protection', '12');
          tplIds.addAll(['defense_brief', 'legal_aid']);
        }
        break;

      case 'fraud_cyber':
        final kind = s.facts[Slots.kind] ?? 'classic_fraud';
        sb.writeln('📋 تحلیل و استدلال کیفری جرم مالی / اینترنتی:');
        sb.writeln();
        if (kind == 'cyber') {
          sb.writeln(
            '۱. برداشت غیرمجاز اینترنتی، فیشینگ یا فریب رایانه‌ای مشمول **مادهٔ ۱۳ قانون جرایم رایانه‌ای** (کلاهبرداری رایانه‌ای) است که مجازات آن علاوه بر **رد کامل مال به صاحبش**، حبس از یک تا پنج سال یا جزای نقدی است.\n'
            '۲. اقدام فوری: پرینت گردش حساب مبدأ همراه با شناسهٔ شبا/کارت مقصد را از بانک بگیرید و از طریق دفتر خدمات قضایی شکوائیه به «دادسرای ویژهٔ جرایم رایانه‌ای» ثبت کنید تا دستور مسدودی حساب مقصد به پلیس فتا صادر شود.',
          );
          addRef('cybercrime', '13');
          addRef('cybercrime', '1');
        } else if (kind == 'trust_breach') {
          sb.writeln(
            '۱. اگر مال به شرط بازگرداندن یا مصرف معین به طرف مقابل سپرده شده و او عمداً از استرداد خودداری یا آن را تصاحب کرده است، مشمول جرم **خیانت در امانت (مادهٔ ۶۷۴ کتاب پنجم قانون مجازات اسلامی - تعزیرات)** است.\n'
            '۲. نکتهٔ کلیدی وکیل: پیش از ثبت شکایت کیفری خیانت در امانت، حتماً یک **«اظهارنامهٔ رسمی استرداد مال امانی»** بفرستید؛ عدم استرداد پس از ابلاغ اظهارنامه، سوءنیت متهم را در دادسرا به شکل قاطع اثبات می‌کند!',
          );
          addRef('penal_taazirat', '674');
          tplIds.add('formal_notice');
        } else {
          sb.writeln(
            '۱. تحقق جرم **کلاهبرداری (مادهٔ ۱ قانون تشدید مجازات مرتکبین ارتشاء، اختلاس و کلاهبرداری)** مستلزم اثبات «توسل به وسایل متقلبانه» (صحنه‌سازی، سندسازی یا معرفی خلاف واقع) پیش از تسلیم مال است؛ صرفِ خلف وعده یا نپرداختن بدهی، جرم کیفری نیست و جنبهٔ حقوقی دارد.\n'
            '۲. اگر شخص مال شما را بدون مجوز قانونی به دیگری فروخته باشد، عمل او در حکم کلاهبرداری (انتقال مال غیر) است و علاوه بر حبس و جزای نقدی، حکم به رد اصل مال صادر می‌شود.',
          );
          addRef('fraud_intensify', '1');
        }
        tplIds.addAll(['complaint', 'demand_money']);
        break;

      case 'criminal_harm':
        final harm = s.facts[Slots.harmType] ?? 'insult';
        sb.writeln('📋 تحلیل و استدلال کیفری:');
        sb.writeln();
        if (harm == 'assault') {
          sb.writeln(
            '۱. در صدمات بدنی عمدی، بلافاصله با مراجعه به کلانتری یا دفتر خدمات قضایی نامهٔ معرفی به **پزشکی قانونی** دریافت کنید تا نوع و میزان صدمات (کبودی، جراحت یا شکستگی) برای تعیین **دیه و مجازات تعزیری** مستندسازی شود.',
          );
          addRef('penal_taazirat', '614');
        } else if (harm == 'private_media') {
          sb.writeln(
            '۱. انتشار یا تهدید به انتشار صوت، تصویر یا اسرار خصوصی دیگران در فضای مجازی، مشمول **مادهٔ ۱۷ قانون جرایم رایانه‌ای** است و مجازات حبس و جزای نقدی دارد. اسکرین‌شات‌ها و نشانی صفحهٔ منتشرکننده را پیش از پاک شدن مستندسازی کنید.',
          );
          addRef('cybercrime', '17');
        } else if (harm == 'threat') {
          sb.writeln(
            '۱. تهدید به قتل یا ضررهای نفسی، شرفی یا مالی و یا افشای سر، به موجب **مادهٔ ۶۶۹ کتاب پنجم قانون مجازات اسلامی (تعزیرات)** جرم مستقل است؛ حتی اگر تهدیدکننده آن تهدید را عملی نکرده باشد.',
          );
          addRef('penal_taazirat', '669');
        } else {
          sb.writeln(
            '۱. توهین و فحاشی به افراد به موجب **مادهٔ ۶۰۸ تعزیرات** و نسبت دادن صریح جرم اثبات‌نشده به دیگری (افترا) به موجب **مادهٔ ۶۹۷ تعزیرات** قابل تعقیب کیفری در دادسرای محل وقوع جرم است.',
          );
          addRef('penal_taazirat', '608');
          addRef('penal_taazirat', '697');
        }
        tplIds.add('complaint');
        break;

      case 'litigation_defense':
        final stage = s.facts[Slots.stage] ?? 'first_hearing';
        final dl = s.facts[Slots.deadline] ?? 'within_20d';
        sb.writeln('📋 تحلیل آیین دادرسی و راهبرد دفاعی شما:');
        sb.writeln();
        if (stage == 'default_judgment') {
          sb.writeln(
            dl == 'within_20d'
                ? '۱. از آنجا که رأی **غیابی** صادر شده و هنوز در مهلت ۲۰ روزه هستید، طبق **مواد ۳۰۵ و ۳۰۶ قانون آیین دادرسی مدنی** (و مادهٔ ۴۰۶ قانون آیین دادرسی کیفری) حق «واخواهی» در همان شعبهٔ صادرکنندهٔ رأی را دارید و با ثبت واخواهی، اجرای حکم متوقف می‌شود.'
                : '۱. حتی اگر بیش از ۲۰ روز از ابلاغ قانونی رأی غیابی گذشته باشد، طبق **تبصرهٔ ۱ مادهٔ ۳۰۶ قانون آیین دادرسی مدنی** در صورتی که ابلاغ واقعی نبوده و از مفاد رأی مطلع نبوده‌اید یا عذر موجهی (مانند بیماری مانع حرکت) داشته‌اید، همچنان می‌توانید دادخواست واخواهی خارج از مهلت با ذکر دلیل عدم اطلاع بدهید!',
          );
          addRef('civil_procedure', '305');
          addRef('civil_procedure', '306');
        } else if (stage == 'appeal') {
          sb.writeln(
            '۱. طبق **مادهٔ ۳۳۶ قانون آیین دادرسی مدنی** مهلت تجدیدنظرخواهی برای اشخاص مقیم ایران **۲۰ روز** از تاریخ ابلاغ رأی است. در لایحهٔ تجدیدنظرخواهی باید جهات نقض رأی (مخالفت رأی با قانون یا عدم توجه قاضی به دلایل ابرازی) را مستند و دقیق بنویسید.',
          );
          addRef('civil_procedure', '336');
        } else {
          sb.writeln(
            '۱. چون پرونده در جریان رسیدگی است، مهم‌ترین قاعدهٔ دفاعی این است که هرگونه ایراد شکلی (مثل عدم صلاحیت دادگاه) را تا **پایان اولین جلسهٔ دادرسی** مطرح کنید (مادهٔ ۸۷ آیین دادرسی مدنی) و در دادسرا نیز طبق **مادهٔ ۱۹۰ قانون آیین دادرسی کیفری** حق همراه داشتن وکیل و ارائهٔ لایحهٔ دفاعیه و مستندات را دارید.',
          );
          addRef('civil_procedure', '96');
          addRef('criminal_procedure', '190');
        }
        tplIds.addAll(['defense_brief', 'insolvency', 'legal_aid']);
        break;

      case 'debt':
      default:
        final isDebtor = s.facts[Slots.role] == 'debtor';
        sb.writeln('📋 تحلیل و استدلال حقوقی مطالبات و دیون:');
        sb.writeln();
        if (!isDebtor) {
          sb.writeln(
            '۱. به عنوان طلبکار، اگر هنوز اخطار رسمی نفرستاده‌اید، ابتدا یک **«اظهارنامهٔ رسمی» (مادهٔ ۱۵۶ قانون آیین دادرسی مدنی)** ارسال کنید تا مبدأ مطالبه و خسارت تأخیر تأدیه (مادهٔ ۵۲۲ آیین دادرسی مدنی) رسماً ثبت شود.\n'
            '۲. سپس دادخواست «مطالبهٔ وجه» (در دعاوی تا نصاب قانونی در دادگاه صلح و بالاتر از آن در دادگاه عمومی حقوقی محل اقامت خوانده) ثبت کنید و اگر بیم تضییع اموال بدهکار وجود دارد، هم‌زمان تقاضای **قرار تأمین خواسته** (مادهٔ ۱۰۸ آیین دادرسی مدنی) بنمایید.',
          );
          addRef('civil_procedure', '156');
          addRef('civil_procedure', '108');
          tplIds.addAll(['formal_notice', 'demand_money']);
        } else {
          sb.writeln(
            '۱. طبق **مواد ۳، ۸ و ۱۱ قانون نحوهٔ اجرای محکومیت‌های مالی**، حبس بدهکارِ فاقد توان مالی (معسر) ممنوع است؛ فقط کسی که مال دارد و از معرفی یا پرداخت خودداری می‌کند بازداشت می‌شود و مسکن و وسایل ضروری زندگی نیز جزء **مستثنیات دین** و غیرقابل توقیف است.\n'
            '۲. در برابر دادخواست یا اجرائیه، یا با «لایحهٔ دفاعیه» مستندات پرداخت/برائت ذمهٔ خود را ارائه دهید و یا دادخواست «اعسار و تقسیط محکوم‌به» با شهادت شهود مطلع از وضعیت معیشتی خود ثبت نمایید.',
          );
          addRef('financial_sentences', '3');
          addRef('financial_sentences', '24');
          tplIds.addAll(['insolvency', 'defense_brief', 'legal_aid']);
        }
        break;
    }

    if (refs.isNotEmpty) {
      sb.writeln();
      sb.writeln('📚 مستندات قانونی مرتبط در بانک قوانین برنامه:');
      for (final r in refs) {
        sb.writeln(r);
      }
    }

    final chips = _templateChipsForIds(tplIds, templates);
    if (chips.isNotEmpty) {
      sb.writeln();
      sb.write('✍️ اگر مایل باشید، می‌توانم همین حالا پیش‌نویس استاندارد هر یک از متون زیر را گام‌به‌گام برایتان تنظیم کنم (کافی است روی دکمهٔ آن بزنید):');
    }

    final open = replies == null ? '' : '${_pick(replies, rnd, 'counselor_conclusion_open', 'خب، تحلیل نهایی‌ام از وضعیت شما با تکیه بر متن قوانین:')}\n\n';
    return CounselorTurn(text: '$open${sb.toString().trim()}', chips: chips, completed: true);
  }
}
