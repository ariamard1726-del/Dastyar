import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/jalali.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/qa_bank.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/case_plan.dart';
import 'package:dastyar/domain/advocate/dialogue_state.dart';
import 'package:dastyar/domain/advocate/glossary.dart';
import 'package:dastyar/domain/advocate/law_terms.dart';
import 'package:dastyar/domain/advocate/phrases.dart';
import 'package:dastyar/domain/advocate/reply_voice.dart';
import 'package:dastyar/domain/advocate/reasoner.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topic_score.dart';
import 'package:dastyar/domain/advocate/topic_flow.dart';
import 'package:dastyar/domain/advocate/topics/all.dart';
import 'package:dastyar/domain/advocate/topics/shared.dart';
import 'package:dastyar/domain/advocate/understanding.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/lawyer/lawyer_voice.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';
import 'package:dastyar/domain/understanding/topic_guess.dart';

part 'advocate_topic.dart';
part 'advocate_case.dart';
part 'case_flow.dart';
part 'case_facts.dart';
part 'case_answer.dart';
part 'case_text.dart';
part 'advocate_argue.dart';
part 'case_recap.dart';
part 'chip_plan.dart';
part 'advocate_chips.dart';
part 'advocate_meta.dart';
part 'law_answer.dart';
part 'talk_reply.dart';
part 'talk_route.dart';
part 'topic_picker.dart';
part 'advocate_talk.dart';
part 'term_reply.dart';
part 'answer_candidate.dart';
part 'topic_read.dart';
part 'safety_reply.dart';
part 'advocate_constants.dart';
part 'advocate_reply.dart';
part 'advocate_reply_guard.dart';
part 'advocate_reply_case.dart';
part 'guide_reply.dart';
part 'advocate_model.dart';
part 'chip_texts.dart';
part 'advocate_data.dart';
part 'advocate_text.dart';
part 'reply_routes.dart';
part 'advocate_leave.dart';

class Advocate {
  Advocate(
    this.engine, {
    Map<String, String> draftTitles = const {},
    this.intentNet,
  }) : _draftTitles = draftTitles;

  /// طبقه‌بند نیت (اختیاری). بدون آن هم وکیل کامل کار می‌کند.
  final IntentNet? intentNet;

  final KnowledgeEngine engine;

  /// ساختِ پاسخ‌ها: استناد، برش، سقفِ تکرارِ پرسش و چیدمان دکمه‌ها.
  /// وضعیتِ «چه گفتیم و چه پرسیدیم» این‌جاست، نه روی خودِ وکیل.
  /// پاسخ از بانک پرسش‌وپاسخ و متن قوانین.
  late final LawAnswer _lawAnswer = LawAnswer(
    engine: engine,
    voice: voice,
    party: _party,
    prepared: preparedEngineReply,
  );

  /// تشخیص موضوع و بحث (کدام پرونده به این پیام می‌خورد).
  late final TopicPicker _picker = TopicPicker(
    file: file,
    dialog: dialog,
    intentNet: intentNet,
    open: (t, n, {bool guessed = false}) => _open(t, n, guessed: guessed),
    voice: () => voice,
  );

  /// روندِ پرونده: بازکردن، خواندنِ واقعیت‌ها، پرسشِ بعدی و جمع‌بندی.
  late final CaseFlow _case = CaseFlow(
    file: file,
    dialog: dialog,
    voice: voice,
    argument: _argument,
    picker: _picker,
    talk: _talk,
    law: _lawAnswer,
    chipPlan: () => _chipPlan,
    filings: () => filings,
    draftTitles: _draftTitles,
    echo: _echo,
    flips: _flips,
    glossary: _guides.glossary,
    openGuide: (g, raw, n, {bool? switched}) =>
        _guides.openGuide(g, raw, n, switched: switched ?? false),
    fillFor: fillFor,
    draftIds: draftIds,
  );

  /// گفت‌وگوی انسانی: خلاصه، احوال‌پرسی، سوگ، «منظورتان چیست؟».
  late final TalkReply _talk = TalkReply(
    file: file,
    dialog: dialog,
    voice: voice,
    intentNet: intentNet,
    chipPlan: () => _chipPlan,
  );

  /// راهنما، واژه‌نامه و آخرین راه (بانک و متن قوانین).
  late final GuideReply _guides = GuideReply(
    file: file,
    dialog: dialog,
    voice: voice,
    engine: engine,
    talk: _talk,
    lawAnswer: _lawAnswer,
    metaReplies: _metaReplyBot,
    draftTitles: _draftTitles,
    closeCase: () => _case.closeCase(),
  );

  /// مسیرهای یک‌نوبتیِ پاسخ (سیزده مسیرِ نام‌دار).
  late final ReplyRoutes _routes = ReplyRoutes(
    file: file,
    dialog: dialog,
    voice: voice,
    flow: _case,
    picker: _picker,
    talk: _talk,
    talkRoute: _talkRoute,
    reply: (raw, {bool again = true}) => _reply(raw, again: again),
  );

  /// مسیرِ گفت‌وگوی عمومی: سلام، سوگ، خلاصه، دستهٔ مشکل، «خارج شدم و برگشتم».
  late final TalkRoute _talkRoute = TalkRoute(
    file: file,
    dialog: dialog,
    voice: voice,
    engine: engine,
    talk: _talk,
    picker: _picker,
    chipPlan: () => _chipPlan,
    closeCase: () => _case.closeCase(),
  );

  /// پاسخ‌های «دربارهٔ برنامه» و «ماجرای حقوقی نیست».
  late final MetaReply _metaReplyBot = MetaReply(
    file: file,
    dialog: dialog,
    voice: voice,
    current: _current,
    anyTopicCue: _anyTopicCue,
  );
  /// استدلال: مقایسهٔ ادعاها با واقعیت‌های پرونده و گفتنِ نتیجه.
  late final CaseArgument _argument = CaseArgument(file, voice, (t) => recapOf(t, file), _flips);

  late final ReplyVoice voice =
      ReplyVoice(engine: engine, file: file, unresolved: unresolved,
          defaultBudget: _budget);

  late final LawTerms _terms = LawTerms(engine);

  /// پاسخِ ایمنی (خشونت، تهدید، اورژانس) — پیش از هر پاسخِ دیگر.
  late final SafetyReply _safetyBot = SafetyReply(voice: voice);

  /// داورِ فهرستِ پاسخ‌ها؛ ترتیب = اولویت.
  static const AnswerArbiter _arbiter = AnswerArbiter();

  /// آخرین تصمیم: کدام کاندید با چه منبع و دلیلی برنده شد.
  /// فقط برای بازرسی است؛ رفتار و ترتیب کاندیدها عوض نمیشود.
  AnswerDecision? lastDecision;

  /// پاسخ‌های واژه‌محور: متنِ مواد و مسیرِ موضوع.
  late final TermReply _termReply = TermReply(
    file: file,
    dialog: dialog,
    voice: voice,
    engine: engine,
    terms: _terms,
  );

  /// شناسهٔ قالب سند → عنوان آن (برای دکمهٔ «تهیهٔ متن»).
  final Map<String, String> _draftTitles;

  final CaseFile file = CaseFile();

  /// استنادهایی که متنشان در بانک پیدا نشد (برای آزمون؛ باید خالی بماند).
  final List<String> unresolved = [];

  /// واقعیت‌هایی که کاربر در همین پیام دوباره گفت (بدون تغییر مقدار).
  final List<Slot> _echo = [];

  /// واقعیت‌های بله/نه‌ای که کاربر در همین پیام برعکسِ قبل گفت (نام → مقدار
  /// قبلی)؛ وکیل باید بگوید برداشتش را عوض کرده است.
  final Map<String, String> _flips = {};

  /// پیام پیشین کاربر (نرمال‌شده)، برای تشخیص تکرار حرف.
  String _prevN = '';

  /// چه چیزی روی میز است: پرسشِ جاری، پیشنهادِ معلق، موضوعِ منتظر تأیید،
  /// راهنمای باز و پروندهٔ کمکی. این وضعیت صاحبِ جدا دارد؛ پیش‌تر ۲۵ فیلد
  /// آن، کنارِ موتور و پرونده، روی خودِ همین شیء بود.
  final DialogueState dialog = DialogueState();

  /// آیا از پاسخ قبلی چیزی نگفته مانده است؟
  bool get hasMore => voice.rest.isNotEmpty;

  /// قالبی که در پاسخ قبلی پیشنهاد نوشتنش را داده‌ام (یا `null`).
  String? get offeredDraft =>
      dialog.offer == 'draft' && dialog.offerDraft.isNotEmpty
          ? dialog.offerDraft
          : null;

  /// پیشنهادِ معلق را کنار می‌گذارد (وقتی لایهٔ بالاتر خودش به آن رسید).
  void clearOffer() => dialog.clearOffer();

  /// همهٔ موضوع‌ها (فهرست در `topics/all.dart`).
  static final List<Topic> topics = allTopics;

  /// نشانه‌های اصلاحِ موضوع توسط کاربر.
  static const String _correctionPattern =
      'اصلاً? در مورد .{1,40}?صحبت نکرد|منظورم این نبود|حرفم این نبود|اشتباه (?:گرفتی|متوجه شدی|متوجه شدید)';

  /// بخشی از پیام که بعد از آخرین نشانهٔ «در مورد/بلکه/منظورم/ماجرا» می‌آید.
  static String _afterCorrection(String n) {
    final ms = RegExp(r'(?:در مورد|بلکه|منظورم|ماجرا) ').allMatches(n).toList();
    if (ms.isEmpty) return '';
    return n.substring(ms.last.end).trim();
  }

  bool get hasCase => file.topic.isNotEmpty || dialog.guide != null;

  /// شناسهٔ قالب‌های سندی که به پروندهٔ جاری می‌خورد (به ترتیب اولویت).
  List<String> get draftIds {
    final t = _current();
    if (t != null) {
      final d = t.drafts;
      final out = <String>[...?(d == null ? null : d(file))];
      for (final g in filings) {
        if (!out.contains(g.template)) out.add(g.template);
      }
      return out;
    }
    return dialog.guide?.templateIds ?? const [];
  }

  /// سندهایی که به وضعیتِ همین پرونده می‌خورد: اول دادخواست، بعد لایحه.
  /// فقط قالب‌هایی که واقعاً در برنامه هستند.
  List<Filing> get filings {
    final t = _current();
    if (t == null) return const [];
    final out = <Filing>[];
    for (final make in [t.petition, t.brief]) {
      final g = make == null ? null : make(file);
      if (g != null && _draftTitles.containsKey(g.template)) out.add(g);
    }
    return out;
  }

  /// اگر این متن دکمهٔ یکی از سندهای پیشنهادیِ همین پرونده باشد، همان را
  /// می‌دهد.
  Filing? filingFor(String raw) {
    final key = Sense.norm(raw);
    for (final g in filings) {
      if (Sense.norm(g.chip) == key) return g;
    }
    return null;
  }

  /// آیا پیام می‌گوید «همین حالا» کسی در خطر است؟
  ///
  /// این حالت به پرونده و به اینکه پیش‌تر هشدار داده‌ام یا نه گره نمی‌خورد؛
  /// هر بار که کاربر این را بگوید، پاسخ فوری می‌گیرد.


  /// متن‌های پیشنهادی برای فیلدهای یک قالب، از روی واقعیت‌های همین پرونده
  /// (شناسهٔ فیلد → متن).
  Map<String, String> fillFor(String templateId) {
    final fill = _current()?.fill;
    return fill == null ? const {} : fill(file, templateId);
  }

  void reset() {
    _closeCase();
    dialog.reset();
    _prevN = '';
    dialog.also = null;
    voice.relevantChip = '';
    voice.reset();
    file.turns = 0;
    file.disclaimed = false;
    unresolved.clear();
  }

  /// بازسازی حافظه از پیام‌های قبلی کاربر (هنگام بازکردن گفتگوی ذخیره‌شده).
  ///
  /// این راه، پرهزینه و شکننده است: هر پیام دوباره از کل خط لوله می‌گذرد،
  /// پس اگر قاعده‌ای تغییر کرده باشد پروندهٔ بازیابی‌شده با پروندهٔ اصلی یکی
  /// نیست. فقط برای گفتگوهای قدیمی که پروندهٔ ذخیره‌شده ندارند به کار
  /// می‌رود؛ گفتگوهای تازه با [restoreCase] باز می‌شوند.
  void replay(Iterable<String> userTexts) {
    reset();
    for (final t in userTexts) {
      respond(t);
    }
  }

  /// بازیابی پرونده از نسخهٔ ذخیره‌شده (JSON تاریخچه) بدون پخش دوبارهٔ پیام‌ها.
  /// ورودی نامعتبر پروندهٔ خالی می‌دهد.
  void restoreCase(Map<String, dynamic> json) {
    reset();
    file.copyFrom(CaseFile.fromJson(json));
  }

  /// آیا کاربر صریحاً خواسته متنی برایش نوشته شود؟
  static bool wantsDraft(String raw) {
    final n = Sense.norm(raw);
    return Sense.has(n,
        r'بنویس(?:ش|ید|ی)?(?![\u0600-\u06FF])|تنظیم کن|آماده کن|تهیه کن|متن[^ ]* (?:رو |را )?(?:بده|میخوام|آماده)|پیش ?نویس|نمونه[^ ]* (?:بده|میخوام)');
  }

  /// [guess] حدسِ خوانندهٔ موضوع برای همین پیام است (اگر محاسبه شده باشد)؛
  /// فقط وقتی به‌کار می‌آید که قاعده‌ها موضوع را نشناخته باشند.
  /// پاسخِ ازپیشساختهٔ موتور در isolate. فقط برای همان متن پیام معتبر است و
  /// بعد از یک نوبت پاک میشود؛ مسیرهای قدیمی/آزمونها بدون آن کار میکنند.
  EngineReply? _preparedEngineReply;
  String _preparedText = '';

  EngineReply? preparedEngineReply(String raw) =>
      _preparedText == raw ? _preparedEngineReply : null;

  AdvocateReply respond(
    String raw, {
    TopicGuess? guess,
    EngineReply? engineReply,
  }) {
    _preparedEngineReply = engineReply;
    _preparedText = raw;
    try {
      return _withLeave(_reply(raw, guess: guess));
    } finally {
      _preparedEngineReply = null;
      _preparedText = '';
    }
  }








  /// موضوعی که این پیام به‌تنهایی پرونده‌اش را باز می‌کند، یا `null`. همان
  /// قاعدهٔ بازشدن پرونده است تا پیشنهادهای هنگام نوشتن هم از همین‌جا بیاید.
  static String? topicOf(String raw) {
    final n = Sense.norm(raw);
    Topic? best;
    var bestScore = 0;
    for (final t in topics) {
      final s = _score(t, n);
      if (s > bestScore) {
        best = t;
        bestScore = s;
      }
    }
    return best != null && bestScore >= 3 ? best.id : null;
  }

  /// آیا برای این پیام حدسِ خوانندهٔ موضوع به کار می‌آید؟ محاسبهٔ حدس روی
  /// گوشی زمان می‌برد؛ فقط وقتی خواسته می‌شود که پرونده‌ای باز نیست و
  /// قاعده‌ها خودشان موضوع را نشناخته‌اند.
  bool wantsGuess(String raw) {
    if (file.topic.isNotEmpty || dialog.guide != null || dialog.choices.isNotEmpty) {
      return false;
    }
    if (raw.trim() == ChipTexts.newCaseChip) return false;
    final n = Sense.norm(raw);
    if (!_guessable(n)) return false;
    for (final t in topics) {
      if (_score(t, n) >= 3) return false;
    }
    return true;
  }

    /// خروجیِ هر پاسخ: استنادها را به نام ماده برمی‌گرداند، متن را کوتاه
  /// نگه می‌دارد (باقی‌مانده با «ادامه بده» می‌آید) و پرسشِ [ask] را در
  /// پایان می‌گذارد تا گفتگو دوطرفه بماند.
  AdvocateReply _out(
    String text, {
    List<String> chips = const [],
    String ask = '',
    bool full = false,
    int budget = _budget,
    AnswerSource source = AnswerSource.topic,
  }) =>
      voice.out(text,
          chips: chips, ask: ask, full: full, budget: budget, source: source);
  /// دکمه‌های پیشنهادی برای وضعیتِ فعلیِ گفتگو (تصمیم است، نه داده؛ برچسب‌ها
  /// در `chip_texts.dart`).
  List<String> get idleChips => _idleChips();

}
