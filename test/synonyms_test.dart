import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine e;

  setUpAll(() async {
    e = KnowledgeEngine();
    await e.load();
  });

  test('«قسطی» به مواد اعسار و تقسیط می‌رسد', () {
    final r = e.rank('میخوام قسطی بدم', k: 3);
    expect(r.hits, isNotEmpty);
    expect(r.hits.first.chunk.lawId, 'financial_sentences');
  });

  test('«چک پاس نشد» به قانون چک می‌رسد', () {
    final r = e.rank('چک من پاس نشد', k: 3);
    expect(r.hits, isNotEmpty);
    expect(r.hits.first.chunk.lawId, 'cheque');
  });

  test('«زندانیش کنم» به مواد حبس محکومیت مالی می‌رسد', () {
    final r = e.rank('بدهکار پول نمیده میخوام زندانیش کنم', k: 3);
    expect(r.hits, isNotEmpty);
    expect(r.hits.first.chunk.lawId, 'financial_sentences');
  });

  test('جست‌وجوی شمارهٔ ماده با فرهنگ تغییر نمی‌کند', () {
    final a = e.answer('ماده ۱۰ قانون مدنی');
    expect(a, startsWith('ماده 10'));
  });
}
