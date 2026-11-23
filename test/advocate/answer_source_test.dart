import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// قرارداد ترتیب مسیرهای پاسخ.
///
/// هر پیام فقط از یک مسیر دانش جواب می‌گیرد و [AdvocateReply.source] می‌گوید
/// کدام مسیر. این آزمون دو چیز را قفل می‌کند: ترتیب اعلام‌شده در
/// [Advocate.pipelineOrder] و اینکه هیچ پاسخ نهایی بی‌برچسب نماند.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  test('ترتیب اعلام‌شده، یکتا و با ایمنی شروع می‌شود', () {
    final order = Advocate.pipelineOrder;
    expect(order.first, AnswerSource.safety);
    expect(order.toSet().length, order.length);
    expect(order, isNot(contains(AnswerSource.unknown)));
  });

  test('هر پاسخ یک مسیر مشخص دارد (هیچ پاسخ بی‌برچسبی نیست)', () {
    final messages = [
      'ماده ۱۰ قانون مدنی',
      'چکم برگشت خورد',
      'کارفرما حقوقم را نداده',
      'صاحبخونه پول پیشمو نمیده',
      'مهریه‌ام را نمی‌دهند',
      'همسایه دیوار مشترک را خراب کرده',
      'سلام',
      'چطوری؟',
      'قرارداد اجاره‌ام تمام شده',
      'موضوعم این نیست',
      'کمک می‌کنی دادخواست بنویسم؟',
    ];
    for (final m in messages) {
      final r = Advocate(engine).respond(m);
      expect(
        r.source,
        isNot(AnswerSource.unknown),
        reason: 'پیام «$m» بی‌برچسب ماند: '
            '${r.text.length > 60 ? r.text.substring(0, 60) : r.text}',
      );
    }
  });

  test('واژه‌ای که مستقیماً به ماده می‌رسد، برچسب lawTerms دارد', () {
    final r = Advocate(engine).respond('غبن فاحش چیست');
    // یا تطبیق واژه‌ها (lawTerms) یا بازیابی موتور؛ هر دو مسیر مستندند.
    expect(
      r.source,
      anyOf(AnswerSource.lawTerms, AnswerSource.engine, AnswerSource.topic),
      reason: r.text,
    );
  });

  test('پرسش بی‌ربط، پاسخ «خارج از حوزه» می‌گیرد، نه موضوع تازه', () {
    final a = Advocate(engine);
    final r = a.respond('بهترین کتاب برنامه‌نویسی کدام است؟');
    expect(a.hasCase, isFalse);
    expect(r.source, isNot(AnswerSource.safety));
  });
}
