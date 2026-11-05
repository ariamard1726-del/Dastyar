import 'dart:convert';

/// مراحلِ یک «نوبت گفت‌وگو» که [DebugLogger] ثبت می‌کند.
///
/// ترتیب اعضا همان ترتیب طبیعیِ پردازش یک پیام است و گزارشِ متنی هم به
/// همین ترتیب چاپ می‌شود:
/// ورودی کاربر ← نیت ← اسلات‌ها ← شواهد بازیابی‌شده ← پرامپت نهایی ←
/// خروجی مدل ← گارد استناد ← پاسخ نهایی کاربر.
enum TurnStage {
  /// پیام خام کاربر و متن یکدست‌شدهٔ آن.
  input,

  /// طبقه‌بندی نیت (شبکهٔ عصبی) و موضوع/دامنهٔ تشخیص‌داده‌شده.
  intent,

  /// اسلات‌های استخراج‌شده و تغییراتشان نسبت به نوبت قبل.
  slots,

  /// مواد قانونیِ بازیابی‌شده (RAG) که به مدل داده می‌شوند.
  retrieval,

  /// پرامپت نهاییِ فرستاده‌شده به مدل زبانی.
  prompt,

  /// خروجی مدل زبانی (در حالت استریم، متنِ انباشته).
  llm,

  /// تصمیم گاردِ استناد: پاسخ پذیرفته شد یا به پاسخ موتور بازگشت.
  guard,

  /// پاسخ نهایی که به کاربر نشان داده می‌شود.
  response,

  /// خطای غیرمنتظره در میانهٔ پردازش نوبت.
  error,
}

/// یک رویداد تکی درون یک نوبت.
///
/// `data` باید JSON-friendly باشد (Map/List/String/num/bool/null) تا
/// [TurnTrace.toJson] بدون تبدیل اضافی کار کند.
class DebugEvent {
  final TurnStage stage;
  final String label;
  final Object? data;

  /// میلی‌ثانیه‌های سپری‌شده از آغاز نوبت تا وقوع این رویداد.
  final int millis;

  const DebugEvent({
    required this.stage,
    required this.label,
    this.data,
    this.millis = 0,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'stage': stage.name,
        'label': label,
        'millis': millis,
        if (data != null) 'data': data,
      };

  /// یک خط خوانا برای لاگ کنسول.
  String toLine() {
    final head = '[${stage.name}] $label';
    if (data == null) return head;
    final encoded = _encode(data);
    return '$head = $encoded';
  }

  static String _encode(Object? value) {
    try {
      return jsonEncode(value);
    } catch (_) {
      return value.toString();
    }
  }
}

/// ردِ کاملِ یک نوبت گفت‌وگو: از پیام کاربر تا پاسخ نهایی.
///
/// اگر لاگر خاموش باشد، [enabled] برابر false است و هیچ رویدادی ذخیره
/// نمی‌شود؛ بنابراین فراخوانی‌های `add` در کدِ تولیدی هزینهٔ حافظه ندارند.
class TurnTrace {
  TurnTrace({
    required this.id,
    required this.input,
    DateTime? startedAt,
    this.enabled = true,
  }) : startedAt = startedAt ?? DateTime.now();

  final String id;
  final String input;
  final DateTime startedAt;
  final bool enabled;

  final List<DebugEvent> events = <DebugEvent>[];
  DateTime? _finishedAt;

  bool get isClosed => _finishedAt != null;

  Duration get elapsed => (_finishedAt ?? DateTime.now()).difference(startedAt);

  /// افزودن یک رویداد. در حالت خاموش، هیچ کاری نمی‌کند.
  void add(TurnStage stage, String label, [Object? data]) {
    if (!enabled || _finishedAt != null) return;
    events.add(
      DebugEvent(
        stage: stage,
        label: label,
        data: data,
        millis: DateTime.now().difference(startedAt).inMilliseconds,
      ),
    );
  }

  /// بستن نوبت؛ پس از آن رویداد تازه‌ای پذیرفته نمی‌شود.
  void close() {
    _finishedAt ??= DateTime.now();
  }

  Iterable<DebugEvent> ofStage(TurnStage stage) =>
      events.where((e) => e.stage == stage);

  DebugEvent? lastOf(TurnStage stage) {
    for (final e in events.reversed) {
      if (e.stage == stage) return e;
    }
    return null;
  }

  /// مسیری که مشاور حقوقی برای این نوبت انتخاب کرده (اگر ثبت شده باشد).
  String? get route {
    final e = lastOf(TurnStage.intent);
    final data = e?.data;
    if (data is Map && data['route'] is String) return data['route'] as String;
    return null;
  }

  /// پاسخ نهاییِ ثبت‌شده در مرحلهٔ [TurnStage.response].
  String? get finalAnswer {
    final data = lastOf(TurnStage.response)?.data;
    if (data is Map && data['text'] is String) return data['text'] as String;
    return null;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'input': input,
        'started_at': startedAt.toIso8601String(),
        'elapsed_ms': elapsed.inMilliseconds,
        'events': events.map((e) => e.toJson()).toList(),
      };

  /// گزارش خوانا برای کنسول یا فایل متنی.
  String toText() {
    final sb = StringBuffer()
      ..writeln('── نوبت $id (${elapsed.inMilliseconds} میلی‌ثانیه) ──')
      ..writeln('ورودی: $input');
    for (final e in events) {
      sb.writeln('  ${e.toLine()}');
    }
    return sb.toString();
  }
}

/// مقصد دریافت رویدادهای دیباگ.
///
/// پیاده‌سازی‌ها باید سبک و بی‌خطر باشند؛ [DebugLogger] هر خطای مقصد را
/// می‌بلعد تا اشکالِ لاگ هرگز پاسخ کاربر را خراب نکند.
abstract class DebugSink {
  const DebugSink();

  void onEvent(TurnTrace trace, DebugEvent event);

  /// هنگام بسته‌شدن نوبت فراخوانی می‌شود.
  void onTurn(TurnTrace trace) {}
}

/// چاپ رویدادها در کنسول (برای اجرای دستیِ ابزار ارزیابی).
class ConsoleDebugSink extends DebugSink {
  ConsoleDebugSink({this.write = _stdoutWrite, this.verbose = true});

  final void Function(String line) write;
  final bool verbose;

  // ignore: avoid_print
  static void _stdoutWrite(String line) => print(line);

  @override
  void onEvent(TurnTrace trace, DebugEvent event) {
    if (!verbose && event.stage != TurnStage.error) return;
    write('  ${event.toLine()}');
  }

  @override
  void onTurn(TurnTrace trace) => write(trace.toText());
}

/// نگه‌داشتن ردِ نوبت‌های کامل در حافظه (برای تست و صفحهٔ دیباگِ درون‌برنامه).
class MemoryDebugSink extends DebugSink {
  MemoryDebugSink({this.capacity = 50});

  final int capacity;
  final List<TurnTrace> turns = <TurnTrace>[];

  /// رویدادهای درون‌نوبتی جداگانه ذخیره نمی‌شوند؛ خودِ [TurnTrace] آن‌ها
  /// را دارد و در [onTurn] یک‌جا نگه‌داری می‌شود.
  @override
  void onEvent(TurnTrace trace, DebugEvent event) {}

  @override
  void onTurn(TurnTrace trace) {
    turns.add(trace);
    while (turns.length > capacity) {
      turns.removeAt(0);
    }
  }

  void clear() => turns.clear();
}

/// لاگر ساختاریافتهٔ نوبت‌های گفت‌وگو.
///
/// چرا لازم است؟ پاسخ «عجیب» یک ربات حقوقی معمولاً از یکی از این پنج
/// حلقه می‌آید: نیت اشتباه، اسلاتِ اشتباه، شواهد بی‌ربط، پرامپت ناقص، یا
/// خروجیِ مدل. بدون ردِ مرحله‌به‌مرحله، عیب‌یابی حدس‌وگمان است.
///
/// * پیش‌فرض **خاموش** است تا در نسخهٔ تولیدی هیچ هزینه یا نشت اطلاعاتی
///   نداشته باشد؛ با `DebugLogger.instance.enabled = true` روشن می‌شود.
/// * فقط [capacity] نوبت آخر نگه داشته می‌شود (حلقهٔ حافظهٔ ثابت).
/// * متن کاربر پیش از ثبت می‌تواند با [redact] ماسک شود (شمارهٔ تلفن،
///   کد ملی، ایمیل) تا لاگ برای اشتراک‌گذاری امن باشد.
class DebugLogger {
  DebugLogger({
    bool enabled = false,
    this.capacity = 50,
    List<DebugSink>? sinks,
    this.redactInput = false,
  })  : _enabled = enabled,
        sinks = List<DebugSink>.unmodifiable(sinks ?? const <DebugSink>[]);

  /// لاگر سراسری؛ کدِ تولیدی و تست‌ها از همین نمونه استفاده می‌کنند.
  static DebugLogger instance = DebugLogger();

  final int capacity;
  final List<DebugSink> sinks;
  final bool redactInput;

  final List<TurnTrace> _traces = <TurnTrace>[];
  int _seq = 0;
  bool _enabled;

  bool get enabled => _enabled;

  set enabled(bool value) => _enabled = value;

  /// نوبت‌های نگه‌داری‌شده (قدیمی‌ترین اول).
  List<TurnTrace> get traces => List<TurnTrace>.unmodifiable(_traces);

  TurnTrace? get last => _traces.isEmpty ? null : _traces.last;

  /// آغاز یک نوبت تازه. در حالت خاموش، ردِ غیرفعال برمی‌گردد.
  TurnTrace start(String input) {
    final trace = TurnTrace(
      id: 'turn-${++_seq}',
      input: redactInput ? redact(input) : input,
      enabled: _enabled,
    );
    if (_enabled) {
      _traces.add(trace);
      while (_traces.length > capacity) {
        _traces.removeAt(0);
      }
    }
    return trace;
  }

  /// ثبت یک رویداد هم‌زمان در ردِ نوبت و در همهٔ [sinks].
  void record(TurnTrace trace, TurnStage stage, String label, [Object? data]) {
    if (!_enabled || !trace.enabled || trace.isClosed) return;
    trace.add(stage, label, data);
    final event = trace.events.isEmpty ? null : trace.events.last;
    if (event == null) return;
    for (final sink in sinks) {
      try {
        sink.onEvent(trace, event);
      } catch (_) {
        // لاگ هرگز نباید مسیر پاسخ‌دهی را قطع کند.
      }
    }
  }

  /// بستن نوبت و آگاه‌کردن مقصدها.
  void finish(TurnTrace trace) {
    if (!_enabled || !trace.enabled || trace.isClosed) return;
    trace.close();
    for (final sink in sinks) {
      try {
        sink.onTurn(trace);
      } catch (_) {
        // بی‌اثر
      }
    }
  }

  void clear() {
    _traces.clear();
    for (final sink in sinks) {
      if (sink is MemoryDebugSink) sink.clear();
    }
  }

  /// خروجی JSON با همهٔ نوبت‌های نگه‌داری‌شده.
  String exportJson({bool pretty = true}) {
    final payload = <String, dynamic>{
      'turns': _traces.map((t) => t.toJson()).toList(),
    };
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(payload)
        : jsonEncode(payload);
  }

  /// خروجی متنیِ خوانا از همهٔ نوبت‌ها.
  String exportText() {
    final sb = StringBuffer();
    for (final t in _traces) {
      sb.writeln(t.toText());
    }
    return sb.toString();
  }

  static final RegExp _emailRe = RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+');

  /// شمارهٔ همراه ایران (۱۱ رقم، پیشوند ۰۹) با یا بدون جداکننده.
  static final RegExp _mobileRe = RegExp(r'09\d{2}[\s-]?\d{3}[\s-]?\d{4}');

  /// شمارهٔ ثابت با کد شهرِ جدا شده: ۰۲۱-۸۸۷۷۶۶۵۵.
  static final RegExp _landlineRe = RegExp(r'0\d{2}[\s-]\d{3}[\s-]?\d{4}');

  /// هر عددِ ۸ رقم یا بلندتر (کد ملی، شماره حساب، مبلغِ دقیق).
  static final RegExp _longDigitRe = RegExp(r'\d{8,}');

  /// ماسک‌کردن دادهٔ شخصی پیش از ثبت در لاگ.
  static String redact(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAll(_emailRe, '«ایمیل»')
        .replaceAll(_mobileRe, '«تلفن»')
        .replaceAll(_landlineRe, '«تلفن»')
        .replaceAll(_longDigitRe, '«عدد»');
  }
}
