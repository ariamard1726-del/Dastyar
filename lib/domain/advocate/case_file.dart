/// پروندهٔ ذهنی وکیل دربارهٔ ماجرای کاربر در یک گفتگو.
class CaseFile {
  /// شناسهٔ موضوع جاری (خالی = هنوز موضوعی باز نشده).
  String topic = '';

  /// واقعیت‌های پرونده: نام → مقدار («yes»، «no»، عدد، برچسب). مقدار «?»
  /// یعنی کاربر گفته نمی‌داند.
  final Map<String, String> facts = {};

  /// هر پرسش چند بار پرسیده شده (برای اینکه یک پرسش تکرار نشود).
  final Map<String, int> askCount = {};

  /// پرسشی که آخرین پاسخ با آن تمام شد و منتظر جوابش هستیم.
  String pending = '';

  /// مسائلی که تا اینجا درباره‌شان توضیح داده شده.
  final Set<String> covered = {};

  /// آخرین بخشی که توضیح داده شد (برای «ساده‌تر بگو»).
  String lastKey = '';

  int turns = 0;
  bool disclaimed = false;

  bool has(String k) => facts.containsKey(k) && facts[k] != '?';
  bool touched(String k) => facts.containsKey(k);
  bool yes(String k) => facts[k] == 'yes';
  bool no(String k) => facts[k] == 'no';
  bool eq(String k, String v) => facts[k] == v;
  String get(String k) => facts[k] ?? '';
  int? n(String k) => int.tryParse(facts[k] ?? '');

  void clearCase() {
    topic = '';
    facts.clear();
    askCount.clear();
    pending = '';
    covered.clear();
    lastKey = '';
  }
}

typedef Body = String Function(CaseFile f);
typedef Reader = String? Function(String n);
typedef Cond = bool Function(CaseFile f);

/// یک واقعیتِ مهم پرونده که وکیل باید بداند.
class Slot {
  final String id;

  /// پرسشی که وکیل از کاربر می‌پرسد.
  final String ask;

  /// چرا این پرسش مهم است (پاسخ «چرا می‌پرسی؟»).
  final String why;

  /// دکمه‌های پاسخ پیشنهادی.
  final List<String> options;

  /// خواندن مقدار از هر پیامِ کاربر (نه فقط پاسخ همین پرسش).
  final Reader read;

  /// خواندنِ آسان‌گیرتر، فقط وقتی همین پرسش در انتظار پاسخ است.
  final Reader? readPending;

  /// معنای «بله/نه»ی خشک‌وخالی وقتی این پرسش در انتظار است (خالی = بی‌معنا).
  final String yesValue;
  final String noValue;

  /// اثر حقوقیِ این واقعیت؛ وقتی کاربر آن را می‌گوید وکیل همین را توضیح
  /// می‌دهد.
  final Body? effect;

  /// شرط پرسیدن.
  final Cond? when;

  Slot({
    required this.id,
    required this.ask,
    required this.why,
    required this.read,
    this.readPending,
    this.options = const [],
    this.yesValue = 'yes',
    this.noValue = 'no',
    this.effect,
    this.when,
  });
}

/// پرسشی که کاربر ممکن است در این موضوع بپرسد و پاسخ وکیل به آن.
class Issue {
  final String id;

  /// متن دکمهٔ پیشنهادی (به زبان کاربر).
  final String chip;

  /// الگوی تشخیص.
  final String cues;
  final Body body;
  final Cond? when;

  Issue({
    required this.id,
    required this.chip,
    required this.cues,
    required this.body,
    this.when,
  });
}

class Topic {
  final String id;
  final String title;

  /// الگو → وزن. جمع وزن‌ها امتیاز موضوع است.
  final Map<String, int> cues;

  /// اگر یکی از این‌ها در متن باشد، موضوع رد می‌شود.
  final String anti;
  final List<Slot> slots;
  final List<Issue> issues;

  /// نخستین ارزیابی وکیل.
  final Body opening;

  /// پاسخ به پرسش‌های عمومیِ پیگیری: next, where, cost, time, deadline,
  /// chance, evidence, refuse, lawyer.
  final Map<String, Body> follow;

  /// شناسهٔ قالب‌های سند مرتبط (به ترتیب اولویت).
  final List<String> Function(CaseFile f)? drafts;

  Topic({
    required this.id,
    required this.title,
    required this.cues,
    required this.slots,
    required this.issues,
    required this.opening,
    required this.follow,
    this.anti = '',
    this.drafts,
  });
}
