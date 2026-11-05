/// نتیجهٔ تصمیم `DialoguePlanner` در هر نوبت گفتگو.
///
/// طبق اصل Open/Closed، برای هر نوع رفتار جدید یک زیرکلاس جدید اضافه
/// می‌شود؛ `DialoguePlanner` و `ResponseComposer` با `switch` روی این
/// sealed class همهٔ حالت‌ها را پوشش می‌دهند (بدون نیاز به default
/// branch یا casting).
///
/// چهار نوع تصمیم داریم:
///   • `AskForSlot` — Planner یک اسلات الزامی را پرنشده می‌بیند و از
///     کاربر می‌پرسد.
///   • `GiveAnswer` — همهٔ اسلات‌های الزامی پر شده‌اند؛ پاسخ نهایی.
///     این نوع در Phase 2 اولیه مستقیماً استفاده نمی‌شود (چون
///     `_buildConclusion` موجود در `LegalCounselor` منطق غنی‌تری
///     دارد)، ولی برای Phase 2.5+ آماده است.
///   • `ExplainConflict` — دو یا چند شاهد متعارض پیدا شد. Planner
///     توضیح می‌دهد و تصمیم را به کاربر می‌سپارد.
///   • `DisambiguateDomain` — دامنهٔ حقوقی مشخص نیست یا چند دامنهٔ
///     ممکن وجود دارد.
///
/// **همهٔ فیلدها immutable** هستند. `DialogueAction` به‌عنوان خروجی
/// تابع `plan` است و تست‌پذیری را آسان می‌کند.
sealed class DialogueAction {
  const DialogueAction();
}

/// Planner از کاربر می‌خواهد اسلات [slotKey] را پر کند.
///
/// [rationale] توضیح فارسی است که در Phase 2 توسط `ResponseComposer`
/// در متن سؤال می‌آید («چرا این را می‌پرسم»). این متن مستقیماً از
/// `DomainSchema.slots[].rationale` گرفته می‌شود و در `domain_slot_schemas.dart`
/// برای هر اسلات تعریف شده است.
///
/// [options] فهرست گزینه‌های پیشنهادی است (برای دکمه‌های چت). اگر
/// خالی باشد، سؤال فقط متنی است و کاربر باید خودش پاسخ دهد.
///
/// [hint] متن اختیاری کوتاه برای Composer است (مثلاً اگر
/// `pendingSlot == slotKey` و همین اسلات قبلاً پرسیده شده، Composer
/// می‌تواند لحن را ملایم‌تر کند).
class AskForSlot extends DialogueAction {
  final String slotKey;
  final String rationale;
  final List<String> options;
  final String? hint;

  const AskForSlot({
    required this.slotKey,
    required this.rationale,
    this.options = const [],
    this.hint,
  });

  @override
  String toString() =>
      'AskForSlot(slotKey: $slotKey, options: ${options.length})';
}

/// Planner همهٔ اسلات‌های الزامی را پر شده می‌بیند و پاسخ نهایی می‌دهد.
///
/// [conclusions] فهرست جملات فارسی است که Composer آن‌ها را به هم
/// می‌چسباند. در Phase 2.5+, این‌ها از `_buildConclusion` گرفته
/// می‌شوند. برای Phase 2 اولیه، این نوع استفاده نمی‌شود (چون
/// `_buildConclusion` موجود بهتر است)، ولی ساختار آماده است.
class GiveAnswer extends DialogueAction {
  final List<String> conclusions;

  const GiveAnswer({required this.conclusions});

  @override
  String toString() => 'GiveAnswer(conclusions: ${conclusions.length})';
}

/// Planner تعارض بین دو یا چند شاهد را تشخیص داد.
///
/// [alternatives] فهرست گزینه‌های پیشنهادی (مثلاً «ماده ۳ قانون
/// روابط موجر و مستأجر» و «ماده ۴۹۴ قانون مدنی»). Composer متن
/// توضیحی می‌سازد و کاربر را به انتخاب هدایت می‌کند.
class ExplainConflict extends DialogueAction {
  final List<String> alternatives;
  final String? rationale;

  const ExplainConflict({
    required this.alternatives,
    this.rationale,
  });

  @override
  String toString() =>
      'ExplainConflict(alternatives: ${alternatives.length})';
}

/// Planner دامنه را از متن کاربر تشخیص نداد یا چند دامنه ممکن است.
///
/// [candidates] فهرست شناسه‌های دامنه‌های ممکن (مثلاً `['cheque', 'debt']`).
/// Composer با `DomainSchemaRegistry.forDomain` نام فارسی هر دامنه را
/// می‌آورد.
class DisambiguateDomain extends DialogueAction {
  final List<String> candidates;

  const DisambiguateDomain({required this.candidates});

  @override
  String toString() => 'DisambiguateDomain(candidates: $candidates)';
}
