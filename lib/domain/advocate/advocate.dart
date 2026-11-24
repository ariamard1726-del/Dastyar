import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/jalali.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/qa_bank.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/dialogue_state.dart';
import 'package:dastyar/domain/advocate/glossary.dart';
import 'package:dastyar/domain/advocate/law_terms.dart';
import 'package:dastyar/domain/advocate/phrases.dart';
import 'package:dastyar/domain/advocate/reply_voice.dart';
import 'package:dastyar/domain/advocate/reasoner.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
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
part 'advocate_argue.dart';
part 'advocate_chips.dart';
part 'advocate_meta.dart';
part 'advocate_talk.dart';
part 'advocate_guides.dart';
part 'advocate_text.dart';
part 'advocate_routes.dart';

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
  late final ReplyVoice voice =
      ReplyVoice(engine: engine, file: file, unresolved: unresolved,
          defaultBudget: _budget);

  late final LawTerms _terms = LawTerms(engine);

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

  /// موضوع دومی که کاربر در همان پیام به آن اشاره کرده است.
  Topic? _also;

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

  String _factsKey() {
    final keys = file.facts.keys.toList()..sort();
    final sb = StringBuffer(file.topic);
    for (final k in keys) {
      sb.write('|$k=${file.facts[k]}');
    }
    return sb.toString();
  }

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
  bool _asksDanger(String n) => Sense.has(n,
      'الان در خطر(?: هستم|یم)?(?! نیست)|همین حالا در خطر|در خطر فوری|هنوز در خطر|کسی در خطر');

  /// خشونت (کتک، پرت‌کردن چیزی، تهدید) در خانواده، یا گزارش تماس با اورژانس.
  /// پاسخ امنیت را می‌دهد و پرونده را نمی‌بندد.
  AdvocateReply? _safety(String n) {
    // «الان در خطر هستم» جوابِ پرسش خودِ ماست و باید سریع‌ترین راه را بدهد.
    if (_asksDanger(n)) {
      return _out(
        'اگر همین حالا کسی در خطر است، اول از محل دور شوید و ۱۱۰ یا ۱۱۵ را بگیرید. اگر درگیری خانوادگی است، اورژانس اجتماعی ۱۲۳ هم شبانه‌روزی پاسخ می‌دهد. تا وقتی امن نشده، هیچ فرایند حقوقی را شروع نکنید؛ هرچه اتفاق افتاد را با تاریخ و ساعت یادداشت کنید و اگر آسیب جسمی دارید، پیش از محو شدن اثرش به پزشکی قانونی بروید.',
        ask: 'آیا الان جای امنی هستید و کسی همراهتان است؟',
        chips: const ['الان امن هستم', 'هنوز در خطر هستم'],
        source: AnswerSource.safety,
      );
    }
    final called = Sense.has(n, 'اورژانس|۱۱۰|۱۱۵|پلیس|کلانتری|بهزیستی') &&
        Sense.has(n, 'زنگ زدم|زنگ زدیم|تماس گرفتم|خبر دادم|زنگ زده');
    final violent = Sense.has(n,
            'کتک|کفش پرت|پرت (?:می|کرد|کنه|میکنه)|چاقو|تهدید|(?:را|رو|منو|مرا|ما را|او را|بچه رو|بچه را) (?:زد|زده|زدن|میزن|می زن|میزنه|میزنن|میزند)') &&
        Sense.has(n,
            'خاله|عمه|عمو|دایی|مادر|پدر|برادر|خواهر|شوهر|زنم|همسرم|بچه|پسرم|دخترم|مادرم|پدرم|خانواده|نامادری|ناپدری');
    if (called) {
      return _out(
        'خوب کردید که زنگ زدید. اگر درگیری ادامه دارد، از جای امن دور شوید و دوباره ۱۱۰ یا ۱۱۵ را بگیرید. اگر ماجرا در خانواده است، اورژانس اجتماعی ۱۲۳ هم کمک می‌کند.',
        ask: 'الان وضعیت چطور است؟ آیا کسی هنوز در خطر است؟',
        chips: const ['الان در خطر هستم', 'الان امن است'],
        source: AnswerSource.safety,
      );
    }
    if (violent) {
      return _out(
        'این رفتار خشونت است و جدی است. اگر همین حالا کسی در خطر است، ۱۱۰ یا ۱۱۵ را بگیرید؛ اگر در خانواده است، اورژانس اجتماعی ۱۲۳ هم کمک می‌کند. وقتی امنیت برقرار شد، می‌توانیم درباره‌ی شکایت و مدارکش حرف بزنیم.',
        ask: 'الان کسی در خطر است؟',
        chips: const ['الان در خطر هستم', 'الان امن است'],
        source: AnswerSource.safety,
      );
    }
    return null;
  }

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
    _also = null;
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

  AdvocateReply _reply(String raw, {TopicGuess? guess}) {
    final n = Sense.norm(raw);
    final prevN = _prevN;
    _prevN = n;
    voice.relevantChip = Understanding.relevantChip(raw) ?? '';
    file.turns++;
    final choices = dialog.choices;
    final choiceText = dialog.choiceText;
    final guessed = dialog.guessed;
    final branchAsked = dialog.branchAsked;
    dialog.choices = const [];
    dialog.choiceText = '';
    dialog.guessed = false;
    dialog.branchAsked = false;
    if (_routeNewCase(raw) case final r?) return r;
    if (_routeNoOption(raw) case final r?) return r;
    // پاسخ به «این موضوع تازه است یا مربوط به قبلی؟». این پرسش پیش از هر
    // قاعدهٔ دیگری بررسی می‌شود؛ وگرنه «بله»/«خیر» به‌عنوان ادامهٔ پروندهٔ
    // قبلی خوانده می‌شود و پرونده عوض نمی‌شود.
    if (_routePending(raw, n) case final r?) return r;
    // پاسخ به دکمه‌های دستهٔ مشکل، درست در همان نوبتی که نشان داده شده‌اند.
    final branch = _branchReply(raw, n, asked: branchAsked);
    if (branch != null) return branch;
    // «انصراف»، «خروج از موضوع»، «نمی‌خواهم این بحث را ادامه دهم»: پرونده بسته می‌شود.
    if (Drafting.isLeave(raw)) {
      _closeCase();
      dialog.loose.clear();
      dialog.branchAsked = true;
      return _out(
        'باشد، این موضوع را کنار گذاشتم.',
        ask: 'موضوع تازه‌تان چیست؟',
        chips: Advocate.branchChips,
      );
    }
    // ایمنی، پیش از هر چیز و مستقل از امتیاز موضوع.
    //
    // پیش‌تر این بررسی فقط وقتی اجرا می‌شد که هیچ موضوعی امتیاز ۴ به بالا
    // نگرفته باشد؛ یعنی درست همان پیام‌های روشنِ خشونت (که واژه‌های طلاق یا
    // مهریه هم دارند و امتیاز بالا می‌گیرند) پیام اضطراری را از دست
    // می‌دادند. ایمنی به تشخیص موضوع گره نمی‌خورد. در هر پرونده یک بار
    // گفته می‌شود تا گفتگو در حلقه نیفتد؛ ولی اگر کاربر خودش بگوید «الان
    // در خطر هستم»، هر بار جواب فوری می‌گیرد.
    if (!dialog.safetyShown || _asksDanger(n)) {
      final safe = _safety(n);
      if (safe != null) {
        // بازکردن بی‌صدای پرونده فقط بار اول؛ تکرار «در خطر هستم» نباید
        // پرونده را دوباره باز کند.
        if (!hasCase && !dialog.safetyShown) {
          // پیامِ خشونت اغلب موضوع روشنی هم دارد («زد و می‌خوام طلاق
          // بگیرم»). پاسخِ این نوبت ایمنی است، ولی پرونده را بی‌صدا باز
          // می‌کنیم تا نوبت بعد از سرِ همان موضوع ادامه پیدا کند و کاربر
          // مجبور نشود ماجرا را دوباره بگوید.
          Topic? pick;
          var score = 0;
          for (final t in topics) {
            final sc = _score(t, n);
            if (sc > score) {
              pick = t;
              score = sc;
            }
          }
          if (pick != null && score >= 3) {
            _open(pick, n);
            // دکمه‌های داخلی با دکمه‌های ایمنیِ نمایش‌داده‌شده هم‌خوان بماند.
            dialog.askChips = safe.chips;
          } else {
            dialog.safetyCarry = n;
          }
        }
        // پس از `_open` تنظیم می‌شود، چون بازکردن پرونده پرچم‌ها را صفر
        // می‌کند.
        dialog.safetyShown = true;
        return safe;
      }
    }
    // پیام «دربارهٔ خودِ برنامه» («از برنامه خارج شدم») یا جملهٔ کوتاهِ سوگ،
    // ماجرای حقوقی نیست ولی پرسش واقعی دارد؛ پیش از «منظورتان چیست؟» و پیش
    // از حدسِ موضوع، پاسخ صریح می‌گیرد. بعد از بررسی ایمنی می‌آید تا پیام
    // خطر هرگز زیر این پاسخ نماند.
    final aside = _metaReply(raw, n);
    if (aside != null) return aside;
    if (_routeFight(n, hasCase) case final r?) return r;
    if (_routeChoice(raw, n, choices, choiceText) case final r?) return r;
    if (_routeWrongGuess(raw, n, guessed) case final r?) return r;
    final short = Sense.words(n) <= 4;
    // ادامهٔ حرفِ قبلی، وقتی کاربر خودش بخواهد.
    if (_routeMore(raw, n, short) case final r?) return r;
    // لمس دکمهٔ «تنظیم دادخواست …» یا «تنظیم لایحه …».
    final wanted = filingFor(raw);
    if (wanted != null) return _filing(wanted);
    if (_routeOffer(raw, n, short) case final r?) return r;
    if (_routeBareAck(raw, n) case final r?) return r;
    if (_routeSide(raw, n) case final r?) return r;
    final topic = _current();
    // پیامِ پیشینی که پاسخ ایمنی جایش را گرفته بود، فقط وقتی به حساب
    // می‌آید که پیام تازه خودش موضوع روشنی نداشته باشد.
    final carry = dialog.safetyCarry;
    dialog.safetyCarry = '';
    Topic? best;
    var bestScore = 0;
    final scores = <String, int>{};
    for (final t in topics) {
      final s = _score(t, n);
      scores[t.id] = s;
      if (s > bestScore) {
        best = t;
        bestScore = s;
      }
    }
    if (bestScore < 4 && carry.isNotEmpty) {
      for (final t in topics) {
        final s = _score(t, '$n $carry');
        if (s > bestScore) {
          best = t;
          bestScore = s;
        }
        scores[t.id] = s;
      }
    }

    if (_routeDeadline(raw, n, hasCase) case final r?) return r;
    // موضوع صریح (امتیاز بالا، بدون پرونده) بر پاسخ‌های کلیِ مقدم برتری دارد.
    final meta = _meta(n, topic, explicit: topic == null && bestScore >= 5);
    if (meta != null) return meta;

    if (_routeRepeat(prevN, n, hasCase) case final r?) return r;
    if (_routeFixedRules(n) case final r?) return r;
    // مهلت اعتراض یا ابلاغ: مدت به نوع رأی و مرجع بستگی دارد و متن آن در
    // بانک من نیست؛ پس بی‌پاسخ رها نمی‌کنم، راه درست را می‌گویم.
    if (!hasCase && Sense.has(n, 'مهلت') && Sense.has(n, 'اعتراض|ابلاغ')) {
      return _out(
        'مهلت اعتراض معمولاً از تاریخ ابلاغ شمرده می‌شود، ولی مدت دقیق به نوع رأی و مرجع بستگی دارد و متن آن قانون در بانک من نیست. '
        'برای همین، ابلاغ‌نامه و تاریخ دقیق آن را نگه دارید و پیش از گذشتن مهلت، با وکیل یا دفتر خدمات قضایی تأیید کنید.',
        ask: 'رأی یا تصمیمی که ابلاغ شده از کدام مرجع است؟ تاریخ ابلاغ را هم بگویید.',
        full: true,
      );
    }
    // واژهٔ مشخصِ قانونی (مهریه، ودیعه، غبن…) وقتی هیچ پرونده‌ای باز نیست
    // و موضوعی هم تشخیص داده نشده: همان مادهٔ مستند را نشان می‌دهیم.
    if (!hasCase && bestScore < 3) {
      // «قهر» و حدس مطمئنِ خوانندهٔ موضوع پیش از متن قانون می‌آیند.
      final confidentGuess = guess != null && guess.confident;
      final lt = Sense.has(n, 'قهر') || confidentGuess ? null : _lawTermsReply(raw, n);
      if (lt != null) return lt;
      final refs = Understanding.linkedArticles(n);
      if (refs.isNotEmpty) {
        return _out(
          'این واژه به ${refs.join(' ')} مربوط است.',
          ask: 'ماجرای شما دقیقاً چیست؟ چه کسی و چه کاری کرده است؟',
          full: true,
        );
      }
    }

    // «قهر» جرم نیست و کسی را به‌خاطر قهر زندانی یا جریمه نمی‌کنند. این را
    // پیش از هر موضوع می‌گوییم تا برداشت اشتباه جا نماند.
    if (Sense.has(n, 'قهر') &&
        Sense.has(n, 'زندان|حبس|بازداشت|جریمه|پلیس|دادگاه')) {
      return _out(
        'قهر کردن جرم نیست و کسی را به‌خاطر قهر زندانی یا جریمه نمی‌کنند. اگر ماجرای دعوا یا رفتار طرف مقابل نگرانتان کرده، همان را تعریف کنید.',
        ask: 'چه اتفاقی افتاده است؟',
      );
    }

    if (Sense.has(n, 'گفتگوی من با برنامه|گفتگو با برنامه|با برنامه (?:هست|است)')) {
      return _out('درست است؛ این گفتگو با خود همین برنامه است. هر ماجرایی دارید، بگویید.',
          ask: 'چه چیزی را بررسی کنیم؟');
    }

    // اصلاحِ کاربر («من اصلا در مورد طلاق صحبت نکردم، در مورد دستبرد بود»):
    // موضوعِ قبلی رها می‌شود و فقط بخشِ اصلاح‌شده سنجیده می‌شود.
    if (topic != null &&
        Sense.words(n) <= 40 &&
        Sense.has(n, _correctionPattern)) {
      final fixed = _afterCorrection(n);
      Topic? nb;
      var ns = 0;
      for (final t in topics) {
        final s = fixed.isEmpty ? 0 : _score(t, fixed);
        if (s > ns) {
          nb = t;
          ns = s;
        }
      }
      _closeCase();
      dialog.loose.clear();
      if (nb != null && ns >= 3) return _open(nb, fixed);
      return _out(
        'ببخشید، برداشتم اشتباه بود. موضوع را دوباره بفرمایید: چه اتفاقی افتاده است؟',
        ask: 'طرف مقابل کیست و دقیقاً چه کرده است؟',
        chips: _branchStart(),
      );
    }

    if (topic == null) {
      if (best != null && bestScore >= 3) {
        final others = <Topic>[
          for (final t in topics)
            if (t.id != best.id && (scores[t.id] ?? 0) >= 4) t,
        ];
        if (others.isNotEmpty) _also = others.first;
        // پیامِ چندموضوعی: پیش‌تر فقط به یکی از موضوع‌ها جواب می‌داد و بقیه
        // بی‌صدا می‌ماند. حالا موضوع‌ها را نام می‌برد و می‌پرسد از کدام شروع
        // کنیم؛ هر کدام پرونده و مهلت جدا دارد.
        final asksOrder = Sense.has(n,
            'اول کدام|کدوم را اول|کدام را اول|از کجا شروع|اول (?:چی|کدام)|چی را اول');
        if (others.isNotEmpty &&
            (asksOrder || (others.length >= 2 && Sense.words(n) >= 14))) {
          dialog.choices = <Topic>[best, ...others].take(3).toList();
          dialog.choiceText = n;
          final lines = [
            for (final t in dialog.choices) '• ${t.title}',
          ];
          return _out(
            'در این پیام چند ماجرای جدا بود:\n${lines.join('\n')}\n\n'
            'هر کدام پرونده، مهلت و مسیر خودش را دارد و یک‌جا جواب‌دادن به همه '
            'سطحی می‌شود. از کدام شروع کنیم؟',
            chips: [for (final t in dialog.choices) t.title, noneChip],
          );
        }
        return _open(best, n);
      }
      dialog.loose.add(n);
      if (dialog.loose.length > 3) dialog.loose.removeAt(0);
      // دو سه پیامِ کوتاهِ پشت‌سرهم با هم یک ماجرا هستند: اگر روی‌هم موضوع
      // را روشن کنند، همان پرونده باز می‌شود.
      if (dialog.loose.length > 1 && bestScore >= 1) {
        final joined = dialog.loose.join(' ');
        Topic? jb;
        var js = 0;
        for (final t in topics) {
          final sc = _score(t, joined);
          if (sc > js) {
            jb = t;
            js = sc;
          }
        }
        if (jb != null && js >= 3 && (scores[jb.id] ?? 0) >= 1) {
          dialog.loose.removeLast();
          return _open(jb, n);
        }
      }
      final g = _glossary(n);
      if (g != null) {
        return _out(g,
            ask: dialog.guide == null ? 'این واژه در ماجرای خودتان پیش آمده؟ چه شده است؟' : '',
            source: AnswerSource.glossary);
      }
      final guide = dialog.guide;
      if (guide != null) {
        final r = _guideFollow(guide, n);
        if (r != null) return r;
      }
      // واژه‌های پرسش را با متن قوانین می‌سنجیم: ماده‌ای که واژه‌ها را با هم
      // دارد نشان داده می‌شود، و اگر نداشت، گفته می‌شود کدام واژه‌ها در قوانین
      // هست؛ پیش از حدس‌های کلی و پرسش «کدام نزدیک‌تر است؟».
      if (guide == null && (guess == null || !guess.confident)) {
        final tf = _topicReply(raw, n);
        if (tf != null) return tf;
        final lt = _lawTermsReply(raw, n);
        if (lt != null) return lt;
      }
      // حدسِ مطمئنِ مدل بر راهنماهای آماده مقدم است: آن‌ها با یک واژه
      // انتخاب می‌شوند («حقوقم» در «بانک از حقوقم کسر می‌کند») و مدل کل
      // جمله را می‌بیند. «یک سؤال حقوقی دارم» موضوعی ندارد که حدس زده شود.
      final usable = guess != null && !_vague(n) ? guess : null;
      if (usable != null && usable.confident) {
        final r = _fromGuess(usable, raw, n, scores);
        if (r != null) return r;
      }
      // نظر دوم IntentNet پیش از راهنماهای ثابت: راهنماها با جفت واژه‌ها
      // تطبیق می‌یابند (مثلاً «حقوق» و «نداده») و «کارگاه حقوقم را نداده»
      // را به قاعدهٔ حقوق معوق می‌برند، پیش از آنکه موضوع ماجرا روشن شود.
      if (guess == null) {
        final hint = _secondOpinion(raw, n);
        if (hint != null) {
          dialog.loose.removeLast();
          // پرونده از روی نظر طبقه‌بند باز شد، پس برچسب همان است.
          final r = _open(hint, n);
          return AdvocateReply(r.text,
              chips: r.chips, laws: r.laws, source: AnswerSource.intentNet);
        }
      }
      final hopeless = _hopeless(n);
      if (hopeless != null) return hopeless;
      final lg = _matchGuide(raw, n);
      if (lg != null) return _openGuide(lg, raw, n);
      final soc = _social(n, null);
      if (soc != null) return soc;
      if (guess != null) {
        final r = usable == null || usable.confident
            ? null
            : _fromGuess(usable, raw, n, scores);
        if (r != null) return r;
      }
      if (_vague(n)) return _intake(raw);
      return _lookup(raw, n);
    }

    final cur = scores[topic.id] ?? 0;
    final issue = _matchIssue(topic, n);
    // پیامی که موضوع دیگری را با نشانهٔ روشن می‌آورد، پروندهٔ فعلی را که
    // نشانه‌اش کمتر از نصف است عوض می‌کند (به جای چسبیدن به پروندهٔ قبلی).
    final dominant = bestScore >= 5 && cur * 2 < bestScore;
    if (best != null && best.id != topic.id && (cur == 0 || dominant)) {
      // وسط یک پرونده، هر اشاره‌ای به موضوع دیگر به معنی ماجرای تازه
      // نیست (مثلاً «قولنامه داریم» در پروندهٔ اجاره). فقط وقتی می‌پرم که
      // خودِ کاربر موضوع را عوض کند یا نشانه قوی باشد؛ در حالت میانه می‌پرسم.
      final marker = Sense.has(n, _newMatter);
      final answers = _answers(topic, n);
      final long = Sense.words(n) >= 5;
      final need = marker ? 3 : (topic.id == 'accused' ? 9 : 5);
      final strong = bestScore >= need ||
          (topic.id != 'accused' && bestScore >= 4 && Sense.isQuestion(n));
      if (strong &&
          (marker || (long && !answers)) &&
          (bestScore >= 4 || issue == null)) {
        if (marker) return _open(best, n, switched: true);
        return _askSwitch(best, raw);
      }
      // متهم معمولاً ماجرای پشتِ شکایت را تعریف می‌کند (ملک، چک، …)؛ آن‌جا
      // فقط با نشانهٔ خیلی قوی می‌پرسم.
      final hint = topic.id == 'accused' ? 6 : 4;
      if (bestScore >= hint && issue == null && !answers) {
        // جملهٔ کامل دربارهٔ موضوع دیگری: به‌جای نگه‌داشتنِ بی‌صدا، اعلام
        // می‌کنیم و از خودِ کاربر می‌پرسیم؛ اشارهٔ کوتاه («قولنامه داریم»)
        // فقط کنار گذاشته می‌شود.
        if (Sense.words(n) >= 5) return _askSwitch(best, raw);
        dialog.side = best;
        dialog.sideText = raw;
      }
    }
    return _inCase(topic, raw, n, issue);
  }

  /// پیامی به موضوع دیگری اشاره دارد، بدون آنکه کاربر صریحاً بگوید موضوع تازه
  /// است. پیش از عوض‌کردن پرونده می‌پرسیم؛ تا وقتی کاربر «انصراف» نزده، از
  /// موضوع فعلی خارج نمی‌شویم.
  AdvocateReply _askSwitch(Topic t, String raw) {
    dialog.pendingTopic = t;
    dialog.pendingText = raw;
    final curTitle = _current()?.title ?? 'موضوع قبلی';
    // پرسشِ خودِ پرونده کنار می‌رود تا در این نوبت فقط یک پرسش باشد و
    // «بله/خیر» دو معنا نداشته باشد.
    file.pending = '';
    dialog.askText = '';
    dialog.askChips = const [];
    return _out(
      'به نظر می‌رسد این حرف با «$curTitle» فرق دارد و درباره‌ی «${t.title}» است. '
      'هنوز پروندهٔ قبلی باز است و چیزی را پاک نمی‌کنم.',
      ask: 'این موضوع تازه است یا به همان ماجرای قبلی مربوط است؟',
      chips: const [Advocate.newTopicYesChip, Advocate.newTopicNoChip],
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

  String _pick(List<String> options) => voice.pick(options);

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

// ---- ثابت‌ها و نشانه‌های مشترک

/// سقف طول متنِ هر پاسخ (بدون پرسشِ پایانی)؛ بقیه با «ادامه بده» می‌آید.
const int _budget = 380;

const int _roomyBudget = 760;

const List<String> _yesNo = yesNoChips;

const List<String> _replyChips = [
  'انکار می‌کند',
  'امروز و فردا می‌کند',
  'جواب نمی‌دهد',
  'هنوز چیزی نگفته‌ام',
];

const List<String> _goalChips = ['توافق و سازش', 'مسیر قانونی تا آخر'];

/// کاربر خودش گفته دنبال چیست؛ دیگر نمی‌پرسم.
const String _goalSaid =
    '(?:میخوام|میخواهم|ترجیح|دوست دارم|دنبال|بهتره|حاضرم) (?:[^ ]+ ){0,5}(?:توافق|سازش|صلح|دوستانه|مسالمت|کنار بیا)'
    '|(?:توافق|سازش|صلح)[^ ]* (?:[^ ]+ ){0,2}(?:تموم|تمام|حل) (?:بشه|شه|شود|کنیم)'
    '|(?:میخوام|میخواهم) (?:[^ ]+ ){0,3}(?:شکایت کنم|تا (?:آخر|اخر|ته)|برم دادگاه)|کوتاه نمیام';

/// کاربر خودش گفته طرف مقابل چه برخوردی داشته؛ دیگر نمی‌پرسم.
const String _replySaid =
    ' میگه | میگن | میگوید | میگویند | گفته | گفت |جواب(?:م| منو| تلفن)?(?: رو)? نمیده|بلاک|زیر بار نمیره|قبول نمیکنه|قبول نمیکند|قبول نکرد|راضی نمیشه|راضی نمیشود|انکار میکنه|حاشا|امروز و فردا|امروز فردا|قول داده|تهدید(?:م)? (?:کرد|میکنه)';

/// موضوع‌هایی که طرف مقابلِ مشخصی دارند و «او چه می‌گوید؟» معنا دارد.
const Set<String> _adversarial = {
  'rent', 'cheque', 'debt', 'labor', 'family', 'partner', 'neighbor',
  'consumer', 'guarantee', 'property', 'inherit', 'child',
};

/// نشانه‌های اینکه کاربر خودش دارد موضوع را عوض می‌کند.
const String _newMatter =
    ' راستی | در ضمن | ضمنا | (?:یه|یک) (?:مشکل|سوال|موضوع|مورد|چیز|گرفتاری) (?:دیگه|دیگر|دیگه ای|دیگری) | (?:مشکل|سوال|موضوع|مورد) (?:دیگه|دیگر) ';

const String _dontKnowChip = 'نمی‌دانم';

const Map<String, String> _followChips = {
  'next': 'قدم بعدی چیست؟',
  'evidence': 'چه مدرکی لازم است؟',
  'cost': 'هزینه‌اش چقدر است؟',
  'chance': 'شانس موفقیتم چقدر است؟',
  'time': 'چقدر طول می‌کشد؟',
};
