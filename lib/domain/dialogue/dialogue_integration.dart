import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/dialogue/dialogue_action.dart';
import 'package:dastyar/domain/dialogue/dialogue_planner.dart';
import 'package:dastyar/domain/dialogue/dialogue_state.dart';
import 'package:dastyar/domain/dialogue/domain_slot_schemas.dart';
import 'package:dastyar/domain/dialogue/response_composer.dart';
import 'package:dastyar/domain/dialogue/slot.dart';
import 'package:dastyar/domain/dialogue/slot_extractor.dart';
import 'package:dastyar/domain/legal_counselor.dart';

/// لایهٔ ادغام `DialoguePlanner` و `ResponseComposer` در `LegalCounselor`.
///
/// این کلاس مسئولیت «پل زدن» بین `CounselingSession` (که
/// `LegalCounselor` استفاده می‌کند) و `DialogueState`/`EvidenceSet`
/// (که Phase 2 معرفی کرد) را دارد.
class DialogueIntegration {
  DialogueIntegration._();

  static const Set<String> supportedDomains = {'cheque', 'labor', 'lease'};

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

    final extracted = _extractor.extract(session.initialMessage, schema);
    if (extracted.isNotEmpty) {
      state = state.copyWith(slots: extracted);
    }

    session.dialogueState = state;
  }

  /// تلاش برای پردازش پاسخ کاربر با planner/composer جدید.
  ///
  /// **⚠️ تصمیم Phase 2.4**: فقط `AskForSlot` را به‌عنوان پاسخ برمی‌گرداند.
  /// سایر `DialogueAction`ها (GiveAnswer, ExplainConflict,
  /// DisambiguateDomain) → `null` برمی‌گردد تا `LegalCounselor` به
  /// مسیر legacy برود (چون `_buildConclusion` استنادات قانونی غنی‌تری
  /// دارد و تست‌های موجود آن را انتظار دارند).
  ///
  /// **⚠️ sync به `session.facts`**: علاوه بر `dialogueState`،
  /// `session.facts` هم به‌روز می‌شود. این کار تضمین می‌کند که
  /// `_buildConclusion` (که از `session.facts` می‌خواند) داده‌های
  /// استخراج‌شده را ببیند.
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

    // ۲. ادغام با اسلات‌های موجود
    final mergedSlots = <String, SlotValue>{...state.slots, ...extracted};

    // ۳. بازیابی شواهد
    final evidence = engine.retrieveWithEvidence(text, k: 3);

    // ۴. ساخت state جدید
    var newState = state.copyWith(
      slots: mergedSlots,
      evidence: evidence,
      turnIndex: state.turnIndex + 1,
      lastUserUtterance: text,
    );

    // ۵. sync به session.facts (برای _buildConclusion و _advance legacy)
    for (final entry in mergedSlots.entries) {
      final v = entry.value.value;
      if (v != null && v.isNotEmpty) {
        session.facts[entry.key] = v;
      }
    }

    // ۶. تصمیم‌گیری
    final action = _planner.plan(newState, evidence);

    // ۷. فقط AskForSlot را در Phase 2.4 پشتیبانی می‌کنیم.
    //    GiveAnswer/ExplainConflict/DisambiguateDomain → fallback
    if (action is! AskForSlot) {
      session.dialogueState = newState;
      return null;
    }

    newState = newState.copyWith(
      pendingSlot: action.slotKey,
      askedSlots: {...newState.askedSlots, action.slotKey},
    );
    session.dialogueState = newState;

    final reply = _composer.compose(action, newState, evidence);
    return CounselorTurn(
      text: reply.text,
      chips: reply.chips,
      completed: false,
    );
  }
}