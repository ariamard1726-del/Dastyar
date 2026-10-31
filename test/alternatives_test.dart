// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('alternatives resolve back to exact articles', () async {
    final e = KnowledgeEngine();
    await e.load();
    final qs = [
      'وصیت چند نوع است',
      'اکراه به چه کارهایی گفته می‌شود',
      'چک برگشتی چه مجازاتی دارد',
      'حبس کسی که محکومیت مالی را نمی‌پردازد',
    ];
    var total = 0;
    for (final q in qs) {
      final alts = e.alternatives(q);
      expect(alts.length, lessThanOrEqualTo(3));
      for (final a in alts) {
        final r = e.rank(a, k: 3);
        expect(r.hits, isNotEmpty, reason: a);
        expect(r.hits.first.score, greaterThanOrEqualTo(99), reason: a);
        total++;
      }
    }
    print('ALT chips checked: $total');
    expect(total, greaterThan(0));
    expect(e.alternatives('ماده 10 قانون مدنی'), isEmpty);
  });
}
