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
    expect(e.lawCounts['labor'], 203);
  });

  test('ماده ۱۷۲ قانون کار با منبع و تبصره پیدا می‌شود', () {
    final a = e.answer('ماده ۱۷۲ قانون کار');
    expect(a, startsWith('ماده 172'));
    expect(a, contains('کار اجباری'));
    expect(a, contains('تبصره'));
    expect(a, contains('منبع: قانون کار'));
    expect(e.findArticle('قانون کار', '172'), isNotNull);
  });

  test('ماده ۱ قانون کار پیدا می‌شود', () {
    final a = e.answer('ماده ۱ قانون کار');
    expect(a, contains('کلیه کارفرمایان'));
  });
}
