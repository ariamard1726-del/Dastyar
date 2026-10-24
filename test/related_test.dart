import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine e;

  setUpAll(() async {
    e = KnowledgeEngine();
    await e.load();
  });

  test('بیش از دو ماده‌ی نزدیک نشان داده نمی‌شود', () {
    final a = e.answer('چک من پاس نشد');
    expect('•'.allMatches(a).length, lessThanOrEqualTo(2));
  });

  test('جست‌وجوی دقیق شمارهٔ ماده ماده‌ی نزدیک اضافه نمی‌کند', () {
    final a = e.answer('ماده ۱۰ قانون مدنی');
    expect(a.contains('مواد نزدیک دیگر'), isFalse);
  });
}
