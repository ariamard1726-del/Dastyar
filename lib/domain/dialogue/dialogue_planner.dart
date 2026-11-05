import 'package:dastyar/domain/dialogue/dialogue_action.dart';
import 'package:dastyar/domain/dialogue/dialogue_state.dart';
import 'package:dastyar/domain/dialogue/domain_slot_schemas.dart';
import 'package:dastyar/domain/dialogue/evidence.dart';
import 'package:dastyar/domain/dialogue/slot.dart';

/// تصمیم‌گیرندهٔ نوبت بعدی گفتگو.
///
/// این کلاس مسئولیت `DialogueState` و `EvidenceSet` را می‌گیرد و
/// یکی از چهار `DialogueAction` را برمی‌گرداند. هیچ متنی تولید
/// نمی‌کند (تولید متن کار `ResponseComposer` است).
///
/// تصمیم‌گیری به ترتیب اولویت:
///   ۱. اگر تعارض بین شواهد هست → `ExplainConflict` (نمی‌توان
///      با اطمینان پاسخ داد، باید کاربر تصمیم بگیرد).
///   ۲. اگر دامنه مشخص نیست → `DisambiguateDomain` (کاربر باید
///      دامنه را انتخاب کند).
///   ۳. اگر اسلات پرنشده‌ای با prompt غیرخالی هست → `AskForSlot`
///      (طبق `priority` اسلات).
///   ۴. اگر همه اسلات‌های الزامی پر شده و شواهد کافی است →
///      `GiveAnswer`.
///   ۵. در غیر این صورت (شواهد ناکافی) → `AskForSlot` با hint
///      مناسب برای شفاف‌سازی.
///
/// **تصمیم به `null` برنمی‌گرداند** — اگر هیچ‌کدام از شرایط
/// برقرار نبود، یک `AskForSlot` پیش‌فرض برمی‌گرداند. این تضمین
/// می‌کند که `LegalCounselor.step` هرگز به حالت بی‌تصمیم نمی‌افتد.
///
/// **`state` را تغییر نمی‌دهد** — `DialogueState` immutable است
/// و planner فقط می‌خواند. تغییر state وظیفهٔ `LegalCounselor.step`
/// است.
class DialoguePlanner {
  const DialoguePlanner();

  /// تصمیم نوبت بعدی بر اساس `state` و `evidence`.
  DialogueAction plan(DialogueState state, EvidenceSet evidence) {
    // ۱. تعارض بین شواهد
    if (evidence.conflicts.isNotEmpty) {
      return ExplainConflict(
        alternatives: evidence.items
            .map((e) => e.articleId)
            .where((id) => id.isNotEmpty)
            .toList(),
        rationale: 'بین شواهد موجود تعارض هست؛ نمی‌توانم بدون '
            'انتخاب شما پاسخ قطعی بدهم.',
      );
    }

    // ۲. دامنه نامشخص
    final schema = DomainSchemaRegistry.forDomain(state.domain);
    if (schema == null) {
      return DisambiguateDomain(
        candidates: DomainSchemaRegistry.allDomainIds,
      );
    }

    // ۳. اولین اسلات پرنشده با prompt غیرخالی (طبق priority)
    final missing = _findNextMissingSlot(schema, state);
    if (missing != null) {
      return AskForSlot(
        slotKey: missing.name,
        rationale: missing.rationale,
        options: missing.options,
        hint: state.pendingSlot == missing.name
            ? 'قبلاً هم پرسیدم؛ لطفاً یک پاسخ روشن بدهید.'
            : null,
      );
    }

    // ۴. همه اسلات‌های الزامی پر شده
    if (evidence.hasSufficientSupport) {
      return GiveAnswer(
        conclusions: [
          'بر اساس پاسخ‌های شما و شواهد موجود، تحلیل نهایی به شرح زیر است.',
        ],
      );
    }

    // ۵. همه پر شده ولی شواهد کافی نیست — hint برای شفاف‌سازی
    return AskForSlot(
      slotKey: 'clarification',
      rationale: 'برای ارائهٔ پاسخ قطعی، نیاز به توضیح بیشتری دارم.',
      options: const [],
      hint: 'شواهد کافی نیست؛ کاربر را به شفاف‌سازی هدایت کن.',
    );
  }

  /// پیدا کردن اولین اسلات پرنشده با prompt غیرخالی، به ترتیب priority.
  SlotSpec? _findNextMissingSlot(DomainSchema schema, DialogueState state) {
    for (final spec in schema.prioritizedSlots) {
      if (spec.prompt.isEmpty) continue;
      if (state.hasReliableSlot(spec.name)) continue;
      return spec;
    }
    return null;
  }
}
