import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/dialogue/dialogue_state.dart';
import 'package:dastyar/domain/dialogue/slot.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/domain/templates.dart';

CounselingSession _session([String topicId = 'general_intake']) =>
    CounselingSession(topicId: topicId, initialMessage: 'شروع گفتگو');

/// نشستی با planner فعال (اسلات پرشده) تا مسیر شمارندهٔ گیرکردن آزمون شود.
CounselingSession _chequeSessionWithSlot() {
  final s = _session('cheque');
  s.dialogueState = DialogueState.fresh(
    domain: 'cheque',
    topicId: 'cheque',
    initialMessage: 'چک برگشتی دارم',
  ).copyWith(
    slots: <String, SlotValue>{
      'role': SlotValue.confirmed(value: 'holder', sourceTurn: 0),
    },
  );
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final engine = KnowledgeEngine();
  const templates = <LegalTemplate>[];

  // متن خنثی: نه small talk را فعال میکند، نه پرسش حقوقی RAG است،
  // نه موضوع/اسلاتی از آن استخراج میشود.
  const neutral = 'یه نکتهای بود که هنوز نگفتهام';

  group('CounselorSessionState — Expando', () {
    test('مقادیر پیشفرض صفر و خالیاند', () {
      final s = _session();
      expect(CounselorSessionState.intakeAttempts(s), 0);
      expect(CounselorSessionState.stallCount(s), 0);
      expect(CounselorSessionState.conclusionShown(s), isFalse);
      expect(CounselorSessionState.property<String>(s, 'ندارد'), isNull);
    });

    test('شمارندهها فقط روی همان نشست افزایش مییابند', () {
      final a = _session();
      final b = _session();
      expect(CounselorSessionState.bumpIntakeAttempts(a), 1);
      expect(CounselorSessionState.bumpIntakeAttempts(a), 2);
      expect(CounselorSessionState.bumpStallCount(a), 1);
      expect(CounselorSessionState.intakeAttempts(a), 2);
      expect(CounselorSessionState.stallCount(a), 1);
      // Expando وضعیت را به خود شیء وصل میکند، نه به کلاس.
      expect(CounselorSessionState.intakeAttempts(b), 0);
      expect(CounselorSessionState.stallCount(b), 0);
    });

    test('نشست بازیافتشده از JSON وضعیت پویای نشست قبلی را نمیگیرد', () {
      final original = _session();
      CounselorSessionState.bumpIntakeAttempts(original);
      CounselorSessionState.setProperty(original, 'تذکر', 'جمعآوری مدارک');
      final restored = CounselingSession.fromJson(original.toJson())!;
      expect(restored, isNot(same(original)));
      expect(CounselorSessionState.intakeAttempts(restored), 0);
      expect(CounselorSessionState.property<String>(restored, 'تذکر'), isNull);
      // و حالت پویا هرگز وارد JSON ذخیرهشده نمیشود.
      expect(original.toJson().containsKey('تذکر'), isFalse);
      expect(original.toJson().containsKey('intakeAttempts'), isFalse);
    });

    test('ویژگیهای پویا typed هستند و قابل حذفاند', () {
      final s = _session();
      CounselorSessionState.setProperty<int>(s, 'شماره', 7);
      CounselorSessionState.setProperty<String>(s, 'یادداشت', 'مدارک ناقص');
      expect(CounselorSessionState.property<int>(s, 'شماره'), 7);
      expect(CounselorSessionState.property<String>(s, 'یادداشت'), 'مدارک ناقص');
      expect(CounselorSessionState.property<String>(s, 'شماره'), isNull,
          reason: 'نوع اشتباه نباید برگردانده شود');
      CounselorSessionState.clearProperty(s, 'یادداشت');
      expect(CounselorSessionState.property<String>(s, 'یادداشت'), isNull);
      expect(CounselorSessionState.property<int>(s, 'شماره'), 7);
    });

    test('reset همه چیز را پاک میکند و clearStalls فقط شمارندهٔ گیرکردن را', () {
      final s = _session();
      CounselorSessionState.bumpIntakeAttempts(s);
      CounselorSessionState.bumpStallCount(s);
      CounselorSessionState.markConclusionShown(s);
      CounselorSessionState.setProperty<String>(s, 'یادداشت', 'منتظر پاسخ');

      CounselorSessionState.clearStalls(s);
      expect(CounselorSessionState.stallCount(s), 0);
      expect(CounselorSessionState.conclusionShown(s), isFalse);
      expect(CounselorSessionState.intakeAttempts(s), 1);
      expect(CounselorSessionState.property<String>(s, 'یادداشت'), 'منتظر پاسخ');

      CounselorSessionState.bumpStallCount(s);
      CounselorSessionState.reset(s);
      expect(CounselorSessionState.intakeAttempts(s), 0);
      expect(CounselorSessionState.stallCount(s), 0);
      expect(CounselorSessionState.conclusionShown(s), isFalse);
      expect(CounselorSessionState.property<String>(s, 'یادداشت'), isNull);
    });
  });

  group('یکپارچگی Expando با LegalCounselor.step', () {
    test('شمارندهٔ پذیرش اولیه در نوبتهای متوالی و جداگانه', () {
      final s = _session();
      final t1 = LegalCounselor.step(s, neutral, engine, templates);
      final t2 = LegalCounselor.step(s, neutral, engine, templates);
      expect(t1.text, isNot(t2.text), reason: 'نوبت دوم باید متن متفاوتی بدهد');
      expect(CounselorSessionState.intakeAttempts(s), 2);

      final fresh = _session();
      expect(LegalCounselor.step(fresh, neutral, engine, templates).text, t1.text,
          reason: 'نشست تازه نباید شمارندهٔ نشست قبل را ببیند');

      CounselorSessionState.reset(s);
      expect(LegalCounselor.step(s, neutral, engine, templates).text, t1.text);
    });

    test('شروع دوبارهٔ گفتگوی بستهشده، حالت پویا را بازنشانی میکند', () {
      final s = _session();
      LegalCounselor.step(s, neutral, engine, templates);
      LegalCounselor.step(s, neutral, engine, templates);
      expect(CounselorSessionState.intakeAttempts(s), 2);

      s.concluded = true;
      final turn = LegalCounselor.step(s, neutral, engine, templates);
      expect(s.concluded, isFalse);
      expect(CounselorSessionState.intakeAttempts(s), 1);
      expect(turn.text, contains('کدام دسته'));
    });

    test('step() شمارندهٔ گیرکردن planner را افزایش میدهد', () {
      final s = _chequeSessionWithSlot();
      final turn = LegalCounselor.step(s, neutral, engine, templates);
      expect(CounselorSessionState.stallCount(s), 1);
      expect(turn.text, contains('به سؤال قبلی'));
      LegalCounselor.step(s, neutral, engine, templates);
      expect(CounselorSessionState.stallCount(s), 2);

      CounselorSessionState.clearStalls(s);
      expect(CounselorSessionState.stallCount(s), 0);
      expect(LegalCounselor.step(s, neutral, engine, templates).text,
          contains('به سؤال قبلی'));
      expect(CounselorSessionState.stallCount(s), 1);
    });

    test('جمعهبندی فقط یکبار نشان داده میشود', () {
      final s = _session();
      expect(CounselorSessionState.conclusionShown(s), isFalse);
      CounselorSessionState.markConclusionShown(s);
      expect(CounselorSessionState.conclusionShown(s), isTrue);
      final other = _session();
      expect(CounselorSessionState.conclusionShown(other), isFalse);
    });
  });
}
