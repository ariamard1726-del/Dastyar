import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/dialogue/dialogue_action.dart';
import 'package:dastyar/domain/dialogue/dialogue_planner.dart';
import 'package:dastyar/domain/dialogue/dialogue_state.dart';
import 'package:dastyar/domain/dialogue/domain_slot_schemas.dart';
import 'package:dastyar/domain/dialogue/response_composer.dart';
import 'package:dastyar/domain/dialogue/slot.dart';
import 'package:dastyar/domain/dialogue/slot_extractor.dart';
import 'package:dastyar/domain/dialogue/slots.dart';
import 'package:dastyar/domain/legal_counselor.dart';

/// لایهٔ ادغام `DialoguePlanner` و `ResponseComposer` در `LegalCounselor`.
class DialogueIntegration {
  DialogueIntegration._();

  static const Set<String> supportedDomains = {
    'cheque',
    'labor',
    'lease',
    'family',
    'fraud_cyber',
    'criminal_harm',
    'litigation_defense',
    'debt',
  };

  static const DialoguePlanner _planner = DialoguePlanner();
  static const ResponseComposer _composer = ResponseComposer();
  static const SlotExtractor _extractor = SlotExtractor();

  static bool supportsDomain(String domainId) =>
      supportedDomains.contains(domainId);

  /// Initialize `DialogueState` on a new or resumed session for supported
  /// domains. اگر domain پشتیبانی نشود یا schema نبود، کاری نمی‌کند.
  static void initializeState(CounselingSession session) {
    if (!supportsDomain(session.topicId)) return;
    if (session.dialogueState != null) return;

    final schema = DomainSchemaRegistry.forDomain(session.topicId);
    if (schema == null) return;

    var state = DialogueState.fresh(
      domain: session.topicId,
      topicId: session.topicId,
      initialMessage: session.initialMessage,
    );

    // ۱. استخراج از پیام اولیه
    final extracted = _extractor.extract(session.initialMessage, schema);
    final slots = <String, SlotValue>{};
    for (final entry in extracted.entries) {
      slots[entry.key] = entry.value;
      // sync به facts هم برای اطمینان
      final v = entry.value.value;
      if (v != null && v.isNotEmpty) {
        session.facts[entry.key] = v;
      }
    }

    // ۲. اگر facts از قبل مقداری داشت (مثلاً از resume)، آن‌ها را هم به slots اضافه کن
    for (final entry in session.facts.entries) {
      if (slots.containsKey(entry.key)) continue;
      if (entry.value.isEmpty) continue;
      slots[entry.key] = SlotValue.inferred(
        value: entry.value,
        confidence: 0.9,
        sourceTurn: 0,
      );
    }

    if (slots.isNotEmpty) {
      state = state.copyWith(slots: slots);
    }

    session.dialogueState = state;
  }

  /// تلاش برای پردازش پاسخ کاربر با planner/composer جدید.
  ///
  /// **⚠️ اصلاح Phase 2.4.2**:
  ///   - فقط وقتی non-null برمی‌گرداند که واقعاً یک اسلات استخراج شده باشد
  ///     و planner یک `AskForSlot` واقعی (نه clarification) درخواست کند.
  ///   - در غیر این صورت `null` برمی‌گرداند تا `LegalCounselor` به مسیر
  ///     legacy برود (RAG، conclusion، template match، ...).
  ///   - همیشه `session.facts` را با `newState.slots` sync می‌کند تا
  ///     `_buildConclusion` و `_advance` legacy هم داده‌های جدید را ببینند.
  static CounselorTurn? tryStep(
    CounselingSession session,
    String text,
    KnowledgeEngine engine,
  ) {
    final state = session.dialogueState;
    if (state == null) return null;

    final schema = DomainSchemaRegistry.forDomain(session.topicId);
    if (schema == null) return null;

    // ۱. استخراج اسلات‌های جدید
    final extracted = _extractor.extract(
      text,
      schema,
      turnIndex: state.turnIndex,
    );

    // ۲. اگر هیچ اسلات جدیدی استخراج نشد، به legacy بده
    //    (این متن ممکن است سؤال حقوقی، لغو، یا نامرتبط باشد)
    if (extracted.isEmpty) {
      return null;
    }

    // ۳. ادغام با اسلات‌های موجود
    final mergedSlots = <String, SlotValue>{...state.slots, ...extracted};

    // ۴. بازیابی شواهد
    final evidence = engine.retrieveWithEvidence(text, k: 3);

    // ۵. ساخت state جدید
    var newState = state.copyWith(
      slots: mergedSlots,
      evidence: evidence,
      turnIndex: state.turnIndex + 1,
      lastUserUtterance: text,
    );

    // ۶. sync همهٔ اسلات‌ها به session.facts (نه فقط جدید)
    for (final entry in mergedSlots.entries) {
      final v = entry.value.value;
      if (v != null && v.isNotEmpty) {
        session.facts[entry.key] = v;
      }
    }

    // ۷. تصمیم‌گیری
    final action = _planner.plan(newState, evidence);

    // ۸. فقط AskForSlot واقعی (نه clarification) را پاسخ می‌دهیم.
    //    GiveAnswer/ExplainConflict/DisambiguateDomain/clarification → null
    //    تا legacy از _buildConclusion استفاده کند.
    if (action is! AskForSlot || action.slotKey == Slots.clarification) {
      session.dialogueState = newState;
      return null;
    }

    // ۹. به‌روزرسانی pendingSlot
    newState = newState.copyWith(
      pendingSlot: action.slotKey,
      askedSlots: {...newState.askedSlots, action.slotKey},
    );
    session.dialogueState = newState;

    // ۱۰. ساخت متن با Composer
    final reply = _composer.compose(action, newState, evidence);
    return CounselorTurn(
      text: reply.text,
      chips: reply.chips,
      completed: false,
    );
  }
}