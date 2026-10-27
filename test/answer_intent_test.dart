import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  test('پرسش درباره توانایی دستیار پاسخ معرفی می‌دهد', () {
    final answer = engine.answer('سلام، تو چه کاری انجام می‌دهی؟');
    expect(answer, contains('دستیار حقوقی آفلاین'));
    expect(answer, isNot(contains('ماده ۳۷۵')));
    expect(answer, isNot(contains('ماده 375')));
  });

  test('پرسش درباره حکم قطعی قاضی پاسخ محتاطانه می‌دهد', () {
    final answer =
        engine.answer('در پرونده من قاضی دقیقاً چه حکمی صادر خواهد کرد؟');
    expect(answer, contains('به‌طور قطعی پیش‌بینی کنم'));
    expect(answer, isNot(contains('ماده ۱۲۸')));
    expect(answer, isNot(contains('ماده 128')));
  });

  test('پرسش عادی درباره مجازات به پاسخ عمومی پیش‌بینی تبدیل نمی‌شود', () {
    final answer = engine.answer('مجازات کلاهبرداری چیست؟');
    expect(answer, isNot(contains('حکم قاضی یا نتیجه یک پرونده')));
    expect(answer, isNot(contains('ماده ۴۳۸')));
    expect(answer, isNot(contains('ماده 438')));
    expect(answer, contains('پیدا نکردم'));
  });
}
