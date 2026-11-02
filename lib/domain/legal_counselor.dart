import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/core/replies.dart';
import 'package:dastyar/domain/templates.dart';

/// پاسخ یک گام از مشاورهٔ دوطرفهٔ حقوقی (بدون هیچ مدل زبانی).
class CounselorTurn {
  final String text;
  final List<String> chips;
  final bool completed;
  final bool cancelled;
  final LegalTemplate? startTemplate;

  /// اگر این گام پرسش حقوقیِ میانهٔ مشاوره را با RAG پاسخ داده باشد،
  /// پرسش و پاسخ موتور دانش اینجا نگه داشته می‌شود تا حافظهٔ گفتگو
  /// ثبتشان کند و «بعدی‌اش چی؟» بداند آخرین بار دربارهٔ چه حرف زدیم.
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

/// وضعیت فعال یک گفتگوی تشخیصی چندمرحله‌ای با کاربر.
class CounselingSession {
  String topicId;
  final String initialMessage;
  final Map<String, String> facts = {};
  bool concluded = false;

  CounselingSession({
    required this.topicId,
    required this.initialMessage,
  });

  Map<String, dynamic> toJson() => {
        'topicId': topicId,
        'initialMessage': initialMessage,
        'facts': Map<String, String>.of(facts),
        'concluded': concluded,
      };

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
      return s;
    } catch (_) {
      return null;
    }
  }
}

/// ذخیره/بازیابی گفتگوی مشاورهٔ ناتمام بین اجراهای برنامه — هم‌راستا با
/// DraftCheckpointStore (رمزنگاری با PrivacyService تا دادهٔ حساس خام نماند).
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

/// حافظهٔ کوتاه‌مدت گفتگو برای درک پرسش‌های پیگیری («ماده بعدی‌اش؟»، «مهلتش چقدره؟»).
class ConversationMemory {
  String lastTopicQuery = '';
  String lastLawId = '';
  String lastLawTitle = '';
  int? lastArticleNum;
  String lastArticleKind = 'ماده';

  void clear() {
    lastTopicQuery = '';
    lastLawId = '';
    lastLawTitle = '';
    lastArticleNum = null;
    lastArticleKind = 'ماده';
  }

  static final RegExp _artNumRe = RegExp(r'^(ماده|اصل)\s+(\d+)$');

  void recordTurn(String userQuery, EngineReply reply) {
    final cleanQ = PersianText.collapse(PersianText.normalize(userQuery));
    if (cleanQ.length >= 4) {
      lastTopicQuery = userQuery.trim();
    }
    if (reply.contextHits.isNotEmpty) {
      final top = reply.contextHits.first.chunk;
      if (top.lawId.isNotEmpty && top.lawId != 'knowledge') {
        lastLawId = top.lawId;
        lastLawTitle = top.source;
        final m = _artNumRe.firstMatch(top.normTitle);
        if (m != null) {
          lastArticleKind = m.group(1)!;
          lastArticleNum = int.tryParse(m.group(2)!);
        }
      }
    }
  }

  static final List<String> _nextMarkers = [
    'ماده بعدی', 'ماده بعد', 'اصل بعدی', 'اصل بعد', 'بعدی اش', 'بعدیش',
  ];
  static final List<String> _prevMarkers = [
    'ماده قبلی', 'ماده قبل', 'اصل قبلی', 'اصل قبل', 'قبلی اش', 'قبلیش',
  ];
  static final List<String> _ellipticalMarkers = [
    'مهلتش', 'مجازاتش', 'شرایطش', 'مدارکش', 'حکمش', 'کجا باید برم',
    'کجا شکایت کنم', 'کجا مراجعه کنم', 'چطور اقدام کنم', 'چگونه اقدام کنم',
    'قابل گذشت است', 'قابل گذشت هست', 'اگر ندهد', 'اگر نپردازد', 'اگر قبول نکرد',
  ];

  /// بازنویسی هوشمند پرسش‌های کوتاهِ وابسته به پیام قبلی (بدون تغییر پرسش‌های مستقل).
  String resolveFollowUp(String rawQuestion) {
    final n = PersianText.collapse(PersianText.normalize(rawQuestion));
    if (lastArticleNum != null && lastLawTitle.isNotEmpty) {
      if (_nextMarkers.any(n.contains)) {
        final nextN = lastArticleNum! + 1;
        return '$lastArticleKind $nextN $lastLawTitle';
      }
      if (_prevMarkers.any(n.contains) && lastArticleNum! > 1) {
        final prevN = lastArticleNum! - 1;
        return '$lastArticleKind $prevN $lastLawTitle';
      }
    }

    if (lastTopicQuery.isEmpty) return rawQuestion;
    final words = PersianText.tokenizeIndex(rawQuestion);
    if (words.length <= 5 && _ellipticalMarkers.any(n.contains)) {
      return '$rawQuestion درباره $lastTopicQuery';
    }
    return rawQuestion;
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

/// موتور مشاورهٔ دوطرفهٔ حقوقی (۱۰۰٪ بدون مدل زبانی آنلاین یا آفلاین).
///
/// دو لایهٔ تصمیم‌گیری دارد:
///   ۱) شبکهٔ عصبی کوچک [IntentNet] (خروجی brain/train_intent.py، کاملاً
///      آفلاین) که نیت کاربر را از متن پیام تشخیص می‌دهد؛
///   ۲) مسیر نمادین کلیدواژه‌ای به‌عنوان تور ایمنی — وقتی شبکه بارگذاری
///      نشده یا امتیازش پایین است — تا رفتار برنامه هرگز بی‌پایه نشود.
class LegalCounselor {
  LegalCounselor._();

  static const String startCounselCmd = 'مشاورهٔ حقوقی گام‌به‌گام';
  static const String cancelCounselCmd = 'پایان مشاوره';
  static const String draftPrefix = 'تنظیم ';

  /// نام فارسی حوزه‌های مشاوره (برای پیام‌های {topic} و بازیابی جلسه).
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

  static String topicTitleFa(String topicId) =>
      _topicFa[topicId] ?? 'مشاورهٔ حقوقی';

  static bool knownTopic(String topicId) => _topicFa.containsKey(topicId);

  /// دکمه‌های پذیرش عمومی (general_intake).
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

  /// عبارت‌های «ادامهٔ مشاورهٔ قبلی» پس از جمع‌بندی یک جلسه.
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

  // ── ابزارهای پاسخ طبیعی: قالب‌های متنوع assets/replies.json بدون LLM ──
  static String _pick(Replies? r, Random? rnd, String key, String fallback,
      [Map<String, String> vars = const {}]) {
    if (r == null || !r.has(key)) {
      var t = fallback;
      vars.forEach((k, v) => t = t.replaceAll('{$k}', v));
      return t;
    }
    return r.pick(key, vars: vars, rnd: rnd);
  }

  /// پرسش یک گام با کلید 'cq_<topic>_<slot>' از replies.json (در صورت وجود).
  static String _promptFor(
      String topicId, _QuestionStep s, Replies? replies, Random? rnd) {
    final key = 'cq_${topicId}_${s.slot}';
    if (replies != null && replies.has(key)) {
      return replies.pick(key, rnd: rnd);
    }
    return s.prompt;
  }

  /// بازتاب کوتاه پاسخ کاربر در تصدیق طبیعی (بدون تکرار طوطی‌وار).
  static String _reflect(String text) {
    var t = text.trim();
    if (t.endsWith('؟') || t.endsWith('?')) t = t.substring(0, t.length - 1);
    if (t.length > 70) t = '${t.substring(0, 70)}…';
    return t;
  }

  static const List<String> _personalOrProblemCues = [
    'مشاوره', 'راهنمایی کن', 'کمکم کن', 'چه کار کنم', 'چیکار کنم', 'چکار کنم',
    'مشکل حقوقی', 'از من شکایت', 'علیه من', 'ابلاغیه', 'احضاریه',
    'حکم غیابی', 'رای غیابی', 'کارفرما', 'اخراجم', 'اخراج شدم', 'اخراج کرده',
    'بیمه ام را', 'حقوقم را', 'سنواتم', 'مستاجرم', 'صاحبخانه', 'صاحب خانه',
    'تخلیه نمی', 'پول پیشم', 'ودیعه ام', 'مهریه ام', 'مهریه را اجرا',
    'نفقه نمی', 'طلاق بگیرم', 'حضانت بچه', 'حضانت فرزند', 'ملاقات فرزند',
    'از حسابم', 'فیشینگ', 'هک شده', 'کلاهبرداری شده', 'امانت دادم',
    'فروش مال غیر', 'فحاشی کرد', 'تهدیدم کرد', 'کتکم زد', 'ضرب و جرح',
    'چک دادم', 'چک ضمانت', 'چک برگشتی دارم',
  ];

  static String _norm(String s) =>
      PersianText.collapse(PersianText.normalize(s));

  /// آیا پیام کاربر شروع صریح یا ضمنی یک گفتگوی مشاوره‌ای دوطرفه است؟
  /// تصمیم اصلی با شبکهٔ عصبی [net] است؛ در نبودِ شبکه یا امتیاز پایین،
  /// قاعدهٔ نمادین کلیدواژه‌ها به‌عنوان تور ایمنی اعمال می‌شود.
  static bool shouldStartCounseling(String rawText, {IntentNet? net}) {
    final n = _norm(rawText);
    if (n.isEmpty) return false;
    if (rawText.trim() == startCounselCmd ||
        rawText.trim() == DraftCmd.offerCounsel ||
        n == 'مشاوره' ||
        n == 'مشاوره حقوقی') {
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

  /// تشخیص حوزهٔ حقوقی از متن کاربر.
  /// اولویت: دستور صریح → شبکهٔ عصبی → آبشار نمادین کلیدواژه‌ها.
  static String? detectTopic(String rawText, {IntentNet? net}) {
    final n = _norm(rawText);
    if (rawText.trim() == startCounselCmd ||
        n == 'مشاوره' ||
        n == 'مشاوره حقوقی' ||
        n.contains('مشکل حقوقی دارم') ||
        n.contains('یک سوال حقوقی دارم')) {
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
    if (n.contains('چک') || n.contains('صیادی') || n.contains('برگشت خورد')) {
      return 'cheque';
    }
    if (n.contains('کارفرما') ||
        n.contains('اخراج') ||
        n.contains('سنوات') ||
        n.contains('حقوق کارگر') ||
        n.contains('بیمه بیکاری') ||
        n.contains('رد نکردن بیمه') ||
        (n.contains('بیمه') && n.contains('کار'))) {
      return 'labor';
    }
    if (n.contains('مستاجر') ||
        n.contains('موجر') ||
        n.contains('صاحبخانه') ||
        n.contains('صاحب خانه') ||
        n.contains('تخلیه') ||
        n.contains('پول پیش') ||
        n.contains('ودیعه اجاره') ||
        (n.contains('اجاره') &&
            (n.contains('خانه') || n.contains('ملک') || n.contains('مغازه')))) {
      return 'lease';
    }
    if (n.contains('مهریه') ||
        n.contains('نفقه') ||
        n.contains('تمکین') ||
        n.contains('طلاق') ||
        n.contains('حضانت') ||
        n.contains('ملاقات فرزند') ||
        n.contains('اجرت المثل')) {
      return 'family';
    }
    if (n.contains('فیشینگ') ||
        n.contains('اینترنتی') ||
        n.contains('هک') ||
        n.contains('کلاهبرداری') ||
        n.contains('امانت') ||
        n.contains('مال غیر')) {
      return 'fraud_cyber';
    }
    if (n.contains('توهین') ||
        n.contains('فحاشی') ||
        n.contains('فحش') ||
        n.contains('تهدید') ||
        n.contains('ضرب و جرح') ||
        n.contains('کتک') ||
        n.contains('عکس خصوصی') ||
        n.contains('فیلم خصوصی')) {
      return 'criminal_harm';
    }
    if (n.contains('حکم غیابی') ||
        n.contains('رای غیابی') ||
        n.contains('واخواهی') ||
        n.contains('تجدیدنظر') ||
        n.contains('اعتراض به رای') ||
        n.contains('ابلاغیه') ||
        n.contains('احضاریه') ||
        n.contains('از من شکایت') ||
        n.contains('علیه من')) {
      return 'litigation_defense';
    }
    if (n.contains('قرض') ||
        n.contains('طلب') ||
        n.contains('بدهی') ||
        n.contains('بدهکار') ||
        n.contains('سفته') ||
        n.contains('اعسار')) {
      return 'debt';
    }
    if (n.contains('مشاوره') ||
        n.contains('چه کار کنم') ||
        n.contains('چیکار کنم') ||
        n.contains('راهنمایی کن')) {
      return 'general_intake';
    }
    return null;
  }

  /// نکتهٔ موضوع برای دکمهٔ «شروع مشاوره» در پاسخ‌های اطلاعاتی؛ با شبکهٔ
  /// عصبی حتی وقتی پیام کلیدواژهٔ نمادین ندارد هم حوزهٔ محتمل پیشنهاد می‌شود.
  static String? detectTopicHint(String rawText, {IntentNet? net}) {
    final direct = detectTopic(rawText, net: net);
    if (direct != null) return direct;
    // پرسش اطلاعاتی (برچسب RAG) → همان آبشار نمادین قبلاً پیشنهاد مشاوره
    // روی حوزهٔ مرتبط می‌داد؛ آن را حفظ می‌کنیم.
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

  /// آغاز جلسهٔ مشاورهٔ دوطرفه بر اساس پیام کاربر.
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
    if (topic == 'general_intake') {
      return (
        session,
        CounselorTurn(
          text: _pick(replies, rnd, 'counselor_intake_greeting',
              _intakeGreetingFallback),
          chips: _intakeChips,
        ),
      );
    }
    _extractAllFacts(session, rawText);
    return (
      session,
      _advance(session, engine, templates,
          firstTurn: true, replies: replies, rnd: rnd)
    );
  }

  /// بازگشایی مشاورهٔ یک موضوع پس از جمع‌بندی جلسهٔ قبلی («ادامهٔ مشاوره»).
  static (CounselingSession, CounselorTurn)? resumeTopic(
    String topicId,
    String initialMessage,
    KnowledgeEngine engine,
    List<LegalTemplate> templates, {
    Replies? replies,
    Random? rnd,
  }) {
    if (!knownTopic(topicId)) return null;
    final session =
        CounselingSession(topicId: topicId, initialMessage: initialMessage);
    if (topicId == 'general_intake') {
      return (
        session,
        CounselorTurn(
          text: _pick(replies, rnd, 'counsel_resumed',
              'باشه، برگردیم سر موضوع «{topic}». از اول با چند سؤال کوتاه وضعیت را روشن می‌کنیم:',
              {'topic': topicTitleFa(topicId)}),
          chips: _intakeChips,
        ),
      );
    }
    _extractAllFacts(session, initialMessage);
    final turn = _advance(session, engine, templates,
        firstTurn: true, replies: replies, rnd: rnd);
    final lead = _pick(replies, rnd, 'counsel_resumed',
        'باشه، برگردیم سر موضوع «{topic}». از اول با چند سؤال کوتاه وضعیت را روشن می‌کنیم:',
        {'topic': topicTitleFa(topicId)});
    return (
      session,
      CounselorTurn(text: '$lead\n\n${turn.text}', chips: turn.chips),
    );
  }

  /// پرسش بازِ یک جلسهٔ نیمه‌کاره (برای بازیابی هنگام راه‌اندازی برنامه).
  static CounselorTurn? pendingTurn(
    CounselingSession session, {
    Replies? replies,
    Random? rnd,
  }) {
    if (session.concluded) return null;
    final note = _pick(replies, rnd, 'counsel_resumed_note',
        'گفتگوی مشاورهٔ ناتمام دربارهٔ «{topic}» بازیابی شد. می‌توانیم از همان‌جا ادامه دهیم:',
        {'topic': topicTitleFa(session.topicId)});
    if (session.topicId == 'general_intake') {
      return CounselorTurn(
        text: '$note\n\n$_intakeRepromptFallback',
        chips: _intakeRepromptChips,
      );
    }
    final steps = _stepsFor(session.topicId);
    final pending =
        steps.where((s) => !session.facts.containsKey(s.slot)).firstOrNull;
    if (pending == null) return null;
    return CounselorTurn(
      text: '$note\n\n${_promptFor(session.topicId, pending, replies, rnd)}',
      chips: [...pending.options, cancelCounselCmd],
    );
  }

  /// پردازش پاسخ کاربر در میانهٔ جلسهٔ مشاوره.
  static CounselorTurn step(
    CounselingSession session,
    String rawText,
    KnowledgeEngine engine,
    List<LegalTemplate> templates, {
    IntentNet? net,
    Replies? replies,
    Random? rnd,
  }) {
    final trimmed = rawText.trim();
    final n = _norm(trimmed);

    if (trimmed == cancelCounselCmd ||
        trimmed == DraftCmd.cancel ||
        n == 'انصراف' ||
        n == 'پایان مشاوره' ||
        n == 'لغو') {
      return const CounselorTurn(
        text:
            'مشاورهٔ گام‌به‌گام پایان یافت. هر زمان پرسش دیگری داشتید یا خواستید متنی تنظیم کنیم، در خدمتم.',
        cancelled: true,
      );
    }
    // شبکهٔ عصبی نیت «لغو/انصراف» را حتی از عبارت آزادِ کاربر می‌گیرد.
    if (net != null) {
      final s = net.classify(trimmed);
      if (s.label == 'cancel' && s.score >= net.cancelMin) {
        return const CounselorTurn(
          text:
              'مشاورهٔ گام‌به‌گام پایان یافت. هر زمان پرسش دیگری داشتید یا خواستید متنی تنظیم کنیم، در خدمتم.',
          cancelled: true,
        );
      }
    }

    // اگر جلسه در مرحلهٔ پایانی بوده و کاربر روی دکمهٔ «تنظیم ...» کلیک کرده است:
    if (session.concluded) {
      final picked = _matchTemplateChip(trimmed, templates);
      if (picked != null) {
        return CounselorTurn(
          text: '',
          completed: true,
          startTemplate: picked,
        );
      }
      // اگر بعد از جمع‌بندی سؤال جدیدی پرسید، جلسه تمام شود تا موتور عادی جواب دهد
      return const CounselorTurn(text: '', completed: true);
    }

    // پرسش حقوقی در میانهٔ مشاوره → پاسخ RAG از بانک قوانین + بازگشت خودکار
    // به پرسش بازِ درخت تصمیم (بدون از دست رفتن وضعیت جلسه).
    if (_isLegalQuestion(trimmed, net)) {
      return _ragTurn(session, trimmed, engine, replies, rnd);
    }

    if (session.topicId == 'general_intake') {
      final detected =
          _topicFromIntakeChoice(n) ?? detectTopic(trimmed, net: net);
      if (detected != null && detected != 'general_intake') {
        session.topicId = detected;
        _extractAllFacts(session, trimmed);
        return _advance(session, engine, templates,
            firstTurn: true, replies: replies, rnd: rnd);
      }
      return CounselorTurn(
        text: _pick(replies, rnd, 'counselor_intake_reprompt',
            _intakeRepromptFallback),
        chips: _intakeRepromptChips,
      );
    }

    final steps = _stepsFor(session.topicId);
    final pendingStep = steps.where((s) => !session.facts.containsKey(s.slot)).firstOrNull;
    String? ack;
    if (pendingStep != null) {
      final val = pendingStep.extractor(n);
      if (val != null) {
        session.facts[pendingStep.slot] = val;
        // تصدیق طبیعیِ پاسخ کاربر (فقط وقتی قالب‌های replies.json فعال‌اند
        // تا رفتار قطعیِ قدیمی بدون آن‌ها مو به مو حفظ شود).
        if (replies != null) {
          ack = _pick(replies, rnd, 'counselor_ack',
              'باشه، پس «{answer}» — این را یادداشت کردم.',
              {'answer': _reflect(trimmed)});
        }
      } else {
        // اگر پاسخ آزاد بود ولی در گزینه‌ها جا نگرفت، متن کاربر را ذخیره و به نزدیک‌ترین حالت نگاشت کن
        session.facts[pendingStep.slot] = trimmed;
        if (replies != null) {
          ack = _pick(replies, rnd, 'counselor_ack_generic',
              'خب، این نکته را هم در نظر می‌گیرم. حالا بفرمایید:');
        }
      }
      // شاید در همین جمله اطلاعات سؤال‌های بعدی هم گفته شده باشد
      _extractAllFacts(session, trimmed);
    }

    return _advance(session, engine, templates,
        firstTurn: false, replies: replies, rnd: rnd, ack: ack);
  }

  // ── پرسش حقوقی در میانهٔ مشاوره (RAG) ────────────────────────────────
  static final RegExp _questionGlowRe = RegExp(
    r'[؟?]|چیست|چیه|چقدر|چطور|چگونه|کجا|آیا|یعنی|چرا|کدام|کیست|چه می‌گوید',
  );

  static bool _lawishCue(String n) =>
      n.contains('قانون') ||
      n.contains('ماده') ||
      n.contains('اصل') ||
      n.contains('مجازات') ||
      n.contains('مهلت') ||
      n.contains('شرایط') ||
      n.contains('تعریف');

  /// آیا پیام کاربر در میانهٔ مشاوره پرسش حقوقی/قانونی است که باید با
  /// موتور دانش (RAG) پاسخ داده شود؟ تصمیم اصلی با شبکهٔ عصبی است و
  /// نشانه‌های پرسشی + کلیدواژه‌ها تور ایمنی‌اند تا پاسخ‌های خبریِ
  /// خانهٔ پرسش (مثلاً «خودم موجرم») هرگز گفتگو را از ریل خارج نکنند.
  static bool _isLegalQuestion(String rawText, IntentNet? net) {
    final n = _norm(rawText);
    if (_directArtRe.hasMatch(n)) return true;
    if (net != null) {
      final s = net.classify(rawText);
      if (s.score >= net.ragMin) {
        return IntentNet.ragLabels.contains(s.label) &&
            _questionGlowRe.hasMatch(n);
      }
    }
    return _questionGlowRe.hasMatch(n) &&
        (_pureDefRe.hasMatch(n) || _lawishCue(n));
  }

  static CounselorTurn _ragTurn(
    CounselingSession session,
    String rawText,
    KnowledgeEngine engine,
    Replies? replies,
    Random? rnd,
  ) {
    final reply = engine.query(rawText, maxAlternatives: 0);
    final notFound = reply.text.contains('پیدا نکردم') ||
        reply.text.contains('پیدا نشد') ||
        reply.text.contains('هنوز در برنامه نیست');
    final sb = StringBuffer();
    if (!notFound) {
      sb.writeln(_pick(replies, rnd, 'counselor_rag_intro',
          'سؤال خوبی است؛ اجازه بدهید همین را مستقیم از متن رسمی قانون بیاورم:'));
      sb.writeln();
      sb.write(reply.text);
    } else {
      sb.write(_pick(replies, rnd, 'counselor_rag_miss',
          'پاسخ دقیقی برای این پرسش در بانک قوانین برنامه پیدا نکردم و بهتر است حدس نزنم. برویم سراغ ادامهٔ بررسی وضعیت خودت:'));
    }

    if (session.topicId == 'general_intake') {
      sb.writeln();
      sb.writeln();
      sb.write(_pick(replies, rnd, 'counselor_intake_reprompt',
          _intakeRepromptFallback));
      return CounselorTurn(
        text: sb.toString(),
        chips: _intakeRepromptChips,
        ragQuery: notFound ? null : rawText,
        ragReply: notFound ? null : reply,
      );
    }

    final steps = _stepsFor(session.topicId);
    final pending =
        steps.where((s) => !session.facts.containsKey(s.slot)).firstOrNull;
    if (pending != null) {
      if (!notFound) {
        sb.writeln();
        sb.writeln();
        sb.writeln(_pick(replies, rnd, 'counselor_resume',
            'حالا برگردیم به وضعیت خودت؛ این پرسش هنوز باز است:'));
      }
      sb.writeln();
      sb.write(_promptFor(session.topicId, pending, replies, rnd));
      return CounselorTurn(
        text: sb.toString(),
        chips: [...pending.options, cancelCounselCmd],
        ragQuery: notFound ? null : rawText,
        ragReply: notFound ? null : reply,
      );
    }
    return CounselorTurn(
      text: sb.toString(),
      chips: const [cancelCounselCmd],
      ragQuery: notFound ? null : rawText,
      ragReply: notFound ? null : reply,
    );
  }

  static LegalTemplate? _matchTemplateChip(
    String text,
    List<LegalTemplate> templates,
  ) {
    final cleaned = text.startsWith(draftPrefix)
        ? text.substring(draftPrefix.length).trim()
        : text.trim();
    final cn = _norm(cleaned);
    for (final t in templates) {
      final tn = _norm(t.title);
      if (cn == tn || cn.contains(tn) || tn.contains(cn)) {
        return t;
      }
    }
    return null;
  }

  static String? _topicFromIntakeChoice(String n) {
    if (n.contains('چک')) return 'cheque';
    if (n.contains('کار') || n.contains('بیمه')) return 'labor';
    if (n.contains('اجاره') || n.contains('تخلیه') || n.contains('پول پیش')) {
      return 'lease';
    }
    if (n.contains('مهریه') ||
        n.contains('نفقه') ||
        n.contains('طلاق') ||
        n.contains('حضانت')) {
      return 'family';
    }
    if (n.contains('کلاهبرداری') ||
        n.contains('فیشینگ') ||
        n.contains('امانت')) {
      return 'fraud_cyber';
    }
    if (n.contains('ابلاغیه') ||
        n.contains('اعتراض به رای') ||
        n.contains('شکایت علیه من')) {
      return 'litigation_defense';
    }
    if (n.contains('طلب') || n.contains('سفته') || n.contains('اعسار')) {
      return 'debt';
    }
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
    String? ack,
  }) {
    final steps = _stepsFor(session.topicId);
    final nextStep =
        steps.where((s) => !session.facts.containsKey(s.slot)).firstOrNull;

    if (nextStep != null) {
      final lead = firstTurn
          ? '${_pick(replies, rnd, 'ci_${session.topicId}', _empathyIntro(session.topicId))}\n\n'
          : (ack == null || ack.isEmpty ? '' : '$ack\n\n');
      final prompt =
          _promptFor(session.topicId, nextStep, replies, rnd);
      return CounselorTurn(
        text: '$lead$prompt',
        chips: [...nextStep.options, cancelCounselCmd],
      );
    }

    session.concluded = true;
    return _buildConclusion(session, engine, templates,
        replies: replies, rnd: rnd);
  }

  static String _empathyIntro(String topicId) {
    switch (topicId) {
      case 'cheque':
        return 'متوجه موضوع چک شما شدم. در دعاوی چک، تفاوت ظریفی بین مسیر «کیفری»، «اجرائیهٔ مستقیم ثبت/دادگاه» و «دعوای حقوقی» وجود دارد؛ اجازه بدهید با دو سؤال کوتاه وضعیت دقیق شما را مشخص کنم.';
      case 'labor':
        return 'پیگیری حقوق کارگری و بیمه کاملاً حق قانونی شماست و مهلت‌های مهمی دارد. برای اینکه دقیق‌ترین مسیر را پیشنهاد دهم، لطفاً این مورد را مشخص کنید:';
      case 'lease':
        return 'اختلافات موجر و مستأجر بسته به نوع قرارداد و امضای شهود، مسیر قضایی کاملاً متفاوتی (فوری یا عادی) دارند. بیایید گام‌به‌گام بررسی کنیم:';
      case 'family':
        return 'مسائل خانواده نیازمند دقت و آرامش است تا حقوق قانونی شما به بهترین شکل حفظ شود. برای ارائهٔ تحلیل دقیق، لطفاً بفرمایید:';
      case 'fraud_cyber':
        return 'متأسفم که چنین اتفاقی افتاده است. در جرایم مالی و اینترنتی، تشخیص درست عنوان اتهامی (کلاهبرداری، جرم رایانه‌ای یا خیانت در امانت) از رد شدن شکایت در دادسرا جلوگیری می‌کند.';
      case 'criminal_harm':
        return 'حفظ امنیت و حیثیت شما مورد حمایت کامل قانون است. برای اینکه ببینیم بهترین ادله و عنوان شکایت چیست، لطفاً بفرمایید:';
      case 'litigation_defense':
        return 'نگران نباشید؛ دریافت ابلاغیه یا صدور رأی به معنای پایان کار نیست و قانون به شما فرصت دفاع و اعتراض داده است. زمان در اینجا بسیار مهم است:';
      case 'debt':
      default:
        return 'بسیار خوب؛ بیایید وضعیت طلب یا بدهی و مدارک شما را دقیق بررسی کنیم تا بهترین اقدام قانونی مشخص شود:';
    }
  }

  // -------------------- درخت‌های پرسشگری تشخیصی --------------------

  static List<_QuestionStep> _stepsFor(String topicId) {
    switch (topicId) {
      case 'cheque':
        return [
          _QuestionStep(
            slot: 'role',
            prompt:
                '۱. نقش شما در مورد این چک چیست؟ (دارندهٔ چک هستید و می‌خواهید وجهش را بگیرید، یا صادرکننده/ضامن هستید که علیه‌تان اقدام شده است؟)',
            options: const [
              'دارندهٔ چک هستم (طلبکار)',
              'صادرکننده یا ضامن چک هستم',
            ],
            extractor: (n) {
              if (n.contains('دارنده') ||
                  n.contains('طلبکار') ||
                  n.contains('چکم برگشت') ||
                  n.contains('چک برگشتی دارم') ||
                  n.contains('پولم را بگیرم')) {
                return 'holder';
              }
              if (n.contains('صادرکننده') ||
                  n.contains('ضامن') ||
                  n.contains('چک دادم') ||
                  n.contains('چک کشیدم') ||
                  n.contains('بابت ضمانت داده بودم')) {
                return 'issuer';
              }
              return null;
            },
          ),
          _QuestionStep(
            slot: 'nature',
            prompt:
                '۲. آیا چک بابت بدهی قطعی و به تاریخ روز صادر شده، یا بابت تضمین، امانت، معاملهٔ مشروط و سفیدامضا بوده است؟\n(این نکته طبق مادهٔ ۱۳ قانون صدور چک تعیین‌کنندهٔ امکان شکایت کیفری است.)',
            options: const [
              'بابت بدهی قطعی و تاریخ روز',
              'بابت تضمین، امانت، مشروط یا وعده‌دار',
            ],
            extractor: (n) {
              if (n.contains('تضمین') ||
                  n.contains('ضمانت') ||
                  n.contains('امانت') ||
                  n.contains('مشروط') ||
                  n.contains('سفید') ||
                  n.contains('وعده')) {
                return 'conditional';
              }
              if (n.contains('بدهی قطعی') || n.contains('تاریخ روز')) {
                return 'unconditional';
              }
              return null;
            },
          ),
          _QuestionStep(
            slot: 'cert_time',
            prompt:
                '۳. آیا گواهی عدم پرداخت از بانک دریافت شده و کمتر از ۶ ماه از تاریخ چک و گواهی گذشته است؟',
            options: const [
              'بله، گواهی دارم و زیر ۶ ماه است',
              'بیش از ۶ ماه گذشته است',
              'هنوز برگشت نزده‌ام / گواهی ندارم',
            ],
            extractor: (n) {
              if (n.contains('هنوز برگشت نزده') || n.contains('گواهی ندارم')) {
                return 'no_cert';
              }
              if (n.contains('بیش از 6 ماه') ||
                  n.contains('بیشتر از 6 ماه') ||
                  n.contains('یک سال گذشته')) {
                return 'over_6m';
              }
              if (n.contains('زیر 6 ماه') || n.contains('گواهی دارم')) {
                return 'under_6m';
              }
              return null;
            },
          ),
        ];

      case 'labor':
        return [
          _QuestionStep(
            slot: 'issue',
            prompt: '۱. مشکل اصلی شما با کارفرما کدام مورد است؟',
            options: const [
              'اخراج یا عدم تمدید و بازگشت به کار',
              'عدم پرداخت حقوق، عیدی یا سنوات',
              'رد نکردن حق بیمهٔ تأمین اجتماعی',
            ],
            extractor: (n) {
              if (n.contains('اخراج') || n.contains('بازگشت به کار')) {
                return 'dismissal';
              }
              if (n.contains('بیمه') && !n.contains('حقوق')) {
                return 'insurance';
              }
              if (n.contains('حقوق') ||
                  n.contains('سنوات') ||
                  n.contains('عیدی')) {
                return 'wages';
              }
              return null;
            },
          ),
          _QuestionStep(
            slot: 'proof',
            prompt:
                '۲. چه مدرکی برای اثبات رابطهٔ کاری دارید؟ (قرارداد کتبی، فیش واریز حقوق، لیست بیمه یا پیامک و شهادت همکاران؟)',
            options: const [
              'قرارداد کتبی یا سابقهٔ بیمه دارم',
              'قرارداد شفاهی ولی واریزی بانکی/پیامک دارم',
              'هیچ مدرک کتبی یا بانکی ندارم',
            ],
            extractor: (n) {
              if (n.contains('کتبی') || n.contains('سابقه بیمه')) {
                return 'written';
              }
              if (n.contains('شفاهی') || n.contains('واریزی')) {
                return 'bank_sms';
              }
              if (n.contains('هیچ مدرک')) {
                return 'none';
              }
              return null;
            },
          ),
          _QuestionStep(
            slot: 'time',
            prompt:
                '۳. در حال حاضر مشغول به کار هستید یا قطع همکاری شده؟ اگر اخراج شده‌اید، آیا کمتر از ۳۰ روز از تاریخ اخراج گذشته است؟',
            options: const [
              'کمتر از ۳۰ روز از اخراج گذشته است',
              'بیش از ۳۰ روز از قطع همکاری گذشته',
              'هنوز در کارگاه مشغول به کارم',
            ],
            extractor: (n) {
              if (n.contains('کمتر از 30') || n.contains('هفته پیش اخراج')) {
                return 'under_30d';
              }
              if (n.contains('بیش از 30') || n.contains('چند ماه پیش')) {
                return 'over_30d';
              }
              if (n.contains('مشغول به کار')) {
                return 'active';
              }
              return null;
            },
          ),
        ];

      case 'lease':
        return [
          _QuestionStep(
            slot: 'role',
            prompt: '۱. در این رابطهٔ اجاره، شما موجر (مالک) هستید یا مستأجر؟',
            options: const [
              'موجر (مالک) هستم',
              'مستأجر هستم',
            ],
            extractor: (n) {
              if (n.contains('مستاجرم') ||
                  n.contains('مستاجر من') ||
                  n.contains('مالک هستم') ||
                  n.contains('موجر هستم')) {
                return 'landlord';
              }
              if (n.contains('صاحبخانه') ||
                  n.contains('صاحب خانه') ||
                  n.contains('مستاجر هستم') ||
                  n.contains('پول پیشم')) {
                return 'tenant';
              }
              return null;
            },
          ),
          _QuestionStep(
            slot: 'expired',
            prompt: '۲. آیا مدت قرارداد اجاره به پایان رسیده است؟',
            options: const [
              'بله، مدت قرارداد تمام شده است',
              'خیر، هنوز در میانهٔ مدت قرارداد هستیم',
            ],
            extractor: (n) {
              if (n.contains('تمام شده') ||
                  n.contains('منقضی شده') ||
                  n.contains('پایان رسیده')) {
                return 'yes';
              }
              if (n.contains('میانه مدت') || n.contains('تمام نشده')) {
                return 'no';
              }
              return null;
            },
          ),
          _QuestionStep(
            slot: 'witnesses',
            prompt:
                '۳. نوع قرارداد اجارهٔ شما چگونه است؟ (سند رسمی، قرارداد عادی با امضای دو شاهد/کد رهگیری، یا دست‌نویس بدون دو شاهد؟)',
            options: const [
              'قرارداد کتبی با امضای دو شاهد یا سند رسمی',
              'قرارداد عادی بدون امضای دو شاهد یا شفاهی',
            ],
            extractor: (n) {
              if (n.contains('دو شاهد') ||
                  n.contains('رسمی') ||
                  n.contains('کد رهگیری')) {
                return 'two_witnesses';
              }
              if (n.contains('بدون امضای دو شاهد') ||
                  n.contains('بدون شاهد') ||
                  n.contains('شفاهی')) {
                return 'no_witnesses';
              }
              return null;
            },
          ),
        ];

      case 'family':
        return [
          _QuestionStep(
            slot: 'subtopic',
            prompt: '۱. موضوع اصلی پرونده یا پرسش خانوادگی شما کدام است؟',
            options: const [
              'مطالبه یا تقسیط مهریه',
              'نفقه و تمکین',
              'درخواست طلاق',
              'حضانت و ملاقات فرزند',
            ],
            extractor: (n) {
              if (n.contains('مهریه')) return 'mehrieh';
              if (n.contains('نفقه') || n.contains('تمکین')) return 'nafaqeh';
              if (n.contains('حضانت') || n.contains('ملاقات')) return 'custody';
              if (n.contains('طلاق')) return 'divorce';
              return null;
            },
          ),
          _QuestionStep(
            slot: 'side',
            prompt: '۲. شما از طرف زوجه (خانم) پیگیر موضوع هستید یا زوج (آقا)؟',
            options: const [
              'زوجه (خانم) هستم',
              'زوج (آقا) هستم',
            ],
            extractor: (n) {
              if (n.contains('زوجه') ||
                  n.contains('شوهرم') ||
                  n.contains('خانم هستم')) {
                return 'wife';
              }
              if (n.contains('زوج هستم') ||
                  n.contains('آقا هستم') ||
                  n.contains('خانمم') ||
                  n.contains('مهریه را اجرا گذاشته')) {
                return 'husband';
              }
              return null;
            },
          ),
          _QuestionStep(
            slot: 'detail',
            prompt:
                '۳. کدام وضعیت به شرایط فعلی شما نزدیک‌تر است؟',
            options: const [
              'توافق نداریم و طرف مقابل همکاری نمی‌کند',
              'حکم یا اجرائیه صادر شده و بحث توان مالی/اعسار مطرح است',
              'زمینهٔ توافق بین زوجین وجود دارد',
            ],
            extractor: (n) {
              if (n.contains('توان مالی') ||
                  n.contains('اعسار') ||
                  n.contains('اجرا گذاشته')) {
                return 'enforcement_insolvency';
              }
              if (n.contains('توافق داریم') || n.contains('توافقی')) {
                return 'mutual';
              }
              if (n.contains('توافق نداریم') || n.contains('همکاری نمی')) {
                return 'contested';
              }
              return null;
            },
          ),
        ];

      case 'fraud_cyber':
        return [
          _QuestionStep(
            slot: 'kind',
            prompt:
                '۱. نحوهٔ از دست رفتن مال یا وقوع جرم دقیقاً به چه شکلی بوده است؟',
            options: const [
              'برداشت اینترنتی، لینک جعلی (فیشینگ) یا هک',
              'فریب با مانور متقلبانه و صحنه‌سازی (کلاهبرداری)',
              'مالی را به امانت دادم و پس نمی‌دهد',
              'ملک یا مال مرا بدون اجازه به دیگری فروخته است',
            ],
            extractor: (n) {
              if (n.contains('فیشینگ') ||
                  n.contains('اینترنتی') ||
                  n.contains('هک') ||
                  n.contains('لینک')) {
                return 'cyber';
              }
              if (n.contains('امانت')) return 'trust_breach';
              if (n.contains('مال غیر') || n.contains('بدون اجازه فروخته')) {
                return 'unauthorized_sale';
              }
              if (n.contains('مانور') || n.contains('صحنه سازی')) {
                return 'classic_fraud';
              }
              return null;
            },
          ),
          _QuestionStep(
            slot: 'evidence',
            prompt:
                '۲. چه مستنداتی در دست دارید؟ (رسید بانکی و شماره حساب مقصد، قرارداد/رسید امانت، پیامک‌ها یا شاهد؟)',
            options: const [
              'گردش حساب بانکی، اسکرین‌شات یا رسید کتبی دارم',
              'فقط شاهد یا مکالمهٔ شفاهی دارم',
            ],
            extractor: (n) {
              if (n.contains('گردش حساب') ||
                  n.contains('رسید') ||
                  n.contains('اسکرین')) {
                return 'strong';
              }
              if (n.contains('فقط شاهد') || n.contains('شفاهی')) {
                return 'weak';
              }
              return null;
            },
          ),
        ];

      case 'criminal_harm':
        return [
          _QuestionStep(
            slot: 'harm_type',
            prompt: '۱. چه رفتاری علیه شما رخ داده است؟',
            options: const [
              'ضرب و جرح و آسیب بدنی',
              'تهدید یا اخاذی',
              'توهین، فحاشی یا افترا',
              'انتشار عکس/فیلم خصوصی در فضای مجازی',
            ],
            extractor: (n) {
              if (n.contains('ضرب') || n.contains('کتک')) return 'assault';
              if (n.contains('عکس خصوصی') || n.contains('فیلم خصوصی')) {
                return 'private_media';
              }
              if (n.contains('تهدید') || n.contains('اخاذی')) return 'threat';
              if (n.contains('توهین') ||
                  n.contains('فحاشی') ||
                  n.contains('افترا')) {
                return 'insult';
              }
              return null;
            },
          ),
          _QuestionStep(
            slot: 'proof',
            prompt:
                '۲. آیا مدرکی مانند گواهی پزشکی قانونی، گزارش پلیس ۱۱۰، شهادت شهود یا پیامک و صدای ضبط‌شده دارید؟',
            options: const [
              'گواهی پزشکی قانونی / گزارش پلیس / پیامک دارم',
              'فقط شاهد دارم',
              'فعلاً مدرکی جمع‌آوری نکرده‌ام',
            ],
            extractor: (n) {
              if (n.contains('پزشکی قانونی') ||
                  n.contains('پلیس') ||
                  n.contains('پیامک')) {
                return 'documented';
              }
              if (n.contains('شاهد')) return 'witness';
              if (n.contains('فعلا مدرکی')) return 'none';
              return null;
            },
          ),
        ];

      case 'litigation_defense':
        return [
          _QuestionStep(
            slot: 'stage',
            prompt:
                '۱. ابلاغیه‌ای که در سامانهٔ ثنا دریافت کرده‌اید مربوط به کدام مرحله است؟',
            options: const [
              'ابلاغ وقت رسیدگی یا احضاریه (پرونده در جریان است)',
              'حکم غیابی صادر شده است (در جلسات شرکت نکرده‌ام)',
              'رأی حضوری بدوی صادر شده و می‌خواهم اعتراض کنم',
            ],
            extractor: (n) {
              if (n.contains('غیابی')) return 'default_judgment';
              if (n.contains('حضوری بدوی') || n.contains('تجدیدنظر')) {
                return 'appeal';
              }
              if (n.contains('وقت رسیدگی') || n.contains('احضاریه')) {
                return 'first_hearing';
              }
              return null;
            },
          ),
          _QuestionStep(
            slot: 'deadline',
            prompt:
                '۲. چند روز از تاریخ درج ابلاغیه در سامانهٔ ثنا گذشته است؟ (برای مقیمان ایران مهلت واخواهی و تجدیدنظر ۲۰ روز است.)',
            options: const [
              'کمتر از ۲۰ روز گذشته است (مهلت دارم)',
              'بیش از ۲۰ روز گذشته ولی عذر موجه (بیماری/عدم اطلاع واقعی) دارم',
              'بیش از ۲۰ روز گذشته و رأی به اجرا رفته است',
            ],
            extractor: (n) {
              if (n.contains('کمتر از 20') || n.contains('مهلت دارم')) {
                return 'within_20d';
              }
              if (n.contains('عذر موجه')) return 'excused_late';
              if (n.contains('به اجرا رفته') || n.contains('بیش از 20')) {
                return 'late';
              }
              return null;
            },
          ),
        ];

      case 'debt':
      default:
        return [
          _QuestionStep(
            slot: 'role',
            prompt:
                '۱. شما طلبکار هستید که می‌خواهید پولتان را مطالبه کنید، یا بدهکار/خوانده هستید که علیه‌تان مطالبه شده است؟',
            options: const [
              'طلبکار هستم و می‌خواهم پولم را بگیرم',
              'بدهکار هستم و توان پرداخت یکجای بدهی را ندارم',
            ],
            extractor: (n) {
              if (n.contains('بدهکار هستم') ||
                  n.contains('توان پرداخت') ||
                  n.contains('اعسار')) {
                return 'debtor';
              }
              if (n.contains('طلبکار') ||
                  n.contains('قرض دادم') ||
                  n.contains('پولم را بگیرم')) {
                return 'creditor';
              }
              return null;
            },
          ),
          _QuestionStep(
            slot: 'doc',
            prompt:
                '۲. چه مدرکی بابت این بدهی/طلب وجود دارد؟',
            options: const [
              'رسید کتبی، قرارداد یا سفته',
              'فیش واریز بانکی و پیامک‌های اقرار به بدهی',
              'فقط شهادت شهود (شفاهی)',
            ],
            extractor: (n) {
              if (n.contains('رسید کتبی') ||
                  n.contains('سفته') ||
                  n.contains('قرارداد')) {
                return 'written';
              }
              if (n.contains('فیش') || n.contains('واریز')) {
                return 'bank';
              }
              if (n.contains('شفاهی') || n.contains('شهادت')) {
                return 'oral';
              }
              return null;
            },
          ),
        ];
    }
  }

  // -------------------- استنتاج منطقی و جمع‌بندی مستند به قانون --------------------

  static String _citeSnippet(
    KnowledgeEngine engine,
    String lawId,
    String article,
  ) {
    final c = engine.findArticle(lawId, article);
    if (c == null) return '';
    final clean = c.body.trim();
    final excerpt =
        clean.length > 260 ? '${clean.substring(0, 257)}...' : clean;
    return PersianText.toFaDigits('• ${c.title} ${c.source}: «$excerpt»');
  }

  static List<String> _templateChipsForIds(
    List<String> ids,
    List<LegalTemplate> templates,
  ) {
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
        final isIssuer = s.facts['role'] == 'issuer';
        final isCond = s.facts['nature'] == 'conditional';
        final time = s.facts['cert_time'] ?? 'under_6m';
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
        final issue = s.facts['issue'] ?? 'wages';
        final time = s.facts['time'] ?? 'under_30d';
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
        final isLandlord = s.facts['role'] == 'landlord';
        final expired = s.facts['expired'] != 'no';
        final twoWit = s.facts['witnesses'] == 'two_witnesses';
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
        final sub = s.facts['subtopic'] ?? 'mehrieh';
        final isWife = s.facts['side'] != 'husband';
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
        final kind = s.facts['kind'] ?? 'classic_fraud';
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
        final harm = s.facts['harm_type'] ?? 'insult';
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
        final stage = s.facts['stage'] ?? 'first_hearing';
        final dl = s.facts['deadline'] ?? 'within_20d';
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
        final isDebtor = s.facts['role'] == 'debtor';
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
      sb.write(
        '✍️ اگر مایل باشید، می‌توانم همین حالا پیش‌نویس استاندارد هر یک از متون زیر را گام‌به‌گام برایتان تنظیم کنم (کافی است روی دکمهٔ آن بزنید):',
      );
    }

    // مقدمهٔ متنوع برای جمع‌بندی (فقط وقتی قالب‌های replies.json فعال‌اند).
    final open = replies == null
        ? ''
        : '${_pick(replies, rnd, 'counselor_conclusion_open', 'خب، تحلیل نهایی‌ام از وضعیت شما با تکیه بر متن قوانین:')}\n\n';
    return CounselorTurn(
      text: '$open${sb.toString().trim()}',
      chips: chips,
      completed: true,
    );
  }
}
