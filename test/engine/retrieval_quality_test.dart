import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  group('دقت بازیابی تعاریف، مترادف‌های حقوقی و نگهبان حوزه‌های خارج از پوشش', () {
    test('پرسش «معسر کیست» و «مجازات چک برگشتی» دقیقاً مادهٔ اصلی را رتبهٔ ۱ می‌آورند', () {
      final r1 = engine.rank('معسر کیست', k: 3);
      expect(r1.hits, isNotEmpty);
      expect(r1.hits.first.chunk.lawId, 'financial_sentences');
      expect(r1.hits.first.chunk.title, 'ماده 6');

      final r2 = engine.rank('چک برگشتی چه مجازاتی دارد', k: 3);
      expect(r2.hits, isNotEmpty);
      expect(r2.hits.first.chunk.lawId, 'cheque');
      expect(r2.hits.first.chunk.title, 'ماده 7');

      final r3 = engine.rank('حداقل حقوق کارگر چقدر است', k: 3);
      expect(r3.hits, isNotEmpty);
      expect(r3.hits.first.chunk.lawId, 'labor');
    });

    test('قوانین تازه واردشده پاسخ مستند می‌دهند و حوزه‌های واقعاً خارج از برنامه رد می‌شوند', () {
      for (final q in const [
        'مجازات سرقت چیست',
        'مالیات بر درآمد حقوق چگونه محاسبه می‌شود',
        'حق بیمه تامین اجتماعی را چه کسی می‌پردازد',
        'شرایط طلاق یک‌طرفه از طرف زن چیست',
      ]) {
        final reply = engine.query(q);
        expect(reply.text, isNot(contains('پیدا نکردم')), reason: q);
      }

      for (final outQ in const [
        'شرایط معافیت کفالت سربازی چیست',
        'تعرفه ترخیص خودرو از گمرک چقدر است',
        'مدارک لازم برای گرفتن ویزای شنگن چیست',
      ]) {
        final reply = engine.query(outQ);
        expect(reply.text, contains('پیدا نکردم'), reason: outQ);
      }
    });
  });
}
