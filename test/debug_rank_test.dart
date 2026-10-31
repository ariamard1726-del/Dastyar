// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('DBG rank', () async {
    final e = KnowledgeEngine();
    await e.load();
    for (final l in File('brain/debug_queries.txt').readAsLinesSync()) {
      final q = l.trim();
      if (q.isEmpty || q.startsWith('#')) continue;
      final res = e.rank(q, k: 6);
      print('DBG ? $q');
      for (var i = 0; i < res.hits.length && i < 6; i++) {
        final h = res.hits[i];
        print('DBG   ${i + 1} | ${h.chunk.lawId} | ${h.chunk.title} | '
            '${h.score.toStringAsFixed(2)}');
      }
    }
    expect(true, isTrue);
  });
}
