import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/understanding/reader_service.dart';

/// مسیر واقعیِ برنامه: فایل‌های مدل از بستهٔ برنامه خوانده می‌شوند، مدل در
/// یک Isolate جدا ساخته می‌شود و حدس از همان‌جا برمی‌گردد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('خوانندهٔ موضوع در Isolate بالا می‌آید و همان حدسِ مرجع را می‌دهد',
      () async {
    final service = await ReaderService.start();
    expect(service, isNotNull);
    addTearDown(service!.dispose);
    expect(service.revision, isNotEmpty);
    expect(service.loadMillis, greaterThanOrEqualTo(0));

    final ref = jsonDecode(
            File('test/understanding/noql_ref.json').readAsStringSync())
        as Map<String, dynamic>;
    final cases = (ref['probe'] as List).cast<Map<String, dynamic>>();
    // چند درخواستِ هم‌زمان باید هرکدام جواب خودش را بگیرد.
    final picked = [cases[1], cases[7], cases[13]];
    final guesses = await Future.wait(
        [for (final c in picked) service.read(c['text'] as String)]);
    for (var i = 0; i < picked.length; i++) {
      final g = guesses[i];
      expect(g, isNotNull);
      expect(g!.label, picked[i]['label']);
      expect(g.score,
          closeTo((picked[i]['score'] as num).toDouble(), 0.01));
      expect(g.confident, picked[i]['confident']);
      expect(g.plausible, picked[i]['plausible']);
      expect(g.tokens, greaterThan(2));
    }
    expect(service.last, isNotNull);

    service.dispose();
    expect(await service.read('بعد از بستن'), isNull);
  }, timeout: const Timeout(Duration(minutes: 3)));
}
