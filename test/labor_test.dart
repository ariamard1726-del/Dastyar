import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine e;

  setUpAll(() async {
    e = KnowledgeEngine();
    await e.load();
  });

  test('قانون کار در برنامه بارگذاری شده است', () {
    expect(e.isLoaded('labor'), isTrue);
  });

  test('ماده ۱۷۲ قانون کار پیدا می‌شود', () {
    final a = e.answer('ماده ۱۷۲ قانون کار');
    expect(a, startsWith('ماده 172'));
    expect(a, contains('کار اجباری'));
  });

  test('ماده ۱ قانون کار پیدا می‌شود', () {
    final a = e.answer('ماده ۱ قانون کار');
    expect(a, contains('کلیه کارفرمایان'));
  });
}
