import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/domain/templates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  const templates = <LegalTemplate>[];

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  (CounselingSession, CounselorTurn) startCounseling(String text) {
    final started = LegalCounselor.start(
      text,
      engine,
      templates,
      replies: engine.replies,
    );
    expect(started, isNotNull);
    return started!;
  }

  CounselorTurn step(CounselingSession session, String text) {
    return LegalCounselor.step(
      session,
      text,
      engine,
      templates,
      replies: engine.replies,
    );
  }

  group('Phase 4 — general intake', () {
    test('routes a new legal issue and initializes its planner state', () {
      final (session, _) = startCounseling('مشاوره');
      expect(session.topicId, 'general_intake');

      final turn = step(session, 'کارفرما اخراجم کرده');

      expect(session.topicId, 'labor');
      expect(session.dialogueState, isNotNull);
      expect(session.dialogueState!.domain, 'labor');
      expect(session.facts['issue'], 'dismissal');
      expect(turn.text, contains('مدرک'));
      expect(turn.completed, isFalse);
      expect(session.concluded, isFalse);
    });

    test('varies unknown-intake reprompts without inventing a topic', () {
      final (session, _) = startCounseling('مشاوره');
      const unclear = 'یه نکتهای بود که هنوز نگفتهام';

      final first = step(session, unclear);
      final second = step(session, unclear);

      expect(session.topicId, 'general_intake');
      expect(session.facts, isEmpty);
      expect(first.text, isNot(second.text));
      expect(CounselorSessionState.intakeAttempts(session), 2);
      expect(first.ragReply, isNull);
      expect(second.ragReply, isNull);
    });
  });

  group('Phase 4 — planner completion and stalls', () {
    test('concludes immediately when the final required slot is extracted', () {
      final (session, _) = startCounseling(
        'مستأجرم مدت قراردادش تمام شده ولی خانه را تخلیه نمی‌کند',
      );
      expect(session.facts.containsKey('witnesses'), isFalse);

      final turn = step(session, 'قرارداد کتبی با امضای دو شاهد داریم');

      expect(session.facts['witnesses'], 'two_witnesses');
      expect(turn.completed, isTrue);
      expect(session.concluded, isTrue);
      expect(turn.text, contains('دستور تخلیهٔ فوری'));
      expect(CounselorSessionState.stallCount(session), 0);
    });

    test('keeps a topical declarative answer out of RAG and completes legacy flow', () {
      final (session, _) = startCounseling(
        'مستأجرم مدت قراردادش تمام شده ولی خانه را تخلیه نمی‌کند',
      );

      final turn = step(session, 'خودم موجرم و مستأجر مشکل دارد');

      expect(turn.ragQuery, isNull);
      expect(turn.ragReply, isNull);
      expect(turn.completed, isTrue);
      expect(session.concluded, isTrue);
      expect(turn.text, contains('دادخواست صدور حکم تخلیه'));
    });

    test('re-asks an unanswered slot differently without changing facts', () {
      final (session, _) = startCounseling(
        'چک دادم بابت ضمانت الان برگشت زده و می‌خواهم بدانم چه کار کنم',
      );
      final factsBefore = Map<String, String>.of(session.facts);
      const irrelevant = 'یه نکتهای بود که هنوز نگفتهام';

      final first = step(session, irrelevant);
      final second = step(session, irrelevant);

      expect(first.text, contains('به سؤال قبلی'));
      expect(first.text, contains('گواهی عدم پرداخت'));
      expect(second.text, contains('گواهی عدم پرداخت'));
      expect(second.text, isNot(first.text));
      expect(first.chips, contains(LegalCounselor.cancelCounselCmd));
      expect(second.chips, contains(LegalCounselor.cancelCounselCmd));
      expect(session.facts, factsBefore);
      expect(session.concluded, isFalse);
      expect(CounselorSessionState.stallCount(session), 2);
    });

    test('does not save a refusal as the pending slot value', () {
      final (session, _) = startCounseling(
        'چک دادم بابت ضمانت الان برگشت زده و می‌خواهم بدانم چه کار کنم',
      );

      final turn = step(session, 'نمی‌خواهم به این سؤال جواب بدهم');

      expect(session.facts.containsKey('cert_time'), isFalse);
      expect(turn.completed, isFalse);
      expect(turn.text, contains('به سؤال قبلی'));
      expect(turn.text, contains('گواهی عدم پرداخت'));
      expect(CounselorSessionState.stallCount(session), 1);
    });

    test('a valid answer after a stall clears the stall state and concludes', () {
      final (session, _) = startCounseling(
        'چک دادم بابت ضمانت الان برگشت زده و می‌خواهم بدانم چه کار کنم',
      );
      step(session, 'یه نکتهای بود که هنوز نگفتهام');
      expect(CounselorSessionState.stallCount(session), 1);

      final turn = step(session, 'بله، گواهی دارم و زیر ۶ ماه است');

      expect(turn.completed, isTrue);
      expect(session.concluded, isTrue);
      expect(session.facts['cert_time'], 'under_6m');
      expect(CounselorSessionState.stallCount(session), 0);
      expect(turn.text, contains('مادهٔ ۱۳ قانون صدور چک'));
    });
  });

  group('Phase 4 — RAG eligibility', () {
    test('does not query RAG for a simple amount answer', () {
      final (session, _) = startCounseling(
        'چک دادم بابت ضمانت الان برگشت زده و می‌خواهم بدانم چه کار کنم',
      );

      final turn = step(session, 'مبلغ چک ۵۰۰ تومان است');

      expect(turn.ragQuery, isNull);
      expect(turn.ragReply, isNull);
      expect(session.facts['amount'], '500');
      expect(turn.text, contains('گواهی عدم پرداخت'));
      expect(session.concluded, isFalse);
    });

    test('queries RAG for legal consequences and resumes the pending slot', () {
      final (session, _) = startCounseling(
        'مستأجرم مدت قراردادش تمام شده ولی خانه را تخلیه نمی‌کند',
      );

      final turn = step(session, 'مجازات کلاهبرداری چیست؟');

      expect(turn.ragQuery, 'مجازات کلاهبرداری چیست؟');
      expect(turn.ragReply, isNotNull);
      expect(turn.text, contains('مجازات'));
      expect(turn.text, contains('دو شاهد'));
      expect(session.facts.containsKey('witnesses'), isFalse);
      expect(session.concluded, isFalse);
    });
  });
}
