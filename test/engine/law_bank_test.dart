import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  group('۱. تکمیل ۱۰۰٪ بانک قوانین رسمی و پشتیبانی از اصول قانون اساسی', () {
    test('تمام قوانین فهرست کاتالوگ (۲۴ قانون، بیش از ۵۶۰۰ ماده/اصل) بارگذاری شده‌اند', () {
      expect(engine.catalog.length, greaterThanOrEqualTo(24));
      for (final law in engine.catalog) {
        expect(
          engine.isLoaded(law.id),
          isTrue,
          reason: 'قانون ${law.id} (${law.title}) باید کامل بارگذاری شده باشد',
        );
      }
      expect(engine.size, greaterThan(5500));
    });

    test('جستجوی مستقیم اصول قانون اساسی با واژهٔ «اصل» کار می‌کند', () {
      final r22 = engine.answer('اصل ۲۲ قانون اساسی چه می‌گوید؟');
      expect(r22, contains('اصل 22'));
      expect(r22, contains('حیثیت'));

      final r37 = engine.answer('اصل ۳۷ قانون اساسی');
      expect(r37, contains('اصل 37'));
      expect(r37, contains('برائت'));

      final missing = engine.answer('اصل ۳۰۰ قانون اساسی');
      expect(missing, contains('پیدا نشد'));
    });

    test('گسترش فرهنگ لغات محاوره‌ای روی قوانین جدید دقیق کار می‌کند', () {
      final cyber =
          engine.rank('مجازات برداشت اینترنتی از حساب و فیشینگ چیست', k: 3);
      expect(cyber.hits.first.chunk.lawId, 'cybercrime');
      expect(cyber.hits.first.chunk.title, 'ماده 13');

      final vakhoahi =
          engine.rank('مهلت واخواهی از حکم غیابی در دادگاه حقوقی چقدر است', k: 3);
      expect(vakhoahi.hits.first.chunk.lawId, 'civil_procedure');
      expect(vakhoahi.hits.first.chunk.title, 'ماده 306');

      final mehrieh =
          engine.rank('مهریه تا چند سکه ضمانت اجرای جلب دارد', k: 3);
      expect(mehrieh.hits.first.chunk.lawId, 'family_protection');
      expect(mehrieh.hits.first.chunk.title, 'ماده 22');
    });
  });
}
