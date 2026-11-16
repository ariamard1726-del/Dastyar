import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/glossary.dart';
import 'package:dastyar/domain/advocate/phrases.dart';
import 'package:dastyar/domain/advocate/reasoner.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/all.dart';
import 'package:dastyar/domain/advocate/topics/shared.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/lawyer/lawyer_voice.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';
import 'package:dastyar/domain/understanding/topic_guess.dart';

part 'advocate_topic.dart';
part 'advocate_case.dart';
part 'advocate_argue.dart';
part 'advocate_chips.dart';
part 'advocate_talk.dart';
part 'advocate_guides.dart';
part 'advocate_text.dart';

/// پاسخ وکیل به یک پیام.
class AdvocateReply {
  final String text;
  final List<String> chips;
  final List<LawText> laws;
  AdvocateReply(this.text, {this.chips = const [], this.laws = const []});
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
  };

  /// کمترین اطمینانی که نظر طبقه‌بند با آن پذیرفته می‌شود.
  static const double netMin = 0.6;

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

  /// نام ادعایی که آخرین پرسشِ من برای روشن‌شدنِ آن بود.
  String _lastServed = '';

  /// حرف‌هایی که تا اینجا در گفتگو زده‌ام (برای تکرارنکردن).
  final Set<String> _said = {};

  /// پیام‌های کاربر پیش از بازشدن پرونده (حداکثر سه تای آخر).
  final List<String> _loose = [];

  LegalGuide? _guide;

  String _lastBody = '';

  String _deferred = '';

  /// موضوع دومی که کاربر در همان پیام به آن اشاره کرده است.
  Topic? _also;

  /// واقعیت‌هایی که آخرین استدلال روی آن‌ها بنا شده بود.
  String _arguedOn = '';

  /// موضوع دیگری که وسط پرونده به آن اشاره شد ولی مطمئن نیستم ماجرای
  /// جدایی باشد؛ به‌جای پریدنِ خودسرانه از کاربر می‌پرسم.
  Topic? _side;

  String _sideText = '';

  /// موضوع‌هایی که با حدسِ نامطمئنِ مدل از کاربر پرسیده‌ام «کدام؟»، و پیامی
  /// که این پرسش را پیش آورد. فقط برای پیام بعدی معتبر است.
  List<Topic> _choices = const [];

  String _choiceText = '';

  /// پروندهٔ جاری با حدسِ مدل باز شده و کاربر هنوز تأییدش نکرده است.
  bool _guessed = false;

  /// بخشی از پاسخ قبلی که برای کوتاه‌ماندنِ حرف، نگفته مانده است.
  String _rest = '';

  /// آیا در پاسخ قبلی پرسیده‌ام «ادامه‌اش را هم بگویم؟»
  bool _offeredMore = false;

  /// پیشنهادی که در پاسخ قبلی به شکل پرسش داده‌ام: `argue`، `next` یا
  /// `draft` (خالی = هیچ).
  String _offer = '';

  String _offerDraft = '';

  /// آخرین پرسشی که از کاربر کرده‌ام و گزینه‌های جوابش.
  String _askText = '';

  List<String> _askChips = const [];

  /// پاسخ بعدی توضیحی است که خودِ کاربر خواسته (استدلال، نقشهٔ راه) و جای
  /// بیشتری می‌گیرد.
  bool _roomy = false;

  /// آیا پرسشِ پایانِ راهنما هنوز بی‌جواب است؟
  bool _guideAsked = false;

  bool _guideStepped = false;

  /// همهٔ حرف‌های کاربر در پروندهٔ جاری (برای پیشنهادهای متناسب).
  String _heard = '';

  /// مواد قانونیِ آخرین پاسخی که استناد داشت (برای «متن قانون را ببینم»).
  List<LawText> _lastLaws = const [];

  static const String moreChip = 'ادامه بده';

  static const String lawChip = 'متن قانون را ببینم';

  /// آیا از پاسخ قبلی چیزی نگفته مانده است؟
  bool get hasMore => _rest.isNotEmpty;

  /// قالبی که در پاسخ قبلی پیشنهاد نوشتنش را داده‌ام (یا `null`).
  String? get offeredDraft =>
      _offer == 'draft' && _offerDraft.isNotEmpty ? _offerDraft : null;

  /// پیشنهادِ معلق را کنار می‌گذارد (وقتی لایهٔ بالاتر خودش به آن رسید).
  void clearOffer() {
    _offer = '';
    _offerDraft = '';
  }

  String _factsKey() {
    final keys = file.facts.keys.toList()..sort();
    final sb = StringBuffer(file.topic);
    for (final k in keys) {
      sb.write('|$k=${file.facts[k]}');
    }
    return sb.toString();
  }

  int _vary = 0;

  static const String newCaseChip = 'موضوع تازه‌ای دارم';

  /// پاسخ کاربر به «این ماجرای جدایی است؟».
  static const String sideChip = 'این یک موضوع جداست';

  /// پاسخ کاربر به «ماجرای شما به کدام نزدیک‌تر است؟».
  static const String noneChip = 'هیچ‌کدام';

  /// پاسخ کاربر وقتی پرونده با حدسِ مدل باز شده و حدس غلط بوده.
  static const String wrongChip = 'موضوعم این نیست';

  /// همهٔ موضوع‌ها (فهرست در `topics/all.dart`).
  static final List<Topic> topics = allTopics;

  static const List<String> starterChips = [
    'صاحبخانه پول پیشم را نمی‌دهد',
    'کارفرما اخراجم کرده',
    'چکم برگشت خورده',
    'می‌خواهم طلاق بگیرم',
  ];

  bool get hasCase => file.topic.isNotEmpty || _guide != null;

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
    return _guide?.templateIds ?? const [];
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

  /// متن‌های پیشنهادی برای فیلدهای یک قالب، از روی واقعیت‌های همین پرونده
  /// (شناسهٔ فیلد → متن).
  Map<String, String> fillFor(String templateId) {
    final fill = _current()?.fill;
    return fill == null ? const {} : fill(file, templateId);
  }

  void reset() {
    _closeCase();
    file.turns = 0;
    file.disclaimed = false;
    _said.clear();
    _loose.clear();
    unresolved.clear();
    _also = null;
    _side = null;
    _sideText = '';
    _choices = const [];
    _choiceText = '';
    _guessed = false;
    _vary = 0;
    _rest = '';
    _offeredMore = false;
    _lastLaws = const [];
  }

  /// بازسازی حافظه از پیام‌های قبلی کاربر (هنگام بازکردن گفتگوی ذخیره‌شده).
  void replay(Iterable<String> userTexts) {
    reset();
    for (final t in userTexts) {
      respond(t);
    }
  }

  /// آیا کاربر صریحاً خواسته متنی برایش نوشته شود؟
  static bool wantsDraft(String raw) {
    final n = Sense.norm(raw);
    return Sense.has(n,
        'بنویس|تنظیم کن|آماده کن|تهیه کن|متن[^ ]* (?:رو |را )?(?:بده|میخوام|آماده)|پیش ?نویس|نمونه[^ ]* (?:بده|میخوام)');
  }

  /// [guess] حدسِ خوانندهٔ موضوع برای همین پیام است (اگر محاسبه شده باشد)؛
  /// فقط وقتی به‌کار می‌آید که قاعده‌ها موضوع را نشناخته باشند.
  AdvocateReply respond(String raw, {TopicGuess? guess}) {
    final n = Sense.norm(raw);
    file.turns++;
    final choices = _choices;
    final choiceText = _choiceText;
    final guessed = _guessed;
    _choices = const [];
    _choiceText = '';
    _guessed = false;
    if (raw.trim() == newCaseChip) {
      _closeCase();
      _loose.clear();
      return _out(
        'باشد، آن موضوع را کنار می‌گذارم.',
        ask: 'ماجرای تازه چیست؟ از هر جا که راحت‌ترید شروع کنید.',
      );
    }
    // جواب به «ماجرای شما به کدام نزدیک‌تر است؟».
    if (choices.isNotEmpty) {
      for (final t in choices) {
        if (n == Sense.norm(t.title)) {
          return _open(t, Sense.norm(choiceText));
        }
      }
      if (choices.length == 1 && Sense.words(n) <= 3 && Sense.saysYes(n)) {
        return _open(choices.first, Sense.norm(choiceText));
      }
      if (raw.trim() == noneChip ||
          (Sense.words(n) <= 3 && Sense.saysNo(n))) {
        return _out(
          'باشد.',
          ask:
              'پس خودتان بگویید: چه اتفاقی افتاده و طرف مقابل کیست؟ هرچه بیشتر تعریف کنید بهتر می‌فهمم.',
          chips: _starters(),
        );
      }
    }
    // پرونده با حدس باز شده بود و کاربر می‌گوید حدس غلط است.
    if (guessed &&
        (raw.trim() == wrongChip ||
            (Sense.words(n) <= 7 &&
                Sense.has(n,
                    'موضوع(?:م)? (?:این|اون|آن|ان) نیست|اشتباه (?:گرفتی|فهمیدی|متوجه شدی)|منظورم این نبود|ربطی نداره|ربطی ندارد')))) {
      _closeCase();
      _loose.clear();
      return _out(
        'ببخشید، اشتباه برداشت کردم.',
        ask:
            'موضوع شما چیست؟ با یکی دو جمله بگویید چه شده و طرف مقابل کیست.',
        chips: _starters(),
      );
    }
    final short = Sense.words(n) <= 4;
    // ادامهٔ حرفِ قبلی، وقتی کاربر خودش بخواهد.
    final rest = _rest;
    if (rest.isNotEmpty &&
        (raw.trim() == moreChip ||
            (short &&
                Sense.has(n,
                    'ادامه|بقیه|بیشتر (?:بگو|توضیح|باز)|کامل(?:ش|ترش)? (?:بگو|کن)')) ||
            (_offeredMore && short && Sense.saysYes(n)))) {
      var ask = _askText;
      var chips = _askChips;
      final t0 = _current();
      if (ask.isEmpty && t0 != null && _cut(rest, _budget)[1].isEmpty) {
        final a = _nextAsk(t0);
        _askText = ask = a.text;
        _askChips = chips = a.chips;
      }
      return _out(rest, ask: ask, chips: chips);
    }
    if (_offeredMore && rest.isNotEmpty && short && Sense.saysNo(n)) {
      final t0 = _current();
      if (t0 != null) return _finish(t0, [_pick(Say.fine)]);
      return _out(_pick(Say.fine), ask: 'چیز دیگری هست که بخواهید بدانید؟');
    }
    // لمس دکمهٔ «تنظیم دادخواست …» یا «تنظیم لایحه …».
    final wanted = filingFor(raw);
    if (wanted != null) return _filing(wanted);
    // جواب به پیشنهادی که به شکل پرسش داده بودم.
    if (_offer.isNotEmpty && short) {
      final t0 = _current();
      final offer = _offer;
      if (t0 != null &&
          (Sense.saysYes(n) ||
              raw.trim() == moreChip ||
              Sense.has(n, '^ (?:بگو|بگید|بگویید|حتما|لطفا|ادامه) '))) {
        clearOffer();
        if (offer == 'draft') {
          return _out(
              'برای نوشتنش کافی است بگویید «بنویس»؛ چند سؤال کوتاه می‌پرسم و متن را آماده می‌کنم.');
        }
        file.turns--;
        return respond(offer == 'argue' ? 'استدلالت چیه؟' : 'قدم بعدی چیست؟');
      }
      if (t0 != null && Sense.saysNo(n)) {
        clearOffer();
        return _finish(t0, [_pick(Say.fine)]);
      }
    }
    // «باشه»، «نه» یا «ادامه بده» وقتی پرسشی روی میز نیست: گفتگو را با
    // پرسش بعدی جلو می‌برم، نه با «متوجه نشدم».
    final t1 = _current();
    if (t1 != null &&
        rest.isEmpty &&
        _offer.isEmpty &&
        file.pending.isEmpty &&
        _side == null &&
        Sense.words(n) <= 3 &&
        (raw.trim() == moreChip ||
            Sense.has(n, '^ ادامه ') ||
            Sense.saysYes(n) ||
            Sense.saysNo(n))) {
      return _finish(t1, [_pick(Say.fine)]);
    }
    // پیشنهادِ «موضوع جداست؟» فقط برای همان پیامِ بعدی معتبر است.
    final side = _side;
    final sideText = _sideText;
    _side = null;
    _sideText = '';
    if (side != null &&
        (raw.trim() == sideChip ||
            (Sense.words(n) <= 4 &&
                Sense.has(n, 'جدا(?:ست| است|گانه)|موضوع دیگه|ماجرای دیگه')))) {
      return _open(side, Sense.norm(sideText), switched: true);
    }
    final topic = _current();
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

    final meta = _meta(n, topic);
    if (meta != null) return meta;

    if (topic == null) {
      if (best != null && bestScore >= 3) {
        for (final t in topics) {
          if (t.id != best.id && (scores[t.id] ?? 0) >= 4) {
            _also = t;
            break;
          }
        }
        return _open(best, n);
      }
      _loose.add(n);
      if (_loose.length > 3) _loose.removeAt(0);
      // دو سه پیامِ کوتاهِ پشت‌سرهم با هم یک ماجرا هستند: اگر روی‌هم موضوع
      // را روشن کنند، همان پرونده باز می‌شود.
      if (_loose.length > 1 && bestScore >= 1) {
        final joined = _loose.join(' ');
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
          _loose.removeLast();
          return _open(jb, n);
        }
      }
      final g = _glossary(n);
      if (g != null) {
        return _out(g,
            ask: _guide == null ? 'این واژه در ماجرای خودتان پیش آمده؟ چه شده است؟' : '');
      }
      final guide = _guide;
      if (guide != null) {
        final r = _guideFollow(guide, n);
        if (r != null) return r;
      }
      // حدسِ مطمئنِ مدل بر راهنماهای آماده مقدم است: آن‌ها با یک واژه
      // انتخاب می‌شوند («حقوقم» در «بانک از حقوقم کسر می‌کند») و مدل کل
      // جمله را می‌بیند. «یک سؤال حقوقی دارم» موضوعی ندارد که حدس زده شود.
      final usable = guess != null && !_vague(n) ? guess : null;
      if (usable != null && usable.confident) {
        final r = _fromGuess(usable, raw, n, scores);
        if (r != null) return r;
      }
      final lg = _matchGuide(raw, n);
      if (lg != null) return _openGuide(lg, raw, n);
      final soc = _social(n, null);
      if (soc != null) return soc;
      if (guess != null) {
        final r = usable == null || usable.confident
            ? null
            : _fromGuess(usable, raw, n, scores);
        if (r != null) return r;
      } else {
        final hint = _secondOpinion(raw, n);
        if (hint != null) {
          _loose.removeLast();
          return _open(hint, n);
        }
      }
      if (_vague(n)) return _intake();
      return _lookup(raw, n);
    }

    final cur = scores[topic.id] ?? 0;
    final issue = _matchIssue(topic, n);
    if (best != null && best.id != topic.id && cur == 0) {
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
        return _open(best, n, switched: true);
      }
      // متهم معمولاً ماجرای پشتِ شکایت را تعریف می‌کند (ملک، چک، …)؛ آن‌جا
      // فقط با نشانهٔ خیلی قوی می‌پرسم.
      final hint = topic.id == 'accused' ? 6 : 4;
      if (bestScore >= hint && issue == null && !answers) {
        _side = best;
        _sideText = raw;
      }
    }
    return _inCase(topic, raw, n, issue);
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
    if (file.topic.isNotEmpty || _guide != null || _choices.isNotEmpty) {
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

  String _pick(List<String> options) {
    final v = options[_vary % options.length];
    _vary++;
    return v;
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
  }) {
    final laws = <LawText>[];
    final seen = <String>{};
    var body = text.replaceAllMapped(_refRun, (m) {
      // مواد یک قانون کنار هم می‌آیند: «مواد ۵۲۲ و ۵۱۹ قانون …».
      final byLaw = <String, List<String>>{};
      for (final r in _refOne.allMatches(m[0] ?? '')) {
        final law = r[1] ?? '';
        final rep = (r[3] ?? '').isNotEmpty;
        final art = r[2] ?? '';
        final key = '$law:$art${rep ? 'm' : ''}';
        final kind = law == 'constitution' ? 'اصل' : 'ماده';
        final c = engine.findArticle(law, '$kind $art${rep ? ' مکرر' : ''}');
        if (c == null) {
          if (!unresolved.contains(key)) unresolved.add(key);
          continue;
        }
        final num = '${Sense.fa(art)}${rep ? ' مکرر' : ''}';
        final label = '$kind $num ${c.source}';
        final nums = byLaw.putIfAbsent(c.source, () => <String>[]);
        if (!nums.contains(num)) nums.add(num);
        if (seen.add(key)) laws.add(LawText(label, c.source, c.body, ''));
      }
      if (byLaw.isEmpty) return '';
      final names = <String>[];
      byLaw.forEach((source, nums) {
        final basic = source.contains('قانون اساسی');
        final one = basic ? 'اصل' : 'ماده';
        final many = basic ? 'اصول' : 'مواد';
        names.add(nums.length == 1
            ? '$one ${nums.first} ${_shortLaw(source)}'
            : '$many ${nums.join(' و ')} ${_shortLaw(source)}');
      });
      return ' (${names.join('؛ ')})';
    });
    body = body.trim();
    _rest = '';
    _offeredMore = false;
    if (!full) {
      final cut = _cut(body, budget);
      body = cut[0];
      _rest = cut[1];
    }
    if (laws.isNotEmpty) _lastLaws = laws;
    var tail = ask;
    if (tail.isEmpty && _rest.isNotEmpty) {
      tail = _pick(Say.more);
      _offeredMore = true;
    }
    final first = laws.isNotEmpty && !file.disclaimed;
    if (first) {
      file.disclaimed = true;
      body = '$body\n\n${Say.disclaimer}';
    }
    if (tail.isNotEmpty) body = body.isEmpty ? tail : '$body\n\n$tail';
    final all = <String>[
      if (_offeredMore) ..._yesNo,
      ...chips,
      if (_rest.isNotEmpty && !_offeredMore) moreChip,
      if (laws.isNotEmpty && (first || chips.isEmpty)) lawChip,
    ];
    return AdvocateReply(body, chips: all, laws: laws);
  }
}

// ---- ثابت‌ها و نشانه‌های مشترک

/// سقف طول متنِ هر پاسخ (بدون پرسشِ پایانی)؛ بقیه با «ادامه بده» می‌آید.
const int _budget = 380;

const int _roomyBudget = 760;

const List<String> _yesNo = ['بله، بگو', 'نه، لازم نیست'];

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
