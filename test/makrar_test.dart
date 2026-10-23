import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine e;

  setUpAll(() async {
    e = KnowledgeEngine();
    await e.load();
  });

  test('قانون چک در برنامه بارگذاری شده است', () {
    expect(e.isLoaded('cheque'), isTrue);
  });

  test('نام رایج «قانون چک» شناخته می‌شود', () {
    final a = e.answer('ماده ۱۰ قانون چک');
    expect(a, contains('ماده 10'));
    expect(a, contains('قانون صدور چک'));
  });

  test('ماده ۲۱ مکرر چک با ماده ۲۱ فرق دارد', () {
    final a = e.answer('ماده ۲۱ مکرر قانون صدور چک');
    expect(a, startsWith('ماده 21 مکرر'));
    final b = e.answer('ماده ۲۱ قانون صدور چک');
    expect(b, startsWith('ماده 21\n'));
  });

  test('ماده ۸۸۱ مکرر مدنی', () {
    final a = e.answer('ماده ۸۸۱ مکرر قانون مدنی');
    expect(a, startsWith('ماده 881 مکرر'));
    expect(a, contains('کافر از مسلم'));
    final b = e.answer('ماده ۸۸۱ قانون مدنی');
    expect(b, contains('قتل عمدی'));
  });

  test('ماده ۱۳۱۳ مکرر مدنی', () {
    final a = e.answer('ماده ۱۳۱۳ مکرر قانون مدنی');
    expect(a, startsWith('ماده 1313 مکرر'));
    expect(a, contains('بلوغ'));
  });

  test('مکرر برای ماده‌ای که ندارد ساخته نمی‌شود', () {
    final a = e.answer('ماده ۱۰ مکرر قانون مدنی');
    expect(a, contains('پیدا نشد'));
  });
}
