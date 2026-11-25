part of 'advocate.dart';

// روندِ پرونده: وضعیتِ پروندهٔ باز و ابزارهای کوتاهِ پاسخ.
//
// این کلاس عمداً کوچک است: فقط پرونده، گفتگو، صدا و همکارانی که هر تصمیم به
// آن‌ها نیاز دارد. سه مسئولیتِ سنگین‌تر در بخش‌های خودشان‌اند و هر کدام با یک
// `extension` روی همین کلاس به همان وضعیت دسترسی دارند (هم‌کتابخانه، پس
// متدها خصوصی می‌مانند و سطحِ عمومی عوض نمی‌شود):
//
//  • `case_facts.dart`  — واقعیت‌ها: شنیدنِ حرفِ تازه، برعکس شدن، بستن.
//  • `case_answer.dart` — پاسخِ نوبت: بازکردن، پاسخِ درونِ پرونده، جمع‌بندی.
//  • `case_text.dart`   — متنِ پاسخ: پیشنهادِ سند، اثرها، پرسشِ بعدی، واکنش.
//
// چیزی که این‌جا *نیست* و نباید باشد: تصمیمِ «این پیام مالِ کدام مسیر است».

class CaseFlow {
  CaseFlow({
    required this.file,
    required this.dialog,
    required this.voice,
    required this.argument,
    required this.picker,
    required this.talk,
    required this.law,
    required this.chipPlan,
    required this.filings,
    required this.draftTitles,
    required this.echo,
    required this.flips,
    required this.glossary,
    required this.openGuide,
    required this.fillFor,
    required this.draftIds,
  });

  final CaseFile file;
  final DialogueState dialog;
  final ReplyVoice voice;

  /// استدلال: ارکانِ ادعاها، حکم، تغییرِ نتیجه و اصلاحِ برداشت.
  final CaseArgument argument;

  /// تشخیصِ بحث و راهنما از متن.
  final TopicPicker picker;

  /// گفت‌وگوی انسانی (احوال‌پرسی، نامفهوم).
  final TalkReply talk;

  /// پاسخ از بانک قوانین، وقتی حرفِ کاربر به متنِ قانون می‌خورد.
  final LawAnswer law;

  /// دکمه‌های پیشنهادی؛ سازنده‌اش هر بار از پروندهٔ جاری ساخته می‌شود.
  final ChipPlan Function() chipPlan;

  /// سندهایی که تا حالا تنظیم شده‌اند (برای پیشنهادِ بعدی).
  final List<Filing> Function() filings;

  /// عنوانِ هر قالب (برای دکمهٔ «تنظیم …»).
  final Map<String, String> draftTitles;

  /// واقعیت‌هایی که کاربر در همین گفتگو گفته (برای «شنیدم»).
  final List<Slot> echo;

  /// واقعیت‌هایی که در همین گفتگو برعکس شده‌اند.
  final Map<String, String> flips;

  /// معنیِ واژه، اگر واژه‌نامه بشناسدش.
  final String? Function(String n) glossary;

  /// بازکردنِ راهنمای آماده.
  final AdvocateReply Function(LegalGuide g, String raw, String n,
      {bool? switched}) openGuide;

  /// متنِ فیلدهای دادخواست برای یک قالب (در وکیل: `fillFor`).
  final Map<String, String> Function(String templateId) fillFor;

  /// شناسهٔ قالب‌هایی که عنوان دارند، به ترتیبِ پیشنهاد.
  final List<String> draftIds;


  bool get hasCase => file.topic.isNotEmpty || dialog.guide != null;

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

  String _pick(List<String> options) => voice.pick(options);

  void clearOffer() => dialog.clearOffer();

  /// پاسخِ آخرین راه: بانک قوانین، با همان پرونده‌ای که باز است.
  AdvocateReply? _lookup(String raw, String n) =>
      law.lookup(raw, n, hasCase: hasCase, loose: dialog.loose.length);

  /// برداشت وکیل از واقعیت‌هایی که تا اینجا شنیده است؛ منطقش در
  /// `case_recap.dart` است تا بی‌نیاز از وکیل آزمون شود.
}
