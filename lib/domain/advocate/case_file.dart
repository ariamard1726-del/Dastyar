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

  /// سه‌حالته: برقرار (true)، نابرقرار (false)، هنوز نامعلوم (null).
  bool? tri(String k) => yes(k) ? true : (no(k) ? false : null);

  /// سه‌حالته برای واقعیت‌های برچسبی: اگر معلوم نباشد null.
  bool? isOne(String k, List<String> values) =>
      has(k) ? values.contains(facts[k]) : null;

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
typedef Tri = bool? Function(CaseFile f);

/// یک شرط قانونی که برای رسیدن به یک نتیجه باید برقرار باشد.
class Element {
  /// شرط به زبان ساده («مدت اجاره تمام شده باشد»)، همراه استناد.
  final String text;

  /// آیا با واقعیت‌های پرونده برقرار است؟ null یعنی هنوز نمی‌دانیم.
  final Tri test;

  /// اگر برقرار نباشد چه می‌شود یا چه باید کرد.
  final String ifNo;

  /// واقعیت‌هایی (شناسهٔ پرسش‌ها) که تکلیف این شرط را روشن می‌کنند. وکیل از
  /// روی همین می‌فهمد پرسش بعدی‌اش باید چه باشد.
  final List<String> needs;

  /// پایهٔ واقعیِ نتیجه به زبان خودِ کاربر («قرارداد کتبی دارید»)؛ پس از
  /// «چون» می‌آید. خالی یعنی چیزی برای گفتن نیست.
  final Body? because;

  const Element(
    this.text,
    this.test, {
    this.ifNo = '',
    this.needs = const [],
    this.because,
  });
}

/// یک ادعای حقوقی و شرط‌هایش. وکیل با سنجیدن تک‌تک شرط‌ها روی واقعیت‌های
/// همین پرونده استدلال می‌کند و نتیجه می‌گیرد (نه با متن ازپیش‌نوشته).
class Claim {
  /// نام کوتاه ادعا («حقوق معوق»)؛ وقتی یک ماجرا چند خواسته دارد، با همین
  /// نام از هم جدا می‌شوند.
  final String label;

  /// هدف به زبان کاربر («پس‌گرفتن ودیعه»).
  final String goal;

  /// این ادعا برای چه وضعیتی است.
  final Cond? when;
  final List<Element> elements;

  /// نتیجه وقتی همهٔ شرط‌ها برقرار است.
  final Body win;

  /// محکم‌ترین حرف طرف مقابل و پاسخ آن.
  final Body? counter;

  /// واقعیت‌هایی که برای حساب‌کردنِ نتیجه (مبلغ، مرجع) لازم است، نه برای
  /// برقراریِ شرط‌ها.
  final List<String> uses;

  /// نشانه‌های اینکه کاربر دربارهٔ همین خواسته می‌پرسد («می‌توانم برگردم سر
  /// کار؟»). اگر پرسشش «می‌شود/نمی‌شود» باشد، جوابش حکمِ همین ادعا روی
  /// واقعیت‌های خودش است، نه یک متن کلی.
  final String cues;

  const Claim({
    required this.goal,
    required this.elements,
    required this.win,
    this.label = '',
    this.when,
    this.counter,
    this.uses = const [],
    this.cues = '',
  });
}

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

  /// پرسشِ پایه: تا جوابش معلوم نشود، معلوم نیست کدام ادعا روی میز است؛
  /// پس پیش از هر پرسش دیگری پرسیده می‌شود.
  final bool first;

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
    this.first = false,
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

  /// واقعیت‌هایی که پاسخ این پرسش خودش اثرشان را گفته است (تا همان حرف
  /// دوباره به‌عنوان «اثر واقعیت» تکرار نشود).
  final Set<String> covers;

  Issue({
    required this.id,
    required this.chip,
    required this.cues,
    required this.body,
    this.when,
    this.covers = const {},
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

  /// ادعاهایی که وکیل می‌تواند درباره‌شان استدلال کند (به ترتیب اولویت).
  final List<Claim> claims;

  /// برداشت وکیل از واقعیت‌های پرونده، به صورت عبارت‌های کوتاهِ خطاب به
  /// کاربر («مستأجر هستید»، «ملک را تخلیه کرده‌اید»).
  final List<String> Function(CaseFile f)? recap;

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
    this.claims = const [],
    this.recap,
  });
}
