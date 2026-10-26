import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine e;

  setUpAll(() async {
    e = KnowledgeEngine();
    await e.load();
  });

  test('مادهٔ ۵۰ قانون تجارت: توضیح جایگزینی، نه «پیدا نشد»', () {
    if (!e.isLoaded('commerce')) return;
    final a = e.answer('ماده ۵۰ قانون تجارت');
    expect(a, contains('جایگزین شده'));
    expect(a.contains('پیدا نشد'), isFalse);
  });

  test('مادهٔ ۲۰ و ۹۴ قانون تجارت عادی جواب می‌دهند', () {
    if (!e.isLoaded('commerce')) return;
    expect(e.answer('ماده ۲۰ قانون تجارت'), contains('هفت قسم'));
    expect(e.answer('ماده ۹۴ قانون تجارت').contains('جایگزین شده'), isFalse);
  });

  test('ماده‌ای که واقعاً نیست همچنان پیدا نشد می‌گوید', () {
    if (!e.isLoaded('commerce')) return;
    expect(e.answer('ماده ۹۹۹۹ قانون تجارت'), contains('پیدا نشد'));
  });
}
