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
import 'package:dastyar/domain/lawyer/lawyer_voice.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';

/// پاسخ وکیل به یک پیام.
class AdvocateReply {
  final String text;
  final List<String> chips;
  final List<LawText> laws;
  AdvocateReply(this.text, {this.chips = const [], this.laws = const []});
}

/// وکیل آفلاینِ بدون مدل.
///
/// هیچ مدل زبانی یا شبکهٔ عصبی (نه آفلاین، نه آنلاین) در این مسیر نیست؛
/// همه‌چیز قاعده و دانش صریح است:
///  ۱. فهم: الگوهای منظم روی متن محاوره‌ای ([Sense]).
///  ۲. حافظه: پروندهٔ ماجرا با واقعیت‌هایی که کاربر گفته ([CaseFile]).
///  ۳. استدلال: هر واقعیت «اثر حقوقی» دارد و هر پرسش پاسخی که از روی
///     واقعیت‌های پرونده ساخته می‌شود ([Topic]، [Slot]، [Issue]).
///  ۴. استناد: هر ماده فقط وقتی نام برده می‌شود که متنش در بانک قوانین
///     پیدا شود (`engine.findArticle`)، و متن همان ماده نقل می‌شود.
class Advocate {
  Advocate(this.engine, {Map<String, String> draftTitles = const {}})
      : _draftTitles = draftTitles;

  final KnowledgeEngine engine;

  /// شناسهٔ قالب سند → عنوان آن (برای دکمهٔ «تهیهٔ متن»).
  final Map<String, String> _draftTitles;

  final CaseFile file = CaseFile();

  /// استنادهایی که متنشان در بانک پیدا نشد (برای آزمون؛ باید خالی بماند).
  final List<String> unresolved = [];

  final Set<String> _quoted = {};

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
  int _vary = 0;

  static const String newCaseChip = 'موضوع تازه‌ای دارم';
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
    _quoted.clear();
    _said.clear();
    _loose.clear();
    unresolved.clear();
    _also = null;
    _vary = 0;
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
        'باشد، آن موضوع را کنار می‌گذارم. ماجرای تازه را تعریف کنید؛ از هر جا که راحت‌ترید شروع کنید.',
        chips: starterChips,
      );
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
      final g = _glossary(n);
      if (g != null) return _out(g, chips: _idleChips());
      final guide = _guide;
      if (guide != null) {
        final r = _guideFollow(guide, n);
        if (r != null) return r;
      }
      final lg = _matchGuide(raw, n);
      if (lg != null) return _openGuide(lg, raw, n);
      final soc = _social(n, null);
      if (soc != null) return soc;
      if (_vague(n)) return _intake();
      return _lookup(raw, n);
    }

    final cur = scores[topic.id] ?? 0;
    final issue = _matchIssue(topic, n);
    if (best != null &&
        best.id != topic.id &&
        bestScore >= 3 &&
        cur == 0 &&
        (bestScore >= 4 || issue == null)) {
      return _open(best, n, switched: true);
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

  int _score(Topic t, String n) {
    if (t.anti.isNotEmpty && Sense.has(n, t.anti)) return 0;
    var s = 0;
    for (final e in t.cues.entries) {
      if (Sense.has(n, e.key)) s += e.value;
    }
    return s;
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
    final parts = <String>[];
    // اول نشان می‌دهم حرف کاربر را چطور فهمیده‌ام؛ اگر اشتباه گرفته باشم
    // همان‌جا می‌تواند اصلاحم کند.
    final got = _recap(t);
    if (got.length >= 2) {
      parts.add('${_pick(Say.understood)} ${_join(got)}.');
    }
    final open = t.opening(file);
    if (open.isNotEmpty) parts.add(open);
    final issue = _matchIssue(t, n);
    if (issue != null) {
      if (_roleUnknown(t)) {
        _deferred = issue.id;
      } else {
        final b = issue.body(file);
        if (!parts.contains(b)) parts.add(b);
        file.covered.add(issue.id);
        _said.add(b);
        _lastBody = b;
      }
    }
    _addEffects(parts, news, issue == null ? 3 : 2,
        skip: _deferred.isEmpty && issue != null ? issue.covers : const {});
    _noteAmount(parts, news, n);
    if (_lastBody.isEmpty && parts.isNotEmpty) _lastBody = parts.first;
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
    final news = _absorb(t, n);
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
        final a0 = kind == 'argue' || kind == 'chance' ? _argue(t) : null;
        // استدلالی که عیناً گفته شده برای «شانسم چقدر است؟» تکرار نمی‌شود.
        final arg =
            a0 != null && kind == 'chance' && _said.contains(a0) ? null : a0;
        final fb = kind.isEmpty
            ? null
            : (t.follow[kind == 'argue' ? 'chance' : kind] ?? _generic(kind));
        if (arg != null) {
          parts.add(arg);
          file.covered.add('f:argue');
          file.covered.add('f:chance');
          _said.add(arg);
          _lastBody = arg;
          understood = true;
        } else if (fb != null) {
          final b = fb(file);
          parts.add(b);
          file.covered.add('f:$kind');
          _said.add(b);
          _lastBody = b;
          understood = true;
        }
      }
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
      if (Sense.words(n) >= 3) {
        final lg = _matchGuide(raw, n);
        if (lg != null) return _openGuide(lg, raw, n, switched: true);
      }
      if (Sense.has(n, 'ماده [0-9]+|قانون ')) return _lookup(raw, n);
      parts.add(_pick(Say.lost));
      file.pending = '';
      return _out(parts.join('\n\n'), chips: _suggest(t));
    }
    if (parts.isEmpty) {
      parts.add(_nextSlot(t) == null
          ? 'بسیار خوب. بگویید کدام بخش برایتان مهم‌تر است تا از همان شروع کنم؛ یا یکی از گزینه‌های زیر را انتخاب کنید.'
          : _pick(const ['بسیار خوب.', 'متوجه شدم.', 'خیلی خوب، یادداشت کردم.']));
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

  AdvocateReply _finish(Topic t, List<String> parts, {String lead = ''}) {
    final chips = <String>[];
    var body = parts.join('\n\n');
    if (lead.isNotEmpty) body = body.isEmpty ? lead : '$lead\n\n$body';
    final q = _nextSlot(t);
    final plan = t.follow['next'];
    final planText = q == null && plan != null ? plan(file) : '';
    final planSaid = planText.isNotEmpty &&
        (_said.any((x) => x.contains(planText)) ||
            parts.any((x) => x.contains(planText)));
    _said.addAll(parts);
    if (q != null) {
      final c = file.askCount[q.id] ?? 0;
      file.askCount[q.id] = c + 1;
      file.pending = q.id;
      final intro = _pick(c == 0 ? Say.ask : Say.askAgain);
      body = '$body\n\n$intro ${q.ask}';
      chips.addAll(q.options);
      if (chips.length <= 2) {
        final extra = _suggest(t);
        chips.addAll(extra.take(q.options.isEmpty ? 2 : 1));
      }
    } else {
      // پرسش‌هایم تمام شد: مثل هر وکیلی، جمع‌بندی و نقشهٔ راه می‌دهم.
      if (file.pending.isNotEmpty && body.length < 1200) {
        var opened = false;
        final arg = file.covered.contains('f:argue') ? null : _argue(t);
        if (arg != null) {
          body = '$body\n\n${_pick(Say.wrap)} $arg';
          file.covered.add('f:argue');
          _said.add(arg);
          _lastBody = arg;
          opened = true;
        }
        if (planText.isNotEmpty && !file.covered.contains('f:next')) {
          if (planSaid) {
            body = opened
                ? '$body\n\n${_pick(Say.planSaid)}'
                : '$body\n\n${_pick(Say.wrap)} ${_pick(Say.planSaid)}';
          } else if (body.length < 900) {
            body = opened
                ? '$body\n\n$planText'
                : '$body\n\n${_pick(Say.wrap)} $planText';
            file.covered.add('f:next');
            _said.add(planText);
            _lastBody = planText;
          } else {
            body = '$body\n\n${_pick(Say.offerPlan)}';
          }
        }
      }
      file.pending = '';
      chips.addAll(_suggest(t));
    }
    return _out(body, chips: chips);
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
          'نتیجه: چون شرط ${_join([for (final k in failed) _ord(k)])} برقرار نیست، این راه به شکل فعلی جواب نمی‌دهد؛ اول باید همان گره باز شود');
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

  List<String> _suggest(Topic t) {
    final out = <String>[];
    for (final i in t.issues) {
      if (out.length >= 2) break;
      if (file.covered.contains(i.id)) continue;
      final w = i.when;
      if (w != null && !w(file)) continue;
      out.add(i.chip);
    }
    for (final e in _followChips.entries) {
      if (out.length >= 3) break;
      if (file.covered.contains('f:${e.key}')) continue;
      if (!t.follow.containsKey(e.key)) continue;
      out.add(e.value);
    }
    final d = t.drafts;
    if (d != null) {
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

  List<String> _idleChips() {
    final t = _current();
    return t == null ? starterChips : _suggest(t);
  }

  // ------------------------------------------------------ گفت‌وگوی انسانی

  AdvocateReply? _meta(String n, Topic? topic) {
    final w = Sense.words(n);
    if (w <= 8 &&
        Sense.has(n,
            'تو وکیلی|شما وکیل|وکیل هستی|وکیلی ؟|کی هستی|چی هستی|رباتی|ربات هستی|هوش مصنوعی|آدم واقعی|ادم واقعی|آدمی یا|اسمت چیه')) {
      return _out(
        'نه؛ من وکیل دادگستری نیستم و آدم هم نیستم. یک دستیار حقوقی‌ام که کاملاً روی همین گوشی و بدون اینترنت کار می‌کند؛ به هیچ سرور یا مدل هوش مصنوعی‌ای هم وصل نیستم و حرف‌هایتان جایی نمی‌رود.\n'
        'کاری که از من برمی‌آید این است که مثل یک وکیل با شما حرف بزنم: ماجرا را بشنوم، سؤال‌های لازم را بپرسم، بر پایهٔ متن قوانینی که در حافظه دارم تحلیل کنم و قدم بعدی را نشانتان بدهم. کاری که نمی‌توانم: حضور در دادگاه به‌جای شما و قبول مسئولیت پرونده.'
        '${topic == null ? '\nحالا بگویید چه مشکلی پیش آمده؟' : '\nبرگردیم سر پروندهٔ شما؛ هر جا ماندیم ادامه می‌دهیم.'}',
        chips: _idleChips(),
      );
    }
    if (w <= 10 &&
        Sense.has(n,
            'میشه (?:[^ ]+ ){0,3}اعتماد|اعتماد کنم|قابل اعتماد|مطمئنی|از کجا میدونی|از کجا معلوم|درست میگی|حرف(?:ات|هات) درست|منبع(?:ت)? چیه|دروغ نمیگی')) {
      return _out(
        'سؤال به‌جایی است و جوابش را بی‌تعارف می‌دهم.\n'
        'تا اینجا می‌شود اعتماد کرد: هر جا شمارهٔ ماده می‌آورم، متن همان ماده واقعاً در بانک قوانین برنامه هست و آن را زیر پاسخ نقل می‌کنم تا خودتان بخوانید؛ من ماده از خودم نمی‌سازم.\n'
        'اما سه محدودیت دارم:\n'
        '۱) فقط همان چیزی را می‌دانم که شما گفته‌اید؛ مدارکتان را ندیده‌ام.\n'
        '۲) قانون‌ها عوض می‌شوند و ممکن است بانک من از آخرین اصلاحیه عقب باشد.\n'
        '۳) رویهٔ عملی دادگاه‌ها و ریزه‌کاری‌های هر پرونده را یک وکیل حضوری بهتر می‌بیند.\n'
        'پس: برای فهمیدن وضعیت و آماده‌شدن روی من حساب کنید؛ برای تصمیم‌های بزرگ (امضای توافق، مبلغ سنگین، پروندهٔ کیفری) حرف آخر را با یک وکیل دادگستری چک کنید.',
        chips: _idleChips(),
      );
    }
    if (w <= 8 &&
        Sense.has(n,
            'چی فهمیدی|چه فهمیدی|متوجه (?:شدی|حرفم)|فهمیدی چی|حرف(?:م|مو|م رو) فهمیدی|گرفتی چی|میفهمی چی')) {
      final got = topic == null ? const <String>[] : _recap(topic);
      if (topic == null || got.isEmpty) {
        return _out(
          topic == null
              ? 'هنوز ماجرای مشخصی از شما نشنیده‌ام که بگویم چه فهمیده‌ام. تعریف کنید چه شده؛ بعد برداشتم را بازگو می‌کنم تا اگر اشتباه گرفتم اصلاحم کنید.'
              : 'می‌دانم موضوع «${topic.title}» است، ولی هنوز جزئیات کافی ندارم. هر چه بیشتر بگویید، دقیق‌تر می‌فهمم.',
          chips: topic == null ? starterChips : _suggest(topic),
        );
      }
      return _out(
        '${_pick(Say.understood)} ${_join(got)}.\nاگر جایی را اشتباه گرفته‌ام، همان را بگویید تا اصلاح کنم.',
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
          'حق دارید بپرسید. ${p.why}\nاگر نمی‌دانید یا نمی‌خواهید بگویید هم اشکالی ندارد؛ بگویید «نمی‌دانم» تا از آن بگذرم.\n\nسؤالم این بود: ${p.ask}',
          chips: [...p.options, _dontKnowChip],
        );
      }
      return _out(
        'هر سؤالی که می‌پرسم برای این است که جوابم به وضعیت خود شما بخورد، نه یک توضیح کلی که به درد همه و هیچ‌کس می‌خورد. در حقوق، یک جزئیات کوچک (مثل یک تاریخ یا یک امضا) می‌تواند نتیجه را عوض کند.',
        chips: _idleChips(),
      );
    }
    if (w <= 6 && Sense.has(n, 'خلاصه|جمع ?بندی|در یک جمله|تهش چی|آخرش چی')) {
      return _summary(topic);
    }
    if (w <= 6 &&
        Sense.has(n,
            'ساده ?تر|ساده بگو|نفهمیدم|متوجه نشدم|گیج شدم|پیچیده|دوباره بگو|یه بار دیگه|نگرفتم')) {
      if (_lastBody.isEmpty) {
        return _out('چیزی نگفته‌ام که پیچیده باشد! بگویید چه مشکلی پیش آمده تا ساده و روشن توضیح بدهم.',
            chips: _idleChips());
      }
      final lines = <String>[
        for (final l in _strip(_lastBody).split('\n'))
          if (l.trim().isNotEmpty) _brief(l.trim()),
      ];
      return _out(
        'حق با شماست، ساده‌ترش می‌کنم:\n${lines.take(6).join('\n')}\n\nاگر کلمه‌ای گنگ بود، همان را بپرسید؛ مثلاً «اعسار یعنی چی؟».',
        chips: topic == null ? _idleChips() : _suggest(topic),
      );
    }
    if (w <= 10 &&
        Sense.has(n,
            'هیچ راهی|راهی نیست|راهی نداره|پولم رفت|کاری نمیشه کرد|یعنی هیچی|بیچاره شدم|بدبخت شدم|امیدی نیست|دستم به جایی')) {
      if (topic == null) {
        return _out(
          'هنوز برای ناامیدشدن زود است. تقریباً همیشه راهی هست؛ فقط باید بدانیم کدام. ماجرا را تعریف کنید تا با هم نگاهش کنیم.',
          chips: starterChips,
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
        'هنوز ماجرایی تعریف نکرده‌اید که خلاصه‌اش کنم. بگویید چه شده؛ کوتاه هم بگویید کافی است.',
        chips: starterChips,
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
    return _out(sb.toString().trimRight(), chips: _suggest(topic));
  }

  AdvocateReply? _social(String n, Topic? topic) {
    final w = Sense.words(n);
    if (w > 7) return null;
    if (Sense.has(n, 'ممنون|مرسی|متشکر|سپاس|دستت درد نکنه|دمت گرم|لطف کردی|تشکر')) {
      return _out(
        topic == null
            ? 'خواهش می‌کنم. هر وقت سؤالی بود، همین‌جا هستم.'
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
            ? 'سلام، خوش آمدید. من دستیار حقوقی شما هستم. ماجرا را همان‌طور که هست و به زبان خودتان تعریف کنید: چه اتفاقی افتاده، طرف مقابل کیست و الان چه می‌خواهید؟'
            : 'سلام دوباره. پرونده‌تان را به خاطر دارم؛ هر جا ماندیم ادامه بدهیم.',
        chips: _idleChips(),
      );
    }
    if (Sense.has(n, 'خوبی|چطوری|حالت چطوره|چه خبر')) {
      return _out('ممنون که می‌پرسید. من آماده‌ام؛ بگویید چه کمکی از دستم برمی‌آید.',
          chips: _idleChips());
    }
    return null;
  }

  bool _vague(String n) =>
      Sense.words(n) <= 9 &&
      Sense.has(n,
          'مشکل(?:ی)? (?:حقوقی |قانونی )?(?:دارم|پیش اومده|برام)|سوال(?:ی)? (?:حقوقی )?(?:داشتم|دارم)|مشاوره|کمک(?:م)? (?:کن|میخوام|کنید)|راهنمایی(?:م)? (?:کن|میخوام|کنید)|گرفتار شدم|یه مسئله');

  AdvocateReply _intake() => _out(
        'در خدمتم. برای اینکه درست راهنمایی کنم، ماجرا را کوتاه تعریف کنید:\n'
        '• طرف مقابل کیست؟ (صاحبخانه، کارفرما، همسر، شریک، همسایه، یک اداره…)\n'
        '• چه اتفاقی افتاده؟\n'
        '• الان چه می‌خواهید؟ (پولتان را بگیرید، از خودتان دفاع کنید، جدا شوید…)\n'
        'لازم نیست رسمی بنویسید؛ همان‌طور که برای یک دوست تعریف می‌کنید کافی است.',
        chips: starterChips,
      );

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
    if (legalish && Sense.words(n) >= 2) {
      final r = engine.query(raw);
      if (r.contextHits.isNotEmpty) {
        final laws = [
          for (final h in r.contextHits.take(2))
            LawText(h.chunk.title, h.chunk.source, h.chunk.body, ''),
        ];
        final lead = direct
            ? 'این متنِ همان ماده در بانک قوانین من است:'
            : 'برای این پرسش تحلیل آماده‌ای ندارم، ولی نزدیک‌ترین متن قانونی که در بانک قوانینم پیدا کردم این است (ممکن است دقیقاً جواب شما نباشد):';
        return AdvocateReply(
          '$lead\n\n${r.text}\n\n'
          'اگر ماجرای خودتان را تعریف کنید (چه شد، طرف مقابل کیست، چه می‌خواهید)، می‌توانم متناسب با وضعیت شما راهنمایی کنم.',
          chips: _idleChips(),
          laws: laws,
        );
      }
    }
    if (!legalish && Sense.isQuestion(n)) {
      return _out(
        'این یکی از حوزهٔ کار من بیرون است؛ من فقط در مسائل حقوقی (اجاره، کار، چک و طلب، خانواده، شکایت و دفاع و مانند این‌ها) می‌توانم کمک کنم. اگر گرفتاری حقوقی دارید، همان را تعریف کنید.',
        chips: _idleChips(),
      );
    }
    return _out(
      'راستش این را درست متوجه نشدم، و نمی‌خواهم حدسی جواب بدهم که گمراهتان کند. اگر ماجرا را با چند جملهٔ ساده تعریف کنید (چه شد، طرف مقابل کیست، چه می‌خواهید)، بهتر می‌توانم کمک کنم.',
      chips: _idleChips(),
    );
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
    if (g.followUp.isNotEmpty) sb.write('\n\n${g.followUp}');
    _lastBody = g.answer;
    return _out(sb.toString(), chips: _guideChips(g));
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
    final out = <String>['قدم بعدی چیست؟', 'خلاصه بگو'];
    for (final id in g.templateIds) {
      final title = _draftTitles[id];
      if (title != null) {
        out.add(title);
        break;
      }
    }
    out.add(newCaseChip);
    return out;
  }

  AdvocateReply? _guideFollow(LegalGuide g, String n) {
    final gl = _glossary(n);
    if (gl != null) return _out(gl, chips: _guideChips(g));
    final kind = Sense.followKind(n);
    if (kind == 'next' && g.steps.isNotEmpty) {
      return _out('برای «${g.title}»${_guideSteps(g).replaceFirst('\n\n', ' ')}',
          chips: _guideChips(g));
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

  AdvocateReply _out(String text, {List<String> chips = const []}) {
    final laws = <LawText>[];
    final quotes = <String>[];
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
        if (seen.add(key)) {
          laws.add(LawText(label, c.source, c.body, ''));
          if (!_quoted.contains(key) && quotes.length < 2) {
            _quoted.add(key);
            quotes.add('• $label: «${_snippet(c.body)}»');
          }
        }
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
    if (quotes.isNotEmpty) {
      body = '$body\n\nمتن قانون، برای اینکه خودتان ببینید:\n${quotes.join('\n')}';
    }
    if (laws.isNotEmpty && !file.disclaimed) {
      file.disclaimed = true;
      body =
          '$body\n\nیادآوری: این راهنمایی بر پایهٔ همان چیزی است که شما گفته‌اید و جای بررسی مدارک توسط وکیل دادگستری را نمی‌گیرد.';
    }
    return AdvocateReply(body, chips: chips, laws: laws);
  }
}
