import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/dialogue/dialogue_action.dart';
import 'package:dastyar/domain/dialogue/dialogue_state.dart';
import 'package:dastyar/domain/dialogue/evidence.dart';
import 'package:dastyar/domain/dialogue/response_composer.dart';
import 'package:dastyar/domain/dialogue/slot.dart';

DialogueState makeState({
  String domain = 'cheque',
  Map<String, SlotValue> slots = const {},
  String conversationId = 'test_conv_123',
  int turnIndex = 0,
  String lastUserUtterance = '',
  Map<String, String> matchedSpans = const {},
}) {
  return DialogueState(
    domain: domain,
    slots: slots,
    evidence: EvidenceSet.empty(),
    pendingSlot: null,
    askedSlots: const {},
    conversationId: conversationId,
    turnIndex: turnIndex,
    lastUserUtterance: lastUserUtterance,
    matchedSpans: matchedSpans,
  );
}

bool containsLatin(String text) {
  for (final rune in text.runes) {
    if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A)) {
      return true;
    }
  }
  return false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const composer = ResponseComposer();

  group('ResponseComposer — AskForSlot', () {
    test('returns text, chips and variantId', () {
      final state = makeState();
      final action = AskForSlot(
        slotKey: 'role',
        rationale: 'برای تعیین مسیر حقوقی',
        options: const ['دارنده', 'صادرکننده'],
      );
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(reply.text, isNotEmpty);
      expect(reply.chips, isNotEmpty);
      expect(reply.variantId, isNotNull);
    });

    test('echoes lastUserUtterance when Persian', () {
      final state = makeState(lastUserUtterance: 'چکم برگشت خورده');
      final action = AskForSlot(
        slotKey: 'role',
        rationale: 'r',
        options: const ['دارنده'],
      );
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(reply.text, contains('چکم برگشت خورده'));
    });

    test('does NOT echo when utterance contains Latin chars', () {
      final state = makeState(lastUserUtterance: 'cheque bounced');
      final action = AskForSlot(
        slotKey: 'role',
        rationale: 'r',
        options: const [],
      );
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(containsLatin(reply.text), isFalse);
    });

    test('output is Persian-only (no Latin chars)', () {
      final state = makeState(lastUserUtterance: 'چک برگشتی دارم');
      final action = AskForSlot(
        slotKey: 'role',
        rationale: 'برای تعیین مسیر',
        options: const ['دارنده'],
      );
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(containsLatin(reply.text), isFalse);
    });

    test('chips include لغو when options empty', () {
      final state = makeState();
      final action = AskForSlot(
        slotKey: 'amount',
        rationale: 'r',
        options: const [],
      );
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(reply.chips, contains('لغو'));
    });
  });

  group('ResponseComposer — determinism', () {
    test('same state + action → same variantId and text', () {
      final state = makeState(conversationId: 'abc123');
      final action = AskForSlot(
        slotKey: 'role',
        rationale: 'r',
        options: const [],
      );
      final r1 = composer.compose(action, state, EvidenceSet.empty());
      final r2 = composer.compose(action, state, EvidenceSet.empty());
      expect(r1.variantId, equals(r2.variantId));
      expect(r1.text, equals(r2.text));
    });

    test('different conversationId → different variantId', () {
      final action = AskForSlot(
        slotKey: 'role',
        rationale: 'r',
        options: const [],
      );
      final r1 = composer.compose(
        action,
        makeState(conversationId: 'conv_A'),
        EvidenceSet.empty(),
      );
      final r2 = composer.compose(
        action,
        makeState(conversationId: 'conv_B'),
        EvidenceSet.empty(),
      );
      expect(r1.variantId, isNot(equals(r2.variantId)));
    });
  });

  group('ResponseComposer — anti-repetition', () {
    test('acknowledgment differs across 3 consecutive turns', () {
      final action = AskForSlot(
        slotKey: 'role',
        rationale: 'r',
        options: const [],
      );
      final acks = <String>{};
      for (var i = 0; i < 3; i++) {
        final state = makeState(conversationId: 'same_conv', turnIndex: i);
        final reply = composer.compose(action, state, EvidenceSet.empty());
        final firstLine = reply.text.split('\n').first.trim();
        acks.add(firstLine);
      }
      // سه turn متوالی باید ۳ acknowledgment متفاوت داشته باشند
      expect(acks.length, 3);
    });
  });

  group('ResponseComposer — ExplainConflict', () {
    test('produces Persian text with conflict message', () {
      final state = makeState();
      final action = ExplainConflict(
        alternatives: const ['ماده ۱ قانون مدنی', 'ماده ۲ قانون مدنی'],
        rationale: 'تعارض بین شواهد',
      );
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(reply.text, contains('تعارض'));
      expect(reply.chips, hasLength(2));
      expect(containsLatin(reply.text), isFalse);
    });
  });

  group('ResponseComposer — DisambiguateDomain', () {
    test('produces Persian chips for known domains', () {
      final state = makeState();
      final action = DisambiguateDomain(
        candidates: const ['cheque', 'labor', 'lease'],
      );
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(reply.chips, hasLength(3));
      expect(reply.chips, contains('چک و دعاوی بانکی'));
      expect(reply.chips, contains('روابط کار و بیمه'));
      expect(reply.chips, contains('اجاره و تخلیهٔ ملک'));
    });
  });

  group('ResponseComposer — GiveAnswer', () {
    test('joins conclusions into Persian text', () {
      final state = makeState();
      final action = GiveAnswer(conclusions: const ['نتیجه اول', 'نتیجه دوم']);
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(reply.text, contains('نتیجه اول'));
      expect(reply.text, contains('نتیجه دوم'));
      expect(reply.chips, isEmpty);
    });
  });
}
