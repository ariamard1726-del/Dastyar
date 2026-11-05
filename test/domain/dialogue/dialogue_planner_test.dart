import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/dialogue/dialogue_action.dart';
import 'package:dastyar/domain/dialogue/dialogue_planner.dart';
import 'package:dastyar/domain/dialogue/dialogue_state.dart';
import 'package:dastyar/domain/dialogue/evidence.dart';
import 'package:dastyar/domain/dialogue/slot.dart';
import 'package:dastyar/domain/dialogue/slots.dart';

DialogueState freshChequeState({
  Map<String, SlotValue> slots = const {},
  String? pendingSlot,
}) {
  var state = DialogueState.fresh(
    domain: 'cheque',
    topicId: 'cheque',
    initialMessage: 'چک برگشتی دارم',
  );
  if (slots.isNotEmpty) state = state.copyWith(slots: slots);
  if (pendingSlot != null) state = state.copyWith(pendingSlot: pendingSlot);
  return state;
}

SlotValue sv(String v) =>
    SlotValue.inferred(value: v, confidence: 1.0, sourceTurn: 0);

Evidence makeEvidence({String articleId = 'ماده ۱ قانون مدنی'}) {
  return Evidence(
    articleId: articleId,
    text: 'متن آزمایشی',
    rank: 1,
    score: 1.0,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const planner = DialoguePlanner();

  group('DialoguePlanner — AskForSlot', () {
    test('cheque fresh state asks role (highest priority)', () {
      final action = planner.plan(freshChequeState(), EvidenceSet.empty());
      expect(action, isA<AskForSlot>());
      final a = action as AskForSlot;
      expect(a.slotKey, 'role');
      expect(a.options, isNotEmpty);
      expect(a.rationale, isNotEmpty);
    });

    test('after role filled, asks nature', () {
      final state = freshChequeState(slots: {'role': sv('holder')});
      final action = planner.plan(state, EvidenceSet.empty());
      expect(action, isA<AskForSlot>());
      expect((action as AskForSlot).slotKey, 'nature');
    });

    test('after role+nature, asks cert_time', () {
      final state = freshChequeState(
        slots: {'role': sv('holder'), 'nature': sv('unconditional')},
      );
      final action = planner.plan(state, EvidenceSet.empty());
      expect(action, isA<AskForSlot>());
      expect((action as AskForSlot).slotKey, 'cert_time');
    });

    test('skips optional slots (amount, due_date)', () {
      final state = freshChequeState(
        slots: {
          'role': sv('holder'),
          'nature': sv('unconditional'),
          'cert_time': sv('under_6m'),
        },
      );
      final action = planner.plan(state, EvidenceSet.empty());
      // Either GiveAnswer or clarification — but NEVER amount/due_date
      if (action is AskForSlot) {
        expect(action.slotKey, isNot('amount'));
        expect(action.slotKey, isNot('due_date'));
      }
    });

    test('hint is set when pendingSlot matches', () {
      final state = freshChequeState(pendingSlot: 'role');
      final action = planner.plan(state, EvidenceSet.empty());
      final a = action as AskForSlot;
      expect(a.hint, isNotNull);
      expect(a.hint, contains('قبلاً'));
    });

    test('labor fresh state asks issue first', () {
      final state = DialogueState.fresh(
        domain: 'labor',
        topicId: 'labor',
        initialMessage: 'اخراج شدم',
      );
      final action = planner.plan(state, EvidenceSet.empty());
      expect(action, isA<AskForSlot>());
      expect((action as AskForSlot).slotKey, 'issue');
    });

    test('every fresh domain asks the first canonical core slot', () {
      for (final entry in Slots.coreByDomain.entries) {
        final state = DialogueState.fresh(
          domain: entry.key,
          topicId: entry.key,
          initialMessage: 'شروع گفتگو',
        );
        final action = planner.plan(state, EvidenceSet.empty());

        expect(action, isA<AskForSlot>(), reason: entry.key);
        expect((action as AskForSlot).slotKey, entry.value.first,
            reason: entry.key);
      }
    });
  });

  group('DialoguePlanner — GiveAnswer', () {
    test('all required slots + sufficient evidence → GiveAnswer', () {
      final state = freshChequeState(
        slots: {
          'role': sv('holder'),
          'nature': sv('unconditional'),
          'cert_time': sv('under_6m'),
        },
      );
      final evidence = EvidenceSet.sufficient(
        items: [makeEvidence()],
        coverage: 0.8,
      );
      final action = planner.plan(state, evidence);
      expect(action, isA<GiveAnswer>());
    });

    test('all required slots but insufficient evidence → clarification', () {
      final state = freshChequeState(
        slots: {
          'role': sv('holder'),
          'nature': sv('unconditional'),
          'cert_time': sv('under_6m'),
        },
      );
      final action = planner.plan(state, EvidenceSet.empty());
      expect(action, isA<AskForSlot>());
      expect((action as AskForSlot).slotKey, 'clarification');
    });
  });

  group('DialoguePlanner — ExplainConflict', () {
    test('non-empty conflicts → ExplainConflict', () {
      final state = freshChequeState();
      final evidence = EvidenceSet.insufficient(
        items: [makeEvidence()],
        conflicts: [makeEvidence(articleId: 'ماده ۲')],
        coverage: 0.5,
      );
      final action = planner.plan(state, evidence);
      expect(action, isA<ExplainConflict>());
      final a = action as ExplainConflict;
      expect(a.alternatives, isNotEmpty);
    });
  });

  group('DialoguePlanner — DisambiguateDomain', () {
    test('unknown domain → DisambiguateDomain', () {
      final state = DialogueState.fresh(
        domain: 'unknown_domain',
        topicId: 'unknown_domain',
        initialMessage: 'test',
      );
      final action = planner.plan(state, EvidenceSet.empty());
      expect(action, isA<DisambiguateDomain>());
      final a = action as DisambiguateDomain;
      expect(a.candidates, hasLength(8));
    });
  });
}
