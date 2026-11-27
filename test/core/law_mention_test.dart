import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/law_mention.dart';
import 'package:dastyar/core/models.dart';

/// «کدام قانون در این جمله نام برده شده؟» باید بی‌نیاز از بانکِ قوانین آزمون
/// شود. اگر این کار دوباره به `KnowledgeEngine` چسبیده باشد، آزمودنش یعنی
/// بارگذاریِ همهٔ دارایی‌ها؛ همان چیزی که تا امروز مانعِ آزمونش بود.
CatalogLaw _law(String id, String title, [List<String> aliases = const []]) =>
    CatalogLaw(id, title, 'c', 1, aliases);

void main() {
  final mention = LawMention(
    catalog: [
      _law('labor', 'قانون کار'),
      _law('penal', 'قانون مجازات اسلامی'),
      _law('penal_tazirat', 'قانون مجازات اسلامی تعزیرات'),
      _law('rent', 'قانون روابط موجر و مستاجر', ['قانون موجر و مستاجر']),
    ],
    isLoaded: (id) => id == 'labor' || id == 'rent',
  );

  test('نام قانون از متن بیرون می‌آید', () {
    expect(mention.mentioned('طبق قانون کار، اضافه‌کاری‌ام پرداخت نشده').map((l) => l.id),
        ['labor']);
  });

  test('نام کوتاه داخل نام بلند دوباره شمرده نمی‌شود', () {
    final ids = mention
        .mentioned('این مادهٔ قانون مجازات اسلامی تعزیرات است')
        .map((l) => l.id)
        .toList();
    expect(ids, ['penal_tazirat']);
  });

  test('نام مستعار هم شناخته می‌شود', () {
    expect(mention.mentioned('قانون موجر و مستاجر چه می‌گوید').map((l) => l.id),
        ['rent']);
  });

  test('فقط قوانینِ موجود در بانک در فهرست می‌آیند', () {
    expect(mention.loaded().map((l) => l.id), ['labor', 'rent']);
  });

  test('درخواستِ فهرست قوانین شناخته می‌شود', () {
    expect(mention.asksLawList('چه قوانینی داری؟'), isTrue);
    expect(mention.asksLawList('اضافه‌کاری‌ام را نمی‌دهند'), isFalse);
  });
}
