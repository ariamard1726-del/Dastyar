import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine e;

  setUpAll(() async {
    e = KnowledgeEngine();
    await e.load();
  });

  test('فهرست قوانین بارگذاری می‌شود', () {
    expect(e.catalog, isNotEmpty);
  });

  test('قانونِ وارد‌نشده صریح اعلام می‌شود', () {
    if (e.isLoaded('cheque')) return;
    final a = e.answer('ماده ۱۰ قانون صدور چک چه می‌گوید');
    expect(a, contains('هنوز در برنامه نیست'));
  });

  test('نام رایج «قانون چک» هم شناخته می‌شود', () {
    if (e.isLoaded('cheque')) return;
    final a = e.answer('ماده ۲۱۷ قانون چک');
    expect(a, contains('هنوز در برنامه نیست'));
    expect(a.contains('قانون مدنی'), isFalse);
  });

  test('قانون ناشناخته ماده قانون دیگر نمی‌آورد', () {
    final a = e.answer('ماده ۱۰ قانون زمین شهری');
    expect(a, contains('نام این قانون را'));
  });

  test('فهرست قوانین', () {
    if (!e.isLoaded('civil')) return;
    final a = e.answer('چه قوانینی دارید؟');
    expect(a, contains('قانون مدنی'));
  });

  test('ماده با نام قانون مدنی', () {
    if (!e.isLoaded('civil')) return;
    final a = e.answer('ماده ۱۰ قانون مدنی');
    expect(a, contains('ماده 10'));
    expect(a, contains('قانون مدنی'));
  });

  test('ماده‌ای که وجود ندارد ساخته نمی‌شود', () {
    if (!e.isLoaded('civil')) return;
    final a = e.answer('ماده ۹۹۹۹ قانون مدنی');
    expect(a, contains('پیدا نشد'));
  });

  test('مادهٔ منسوخ علامت می‌خورد', () {
    if (!e.isLoaded('civil')) return;
    final c = e.findArticle('قانون مدنی', '653');
    if (c == null) return;
    expect(c.obsolete, isTrue);
    expect(e.answer('ماده ۶۵۳ قانون مدنی'), contains('منسوخ'));
  });
}
