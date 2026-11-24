/// پایگاه «راهنمای وکیل»: پاسخ‌های ازپیش‌نوشته، دقیق و انسانی برای رایج‌ترین
/// مسائل حقوقی کاربران.
///
/// هر راهنما مثل پاسخ یک وکیل باتجربه ساخته شده است:
///   ۱. همدلی با وضعیت کاربر ([empathy])
///   ۲. توضیح ساده و منطقی حکم قانون ([answer])
///   ۳. قدم‌های عملی ([steps]) و هشدارها ([cautions])
///   ۴. مبنای قانونی که متن آن از خود بانک قوانین برنامه خوانده می‌شود ([refs])
///   ۵. پرسش پیگیری برای ادامهٔ گفتگو ([followUp])
///
/// همهٔ ارجاع‌ها در آزمون `test/domain/lawyer_voice_test.dart` با بانک قوانین
/// تطبیق داده می‌شوند تا هیچ مادهٔ ساختگی‌ای در پاسخ‌ها نیاید.
library;

class LegalRef {
  /// شناسهٔ قانون در `assets/laws/_meta.json` (مثل `cheque`).
  final String lawId;

  /// شمارهٔ ماده (ارقام لاتین).
  final String article;
  const LegalRef(this.lawId, this.article);
}

/// نکتهٔ شرطی: فقط وقتی گفته می‌شود که پیام کاربر نشانهٔ مربوط را داشته باشد.
///
/// هر عضو [cues] یک گروه «و» است و کافی است یک گروه برقرار باشد. نشانه‌ای
/// که با `@` شروع شود، به وضعیت استخراج‌شده در `CaseFacts` اشاره دارد
/// (مثل `@no_insurance`).
class GuideNote {
  final List<List<String>> cues;
  final String text;
  const GuideNote(this.cues, this.text);
}

class LegalGuide {
  final String id;

  /// عنوان کوتاه موضوع (برای جمع‌بندی و آزمون‌ها).
  final String title;

  /// هر عضو یک گروه «و» است: همهٔ عبارت‌های آن گروه باید در پیام باشد.
  /// کافی است یکی از گروه‌ها برقرار باشد.
  final List<List<String>> triggers;

  /// اگر یکی از این عبارت‌ها در پیام باشد، این راهنما انتخاب نمی‌شود.
  final List<String> excludes;

  /// اولویت در تساوی امتیاز (بزرگ‌تر = مقدم).
  final int priority;

  final String empathy;

  /// خلاصهٔ یک‌دوجمله‌ای برای وقتی که مشاورهٔ گام‌به‌گام شروع می‌شود.
  final String brief;
  final String answer;
  final List<String> steps;
  final List<String> cautions;
  final List<LegalRef> refs;
  final String followUp;

  /// شناسهٔ قالب‌های مرتبط در `assets/templates`.
  final List<String> templateIds;

  /// نکته‌های شرطی متناسب با جزئیاتی که کاربر گفته.
  final List<GuideNote> notes;

  const LegalGuide({
    required this.id,
    required this.title,
    required this.triggers,
    this.excludes = const [],
    this.priority = 0,
    required this.empathy,
    required this.brief,
    required this.answer,
    this.steps = const [],
    this.cautions = const [],
    this.refs = const [],
    required this.followUp,
    this.templateIds = const [],
    this.notes = const [],
  });
}

/// راهنماهای نصب‌شده. پیش از این، متنِ همهٔ راهنماها همین‌جا نوشته شده بود
/// (۱٬۳۹۷ خط)؛ حالا در `assets/brain/guides/legal_guides.json` است و با
/// [loadLegalGuides] خوانده می‌شود.
///
/// چرا نصبِ صریح و نه خواندنِ درون‌خطی؟ چون `LawyerVoice` روی این فهرست
/// نقشه می‌سازد و آن نقشه‌ها باید پس از نصب ساخته شوند، نه پیش از آن.
List<LegalGuide> _installed = const [];

/// راهنماهای نصب‌شده (پس از بارگذاری، ۳۴ راهنما).
List<LegalGuide> get legalGuides => _installed;

/// آیا راهنماها بارگذاری شده‌اند؟
bool get legalGuidesLoaded => _installed.isNotEmpty;

/// نصبِ راهنماها از یک منبعِ بیرونی (فایلِ دارایی).
void installLegalGuides(List<LegalGuide> guides) {
  _installed = List<LegalGuide>.unmodifiable(guides);
}
