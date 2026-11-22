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

  group('شناسنامهٔ منبع قوانین', () {
    const required = [
      'title',
      'source',
      'url',
      'date',
      'amended',
      'articles',
      'path',
      'sha256',
      'status',
    ];

    test('هر قانون همهٔ فیلدهای شناسنامه را دارد', () {
      expect(engine.meta, isNotEmpty);
      for (final e in engine.meta.entries) {
        for (final k in required) {
          expect(e.value.containsKey(k), isTrue,
              reason: '${e.key}: فیلد $k نیست');
        }
        expect(['verified', 'unverified'], contains(e.value['status']),
            reason: e.key);
        expect(RegExp(r'^[0-9a-f]{64}$').hasMatch('${e.value['sha256']}'),
            isTrue,
            reason: e.key);
      }
    });

    test('هیچ قانونی بدون نشانیِ منبع رسمی «تطبیق‌شده» نیست', () {
      for (final e in engine.meta.entries) {
        if (e.value['status'] != 'verified') continue;
        final url = '${e.value['url']}';
        expect(url.startsWith('https://'), isTrue, reason: e.key);
        expect('${e.value['source']}'.contains('اختبار'), isFalse,
            reason: e.key);
      }
    });

    test('زیر متن ماده، وضعیت تطبیق با منبع رسمی گفته می‌شود', () {
      final r = engine.answer('اصل ۲۲ قانون اساسی چه می‌گوید؟');
      final verified = engine.meta['constitution']?['status'] == 'verified';
      expect(r.contains('هنوز با منبع رسمی تطبیق داده نشده'), !verified);
      expect(r, contains('تاریخ دریافت متن'));
    });

    test('ماده‌های ۶۹ و ۷۲ قانون مجازات جدا پیدا می‌شوند', () {
      final a69 = engine.answer('ماده ۶۹ قانون مجازات اسلامی');
      expect(a69, contains('ماده 69'));
      expect(a69, contains('مرتکبان جرایمی'));
      final a72 = engine.answer('ماده ۷۲ قانون مجازات اسلامی');
      expect(a72, contains('ماده 72'));
      expect(a72, contains('جرایم عمدی'));
    });
  });
}
