import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/groundedness.dart';

/// خودبررسی پاسخ (فاز ۴): استنادِ ماده/قانون باید دقیقاً همان چیزی باشد
/// که موتور بازیابی کرده است؛ چیزی بیش از آن «نقلِ قالب‌دار» است نه «استناد».
void main() {
  const allowed = {'1167', '384', '697'};
  const titles = ['قانون مدنی', 'قانون مجازات اسلامی'];

  test('پاسخِ بدون هیچ ارجاعی همیشه grounded است', () {
    expect(
      Groundedness.check('سلام، چطور می‌توانم کمکتان کنم؟',
          allowedArticles: allowed, allowedLawTitles: titles),
      isEmpty,
    );
  });

  test('مادهٔ در بازیابی پذیرفته می‌شود (با ارقام فارسی)', () {
    expect(
      Groundedness.check('طبق ماده ۳۸۴ قانون مدنی. مبیع…',
          allowedArticles: allowed, allowedLawTitles: titles),
      isEmpty,
    );
  });

  test('مادهٔ بیرونِ بازیابی نقض است', () {
    final issues = Groundedness.check('طبق ماده ۱۲۵ قانون مدنی…',
        allowedArticles: allowed, allowedLawTitles: titles);
    expect(issues, hasLength(1));
    expect(issues.first.kind, 'article');
  });

  test('نام قانونِ بیرونِ بازیابی نقض است', () {
    final issues = Groundedness.check('طبق قانون اساسی…',
        allowedArticles: allowed, allowedLawTitles: titles);
    expect(issues.map((e) => e.kind), contains('law'));
  });

  test('«قانون مدنی» با عنوان منبعِ بازیابی تطبیق می‌خورد', () {
    expect(
      Groundedness.check('ماده ۱۱۶۷ قانون مدنی',
          allowedArticles: allowed, allowedLawTitles: titles),
      isEmpty,
    );
  });

  test('اصلِ قانون اساسی هم با «اصل N» دیده می‌شود', () {
    expect(Groundedness.articleRefs('اصل ۳۷ قانون اساسی برائت را می‌گوید'),
        contains('37'));
  });

  test('isGrounded با نقض خالیِ true و با قانونِ بی‌ربط false است', () {
    expect(
      Groundedness.isGrounded('ماده ۳۸۴ قانون مدنی',
          allowedArticles: allowed, allowedLawTitles: titles),
      isTrue,
    );
    expect(
      Groundedness.isGrounded('ماده ۹۹۹۹ قانون مدنی',
          allowedArticles: allowed, allowedLawTitles: titles),
      isFalse,
    );
  });
}
