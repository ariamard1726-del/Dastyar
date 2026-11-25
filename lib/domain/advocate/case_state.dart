// پروندهٔ ذهنیِ وکیل: وضعیتِ یک گفتگو و قراردادِ JSON‌اش.
//
// این فایل فقط `CaseFile` است. هشت مدلِ زبانِ موضوع (`Element`، `Claim`،
// `Slot`، `Issue`، `Filing`، `Prompt`، `Topic` و typedefهایشان) در
// `case_model.dart` هستند؛ پیش‌تر هر نه در یک فایلِ ۴۰۱خطی زندگی می‌کردند و هر
// کسی که فقط پرونده را می‌خواست، هشت مدل را هم می‌خواند.
//
// `case_file.dart` دروازه است: همان مسیرِ پیشین و همان دو `export`، تا چهل
// فایلِ `lib/` و آزمون‌ها بی‌تغییر `import` کنند.

/// پروندهٔ ذهنی وکیل دربارهٔ ماجرای کاربر در یک گفتگو.
class CaseFile {
  /// سازندهٔ صریح؛ بدون آن، تعریف [CaseFile.fromJson] سازندهٔ پیش‌فرض ضمنی را
  /// حذف می‌کند و هر `CaseFile()` در کد و آزمون‌ها نمی‌کامپایل می‌شود.
  CaseFile();

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

  /// پروندهٔ چیز مشخصی را نگه داشته است؟ (برای اینکه پروندهٔ خالی ذخیره نشود)
  bool get hasContent => topic.isNotEmpty || facts.isNotEmpty;

  /// محتوای پروندهٔ دیگر را داخل همین نمونه می‌ریزد.
  ///
  /// [CaseFile] در `Advocate` به‌صورت `final` نگه داشته می‌شود تا هیچ‌کس
  /// نمونه را عوض نکند؛ برای بازیابی از تاریخچه، محتوا را کپی می‌کنیم.
  void copyFrom(CaseFile o) {
    topic = o.topic;
    facts
      ..clear()
      ..addAll(o.facts);
    askCount
      ..clear()
      ..addAll(o.askCount);
    covered
      ..clear()
      ..addAll(o.covered);
    pending = o.pending;
    lastKey = o.lastKey;
    turns = o.turns;
    disclaimed = o.disclaimed;
  }

  /// نسخهٔ قالب سریال‌سازی پرونده. تغییر ساختار = افزایش این عدد و نوشتن
  /// مهاجرت در [CaseFile.fromJson].
  static const int schemaVersion = 1;

  /// پرونده به‌صورت JSON؛ برای ذخیرهٔ گفتگو بدون پخش دوبارهٔ پیام‌ها.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'v': schemaVersion,
        'topic': topic,
        'facts': Map<String, String>.of(facts),
        'askCount': Map<String, int>.of(askCount),
        'pending': pending,
        'covered': covered.toList(),
        'lastKey': lastKey,
        'turns': turns,
        'disclaimed': disclaimed,
      };

  /// بازسازی پرونده از JSON. ورودی نامعتبر یا نسخهٔ ناشناخته، پروندهٔ
  /// خالی برمی‌گرداند تا گفتگو با پروندهٔ تازه ادامه یابد، نه با کرش.
  factory CaseFile.fromJson(Map<String, dynamic> j) {
    final f = CaseFile();
    final v = j['v'];
    if (v is int && v != schemaVersion) return f;
    f.topic = (j['topic'] ?? '').toString();
    final factsRaw = j['facts'];
    if (factsRaw is Map) {
      factsRaw.forEach((k, val) {
        if (k != null && val != null) f.facts[k.toString()] = val.toString();
      });
    }
    final askRaw = j['askCount'];
    if (askRaw is Map) {
      askRaw.forEach((k, val) {
        if (k != null && val is int) f.askCount[k.toString()] = val;
      });
    }
    f.pending = (j['pending'] ?? '').toString();
    final coveredRaw = j['covered'];
    if (coveredRaw is List) {
      for (final e in coveredRaw) {
        if (e != null) f.covered.add(e.toString());
      }
    }
    f.lastKey = (j['lastKey'] ?? '').toString();
    final turnsRaw = j['turns'];
    if (turnsRaw is int) f.turns = turnsRaw;
    f.disclaimed = j['disclaimed'] == true;
    return f;
  }
}
