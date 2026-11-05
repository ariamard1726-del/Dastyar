import 'package:dastyar/domain/dialogue/dialogue_action.dart';
import 'package:dastyar/domain/dialogue/dialogue_state.dart';
import 'package:dastyar/domain/dialogue/domain_slot_schemas.dart';
import 'package:dastyar/domain/dialogue/evidence.dart';

/// تصمیم‌گیرندهٔ نوبت بعدی گفتگو.
///
/// این کلاس مسئولیت `DialogueState` و `EvidenceSet` را می‌گیرد و
/// یکی از چهار `DialogueAction` را برمی‌گرداند. هیچ متنی تولید
/// نمی‌کند (تولید متن کار `ResponseComposer` است).
///
/// تصمیم‌گیری به ترتیب اولویت:
///   ۱. تعارض بین شواهد → `ExplainConflict`
///   ۲. دامنه نامشخص → `DisambiguateDomain`
///   ۳. اولین اسلات **اجباری** پرنشده با prompt غیرخالی → `AskForSlot`
///   ۴. همهٔ اسلات‌های اجباری پر شده + شواهد کافی → `GiveAnswer`
///   ۵. شواهد ناکافی → `AskForSlot` با hint شفاف‌سازی
class DialoguePlanner {
  const DialoguePlanner();

  /// تصمیم نوبت بعدی بر اساس `state` و `evidence`.
  DialogueAction plan(DialogueState state, EvidenceSet evidence) {
    // ۱. تعارض بین شواهد
    if (evidence.conflicts.isNotEmpty) {
      final alternatives = evidence.items
          .map((e) => e.articleId)
          .where((id) => id.isNotEmpty)
          .toList();
      // ignore: prefer_const_constructors
      return ExplainConflict(
        alternatives: alternatives,
        rationale:
            'بین شواهد موجود تعارض هست؛ نمی‌توانم بدون '
            'انتخاب شما پاسخ قطعی بدهم.',
      );
    }

    // ۲. دامنه نامشخص
    final schema = DomainSchemaRegistry.forDomain(state.domain);
    if (schema == null) {
      // ignore: prefer_const_constructors
      return DisambiguateDomain(candidates: DomainSchemaRegistry.allDomainIds);
    }

    // ۳. اولین اسلات پرنشدهٔ اجباری با prompt غیرخالی (طبق priority)
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
      return const GiveAnswer(
        conclusions: [
          'بر اساس پاسخ‌های شما و شواهد موجود، تحلیل نهایی به شرح زیر است.',
        ],
      );
    }

    // ۵. همه پر شده ولی شواهد کافی نیست — hint برای شفاف‌سازی
    return const AskForSlot(
      slotKey: 'clarification',
      rationale: 'برای ارائهٔ پاسخ قطعی، نیاز به توضیح بیشتری دارم.',
      options: [],
      hint: 'شواهد کافی نیست؛ کاربر را به شفاف‌سازی هدایت کن.',
    );
  }

  /// پیدا کردن اولین اسلات پرنشدهٔ **اجباری** با prompt غیرخالی،
  /// به ترتیب priority.
  ///
  /// **⚠️ نکتهٔ مهم**: اسلات‌های اختیاری (`amount`, `due_date`,
  /// `deposit_amount`) در Phase 2.4 پرسیده نمی‌شوند.
  SlotSpec? _findNextMissingSlot(DomainSchema schema, DialogueState state) {
    for (final spec in schema.prioritizedSlots) {
      if (!spec.isRequired) continue;
      if (spec.prompt.isEmpty) continue;
      if (state.hasReliableSlot(spec.name)) continue;
      return spec;
    }
    return null;
  }
}
