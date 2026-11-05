import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/dialogue/dialogue_action.dart';
import 'package:dastyar/domain/dialogue/dialogue_state.dart';
import 'package:dastyar/domain/dialogue/evidence.dart';
import 'package:dastyar/domain/dialogue/response_composer.dart';
import 'package:dastyar/domain/dialogue/slot.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/domain/templates.dart';

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
      final action = const AskForSlot(
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
      final action = const AskForSlot(
        slotKey: 'role',
        rationale: 'دلیل آزمایشی',
        options: const ['دارنده'],
      );
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(reply.text, contains('چکم برگشت خورده'));
    });

    test('does NOT echo when utterance contains Latin chars', () {
      final state = makeState(lastUserUtterance: 'cheque bounced');
      final action = const AskForSlot(
        slotKey: 'role',
        rationale: 'دلیل آزمایشی',
        options: const [],
      );
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(containsLatin(reply.text), isFalse);
    });

    test('output is Persian-only (no Latin chars)', () {
      final state = makeState(lastUserUtterance: 'چک برگشتی دارم');
      final action = const AskForSlot(
        slotKey: 'role',
        rationale: 'برای تعیین مسیر',
        options: const ['دارنده'],
      );
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(containsLatin(reply.text), isFalse);
    });

    test('chips include لغو when options empty', () {
      final state = makeState();
      final action = const AskForSlot(
        slotKey: 'amount',
        rationale: 'دلیل آزمایشی',
        options: const [],
      );
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(reply.chips, contains('لغو'));
    });
  });

  group('ResponseComposer — determinism', () {
    test('same state + action → same variantId and text', () {
      final state = makeState(conversationId: 'abc123');
      final action = const AskForSlot(
        slotKey: 'role',
        rationale: 'دلیل آزمایشی',
        options: const [],
      );
      final r1 = composer.compose(action, state, EvidenceSet.empty());
      final r2 = composer.compose(action, state, EvidenceSet.empty());
      expect(r1.variantId, equals(r2.variantId));
      expect(r1.text, equals(r2.text));
    });

    test('different conversationId → different variantId', () {
      final action = const AskForSlot(
        slotKey: 'role',
        rationale: 'دلیل آزمایشی',
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
      final action = const AskForSlot(
        slotKey: 'role',
        rationale: 'دلیل آزمایشی',
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
      final action = const ExplainConflict(
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
      final action = const DisambiguateDomain(
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
      final action = const GiveAnswer(conclusions: const ['نتیجه اول', 'نتیجه دوم']);
      final reply = composer.compose(action, state, EvidenceSet.empty());
      expect(reply.text, contains('نتیجه اول'));
      expect(reply.text, contains('نتیجه دوم'));
      expect(reply.chips, isEmpty);
    });
  });

  // ── Phase 3: acknowledged slot transitions ────────────────────────
  group('ResponseComposer — composeAcknowledged', () {
    bool hasConnector(String text) =>
        RegExp(r'حالا|ادامه دهیم|قدم بعدی').hasMatch(text);

    test('acknowledges the previous input before asking the next slot', () {
      final reply = composer.composeAcknowledged('چک تضمینی', 'amount');
      expect(reply.text, contains('چک تضمینی'));
      expect(reply.text, contains('مبلغ آن چقدر است'));
      expect(hasConnector(reply.text), isTrue);
      expect(reply.text.indexOf('چک تضمینی'),
          lessThan(reply.text.indexOf('مبلغ')));
      expect(reply.variantId, isNotNull);
    });

    test('produces one flowing line (no robotic blocks or numbering)', () {
      final reply = composer.composeAcknowledged(
        'چک تضمینی',
        'amount',
        nextQuestion: '۳. مبلغ آن چقدر است:',
        domain: 'cheque',
      );
      expect(reply.text, isNot(contains('\n')));
      expect(RegExp(r'^\d').hasMatch(reply.text), isFalse);
      expect(reply.text, isNot(contains('{echo}')));
      expect(reply.text, isNot(contains('{question}')));
      expect(reply.text, isNot(contains('{connector}')));
      expect(reply.text, isNot(contains(':')));
      expect(reply.text, contains('مبلغ آن چقدر است'));
    });

    test('explicit question wins over schema prompt and default map', () {
      final reply = composer.composeAcknowledged(
        'چک تضمینی',
        'amount',
        nextQuestion: '۳. لطفاً مبلغ دقیق چک را بگویید:',
        domain: 'cheque',
      );
      expect(reply.text, contains('مبلغ دقیق چک را بگویید'));
      expect(reply.text, isNot(contains('مبلغ چک چقدر است')));
      expect(reply.text, isNot(contains('۳.')));
    });

    test('falls back to the domain schema prompt when no question is given', () {
      final reply = composer.composeAcknowledged(
        'چک تضمینی', 'amount', domain: 'cheque',
      );
      expect(reply.text, contains('مبلغ چک چقدر است'));
      // rationale حقوقی خام نباید به متن گفتوگویی تزریق شود.
      expect(reply.text, isNot(contains('خسارت تأخیر تأدیه')));
    });

    test('falls back to a slot-key question without any domain', () {
      final reply = composer.composeAcknowledged('چک تضمینی', 'due_date');
      expect(reply.text, contains('تاریخ آن چه زمانی بوده است'));
    });

    test('unknown slot key still gets a gentle question', () {
      final reply = composer.composeAcknowledged('چک تضمینی', 'mystery_slot');
      expect(reply.text, contains('کمی بیشتر توضیح دهید'));
      expect(reply.text, contains('چک تضمینی'));
    });

    test('chips: explicit options win', () {
      final reply = composer.composeAcknowledged(
        'چک تضمینی',
        'nature',
        options: const ['گزینهٔ الف', 'گزینهٔ ب'],
      );
      expect(reply.chips, equals(const ['گزینهٔ الف', 'گزینهٔ ب']));
    });

    test('chips: schema options when none supplied', () {
      final reply = composer.composeAcknowledged(
        'چک تضمینی', 'nature', domain: 'cheque',
      );
      expect(reply.chips, contains('بابت بدهی قطعی و تاریخ روز'));
    });

    test('chips: لغو fallback when no options exist', () {
      final reply = composer.composeAcknowledged(
        'چک تضمینی', 'amount', domain: 'cheque',
      );
      expect(reply.chips, contains('لغو'));
    });

    test('output stays Persian-only for Persian input', () {
      final reply = composer.composeAcknowledged(
        'چک تضمینی',
        'amount',
        options: const ['کمتر از ده میلیون', 'بیشتر از ده میلیون'],
      );
      expect(containsLatin(reply.text), isFalse);
      expect(containsLatin(reply.chips.join(' ')), isFalse);
    });

    test('Latin-only input is not echoed and does not leak into output', () {
      final reply = composer.composeAcknowledged('cheque bounced', 'amount');
      expect(reply.text, isNot(contains('cheque')));
      expect(containsLatin(reply.text), isFalse);
      expect(reply.text, contains('مبلغ آن چقدر است'));
      expect(reply.text, isNot(contains('است است')));
    });

    test('empty input still acknowledges and asks the next slot', () {
      final reply = composer.composeAcknowledged('   ', 'amount');
      expect(reply.text, isNotEmpty);
      expect(reply.text, contains('مبلغ آن چقدر است'));
      expect(reply.text, isNot(contains('{echo}')));
      expect(reply.text, isNot(contains('متوجه شدم است')));
    });

    test('normalizes Arabic variants, diacritics and ZWNJ in the echo', () {
      final reply = composer.composeAcknowledged('چك تضمينى', 'amount');
      expect(reply.text, contains('چک تضمینی'));
      expect(containsLatin(reply.text), isFalse);
    });

    test('strips fillers and copulas so it never says «است است»', () {
      final reply = composer.composeAcknowledged(
        'بله، چک تضمینی است.', 'amount',
      );
      expect(reply.text, isNot(contains('است است')));
      expect(reply.text, isNot(contains('بله')));
      expect(reply.text, contains('چک تضمینی'));
    });

    test('long input is truncated to keep the transition short', () {
      final long = 'چک تضمینی ' * 30;
      final reply = composer.composeAcknowledged(long, 'amount');
      expect(reply.text, contains('…'));
      expect(reply.text.length, lessThan(220));
      expect(reply.text, contains('مبلغ آن چقدر است'));
    });

    test('deterministic: identical inputs → identical text/chips/variantId', () {
      final a = composer.composeAcknowledged(
        'چک تضمینی', 'amount', domain: 'cheque',
      );
      final b = composer.composeAcknowledged(
        'چک تضمینی', 'amount', domain: 'cheque',
      );
      expect(a.text, equals(b.text));
      expect(a.chips, equals(b.chips));
      expect(a.variantId, equals(b.variantId));
    });

    test('different conversation → different variantId', () {
      final a = composer.composeAcknowledged(
        'چک تضمینی', 'amount',
        state: makeState(conversationId: 'conv_A'),
      );
      final b = composer.composeAcknowledged(
        'چک تضمینی', 'amount',
        state: makeState(conversationId: 'conv_B'),
      );
      expect(a.variantId, isNot(equals(b.variantId)));
    });

    test('templates rotate across 4 consecutive turns (no robotic repeat)', () {
      final texts = <String>[];
      for (var i = 0; i < 4; i++) {
        texts.add(composer.composeAcknowledged(
          'چک تضمینی', 'amount',
          state: makeState(turnIndex: i),
        ).text);
      }
      expect(texts.toSet().length >= 3, isTrue);
      for (var i = 1; i < texts.length; i++) {
        expect(texts[i], isNot(equals(texts[i - 1])));
      }
    });

    test('legacy turnIndex fallback also rotates templates', () {
      final texts = <String>{};
      for (var i = 0; i < 4; i++) {
        texts.add(composer.composeAcknowledged(
          'چک تضمینی', 'amount', turnIndex: i,
        ).text);
      }
      expect(texts.length >= 3, isTrue);
    });

    test('compose() still uses the renamed base (structured block)', () {
      final action = const AskForSlot(
        slotKey: 'amount',
        rationale: 'دلیل آزمایشی ساختاریافته',
        options: const [],
      );
      final base = composer.compose(action, makeState(), EvidenceSet.empty());
      final ack = composer.composeAcknowledged('چک تضمینی', 'amount');
      expect(base.text, contains('دلیل آزمایشی ساختاریافته'));
      expect(base.text, contains('\n\n'));
      expect(ack.text, isNot(contains('\n')));
    });
  });

  // ── Phase 3: minimal step() wiring (Planner untouched) ────────────
  group('LegalCounselor.step — acknowledged transitions', () {
    const templates = <LegalTemplate>[];

    test('step() acknowledges the previous answer before the next prompt', () {
      final engine = KnowledgeEngine();
      final s = CounselingSession(
        topicId: 'cheque', initialMessage: 'چک برگشتی دارم',
      );
      s.facts['role'] = 'holder';
      final turn = LegalCounselor.step(s, 'چک تضمینی', engine, templates);

      expect(s.facts['nature'], isNotNull);
      expect(s.concluded, isFalse);
      expect(turn.completed, isFalse);
      expect(turn.text, contains('چک تضمینی'));
      expect(turn.text, contains('گواهی عدم پرداخت'));
      expect(turn.text, contains('۶ ماه'));
      expect(turn.text, isNot(contains('۳.')));
      expect(turn.text, isNot(contains('\n\n')));
      expect(turn.chips, contains(LegalCounselor.cancelCounselCmd));
    });

    test('two consecutive step() turns vary the acknowledgement', () {
      final engine = KnowledgeEngine();
      final s = CounselingSession(
        topicId: 'cheque', initialMessage: 'چک برگشتی دارم',
      );
      final t1 = LegalCounselor.step(s, 'دارنده چک هستم', engine, templates);
      final t2 = LegalCounselor.step(s, 'چک تضمینی', engine, templates);

      expect(t1.text, contains('دارنده چک'));
      expect(t2.text, contains('چک تضمینی'));
      expect(t1.text, isNot(equals(t2.text)));
      expect(t1.text, isNot(contains('\n\n')));
      expect(t2.text, isNot(contains('\n\n')));
    });

    test('first turn still uses the empathy intro, not the composer', () {
      final engine = KnowledgeEngine();
      final s = CounselingSession(topicId: 'general_intake', initialMessage: '');
      final turn = LegalCounselor.step(
        s, 'سلام، چک من برگشت خورده', engine, templates,
      );
      expect(s.topicId, 'cheque');
      expect(turn.text, contains('\n\n'));
      expect(turn.text, contains('نقش'));
    });

    test('no acknowledgement is fabricated after the last slot is filled', () {
      final engine = KnowledgeEngine();
      final s = CounselingSession(
        topicId: 'cheque', initialMessage: 'چک برگشتی دارم',
      );
      s.facts['role'] = 'holder';
      s.facts['nature'] = 'conditional';
      final turn = LegalCounselor.step(
        s, 'گواهی عدم پرداخت گرفتم', engine, templates,
      );
      expect(turn.completed, isTrue);
      expect(s.concluded, isTrue);
    });
  });
}
