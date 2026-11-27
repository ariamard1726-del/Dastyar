part of 'advocate.dart';

// تشخیص موضوع: کدام پرونده به حرف کاربر می‌خورد.
//
// این ده متد پیش‌تر روی `Advocate` بودند؛ برای آزمودنِ «این پیام جوابِ همان
// پرسشِ باز است یا نه؟» باید یک وکیلِ کامل با موتور و صدا ساخته می‌شد. حالا
// `TopicPicker` فقط پرونده، وضعیتِ روی میز، طبقه‌بندِ نیت و یک راهِ بازکردنِ
// پرونده را می‌گیرد. تصمیمِ «کدام مسیر این پیام را جواب می‌دهد» همچنان کارِ
// وکیل است، ولی خودِ تشخیص این‌جا آزمون‌شدنی است.

/// تشخیص موضوع و بحث، بی‌نیاز از خودِ وکیل.
class TopicPicker {
  TopicPicker({
    required this.file,
    required this.dialog,
    required this.intentNet,
    required this.open,
    required this.voice,
  });

  final CaseFile file;
  final DialogueState dialog;

  /// طبقه‌بندِ نیت (می‌تواند نباشد).
  final IntentNet? intentNet;

  /// بازکردنِ پرونده با موضوعی که حدس زده‌ام؛ خودِ روندِ پرونده کارِ وکیل است.
  final AdvocateReply Function(Topic t, String n, {bool guessed}) open;

  /// صدا؛ تنبل می‌گیریمش تا آزمونِ تشخیصِ موضوع به صدای واقعی نیاز نداشته باشد.
  final ReplyVoice Function() voice;

  AdvocateReply _out(
    String text, {
    List<String> chips = const [],
    String ask = '',
    bool full = false,
    int budget = _budget,
    AnswerSource source = AnswerSource.topic,
  }) =>
      voice().out(text,
          chips: chips, ask: ask, full: full, budget: budget, source: source);

  Topic? current() {
    for (final t in Advocate.topics) {
      if (t.id == file.topic) return t;
    }
    return null;
  }

  /// آیا این پیام جوابِ همان پرسشی است که منتظرش بودم؟
  bool answers(Topic t, String n) {
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
  String sideNote() {
    final s = dialog.side;
    if (s == null) return '';
    return 'به «${s.title}» هم اشاره کردید. این ماجرای جداگانه‌ای است، یا به همین پرونده مربوط می‌شود؟';
  }

  bool guessable(String n) =>
      dialog.guide == null &&
      Sense.words(n) >= 3 &&
      !Sense.has(n, '(?:ماده|اصل) [0-9]+') &&
      !generalChoice(n);

  /// «بهترین کتاب برای برنامه‌نویسی کدام است؟» پرسش عمومی است، نه ماجرای
  /// حقوقی؛ حدسِ موضوع و پرسش «کدام نزدیک‌تر است؟» برایش نمی‌آید تا به
  /// پاسخ «خارج از حوزه» برسد.
  bool generalChoice(String n) =>
      Sense.has(n, 'بهترین|کدوم|کدام') &&
      !Sense.has(n,
          'قانون|حق|حقوق|جرم|مجازات|دادگاه|شکایت|قرارداد|ارث|مهریه|اجاره|کرایه|طلب|بدهی|چک|کارفرما|کارگر|حقوقی|پول|ملک|خونه|خانه|وکیل|موجر|مستاجر|همسر|طلاق|زن|شوهر|بچه|ضامن|شرکت|تصادف|کلاهبرداری|قاضی');

  /// موضوعِ هم‌معنای یک دستهٔ مدل؛ بین چند نامزد، آن‌که قاعده‌ها هم
  /// نشانه‌ای از آن دیده‌اند.
  Topic? guessTopic(String label, String n, Map<String, int> scores) {
    Topic? pick;
    var top = -1;
    for (final id in guessTopics[label] ?? const <String>[]) {
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
  AdvocateReply? fromGuess(
      TopicGuess g, String raw, String n, Map<String, int> scores) {
    if (!g.plausible || !guessable(n)) return null;
    final first = guessTopic(g.label, n, scores);
    if (first == null) return null;
    if (g.confident) {
      dialog.loose.removeLast();
      final r = open(first, n, guessed: true);
      dialog.guessed = true;
      return AdvocateReply(r.text,
          chips: [ChipTexts.wrongChip, ...r.chips],
          laws: r.laws,
          source: AnswerSource.guess,
          ask: r.ask);
    }
    final second = guessTopic(g.second, n, scores);
    final list = <Topic>[
      first,
      if (second != null && second.id != first.id) second,
    ];
    dialog.loose.removeLast();
    dialog.choices = list;
    dialog.choiceText = raw;
    return _out(
      'می‌خواهم مطمئن شوم موضوع را درست گرفته‌ام.',
      ask: list.length == 1
          ? 'ماجرای شما دربارهٔ «${first.title}» است؟'
          : 'ماجرای شما به کدام نزدیک‌تر است؟',
      chips: [for (final t in list) t.title, ChipTexts.noneChip],
    );
  }

  /// نظر دوم از طبقه‌بند نیت، وقتی قاعده‌ها موضوع را نشناخته‌اند.
  Topic? secondOpinion(String raw, String n) {
    final net = intentNet;
    if (net == null || dialog.guide != null || Sense.words(n) < 3) return null;
    if (Sense.has(n, '(?:ماده|اصل) [0-9]+')) return null;
    final top = net.classify(raw);
    if (top.score < netMin) return null;
    final id = netTopics[top.label];
    if (id == null) return null;
    for (final t in Advocate.topics) {
      if (t.id != id) continue;
      if (t.anti.isNotEmpty && Sense.has(n, t.anti)) return null;
      return t;
    }
    return null;
  }

  Issue? matchIssue(Topic t, String n) {
    for (final i in t.issues) {
      final w = i.when;
      if (w != null && !w(file)) continue;
      if (Sense.has(n, i.cues)) return i;
    }
    return null;
  }

  /// راهنمای آماده برای پیام؛ واژهٔ تک‌افتاده‌ای مثل «صیادیه» نباید به
  /// «دیه» بخورد.
  LegalGuide? matchGuide(String raw, String n) {
    if (Sense.has(n, 'صیاد')) return null;
    return LawyerVoice.matchGuide(raw);
  }
}
