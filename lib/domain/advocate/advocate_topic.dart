part of 'advocate.dart';

// تشخیص موضوع: کدام پرونده به حرف کاربر می‌خورد.

/// امتیاز یک موضوع برای متنِ نرمال‌شده: جمع وزن نشانه‌هایی که در متن هست.
int _score(Topic t, String n) {
  if (t.anti.isNotEmpty && Sense.has(n, t.anti)) return 0;
  var s = 0;
  for (final e in t.cues.entries) {
    if (Sense.has(n, e.key)) s += e.value;
  }
  return s;
}

extension _TopicPicking on Advocate {
  Topic? _current() {
    for (final t in Advocate.topics) {
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

  bool _guessable(String n) =>
      _guide == null &&
      Sense.words(n) >= 3 &&
      !Sense.has(n, '(?:ماده|اصل) [0-9]+') &&
      !_generalChoice(n);

  /// «بهترین کتاب برای برنامه‌نویسی کدام است؟» پرسش عمومی است، نه ماجرای
  /// حقوقی؛ حدسِ موضوع و پرسش «کدام نزدیک‌تر است؟» برایش نمی‌آید تا به
  /// پاسخ «خارج از حوزه» برسد.
  bool _generalChoice(String n) =>
      Sense.has(n, 'بهترین|کدوم|کدام') &&
      !Sense.has(n,
          'قانون|حق|حقوق|جرم|مجازات|دادگاه|شکایت|قرارداد|ارث|مهریه|اجاره|کرایه|طلب|بدهی|چک|کارفرما|کارگر|حقوقی|پول|ملک|خونه|خانه|وکیل|موجر|مستاجر|همسر|طلاق|زن|شوهر|بچه|ضامن|شرکت|تصادف|کلاهبرداری|قاضی');

  /// موضوعِ هم‌معنای یک دستهٔ مدل؛ بین چند نامزد، آن‌که قاعده‌ها هم
  /// نشانه‌ای از آن دیده‌اند.
  Topic? _guessTopic(String label, String n, Map<String, int> scores) {
    Topic? pick;
    var top = -1;
    for (final id in Advocate.guessTopics[label] ?? const <String>[]) {
      for (final t in Advocate.topics) {
        if (t.id != id) continue;
        if (t.anti.isNotEmpty && Sense.has(n, t.anti)) continue;
        final s = scores[id] ?? 0;
        if (s > top) {
          pick = t;
          top = s;
        }
      }
    }
    return pick;
  }

  /// نظر دوم از خوانندهٔ موضوع: حدسِ مطمئن پرونده را باز می‌کند (و کاربر
  /// می‌تواند بگوید اشتباه است)، حدسِ نامطمئن به پرسش از خودِ کاربر می‌رسد،
  /// و پایین‌تر از آن نادیده گرفته می‌شود.
  AdvocateReply? _fromGuess(
      TopicGuess g, String raw, String n, Map<String, int> scores) {
    if (!g.plausible || !_guessable(n)) return null;
    final first = _guessTopic(g.label, n, scores);
    if (first == null) return null;
    if (g.confident) {
      _loose.removeLast();
      final r = _open(first, n, guessed: true);
      _guessed = true;
      return AdvocateReply(r.text,
          chips: [Advocate.wrongChip, ...r.chips],
          laws: r.laws,
          source: AnswerSource.guess);
    }
    final second = _guessTopic(g.second, n, scores);
    final list = <Topic>[
      first,
      if (second != null && second.id != first.id) second,
    ];
    _loose.removeLast();
    _choices = list;
    _choiceText = raw;
    return _out(
      'می‌خواهم مطمئن شوم موضوع را درست گرفته‌ام.',
      ask: list.length == 1
          ? 'ماجرای شما دربارهٔ «${first.title}» است؟'
          : 'ماجرای شما به کدام نزدیک‌تر است؟',
      chips: [for (final t in list) t.title, Advocate.noneChip],
    );
  }

  /// نظر دوم از طبقه‌بند نیت، وقتی قاعده‌ها موضوع را نشناخته‌اند.
  Topic? _secondOpinion(String raw, String n) {
    final net = intentNet;
    if (net == null || _guide != null || Sense.words(n) < 3) return null;
    if (Sense.has(n, '(?:ماده|اصل) [0-9]+')) return null;
    final top = net.classify(raw);
    if (top.score < Advocate.netMin) return null;
    final id = Advocate.netTopics[top.label];
    if (id == null) return null;
    for (final t in Advocate.topics) {
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
}
