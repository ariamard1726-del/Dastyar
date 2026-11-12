import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/domain/templates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  const List<LegalTemplate> templates = <LegalTemplate>[];

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

  group('topic switch during an active counseling session', () {
    test('cheque session then an independent dowry question leaves cheque', () {
      final (session, _) = startCounseling('چک‌م گم شده، چیکار کنم؟');
      expect(session.topicId, 'cheque');

      final turn = step(session, 'شوهرم مهریه‌م رو نمی‌ده، از کجا شروع کنم؟');

      expect(session.topicId, isNot('cheque'));
      expect(turn.text, isNot(contains('دارندهٔ چک')));
    });

    test('cheque session then an independent eviction question leaves cheque', () {
      final (session, _) = startCounseling('چک‌م گم شده، چیکار کنم؟');
      expect(session.topicId, 'cheque');

      step(session, 'مستأجرم اجاره نمی‌ده و نمی‌ره، چطور تخلیه‌اش کنم؟');

      expect(session.topicId, isNot('cheque'));
    });

    test('safety: a normal cheque answer does not drop the cheque topic', () {
      final (session, _) = startCounseling('چک‌م برگشت خورده');
      expect(session.topicId, 'cheque');

      step(session, 'بدهی قطعی بوده');

      expect(session.topicId, 'cheque');
    });

    test('dowry session then an independent cheque message leaves family', () {
      final (session, _) = startCounseling('شوهرم مهریه‌م رو نمی‌ده');
      expect(session.topicId, 'family');

      step(session, 'چک‌م برگشت خورده');

      expect(session.topicId, isNot('family'));
    });

    test('safety: a reference word keeps the current topic', () {
      final (session, _) = startCounseling('چک‌م برگشت خورده');
      expect(session.topicId, 'cheque');

      step(session, 'همین چک بابت اجاره بود');

      expect(session.topicId, 'cheque');
    });
  });
}
