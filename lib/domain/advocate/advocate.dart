import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/glossary.dart';
import 'package:dastyar/domain/advocate/phrases.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics_life.dart';
import 'package:dastyar/domain/advocate/topics_money.dart';
import 'package:dastyar/domain/advocate/topics_extra.dart';
import 'package:dastyar/domain/advocate/topics_more.dart';
import 'package:dastyar/domain/advocate/topics_other.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/lawyer/lawyer_voice.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';

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
/// تنها کمکِ بیرونی، طبقه‌بندِ سبکِ نیت ([IntentNet]، یک فایل JSON کوچک) است
/// و آن هم فقط «نظر دوم» می‌دهد: وقتی قاعده‌ها موضوع پیام را نشناخته‌اند،
/// اگر طبقه‌بند با اطمینان بالا یکی از موضوع‌های شناخته‌شده را بگوید، همان
/// پرونده باز می‌شود. متن پاسخ همیشه از همین قاعده‌هاست.
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

  final KnowledgeEngine engine;

  /// شناسهٔ قالب سند → عنوان آن (برای دکمهٔ «تهیهٔ متن»).
  final Map<String, String> _draftTitles;

  final CaseFile file = CaseFile();

  /// استنادهایی که متنشان در بانک پیدا نشد (برای آزمون؛ باید خالی بماند).
  final List<String> unresolved = [];

  /// واقعیت‌هایی که کاربر در همین پیام دوباره گفت (بدون تغییر مقدار).
  final List<Slot> _echo = [];

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

  /// سقف طول متنِ هر پاسخ (بدون پرسشِ پایانی)؛ بقیه با «ادامه بده» می‌آید.
  static const int _budget = 380;
  static const int _roomyBudget = 760;

  static const String moreChip = 'ادامه بده';
  static const String lawChip = 'متن قانون را ببینم';
  static const List<String> _yesNo = ['بله، بگو', 'نه، لازم نیست'];
  static const List<String> _replyChips = [
    'انکار می‌کند',
    'امروز و فردا می‌کند',
    'جواب نمی‌دهد',
    'هنوز چیزی نگفته‌ام',
  ];
  static const List<String> _goalChips = ['توافق و سازش', 'مسیر قانونی تا آخر'];

  /// کاربر خودش گفته دنبال چیست؛ دیگر نمی‌پرسم.
  static const String _goalSaid =
      '(?:میخوام|میخواهم|ترجیح|دوست دارم|دنبال|بهتره|حاضرم) (?:[^ ]+ ){0,5}(?:توافق|سازش|صلح|دوستانه|مسالمت|کنار بیا)'
      '|(?:توافق|سازش|صلح)[^ ]* (?:[^ ]+ ){0,2}(?:تموم|تمام|حل) (?:بشه|شه|شود|کنیم)'
      '|(?:میخوام|میخواهم) (?:[^ ]+ ){0,3}(?:شکایت کنم|تا (?:آخر|اخر|ته)|برم دادگاه)|کوتاه نمیام';

  /// کاربر خودش گفته طرف مقابل چه برخوردی داشته؛ دیگر نمی‌پرسم.
  static const String _replySaid =
      ' میگه | میگن | گفته | گفت |جواب(?:م| منو| تلفن)?(?: رو)? نمیده|بلاک|زیر بار نمیره|انکار میکنه|حاشا|امروز و فردا|امروز فردا|قول داده|تهدید(?:م)? (?:کرد|میکنه)';

  /// موضوع‌هایی که طرف مقابلِ مشخصی دارند و «او چه می‌گوید؟» معنا دارد.
  static const Set<String> _adversarial = {
    'rent', 'cheque', 'debt', 'labor', 'family', 'partner', 'neighbor',
    'consumer', 'guarantee', 'property', 'inherit', 'child',
  };

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

  /// نشانه‌های اینکه کاربر خودش دارد موضوع را عوض می‌کند.
  static const String _newMatter =
      ' راستی | در ضمن | ضمنا | (?:یه|یک) (?:مشکل|سوال|موضوع|مورد|چیز|گرفتاری) (?:دیگه|دیگر|دیگه ای|دیگری) | (?:مشکل|سوال|موضوع|مورد) (?:دیگه|دیگر) ';

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
  static const String _dontKnowChip = 'نمی‌دانم';

  static final List<Topic> topics = [
    accusedTopic,
    familyTopic,
    laborTopic,
    chequeTopic,
    rentTopic,
    partnerTopic,
    debtTopic,
    neighborTopic,
    adminTopic,
    propertyTopic,
    inheritTopic,
    consumerTopic,
    cyberTopic,
    injuryTopic,
    enforceTopic,
    guaranteeTopic,
    companyTopic,
    childTopic,
    marriageTopic,
  ];

  static const List<String> starterChips = [
    'صاحبخانه پول پیشم را نمی‌دهد',
    'کارفرما اخراجم کرده',
    'چکم برگشت خورده',
    'می‌خواهم طلاق بگیرم',
  ];

  static const Map<String, String> _followChips = {
    'next': 'قدم بعدی چیست؟',
    'evidence': 'چه مدرکی لازم است؟',
    'cost': 'هزینه‌اش چقدر است؟',
    'chance': 'شانس موفقیتم چقدر است؟',
    'time': 'چقدر طول می‌کشد؟',
  };

  bool get hasCase => file.topic.isNotEmpty || _guide != null;

  /// شناسهٔ قالب‌های سندی که به پروندهٔ جاری می‌خورد (به ترتیب اولویت).
  List<String> get draftIds {
    final t = _current();
    if (t != null) {
      final d = t.drafts;
      return d == null ? const [] : d(file);
    }
    return _guide?.templateIds ?? const [];
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

  // ------------------------------------------------------------- ورودی اصلی

  AdvocateReply respond(String raw) {
    final n = Sense.norm(raw);
    file.turns++;
    if (raw.trim() == newCaseChip) {
      _closeCase();
      _loose.clear();
      return _out(
        'باشد، آن موضوع را کنار می‌گذارم.',
        ask: 'ماجرای تازه چیست؟ از هر جا که راحت‌ترید شروع کنید.',
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
      final lg = _matchGuide(raw, n);
      if (lg != null) return _openGuide(lg, raw, n);
      final soc = _social(n, null);
      if (soc != null) return soc;
      final hint = _secondOpinion(raw, n);
      if (hint != null) {
        _loose.removeLast();
        return _open(hint, n);
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

  // ---------------------------------------------------------------- موضوع

  Topic? _current() {
    for (final t in topics) {
      if (t.id == file.topic) return t;
    }
    return null;
  }

  /// آیا این پیام جوابِ همان پرسشی است که منتظرش بودم؟
  bool _answers(Topic t, String n) {
    if (file.pending.isEmpty) return false;
    for (final s in t.slots) {
      if (s.id != file.pending) continue;
      if (s.read(n) != null) return true;
      final rp = s.readPending;
      if (rp != null && rp(n) != null) return true;
    }
    return Sense.words(n) <= 5 &&
        (Sense.saysYes(n) || Sense.saysNo(n) || Sense.saysDontKnow(n));
  }

  /// یادآوریِ موضوعِ دیگری که کاربر وسط پرونده به آن اشاره کرد.
  String _sideNote() {
    final s = _side;
    if (s == null) return '';
    return 'به «${s.title}» هم اشاره کردید. این ماجرای جداگانه‌ای است، یا به همین پرونده مربوط می‌شود؟';
  }

  /// امتیاز یک موضوع برای متنِ نرمال‌شده: جمع وزن نشانه‌هایی که در متن هست.
  static int _score(Topic t, String n) {
    if (t.anti.isNotEmpty && Sense.has(n, t.anti)) return 0;
    var s = 0;
    for (final e in t.cues.entries) {
      if (Sense.has(n, e.key)) s += e.value;
    }
    return s;
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

  /// نظر دوم از طبقه‌بند نیت، وقتی قاعده‌ها موضوع را نشناخته‌اند.
  Topic? _secondOpinion(String raw, String n) {
    final net = intentNet;
    if (net == null || _guide != null || Sense.words(n) < 3) return null;
    if (Sense.has(n, '(?:ماده|اصل) [0-9]+')) return null;
    final top = net.classify(raw);
    if (top.score < netMin) return null;
    final id = netTopics[top.label];
    if (id == null) return null;
    for (final t in topics) {
      if (t.id != id) continue;
      if (t.anti.isNotEmpty && Sense.has(n, t.anti)) return null;
      return t;
    }
    return null;
  }

  Issue? _matchIssue(Topic t, String n) {
    for (final i in t.issues) {
      final w = i.when;
      if (w != null && !w(file)) continue;
      if (Sense.has(n, i.cues)) return i;
    }
    return null;
  }

  /// راهنمای آماده برای پیام؛ واژهٔ تک‌افتاده‌ای مثل «صیادیه» نباید به
  /// «دیه» بخورد.
  LegalGuide? _matchGuide(String raw, String n) {
    if (Sense.has(n, 'صیاد')) return null;
    return LawyerVoice.matchGuide(raw);
  }

  void _closeCase() {
    file.clearCase();
    _guide = null;
    _lastBody = '';
    _deferred = '';
    _arguedOn = '';
    _heard = '';
    _askText = '';
    _askChips = const [];
    _guideAsked = false;
    clearOffer();
  }

  /// واقعیت‌های تازهٔ پیام را در پرونده می‌نشاند و فهرست تغییرها را می‌دهد.
  ///
  /// [live] یعنی این همان پیامی است که کاربر الان فرستاده (نه مرور پیام‌های
  /// قبلی)؛ فقط در این حالت جوابِ کوتاه به پرسشِ معلق تفسیر می‌شود.
  List<Slot> _absorb(Topic t, String n, {bool live = true}) {
    final out = <Slot>[];
    if (live) _echo.clear();
    final unsure = Sense.saysDontKnow(n);
    final hedged = unsure && Sense.has(n, ' یا نه |شاید|مطمئن نیستم');
    final reads = <String, String?>{for (final s in t.slots) s.id: s.read(n)};
    // «آره مدتش تموم شده»: بله‌ای که پشتش واقعیتِ بله/نه‌ایِ دیگری آمده،
    // جوابِ همان واقعیت است نه پرسشِ معلق.
    var otherBool = false;
    var otherAny = false;
    for (final e in reads.entries) {
      if (e.key == file.pending || e.value == null) continue;
      otherAny = true;
      if (e.value == 'yes' || e.value == 'no') otherBool = true;
    }
    for (final s in t.slots) {
      var v = reads[s.id];
      if (v != null && hedged && (v == 'yes' || v == 'no')) v = '?';
      if (live && v == null && s.id == file.pending) {
        final rp = s.readPending;
        final r = rp == null ? null : rp(n);
        if (r != null && !(otherBool && (r == 'yes' || r == 'no'))) v = r;
        if (v == null) {
          if (unsure) {
            if (!otherAny) v = '?';
          } else if (!otherBool) {
            if (Sense.saysYes(n) && s.yesValue.isNotEmpty) {
              v = s.yesValue;
            } else if (Sense.saysNo(n) && s.noValue.isNotEmpty) {
              v = s.noValue;
            }
          }
        }
      }
      if (v == null) continue;
      if (v == file.facts[s.id]) {
        if (live && v != '?') _echo.add(s);
        continue;
      }
      if (v == '?' && file.has(s.id)) continue;
      file.facts[s.id] = v;
      if (v != '?') out.add(s);
    }
    return out;
  }

  bool _roleUnknown(Topic t) {
    for (final s in t.slots) {
      if (s.id == 'role') return !file.has('role');
    }
    return false;
  }

  AdvocateReply _open(Topic t, String n, {bool switched = false}) {
    final earlier = switched ? const <String>[] : List<String>.of(_loose);
    _loose.clear();
    _closeCase();
    file.topic = t.id;
    // حرف‌هایی که پیش از بازشدن پرونده زده شده هم جزو ماجراست.
    for (final old in earlier) {
      _absorb(t, old, live: false);
    }
    final news = _absorb(t, n);
    _heard = '${earlier.join(' ')} $n';
    if (Sense.has(_heard, _replySaid)) file.covered.add('q:reply');
    if (Sense.has(_heard, _goalSaid)) file.covered.add('q:goal');
    final parts = <String>[];
    // اول نشان می‌دهم حرف کاربر را چطور فهمیده‌ام؛ اگر اشتباه گرفته باشم
    // همان‌جا می‌تواند اصلاحم کند.
    final got = _recap(t);
    if (got.isNotEmpty) {
      parts.add('${_pick(Say.understood)} ${_join(got)}.');
    }
    final open = t.opening(file);
    final issue = _matchIssue(t, n);
    var answered = false;
    if (issue != null) {
      if (_roleUnknown(t)) {
        _deferred = issue.id;
      } else {
        // کاربر پرسش مشخصی دارد: اول جواب همان را می‌دهم، نه مقدمهٔ کلی.
        final b = issue.body(file);
        parts.add(b);
        file.covered.add(issue.id);
        _said.add(b);
        _lastBody = b;
        answered = true;
      }
    }
    if (!answered && open.isNotEmpty) parts.add(open);
    _addEffects(parts, news, 1,
        skip: _deferred.isEmpty && issue != null ? issue.covers : const {});
    _noteAmount(parts, news, n);
    if (_lastBody.isEmpty) {
      // «ساده‌تر بگو» باید سراغ حرف قانون برود، نه بازگویی ماجرا.
      if (open.isNotEmpty) {
        _lastBody = open;
      } else if (parts.isNotEmpty) {
        _lastBody = parts.first;
      }
    }
    var lead = '';
    if (switched) {
      lead = _pick(Say.switched);
    } else if (LawyerVoice.expressesDistress(n) ||
        Sense.has(n, 'کتک|میزنه| زد|اخراج|تهدید|بیچاره|بدبخت|نگران|میترسم|استرس')) {
      lead = _pick(Say.empathy);
    }
    final also = _also;
    _also = null;
    if (also != null && also.id != t.id) {
      parts.add(
          'به موضوع «${also.title}» هم اشاره کردید. آن پروندهٔ جدایی است؛ اول همین را روشن می‌کنیم و بعد، هر وقت گفتید، سراغ آن می‌رویم.');
    }
    return _finish(t, parts, lead: lead);
  }

  /// اثر حقوقیِ واقعیت‌های تازه را اضافه می‌کند؛ حرفی که قبلاً زده شده
  /// تکرار نمی‌شود.
  void _addEffects(List<String> parts, List<Slot> news, int max,
      {Set<String> skip = const {}}) {
    var added = 0;
    for (final s in news) {
      if (skip.contains(s.id)) continue;
      final fx = s.effect;
      if (fx == null) continue;
      final e = fx(file);
      if (e.isEmpty || parts.contains(e) || _said.contains(e)) continue;
      parts.add(e);
      _said.add(e);
      added++;
      if (added >= max) break;
    }
  }

  /// اگر مبلغ بدون واحد گفته شده («۳۰ تومن»)، برداشت خودم را شفاف می‌گویم.
  void _noteAmount(List<String> parts, List<Slot> news, String n) {
    if (Sense.amountIsExplicit(n)) return;
    for (final s in news) {
      if (s.id != 'amount' && s.id != 'salary') continue;
      final v = file.n(s.id);
      if (v == null) continue;
      parts.add(
          'رقم را «${Sense.toman(v)}» فهمیدم؛ اگر منظورتان چیز دیگری بود، با واحدش بنویسید (مثلاً «۳۰ میلیون» یا «۵۰۰ هزار»).');
      return;
    }
  }

  AdvocateReply _inCase(Topic t, String raw, String n, Issue? issue) {
    final wasPending = file.pending;
    final news = _absorb(t, n);
    _heard = '$_heard $n';
    // آنچه کاربر خودش گفته، دوباره پرسیده نمی‌شود.
    final heardGoal = wasPending != 'q:goal' &&
        !file.covered.contains('q:goal') &&
        Sense.has(n, _goalSaid);
    if (heardGoal) file.covered.add('q:goal');
    if (wasPending != 'q:reply' &&
        (Sense.has(n, _replySaid) ||
            news.any((s) =>
                file.has(s.id) && s.options.any((o) => o.contains('انکار'))))) {
      file.covered.add('q:reply');
    }
    final parts = <String>[];
    var understood = news.isNotEmpty || file.touched(file.pending);
    var asked = issue;
    if (asked == null && _deferred.isNotEmpty && !_roleUnknown(t)) {
      for (final i in t.issues) {
        if (i.id == _deferred) asked = i;
      }
      _deferred = '';
    }
    // اگر همین بحث قبلاً باز شده و کاربر حالا فقط یک واقعیت تازه می‌دهد
    // (نه پرسش)، کل توضیح تکرار نمی‌شود؛ فقط اثرِ همان واقعیت گفته می‌شود.
    final onlyFact = asked != null &&
        file.covered.contains(asked.id) &&
        !Sense.isQuestion(n) &&
        news.any((s) => s.effect != null && s.effect!(file).isNotEmpty);
    if (asked != null && !onlyFact) {
      final b = asked.body(file);
      parts.add(b);
      file.covered.add(asked.id);
      _said.add(b);
      _lastBody = b;
      understood = true;
    } else if (onlyFact) {
      understood = true;
    } else {
      final g = _glossary(n);
      if (g != null) {
        parts.add(g);
        understood = true;
      } else {
        final kind = Sense.followKind(n);
        // استدلالی که با همین واقعیت‌ها گفته شده برای «شانسم چقدر است؟»
        // تکرار نمی‌شود؛ با «استدلالت چیه؟» یا واقعیت تازه دوباره می‌آید.
        final stale = kind == 'chance' && _arguedOn == _factsKey();
        final arg =
            (kind == 'argue' || kind == 'chance') && !stale ? _argue(t) : null;
        final fb = kind.isEmpty
            ? null
            : (t.follow[kind == 'argue' ? 'chance' : kind] ?? _generic(kind));
        if (arg != null) {
          parts.add(arg);
          _roomy = true;
          _arguedOn = _factsKey();
          file.covered.add('f:argue');
          file.covered.add('f:chance');
          _said.add(arg);
          _lastBody = arg;
          understood = true;
        } else if (fb != null) {
          final b = fb(file);
          parts.add(b);
          _roomy = kind == 'next';
          file.covered.add('f:$kind');
          _said.add(b);
          _lastBody = b;
          understood = true;
        }
      }
    }
    // جوابِ پرسشِ بازِ خودم (طرف چه گفته؟ دنبال چه هستید؟) را بی‌واکنش
    // نمی‌گذارم.
    if (wasPending.startsWith('q:') && parts.isEmpty) {
      if (news.isEmpty) {
        final soc = _social(n, t);
        if (soc != null) return soc;
      }
      parts.add(_react(heardGoal ? 'q:goal' : wasPending, n));
      understood = true;
    } else if (heardGoal && parts.isEmpty) {
      parts.add(_react('q:goal', n));
      understood = true;
    }
    _addEffects(parts, news, 2,
        skip: asked == null || onlyFact ? const {} : asked.covers);
    if (onlyFact && parts.isEmpty) {
      final b = asked.body(file);
      parts.add(b);
      _lastBody = b;
    }
    _noteAmount(parts, news, n);
    if (!understood && _echo.isNotEmpty) {
      parts.add(_pick(Say.known));
      understood = true;
    }
    if (!understood) {
      final soc = _social(n, t);
      if (soc != null) return soc;
      final ask = _sideNote();
      if (ask.isEmpty && Sense.words(n) >= 3) {
        final lg = _matchGuide(raw, n);
        if (lg != null) {
          if (_askText.isEmpty) return _openGuide(lg, raw, n, switched: true);
          // وسطِ پرونده، حرفِ تازه را کوتاه جواب می‌دهم و رشتهٔ گفتگو را
          // نگه می‌دارم.
          return _out(
            '${_relevant(lg.answer, n)}\n\nاین می‌تواند پیگیری جداگانه‌ای داشته باشد؛ هر وقت خواستید سراغش می‌رویم.',
            ask: 'برگردیم سر پروندهٔ خودمان: $_askText',
            chips: _askChips,
            full: true,
          );
        }
      }
      if (ask.isEmpty && Sense.has(n, 'ماده [0-9]+|قانون ')) {
        return _lookup(raw, n);
      }
      file.pending = '';
      clearOffer();
      _askText = '';
      _askChips = const [];
      return _out(
        parts.join('\n\n'),
        ask: ask.isEmpty ? _pick(Say.lost) : ask,
        chips: [if (ask.isNotEmpty) sideChip, ..._suggest(t)],
      );
    }
    if (parts.isEmpty) parts.add(_pick(Say.fine));
    // اگر حرف کاربر را در همین پرونده فهمیده‌ام، فقط برای پیام‌های بلند
    // می‌پرسم که آیا ماجرای جدایی هم هست؛ وگرنه مزاحم گفتگو می‌شود.
    final note = _sideNote();
    if (note.isNotEmpty && Sense.words(n) >= 5) {
      parts.add(note);
    } else {
      _side = null;
      _sideText = '';
    }
    return _finish(t, parts);
  }

  Body? _generic(String kind) {
    switch (kind) {
      case 'lawyer':
        return (f) => anyLawyer;
      case 'cost':
        return (f) => moneyCost;
      default:
        return null;
    }
  }

  Slot? _nextSlot(Topic t) {
    for (final s in t.slots) {
      if (s.ask.isEmpty || file.touched(s.id)) continue;
      final w = s.when;
      if (w != null && !w(file)) continue;
      if ((file.askCount[s.id] ?? 0) >= 2) continue;
      return s;
    }
    return null;
  }

  /// پرسش بعدیِ من در این پرونده. اول واقعیت‌هایی که تحلیل به آن‌ها بسته
  /// است؛ بعد کنجکاوی دربارهٔ برخورد طرف مقابل و خواستهٔ خودِ کاربر؛ و در
  /// آخر پیشنهادِ تحلیل، نقشهٔ راه و نوشتن متن — هر کدام به شکل یک پرسش، تا
  /// تصمیمش با کاربر باشد.
  _Ask _nextAsk(Topic t) {
    clearOffer();
    final q = _nextSlot(t);
    if (q != null) {
      final c = file.askCount[q.id] ?? 0;
      file.askCount[q.id] = c + 1;
      file.pending = q.id;
      return _Ask(c == 0 ? q.ask : '${_pick(Say.askAgain)} ${q.ask}', q.options);
    }
    file.pending = '';
    if (_adversarial.contains(t.id) && file.covered.add('q:reply')) {
      file.pending = 'q:reply';
      return _Ask(_pick(Say.askReply), _replyChips);
    }
    if (file.covered.add('q:goal')) {
      file.pending = 'q:goal';
      return _Ask(_pick(Say.askGoal), _goalChips);
    }
    final claim = _claim(t);
    if (claim != null &&
        claim.elements.isNotEmpty &&
        !file.covered.contains('f:argue') &&
        file.covered.add('o:argue')) {
      _offer = 'argue';
      return const _Ask(
          'می‌خواهید بگویم از نظر قانون دست شما چقدر پر است؟', _yesNo);
    }
    if (t.follow['next'] != null &&
        !file.covered.contains('f:next') &&
        file.covered.add('o:next')) {
      _offer = 'next';
      return const _Ask('قدم‌های عملی را به ترتیب بگویم؟', _yesNo);
    }
    if (!file.covered.contains('o:draft')) {
      for (final id in draftIds) {
        final title = _draftTitles[id];
        if (title == null) continue;
        file.covered.add('o:draft');
        _offer = 'draft';
        _offerDraft = id;
        return _Ask('می‌خواهید «$title» را با همین اطلاعات برایتان بنویسم؟',
            const ['بله، بنویس', 'نه، لازم نیست']);
      }
    }
    return const _Ask('', []);
  }

  /// واکنش به جوابِ پرسش‌های باز.
  String _react(String id, String n) {
    if (id == 'q:reply') {
      if (Sense.has(n,
          'جواب ن|تلفن|بلاک|غیب|گم و گور|در دسترس|پیداش|خاموش|فرار|رفته')) {
        return 'پس عملاً در دسترس نیست. نگران این نباشید؛ ابلاغ رسمی برای همین وقت‌هاست و غیبت او جلوی کار شما را نمی‌گیرد.';
      }
      if (Sense.has(n,
          'انکار|قبول ن|زیر بار|حاشا|گردن ن|نمیدم|نمیده |نمیدهد|دروغ|منکر')) {
        return 'پس زیر بار نمی‌رود؛ یعنی با حرف حل نمی‌شود و همه‌چیز به مدرک شما برمی‌گردد.';
      }
      if (Sense.has(n,
          'امروز و فردا|امروز فردا|قول|میدم|میده |میدهد|صبر|وقت بده|مهلت|ندارم|نداره|دستم خالی|وضعم')) {
        return 'پس اصل حرف شما را رد نمی‌کند و فقط عقب می‌اندازد. این به نفع شماست: هر پیام یا قولی که داده نگه دارید، چون نشان می‌دهد خودش هم حق شما را قبول دارد.';
      }
      if (Sense.has(n, 'تهدید|فحش|فحاشی|دعوا|داد و بیداد|کتک|توهین')) {
        return 'این برخورد را جدی بگیرید و هر پیام یا صدایی که دارید نگه دارید؛ خودش می‌تواند موضوع شکایت جداگانه باشد.';
      }
      if (Sense.has(n,
          'هیچی|چیزی نگفت|حرف نزد|نگفتم|نگفته ام|هنوز ن|خبر نداره|نپرسیدم')) {
        return 'پس هنوز رسماً از او نخواسته‌اید. معمولاً قدم اول همین است که خواسته‌تان را طوری به او برسانید که بعداً قابل اثبات باشد.';
      }
      return 'خوب شد گفتید؛ این را کنار بقیهٔ ماجرا یادداشت کردم.';
    }
    if (Sense.has(n,
        'توافق|سازش|صلح|دوستانه|مسالمت|کنار بیا|زود|بی دردسر|آبرو|کدخدامنشی')) {
      return 'پس اول راهِ توافق را امتحان می‌کنیم: خواسته‌تان را رسمی ولی محترمانه اعلام می‌کنید و مهلت می‌دهید. اگر جواب نداد، مسیر قانونی سر جایش است.';
    }
    if (Sense.has(n,
        'قانونی|شکایت|دادگاه|تا آخر|تا اخر|تا ته|حقمو|حقم|کوتاه نمیام|محکوم')) {
      return 'پس مسیر رسمی را می‌رویم؛ از همین حالا باید مدرک‌ها را مرتب کنیم.';
    }
    return 'متوجه شدم؛ همین را هدف می‌گیرم.';
  }

  AdvocateReply _finish(Topic t, List<String> parts, {String lead = ''}) {
    var body = parts.join('\n\n');
    if (lead.isNotEmpty) body = body.isEmpty ? lead : '$lead\n\n$body';
    _said.addAll(parts);
    final a = _nextAsk(t);
    _askText = a.text;
    _askChips = a.chips;
    final chips = <String>[...a.chips];
    if (a.text.isEmpty) {
      // دیگر پرسشی ندارم؛ در را باز می‌گذارم.
      if (parts.length <= 1 && body.length < 40) {
        body =
            '$body هر وقت سؤال دیگری داشتید یا اتفاق تازه‌ای افتاد، همین‌جا بگویید.';
      }
      chips.addAll(_suggest(t));
    } else if (chips.isEmpty) {
      chips.addAll(_suggest(t).take(2));
    }
    if (_side != null) chips.insert(0, sideChip);
    final roomy = _roomy;
    _roomy = false;
    return _out(body,
        chips: chips, ask: a.text, budget: roomy ? _roomyBudget : _budget);
  }

  /// برداشت وکیل از واقعیت‌هایی که تا اینجا شنیده است.
  List<String> _recap(Topic t) {
    final r = t.recap;
    if (r == null) return const [];
    return [
      for (final x in r(file))
        if (x.trim().isNotEmpty) x.trim(),
    ];
  }

  static String _join(List<String> items) {
    if (items.isEmpty) return '';
    if (items.length == 1) return items.first;
    return '${items.sublist(0, items.length - 1).join('، ')} و ${items.last}';
  }

  static const List<String> _ords = ['اول', 'دوم', 'سوم', 'چهارم', 'پنجم', 'ششم'];
  static const List<String> _counts = ['یک', 'دو', 'سه', 'چهار', 'پنج', 'شش'];

  static String _ord(int k) =>
      k >= 1 && k <= _ords.length ? _ords[k - 1] : Sense.fa(k);

  static String _count(int k) =>
      k >= 1 && k <= _counts.length ? _counts[k - 1] : Sense.fa(k);

  /// ادعایی که به وضعیت فعلی پرونده می‌خورد.
  Claim? _claim(Topic t) {
    for (final c in t.claims) {
      final w = c.when;
      if (w == null || w(file)) return c;
    }
    return null;
  }

  /// استدلال: شرط‌های قانونیِ یک ادعا را یکی‌یکی روی واقعیت‌های همین
  /// پرونده می‌سنجد و از جمع آن‌ها نتیجه می‌گیرد. متن ازپیش‌نوشته نیست؛ با
  /// عوض‌شدن هر واقعیت، استدلال و نتیجه هم عوض می‌شود.
  String? _argue(Topic t) {
    final c = _claim(t);
    if (c == null || c.elements.isEmpty) return null;
    final total = c.elements.length;
    final sb = StringBuffer('${_pick(Say.argue)}\n');
    sb.write(total == 1
        ? 'هدف: ${c.goal}. برای رسیدن به آن، قانون یک شرط دارد:\n'
        : 'هدف: ${c.goal}. برای رسیدن به آن، قانون ${_count(total)} شرط دارد:\n');
    var ok = 0;
    final failed = <int>[];
    final open = <int>[];
    for (var i = 0; i < total; i++) {
      final e = c.elements[i];
      final v = e.test(file);
      final String mark;
      if (v == true) {
        ok++;
        mark = '✓ ${_pick(Say.holds)}.';
      } else if (v == false) {
        failed.add(i + 1);
        mark = '✗ ${_pick(Say.fails)}.${e.ifNo.isEmpty ? '' : ' ${e.ifNo}'}';
      } else {
        open.add(i + 1);
        mark = '؟ ${_pick(Say.unknown)}.';
      }
      sb.write('• شرط ${_ord(i + 1)}: ${e.text}\n   $mark\n');
    }
    if (failed.isEmpty && open.isEmpty) {
      sb.write(
          '${total == 1 ? 'نتیجه: این شرط برقرار است' : 'نتیجه: هر ${_count(total)} شرط جمع است'}؛ پس ${c.win(file)}\n'
          'ارزیابی من: پروندهٔ قوی‌ای دارید، به شرط اینکه همین‌ها را با مدرک نشان بدهید.');
    } else if (failed.isNotEmpty) {
      sb.write(
          'نتیجه: چون شرط ${_join([for (final k in failed) _ord(k)])} برقرار نیست، کار فعلاً همین‌جا گیر است؛ اول باید همین گره باز شود تا این راه به نتیجه برسد');
      sb.write(ok > 0
          ? ' (${_count(ok)} شرط دیگر را دارید و به کارتان می‌آید).'
          : '.');
      if (open.isNotEmpty) {
        sb.write(
            ' شرط ${_join([for (final k in open) _ord(k)])} هم هنوز برایم روشن نیست.');
      }
    } else {
      sb.write(
          'نتیجه تا اینجا: ${ok == 0 ? 'هنوز هیچ‌کدام از شرط‌ها برایم محرز نیست' : '${_count(ok)} شرط از ${_count(total)} شرط محرز است'} و حرف آخر به شرط ${_join([for (final k in open) _ord(k)])} بستگی دارد. اگر ${open.length == 1 ? 'آن هم' : 'آن‌ها هم'} برقرار باشد، ${c.win(file)}');
    }
    final counter = c.counter;
    if (counter != null) {
      final x = counter(file);
      if (x.isNotEmpty) sb.write('\n${_pick(Say.counter)} $x');
    }
    return sb.toString();
  }

  /// پیشنهادهای متناسب با همین گفتگو: پرسش‌هایی که به حرف‌های خودِ کاربر
  /// نزدیک‌ترند جلوتر می‌آیند، و «نوشتن متن» فقط وقتی که پرونده پخته شده یا
  /// خودش حرفِ شکایت و دادخواست را زده باشد.
  List<String> _suggest(Topic t) {
    final cand = <Issue>[];
    for (final i in t.issues) {
      if (file.covered.contains(i.id)) continue;
      final w = i.when;
      if (w != null && !w(file)) continue;
      cand.add(i);
    }
    final near = <String, int>{};
    for (var k = 0; k < cand.length; k++) {
      final i = cand[k];
      var sc = Sense.has(_heard, i.cues) ? 3 : 0;
      for (final w in Sense.norm(i.chip).split(' ')) {
        if (w.length >= 4 && _heard.contains(w)) sc++;
      }
      // در تساوی، ترتیبِ خودِ موضوع حفظ می‌شود.
      near[i.id] = sc * 100 - k;
    }
    cand.sort((a, b) => (near[b.id] ?? 0).compareTo(near[a.id] ?? 0));
    final out = <String>[for (final i in cand.take(2)) i.chip];
    for (final e in _followChips.entries) {
      if (out.length >= 3) break;
      if (file.covered.contains('f:${e.key}')) continue;
      if (!t.follow.containsKey(e.key)) continue;
      out.add(e.value);
    }
    final ripe = _nextSlot(t) == null ||
        Sense.has(_heard, 'شکایت|دادخواست|اظهارنامه|لایحه|شکوائیه|بنویس');
    final d = t.drafts;
    if (d != null && ripe) {
      for (final id in d(file)) {
        final title = _draftTitles[id];
        if (title != null) {
          out.add(title);
          break;
        }
      }
    }
    return out;
  }

  /// دکمه‌های پیشنهادی برای وضعیت فعلی گفتگو.
  List<String> get idleChips => _idleChips();

  /// بیرون از پرونده، نمونه‌های آماده فقط پیش از آن‌که کاربر ماجرایی گفته
  /// باشد نشان داده می‌شود؛ بعد از آن ربطی به حرف او ندارد.
  List<String> _idleChips() {
    final t = _current();
    return t == null ? const [] : _suggest(t);
  }

  /// نمونه‌های آغاز گفتگو؛ فقط وقتی کاربر هنوز هیچ ماجرایی نگفته است.
  List<String> _starters() =>
      _loose.length <= 1 && _guide == null && file.topic.isEmpty
          ? starterChips
          : const [];

  // ------------------------------------------------------ گفت‌وگوی انسانی

  AdvocateReply? _meta(String n, Topic? topic) {
    final w = Sense.words(n);
    if (w <= 8 &&
        Sense.has(n,
            'تو وکیلی|شما وکیل|وکیل هستی|وکیلی ؟|کی هستی|چی هستی|رباتی|ربات هستی|هوش مصنوعی|آدم واقعی|ادم واقعی|آدمی یا|اسمت چیه')) {
      return _out(
        'نه؛ من وکیل دادگستری نیستم و آدم هم نیستم. یک دستیار حقوقی‌ام که روی همین گوشی و بدون اینترنت کار می‌کند و حرف‌هایتان جایی نمی‌رود. کارم این است که ماجرا را بشنوم، سؤال بپرسم و بر پایهٔ متن قانون راهنمایی کنم؛ جای وکیل در دادگاه را نمی‌گیرم.',
        ask: topic == null ? 'حالا بگویید چه پیش آمده؟' : _askText,
        chips: topic == null ? _starters() : _askChips,
        full: true,
      );
    }
    if (w <= 10 &&
        Sense.has(n,
            'میشه (?:[^ ]+ ){0,3}اعتماد|اعتماد کنم|قابل اعتماد|مطمئنی|از کجا میدونی|از کجا معلوم|درست میگی|حرف(?:ات|هات) درست|منبع(?:ت)? چیه|دروغ نمیگی')) {
      return _out(
        'سؤال به‌جایی است. هر ماده‌ای که نام می‌برم واقعاً در بانک قوانین برنامه هست و هر وقت بخواهید متنش را نشانتان می‌دهم؛ از خودم ماده نمی‌سازم. ولی سه محدودیت دارم: مدارکتان را ندیده‌ام، ممکن است قانون تازه‌تر شده باشد، و رویهٔ دادگاه‌ها را یک وکیل حضوری بهتر می‌داند. برای تصمیم‌های بزرگ حرف آخر را با وکیل دادگستری چک کنید.',
        ask: _askText,
        chips: _askText.isEmpty ? _idleChips() : _askChips,
        full: true,
      );
    }
    if (w <= 7 &&
        !Sense.has(n, '(?:ماده|اصل) [0-9]+') &&
        _lastLaws.isNotEmpty &&
        Sense.has(n,
            'متن (?:قانون|ماده)|کدوم ماده|کدام ماده|طبق کدوم|طبق کدام|ماده ?(?:اش|ش) (?:چی|رو|را)|مستند(?:ت|ش)? چی|سندت چیه')) {
      final lines = [
        for (final l in _lastLaws.take(2)) '• ${l.title}: «${_snippet(l.body)}»',
      ];
      return _out(
        'متن قانونی که به آن تکیه کردم:\n${lines.join('\n')}',
        ask: _askText,
        chips: _askChips,
        full: true,
      );
    }
    if (w <= 8 &&
        Sense.has(n,
            'چی فهمیدی|چه فهمیدی|متوجه (?:شدی|حرفم)|فهمیدی چی|حرف(?:م|مو|م رو) فهمیدی|گرفتی چی|میفهمی چی')) {
      final got = topic == null ? const <String>[] : _recap(topic);
      if (topic == null || got.isEmpty) {
        return _out(
          topic == null
              ? 'هنوز ماجرای مشخصی از شما نشنیده‌ام که بگویم چه فهمیده‌ام.'
              : 'می‌دانم موضوع «${topic.title}» است، ولی هنوز جزئیات کافی ندارم.',
          ask: topic == null || _askText.isEmpty
              ? 'دقیقاً چه اتفاقی افتاده است؟'
              : _askText,
          chips: topic == null ? _idleChips() : _askChips,
        );
      }
      return _out(
        '${_pick(Say.understood)} ${_join(got)}.',
        ask: 'درست گرفته‌ام، یا جایی را باید اصلاح کنم؟',
        chips: _suggest(topic),
      );
    }
    if (w <= 8 &&
        Sense.has(n,
            'چرا (?:[^ ]+ ){0,2}(?:می)?پرس|چه ربطی|به چه درد|برای چی میپرس')) {
      Slot? p;
      if (topic != null) {
        for (final s in topic.slots) {
          if (s.id == file.pending) p = s;
        }
      }
      if (p != null && p.why.isNotEmpty) {
        return _out(
          'حق دارید بپرسید. ${p.why}\nاگر نمی‌دانید هم اشکالی ندارد؛ از آن می‌گذرم.',
          ask: 'سؤالم این بود: ${p.ask}',
          chips: [...p.options, _dontKnowChip],
          full: true,
        );
      }
      final why = file.pending == 'q:reply'
          ? 'چون جوابِ او نشان می‌دهد با چه دفاعی روبه‌رو می‌شوید؛ کسی که انکار می‌کند با کسی که فقط عقب می‌اندازد، دو راهِ متفاوت می‌خواهد.'
          : file.pending == 'q:goal'
              ? 'چون راهِ توافق و راهِ دادگاه دو مسیرِ جدا هستند و نمی‌خواهم وقتتان را در مسیری بگذارم که خودتان نمی‌خواهید.'
              : 'برای اینکه جوابم به وضعیت خودِ شما بخورد، نه یک توضیح کلی. در حقوق یک جزئیات کوچک، مثل یک تاریخ یا یک امضا، می‌تواند نتیجه را عوض کند.';
      return _out(
        why,
        ask: _askText,
        chips: _askText.isEmpty ? _idleChips() : _askChips,
        full: true,
      );
    }
    if (w <= 6 && Sense.has(n, 'خلاصه|جمع ?بندی|در یک جمله|تهش چی|آخرش چی')) {
      return _summary(topic);
    }
    if (w <= 6 &&
        Sense.has(n,
            'ساده ?تر|ساده بگو|نفهمیدم|متوجه نشدم|گیج شدم|پیچیده|دوباره بگو|یه بار دیگه|نگرفتم')) {
      if (_lastBody.isEmpty) {
        return _out('هنوز چیزی نگفته‌ام که پیچیده باشد.',
            ask: 'چه مشکلی پیش آمده؟', chips: _idleChips());
      }
      final lines = <String>[
        for (final l in _strip(_lastBody).split('\n'))
          if (l.trim().isNotEmpty) _brief(l.trim()),
      ];
      return _out(
        'ساده‌ترش این است:\n${lines.take(4).join('\n')}',
        ask: 'کدام کلمه یا کدام بخشش هنوز گنگ است؟',
        chips: topic == null ? _idleChips() : _suggest(topic),
      );
    }
    if (w <= 10 &&
        Sense.has(n,
            'هیچ راهی|راهی نیست|راهی نداره|پولم رفت|کاری نمیشه کرد|یعنی هیچی|بیچاره شدم|بدبخت شدم|امیدی نیست|دستم به جایی')) {
      if (topic == null) {
        return _out(
          'هنوز برای ناامیدشدن زود است؛ تقریباً همیشه راهی هست.',
          ask: 'چه اتفاقی افتاده؟',
          chips: _idleChips(),
        );
      }
      final c = topic.follow['chance'];
      final n2 = topic.follow['next'];
      final sb = StringBuffer('نه، بن‌بست نیست؛ فقط راهش سرراست نیست.');
      if (c != null) sb.write('\n${c(file)}');
      if (n2 != null && !file.covered.contains('f:next')) {
        sb.write('\n\n${n2(file)}');
        file.covered.add('f:next');
      }
      _lastBody = sb.toString();
      return _out(_lastBody, chips: _suggest(topic));
    }
    return null;
  }

  AdvocateReply _summary(Topic? topic) {
    final g = _guide;
    if (topic == null && g != null) {
      return _out(g.brief.isNotEmpty ? g.brief : _sentences(g.answer).take(2).join(' '),
          chips: const [newCaseChip]);
    }
    if (topic == null) {
      return _out(
        'هنوز ماجرایی تعریف نکرده‌اید که خلاصه‌اش کنم.',
        ask: 'چه شده؟ کوتاه هم بگویید کافی است.',
        chips: _idleChips(),
      );
    }
    final sb = StringBuffer('خلاصه و بدون حاشیه:\n');
    final got = _recap(topic);
    if (got.isNotEmpty) sb.write('• ماجرا: ${_join(got)}.\n');
    final open = _sentences(_strip(topic.opening(file)));
    if (open.isNotEmpty) sb.write('• حرف قانون: ${open.first}\n');
    final plan = topic.follow['next'];
    if (plan != null) {
      final steps = [
        for (final l in _strip(plan(file)).split('\n'))
          if (RegExp('^[۰-۹]+[)]').hasMatch(l.trim())) _brief(l.trim()),
      ];
      if (steps.isNotEmpty) {
        sb.write('• کاری که باید بکنید:\n');
        for (final s in steps.take(4)) {
          sb.write('   $s\n');
        }
      }
    }
    final q = _nextSlot(topic);
    if (q != null) {
      sb.write('• چیزی که هنوز نمی‌دانم و مهم است: ${q.ask}');
    }
    return _out(sb.toString().trimRight(),
        chips: _suggest(topic), budget: _roomyBudget);
  }

  AdvocateReply? _social(String n, Topic? topic) {
    final w = Sense.words(n);
    if (w > 7) return null;
    if (Sense.has(n, 'ممنون|مرسی|متشکر|سپاس|دستت درد نکنه|دمت گرم|لطف کردی|تشکر')) {
      return _out(
        topic == null
            ? 'خواهش می‌کنم. هر وقت سؤالی بود، همین‌جا هستم.'
            : _askText.isNotEmpty
                ? 'خواهش می‌کنم.'
                : 'خواهش می‌کنم. اگر در ادامهٔ کار به مشکلی خوردید یا طرف مقابل حرکت تازه‌ای کرد، همین‌جا بگویید تا قدم بعد را با هم بچینیم.',
        chips: _idleChips(),
      );
    }
    if (Sense.has(n, 'خداحافظ|خدانگهدار|خدا نگهدار|فعلا |بای ')) {
      return _out('خدانگهدار. امیدوارم کارتان به‌خوبی پیش برود.');
    }
    if (Sense.has(n, '^ (?:سلام|درود|وقت بخیر|صبح بخیر|عصر بخیر|شب بخیر|خسته نباشی)')) {
      return _out(
        topic == null
            ? 'سلام، خوش آمدید.'
            : 'سلام دوباره. پرونده‌تان را به خاطر دارم.',
        ask: topic == null ? 'چه اتفاقی افتاده که سراغ من آمده‌اید؟' : _askText,
        chips: topic == null ? _starters() : _askChips,
      );
    }
    if (Sense.has(n, 'خوبی|چطوری|حالت چطوره|چه خبر')) {
      return _out('ممنون که می‌پرسید؛ من آماده‌ام.',
          ask: topic == null ? 'چه کمکی از دستم برمی‌آید؟' : _askText,
          chips: topic == null ? _starters() : _askChips);
    }
    return null;
  }

  bool _vague(String n) =>
      Sense.words(n) <= 9 &&
      Sense.has(n,
          'مشکل(?:ی)? (?:حقوقی |قانونی )?(?:دارم|پیش اومده|برام)|سوال(?:ی)? (?:حقوقی )?(?:داشتم|دارم)|مشاوره|کمک(?:م)? (?:کن|میخوام|کنید)|راهنمایی(?:م)? (?:کن|میخوام|کنید)|گرفتار شدم|یه مسئله');

  AdvocateReply _intake() => _out(
        'در خدمتم.',
        ask:
            'چه اتفاقی افتاده و طرف مقابل کیست؟ همان‌طور که برای یک دوست تعریف می‌کنید بگویید.',
        chips: _starters(),
      );

  static const List<List<String>> _parties = [
    ['همسایه', 'همسایه‌تان'],
    ['برادر|داداش', 'برادرتان'],
    ['خواهر|آبجی', 'خواهرتان'],
    [' پدر| بابا', 'پدرتان'],
    [' مادر| مامان', 'مادرتان'],
    ['نامزد', 'نامزدتان'],
    ['همکار', 'همکارتان'],
    ['دوستم|رفیق', 'دوستتان'],
    ['عمو|دایی|خاله|عمه|فامیل|اقوام|پسرعمو|دخترعمو', 'یکی از بستگانتان'],
    ['بانک', 'بانک'],
    ['شهرداری', 'شهرداری'],
    ['بیمه', 'بیمه'],
    ['پلیس|مامور|کلانتری', 'پلیس'],
    ['مدرسه|دانشگاه|آموزشگاه|مهدکودک', 'یک مرکز آموزشی'],
    ['دکتر|پزشک|بیمارستان|کلینیک|درمانگاه', 'پزشک یا مرکز درمانی'],
    ['فروشنده|مغازه دار|فروشگاه|نمایشگاه', 'فروشنده'],
    [' پیک |پستچی|اداره پست|شرکت پست|تیپاکس|باربری|اسنپ|تپسی', 'پیک یا شرکت حمل‌ونقل'],
    ['شرکت', 'یک شرکت'],
  ];

  /// طرفِ ماجرا، اگر کاربر نامش را برده باشد.
  static String _party(String n) {
    for (final p in _parties) {
      if (Sense.has(n, p[0])) return p[1];
    }
    return '';
  }

  static const Map<String, String> _areas = {
    'criminal_harm': 'به نظرم ماجرا جنبهٔ کیفری دارد.',
    'fraud_cyber': 'به نظرم پای کلاهبرداری یا سوءاستفاده در میان است.',
    'litigation_defense': 'پس پای دادگاه یا یک رأی در میان است.',
    'family': 'پس ماجرا خانوادگی است.',
    'labor': 'پس ماجرا به کار و کارفرما برمی‌گردد.',
    'lease': 'پس ماجرا به اجاره برمی‌گردد.',
    'debt': 'پس حرفِ پول و طلب است.',
    'cheque': 'پس حرفِ چک است.',
  };

  static String _clip(String raw) {
    final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.length <= 60) return t;
    final cut = t.lastIndexOf(' ', 60);
    return '${t.substring(0, cut < 20 ? 60 : cut)}…';
  }

  /// وقتی موضوع را نمی‌شناسم: به‌جای «متوجه نشدم»، نشان می‌دهم چه شنیده‌ام
  /// و مثل هر وکیلی دربارهٔ ماجرا می‌پرسم تا تصویر روشن شود.
  AdvocateReply _curious(String raw, String n) {
    final all = _loose.join(' ');
    final who = _party(all);
    var area = '';
    final net = intentNet;
    if (net != null && Sense.words(n) >= 3) {
      final top = net.classify(raw);
      if (top.score >= 0.5) area = _areas[top.label] ?? '';
    }
    final heard = who.isNotEmpty
        ? 'پس طرفِ ماجرا $who است.'
        : 'گفتید «${_clip(raw)}».';
    final k = _loose.length;
    if (k <= 1) {
      return _out(area.isEmpty ? heard : '$heard $area',
          ask: who.isNotEmpty
              ? 'دقیقاً چه اتفاقی افتاد و از چه زمانی؟'
              : Sense.words(n) >= 4
                  ? 'این از کِی پیش آمده و تا حالا برایش چه کرده‌اید؟'
                  : 'طرف مقابل کیست و دقیقاً چه کرده است؟');
    }
    if (k == 2) {
      return _out(area.isEmpty ? 'متوجه شدم.' : area,
          ask:
              'و خودتان الان چه می‌خواهید: مال یا پولتان برگردد، از او شکایت کنید، یا از خودتان دفاع کنید؟');
    }
    // برای ماجرایی که تحلیل آماده ندارم، دست‌کم راهِ کلی را روراست می‌گویم.
    final allN = Sense.norm(all);
    if (Sense.has(allN, 'پول|خسارت|پس بد|برگرد|غرامت|هزینه')) {
      return _out(
        'برای این نوع ماجرا تحلیل آماده‌ای ندارم، ولی راه کلیِ پس‌گرفتن پول یا خسارت این است: اول کتبی و قابل اثبات مطالبه کنید (پیام یا اظهارنامهٔ رسمی)، و اگر نداد، دادخواست مطالبهٔ وجه یا خسارت بدهید.',
        ask: 'مبلغش حدوداً چقدر است و چه مدرکی از این ماجرا دارید؟',
      );
    }
    if (Sense.has(allN, 'شکایت|مجازات|زندان|جرم')) {
      return _out(
        'برای این نوع ماجرا تحلیل آماده‌ای ندارم، ولی راه کلیِ شکایت این است: شکوائیه را با مدارکتان در دفتر خدمات الکترونیک قضایی ثبت می‌کنید و دادسرا رسیدگی را شروع می‌کند.',
        ask: 'چه مدرک یا شاهدی از این ماجرا دارید؟',
      );
    }
    return _out(
      'راستش برای این ماجرا هنوز تحلیل آماده‌ای ندارم و نمی‌خواهم حدسی حرف بزنم.',
      ask:
          'به کدام نزدیک‌تر است: قرارداد و پول، خانواده، کار، ملک، یا شکایت کیفری؟',
    );
  }

  // ------------------------------------------------- واژه‌نامه و جست‌وجو

  String? _glossary(String n) {
    final cmp = Glossary.compare(n);
    if (cmp != null) return cmp;
    if (!Glossary.asksMeaning(n)) return null;
    final ts = Glossary.find(n);
    if (ts.isEmpty) return null;
    return ts.first.text;
  }

  /// واپسین راه: جست‌وجوی واژگانی (BM25) در متن قوانین؛ بدون مدل.
  AdvocateReply _lookup(String raw, String n) {
    final direct = Sense.has(n, '(?:ماده|اصل) [0-9]+');
    final legalish = direct ||
        Sense.has(n,
            'قانون|حق |حقوق|جرم|مجازات|دادگاه|دادسرا|شکایت|قرارداد|سند|ارث|دیه|مهریه|جریمه|وکالت|وصیت|ملک|معامله|خسارت|بدهی|طلب|محکوم|حکم |رای |تعهد|ضامن|ضمانت|فسخ|مالکیت|توقیف|زندان|حبس|قاضی|وکیل');
    if (legalish &&
        Sense.words(n) >= 2 &&
        (direct || Sense.isQuestion(n) || _loose.length >= 3)) {
      final r = engine.query(raw);
      if (r.contextHits.isNotEmpty) {
        final laws = [
          for (final h in r.contextHits.take(2))
            LawText(h.chunk.title, h.chunk.source, h.chunk.body, ''),
        ];
        final lead = direct
            ? 'این متنِ همان ماده در بانک قوانین من است:'
            : 'تحلیل آماده‌ای برای این پرسش ندارم؛ نزدیک‌ترین متن قانونی که پیدا کردم این است:';
        _rest = '';
        _offeredMore = false;
        return AdvocateReply(
          '$lead\n\n${r.text}\n\n'
          'این به ماجرای خودتان مربوط است؟ اگر بگویید چه شده، متناسب با وضعیت شما می‌گویم.',
          laws: laws,
        );
      }
    }
    if (!legalish && Sense.isQuestion(n) && _party(n).isEmpty) {
      return _out(
        'این یکی از حوزهٔ کار من بیرون است؛ من فقط در مسائل حقوقی (اجاره، کار، چک و طلب، خانواده، شکایت و دفاع) می‌توانم کمک کنم.',
        ask: 'گرفتاری حقوقی‌ای هست که بخواهید درباره‌اش حرف بزنیم؟',
      );
    }
    if (Sense.words(n) < 2 || !Sense.has(n, '[\u0600-\u06FF]{2}')) {
      return _out(
        'این را متوجه نشدم.',
        ask: 'می‌شود با یکی دو جمله بگویید چه اتفاقی افتاده؟',
      );
    }
    return _curious(raw, n);
  }

  // ----------------------------------------------------- راهنماهای آماده

  AdvocateReply _openGuide(LegalGuide g, String raw, String n,
      {bool switched = false}) {
    _closeCase();
    _guide = g;
    final sb = StringBuffer();
    if (switched) {
      sb.write('این موضوعِ جداگانه‌ای است؛ پس آن را جدا بررسی می‌کنم.\n\n');
    } else if (g.empathy.isNotEmpty && LawyerVoice.expressesDistress(raw)) {
      sb.write('${g.empathy}\n\n');
    }
    sb.write(g.answer);
    sb.write(_guideSteps(g));
    if (g.cautions.isNotEmpty) {
      sb.write('\n\nحواستان باشد:');
      for (final c in g.cautions) {
        sb.write('\n• $c');
      }
    }
    final refs = [for (final r in g.refs) '[[${r.lawId}:${r.article}]]'];
    if (refs.isNotEmpty) sb.write('\n\nمستند این حرف‌ها ${refs.join(' ')} است.');
    _lastBody = g.answer;
    _guideAsked = g.followUp.isNotEmpty;
    _guideStepped = false;
    return _out(sb.toString(), chips: _guideChips(g), ask: g.followUp);
  }

  String _guideSteps(LegalGuide g) {
    if (g.steps.isEmpty) return '';
    final sb = StringBuffer('\n\nقدم‌هایی که پیشنهاد می‌کنم:');
    var i = 1;
    for (final s in g.steps) {
      sb.write('\n${Sense.fa(i)}) $s');
      i++;
    }
    return sb.toString();
  }

  List<String> _guideChips(LegalGuide g) {
    final out = <String>[if (g.steps.isNotEmpty) 'قدم بعدی چیست؟'];
    for (final id in g.templateIds) {
      final title = _draftTitles[id];
      if (title != null) {
        out.add(title);
        break;
      }
    }
    return out;
  }

  AdvocateReply? _guideFollow(LegalGuide g, String n) {
    final gl = _glossary(n);
    if (gl != null) return _out(gl, chips: _guideChips(g));
    final kind = Sense.followKind(n);
    if (kind == 'next' && g.steps.isNotEmpty) {
      _guideAsked = false;
      if (_guideStepped) {
        _guideStepped = false;
        return _out(
          'قدم‌ها همان‌هاست که گفتم. از اولی شروع کنید: ${g.steps.first}',
          ask: 'کجای کار گیر کرده‌اید یا نگران کدام قدم هستید؟',
          chips: _guideChips(g),
        );
      }
      _guideStepped = true;
      return _out('برای «${g.title}»${_guideSteps(g).replaceFirst('\n\n', ' ')}',
          ask: 'کدام‌یک از این قدم‌ها را تا حالا برداشته‌اید؟',
          chips: _guideChips(g),
          budget: _roomyBudget);
    }
    if (kind == 'lawyer') return _out(anyLawyer, chips: _guideChips(g));
    final soc = _social(n, null);
    if (soc != null) return soc;
    if (kind.isNotEmpty || Sense.isQuestion(n)) {
      final r = engine.query('${g.title} $n');
      if (r.contextHits.isNotEmpty) {
        return AdvocateReply(
          'دربارهٔ این بخش از «${g.title}» تحلیل آماده‌ای ندارم؛ نزدیک‌ترین متن قانونی که پیدا کردم این است:\n\n${r.text}',
          chips: _guideChips(g),
          laws: [
            for (final h in r.contextHits.take(2))
              LawText(h.chunk.title, h.chunk.source, h.chunk.body, ''),
          ],
        );
      }
    }
    // جوابِ پرسشی که خودم آخرِ راهنما پرسیده بودم: حالا نوبت قدم‌هاست.
    if (_guideAsked && g.steps.isNotEmpty && !Sense.isQuestion(n)) {
      _guideAsked = false;
      _guideStepped = true;
      return _out('${_pick(Say.fine)} با این حساب${_guideSteps(g).replaceFirst('\n\n', ' ')}',
          ask: 'کدام‌یک از این قدم‌ها را تا حالا برداشته‌اید؟',
          chips: _guideChips(g));
    }
    return null;
  }

  // ------------------------------------------------------------- خروجی

  static final RegExp _refRun =
      RegExp(r'(?:\s*\[\[[a-z_0-9]+:[0-9]+m?\]\])+');
  static final RegExp _refOne = RegExp(r'\[\[([a-z_0-9]+):([0-9]+)(m?)\]\]');
  static final RegExp _sentEnd = RegExp(r'(?<=[.؟!])\s+|\n+');

  static String _strip(String s) => s.replaceAll(_refRun, '');

  static List<String> _sentences(String s) => [
        for (final p in s.split(_sentEnd))
          if (p.trim().isNotEmpty) p.trim(),
      ];

  /// از یک توضیح بلند، جمله‌ای که به حرف کاربر می‌خورد.
  static String _relevant(String answer, String n) {
    final sents = _sentences(answer);
    if (sents.isEmpty) return answer;
    final keys = [
      for (final w in n.trim().split(' '))
        if (w.length >= 5) w.substring(0, 5),
    ];
    for (final s in sents) {
      final sn = Sense.norm(s);
      if (keys.any(sn.contains)) return s;
    }
    return sents.first;
  }

  static String _brief(String line) {
    if (line.length <= 24) return line;
    var cut = line.length;
    for (final mark in const ['؛', '. ']) {
      final i = line.indexOf(mark, 18);
      if (i > 0 && i < cut) cut = i;
    }
    // «عنوان: توضیح» فقط وقتی کوتاه می‌شود که خودِ عنوان گویا باشد.
    final colon = line.indexOf(':', 40);
    if (colon > 0 && colon < cut) cut = colon;
    final out = line.substring(0, cut).trim();
    return out.endsWith('.') ? out : '$out.';
  }

  String _pick(List<String> options) {
    final v = options[_vary % options.length];
    _vary++;
    return v;
  }

  /// نام کوتاه و رایج قانون‌های پرتکرار، برای اینکه متن پاسخ سنگین نشود.
  static String _shortLaw(String source) {
    if (source.contains('آیین دادرسی دادگاه') && source.contains('مدنی')) {
      return 'قانون آیین دادرسی مدنی';
    }
    final paren = source.indexOf(' (');
    if (paren > 8 && source.startsWith('قانون مجازات اسلامی')) {
      return source.contains('تعزیرات')
          ? 'قانون مجازات اسلامی (تعزیرات)'
          : source.substring(0, paren);
    }
    return source;
  }

  static String _snippet(String body) {
    var b = body.trim();
    final nl = b.indexOf('\n');
    if (b.startsWith('(') && nl > 0 && nl < 60) b = b.substring(nl + 1);
    b = b.replaceAll(RegExp(r'\s+'), ' ').trim();
    // حاشیه‌های غیرقانونیِ بانک (مثل «نظر مجلس») جزو متن ماده نیست.
    final note = b.indexOf('نظر مجلس');
    if (note > 20) b = b.substring(0, note).trim();
    if (b.length > 190) {
      var cut = b.lastIndexOf(' ', 190);
      if (cut < 90) cut = 190;
      b = '${b.substring(0, cut).trim()}…';
    }
    return Sense.fa(b);
  }

  static final RegExp _cutAt = RegExp(r'[.؟!]\s+|\n+');

  static final RegExp _listItem = RegExp(r'^(?:[۰-۹0-9]+\)|•)');

  /// متن را در مرزِ جمله به دو بخش می‌کند: آنچه الان گفته می‌شود و باقی.
  static List<String> _cut(String body, int budget) {
    if (body.length <= budget + 60) return [body, ''];
    final ends = <int>[];
    for (final m in _cutAt.allMatches(body)) {
      if (m.end >= body.length) break;
      final head = body.substring(0, m.start + 1).trimRight();
      if (head.endsWith(':') || head.endsWith('،')) continue;
      ends.add(m.end);
    }
    if (ends.isEmpty) return [body, ''];
    var k = 0;
    while (k + 1 < ends.length && ends[k + 1] <= budget) {
      k++;
    }
    // فهرستِ شماره‌دار را وسطش نمی‌بُرم، اگر باقی‌اش جا شود.
    while (k + 1 < ends.length &&
        ends[k + 1] <= budget + 280 &&
        _listItem.hasMatch(body.substring(ends[k]))) {
      k++;
    }
    final pick = ends[k];
    if (body.length - pick < 60) return [body, ''];
    if (body.length <= budget + 280 &&
        _listItem.hasMatch(body.substring(pick))) {
      return [body, ''];
    }
    return [body.substring(0, pick).trimRight(), body.substring(pick).trim()];
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
