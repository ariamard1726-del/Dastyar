// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('EXTRA retrieval report (no assertions)', () async {
    final e = KnowledgeEngine();
    await e.load();
    var n = 0, top1 = 0, top5 = 0;
    var mrr = 0.0;
    for (final l in File('brain/eval_extra.txt').readAsLinesSync()) {
      final t = l.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final r = t.split('|').map((x) => x.trim()).toList();
      final res = e.rank(r[0], k: 60);
      var rank = 0;
      for (var i = 0; i < res.hits.length; i++) {
        final c = res.hits[i].chunk;
        if (c.lawId == r[1] && c.title == r[2]) {
          rank = i + 1;
          break;
        }
      }
      n++;
      if (rank == 1) top1++;
      if (rank >= 1 && rank <= 5) top5++;
      if (rank > 0) mrr += 1 / rank;
      print('EXTRA rank ${rank == 0 ? '>60' : rank} | ${r[0]}');
    }
    print('EXTRA recall@1 ${(top1 / n).toStringAsFixed(2)} '
        'recall@5 ${(top5 / n).toStringAsFixed(2)} '
        'MRR ${(mrr / n).toStringAsFixed(3)}');
    expect(n, greaterThan(0));
  });
}
