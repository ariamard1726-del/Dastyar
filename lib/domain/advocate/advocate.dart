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
part 'guide_reply.dart';
part 'advocate_text.dart';
part 'reply_routes.dart';

/// از کدام مسیر دانش، این پاسخ ساخته شد؟
///
/// این برچسب فقط برای شفافیت و آزمون است: ترتیب اولویت مسیرها در
/// [Advocate.pipelineOrder] نوشته شده و `test/advocate/answer_source_test.dart`
/// همان را می‌سنجد. متن پاسخ هیچ‌جا از مدل نمی‌آید؛ برچسب می‌گوید از کدام
/// منبعِ صریح آمده است.
enum AnswerSource {
  /// پیام اضطراری ایمنی (خشونت خانگی، تماس با اورژانس).
  safety,

  /// پروندهٔ موضوع‌ها: پرسش، استدلال، جمع‌بندی، دادخواست.
  topic,

  /// مسیر تصمیم موضوعی از `assets/brain/topics/*.json`.
  topicFlow,

  /// تطبیق واژه‌های پیام با متن قوانین (`LawTerms`).
  lawTerms,

  /// واژه‌نامهٔ اصطلاحات حقوقی.
  glossary,

  /// راهنمای ازپیش‌نوشتهٔ وکیل (`legal_guides`).
  guide,

  /// حدسِ خوانندهٔ موضوع (Noql) که پرونده را باز کرد.
  guess,

  /// نظر دوم طبقه‌بند سبک نیت (`IntentNet`).
  intentNet,

  /// بانک پرسش‌وپاسخ (`assets/qa`).
  qaBank,

  /// بازیابی BM25F از متن قوانین.
  engine,

  /// پاسخ برچسب‌نخورده؛ نباید در پاسخ‌های نهایی دیده شود.
  unknown,
}

/// پاسخ وکیل به یک پیام.
class AdvocateReply {
  final String text;
  final List<String> chips;
  final List<LawText> laws;

  /// مسیر دانشی که این پاسخ را ساخت (برای شفافیت و آزمون).
  final AnswerSource source;

  AdvocateReply(
    this.text, {
    this.chips = const [],
    this.laws = const [],
    this.source = AnswerSource.unknown,
  });
}

/// یک پرسشِ وکیل و گزینه‌های جوابش.
class _Ask {
  final String text;
  final List<String> chips;
  const _Ask(this.text, this.chips);
}

/// وکیل آفلاینِ بدون مدل زبانی.
///
/// هیچ مدل زبانی (نه آفلاین، نه آنلاین) در این مسیر نیست و هیچ جمله‌ای را
/// ماشین «تولید» نمی‌کند؛ همه‌چیز قاعده و دانش صریح است:
///  ۱. فهم: الگوهای منظم روی متن محاوره‌ای ([Sense]).
///  ۲. حافظه: پروندهٔ ماجرا با واقعیت‌هایی که کاربر گفته ([CaseFile]).
///  ۳. استدلال: هر واقعیت «اثر حقوقی» دارد و هر پرسش پاسخی که از روی
///     واقعیت‌های پرونده ساخته می‌شود ([Topic]، [Slot]، [Issue]).
///  ۴. استناد: هر ماده فقط وقتی نام برده می‌شود که متنش در بانک قوانین
///     پیدا شود (`engine.findArticle`)، و متن همان ماده نقل می‌شود.
///
/// تنها کمکِ بیرونی «نظر دوم» دربارهٔ موضوع پیام است، و فقط وقتی که
/// قاعده‌ها موضوع را نشناخته‌اند: یا حدسِ خوانندهٔ موضوع ([TopicGuess]، مدل
/// برداری Noql با یک سرِ طبقه‌بند) که همراه پیام به [respond] داده می‌شود،
/// یا در نبودِ آن طبقه‌بندِ سبکِ نیت ([IntentNet]). با حدسِ مطمئن پرونده باز
/// می‌شود و با حدسِ نامطمئن از خودِ کاربر پرسیده می‌شود. واقعیت‌ها، استدلال
/// و متن پاسخ همیشه از همین قاعده‌هاست.
class Advocate {
  Advocate(
    this.engine, {
    Map<String, String> draftTitles = const {},
    this.intentNet,
  }) : _draftTitles = draftTitles;

  /// طبقه‌بند نیت (اختیاری). بدون آن هم وکیل کامل کار می‌کند.
  final IntentNet? intentNet;

  /// برچسب‌های طبقه‌بند که موضوعِ هم‌معنا در [topics] دارند.
  static const Map<String, String> netTopics = {
    'cheque': 'cheque',
    'debt': 'debt',
    'family': 'family',
    'labor': 'labor',
    'lease': 'rent',
    'fraud_cyber': 'cyber',
  };

  /// کمترین اطمینانی که نظر طبقه‌بند با آن پذیرفته می‌شود.
  static const double netMin = 0.6;

  /// ترتیب اولویت مسیرهای دانش، همان‌طور که در [respond] اجرا می‌شود.
  ///
  /// این فهرست «قرارداد» است، نه تزئین: هر مسیر تازه باید جای خودش را در
  /// همین فهرست بگیرد و `test/advocate/answer_source_test.dart` هر پاسخ را
  /// با برچسب [AdvocateReply.source] می‌سنجد. تغییر ترتیب = تغییر رفتار،
  /// پس تغییرش باید همراه با به‌روزکردن همین فهرست و آزمون باشد.
  static const List<AnswerSource> pipelineOrder = [
    AnswerSource.safety,
    AnswerSource.topic,
    AnswerSource.lawTerms,
    AnswerSource.glossary,
    AnswerSource.guide,
    AnswerSource.topicFlow,
    AnswerSource.guess,
    AnswerSource.intentNet,
    AnswerSource.qaBank,
    AnswerSource.engine,
  ];

  /// دسته‌های خوانندهٔ موضوع → موضوع‌های هم‌معنا در [topics] به ترتیب
  /// اولویت. دسته‌های crime، general، chat و other پرونده‌ای ندارند و با
  /// آن‌ها وکیل مثل قبل رفتار می‌کند.
  static const Map<String, List<String>> guessTopics = {
    'rent': ['rent'],
    'cheque': ['cheque'],
    'debt': ['debt', 'enforce'],
    'labor': ['labor'],
    'family': ['family', 'child'],
    'accused': ['accused'],
    'injury': ['injury'],
    'neighbor': ['neighbor'],
    'consumer': ['consumer'],
    'cyber': ['cyber'],
    'inherit': ['inherit'],
    'property': ['property'],
    'company': ['company', 'partner'],
    'guarantee': ['guarantee'],
    'admin': ['admin'],
  };

  final KnowledgeEngine engine;

  /// ساختِ پاسخ‌ها: استناد، برش، سقفِ تکرارِ پرسش و چیدمان دکمه‌ها.
  /// وضعیتِ «چه گفتیم و چه پرسیدیم» این‌جاست، نه روی خودِ وکیل.
  /// پاسخ از بانک پرسش‌وپاسخ و متن قوانین.
  late final LawAnswer _lawAnswer = LawAnswer(
    engine: engine,
    voice: voice,
    party: _party,
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

  static const String moreChip = 'ادامه بده';

  static const String lawChip = 'متن قانون را ببینم';

  /// آیا از پاسخ قبلی چیزی نگفته مانده است؟
  bool get hasMore => voice.rest.isNotEmpty;

  /// قالبی که در پاسخ قبلی پیشنهاد نوشتنش را داده‌ام (یا `null`).
  String? get offeredDraft =>
      dialog.offer == 'draft' && dialog.offerDraft.isNotEmpty
          ? dialog.offerDraft
          : null;

  /// پیشنهادِ معلق را کنار می‌گذارد (وقتی لایهٔ بالاتر خودش به آن رسید).
  void clearOffer() => dialog.clearOffer();

  static const String newCaseChip = 'موضوع تازه‌ای دارم';

  /// پاسخ کاربر به «این ماجرای جدایی است؟».
  static const String sideChip = 'این یک موضوع جداست';

  /// پاسخ کاربر به «به همین ماجرای قبلی مربوط است؟».
  static const String relatedChip = 'به همین ماجرای قبلی مربوط است';

  /// پاسخ‌های پرسشِ «موضوع تازه است یا به قبلی مربوط؟» وقتی فقط همین پرسش
  /// روی میز است.
  static const String newTopicYesChip = 'بله';

  static const String newTopicNoChip = 'خیر';

  /// همان پاسخ‌ها وقتی پرسش همراهِ پرسشِ خودِ پرونده می‌آید؛ «بله/خیر» تنها
  /// با جوابِ پرسش‌های پرونده اشتباه می‌شود.
  static const String newTopicChip = 'بله، موضوع تازه است';

  static const String sameCaseChip = 'خیر، به همان ماجرا مربوط است';

  /// خروج از موضوع فقط با این دکمه (یا «انصراف» نوشته‌شده) انجام می‌شود.
  static const String leaveChip = 'انصراف';

  /// پاسخ کاربر به «ماجرای شما به کدام نزدیک‌تر است؟».
  static const String noneChip = 'هیچ‌کدام';

  /// پاسخ کاربر وقتی پرونده با حدسِ مدل باز شده و حدس غلط بوده.
  static const String wrongChip = 'موضوعم این نیست';

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

  static const List<String> starterChips = [
    'صاحبخانه پول پیشم را نمی‌دهد',
    'کارفرما اخراجم کرده',
    'چکم برگشت خورده',
    'می‌خواهم طلاق بگیرم',
  ];

  /// دکمه‌های «دستهٔ مشکل» که بعد از سلام نشان داده می‌شوند.
  ///
  /// پیش‌تر پاسخِ سلام چهار ماجرای آمادهٔ دیگران را پیشنهاد می‌داد؛ برای
  /// کاربری که تازه سلام کرده، این نمی‌گفت از کجا شروع کند. حالا اول شاخهٔ
  /// کار روشن می‌شود و بعد ماجرا پرسیده می‌شود.
  static const String civilChip = 'حقوقی';

  static const String criminalChip = 'کیفری';

  static const String adminChip = 'اداری';

  static const String unsureChip = 'نمی‌دانم';

  /// دکمهٔ خروج، همان [leaveChip] است: هم موضوعِ باز را می‌بندد، هم در آغاز
  /// گفتگو راهِ انصراف است.
  static const List<String> branchChips = [
    civilChip,
    criminalChip,
    adminChip,
    unsureChip,
    leaveChip,
  ];

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
  AdvocateReply respond(String raw, {TopicGuess? guess}) =>
      _withLeave(_reply(raw, guess: guess));

  /// «انصراف» آخرین دکمهٔ **هر** پاسخ است، در هر مرحله‌ای از گفتگو؛ وگرنه
  /// کاربر از وسط ماجرا راه خروج ندارد (بعضی مسیرها مثل جست‌وجوی متن قانون،
  /// پاسخ را مستقیم می‌سازند و از [_out] نمی‌گذرند).
  AdvocateReply _withLeave(AdvocateReply r) {
    if (r.chips.isNotEmpty && r.chips.last == leaveChip) return r;
    return AdvocateReply(
      r.text,
      chips: [...r.chips.where((c) => c != leaveChip), leaveChip],
      laws: r.laws,
      source: r.source,
    );
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
    if (raw.trim() == newCaseChip) return false;
    final n = Sense.norm(raw);
    if (!_guessable(n)) return false;
    for (final t in topics) {
      if (_score(t, n) >= 3) return false;
    }
    return true;
  }

  /// دکمه‌های پیشنهادی برای وضعیت فعلی گفتگو.
  List<String> get idleChips => _idleChips();

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
}
