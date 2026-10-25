import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<KnowledgeEngine> load() async {
    final e = KnowledgeEngine();
    await e.load();
    return e;
  }

  int rankOf(KnowledgeEngine e, String q, String law, String title) {
    final res = e.rank(q, k: 60);
    for (var i = 0; i < res.hits.length; i++) {
      final c = res.hits[i].chunk;
      if (c.lawId == law && c.title == title) return i + 1;
    }
    return 0;
  }

  test('پرسش تعریفی: مادهٔ تعریف‌کننده اول می‌آید', () async {
    final e = await load();
    const cases = [
      ['بیع یعنی چی', 'civil', 'ماده 338'],
      ['عده یعنی چه', 'civil', 'ماده 1150'],
      ['عاریه چیست', 'civil', 'ماده 635'],
      ['رهن چیست و راهن و مرتهن چه کسانی هستند', 'civil', 'ماده 771'],
      ['اجاره چیست و موجر و مستاجر کیست', 'civil', 'ماده 466'],
      ['تاجر به چه کسی می‌گویند', 'commerce', 'ماده 1'],
      ['شرکت سهامی چیست', 'commerce_1347', 'ماده 1'],
    ];
    for (final c in cases) {
      expect(rankOf(e, c[0], c[1], c[2]), 1, reason: c[0]);
    }
    final k = rankOf(e, 'کفالت چیست', 'civil', 'ماده 734');
    expect(k >= 1 && k <= 2, isTrue, reason: 'کفالت چیست: رتبه $k');
  });

  test('پرسش غیرتعریفی دست‌نخورده می‌ماند', () async {
    final e = await load();
    final r = e.rank('ماده ۱۰ قانون مدنی', k: 3);
    expect(r.hits.first.score, 99);
  });
}
