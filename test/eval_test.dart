// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/drafting.dart';
import 'package:dastyar/engine.dart';
import 'package:dastyar/templates.dart';

List<List<String>> rows(String path) {
  final out = <List<String>>[];
  for (final l in File(path).readAsLinesSync()) {
    final t = l.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    out.add(t.split('|').map((e) => e.trim()).toList());
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('EVAL retrieval on the real engine', () async {
    final e = KnowledgeEngine();
    await e.load();
    var n = 0, top1 = 0, top5 = 0;
    var mrr = 0.0;
    for (final r in rows('brain/eval.txt')) {
      final q = r[0], law = r[1], title = r[2];
      final res = e.rank(q, k: 60);
      var rank = 0;
      for (var i = 0; i < res.hits.length; i++) {
        final c = res.hits[i].chunk;
        if (c.lawId == law && c.title == title) {
          rank = i + 1;
          break;
        }
      }
      n++;
      if (rank == 1) top1++;
      if (rank >= 1 && rank <= 5) top5++;
      if (rank > 0) mrr += 1 / rank;
      print('EVAL rank ${rank == 0 ? '>60' : rank} | $q');
    }
    print('EVAL retrieval recall@1 ${(top1 / n).toStringAsFixed(2)} '
        'recall@5 ${(top5 / n).toStringAsFixed(2)} MRR ${(mrr / n).toStringAsFixed(3)}');
    expect(top5 / n, greaterThanOrEqualTo(0.80));
    expect(mrr / n, greaterThanOrEqualTo(0.50));
  });

  test('EVAL intents on the real rules', () async {
    final ts = <LegalTemplate>[];
    for (final f in Directory('assets/templates').listSync()) {
      if (f is File && f.path.endsWith('.json')) {
        ts.add(LegalTemplate.fromJson(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>));
      }
    }
    var ok = 0, n = 0;
    for (final r in rows('brain/intents.txt')) {
      final want = r[0], text = r[1];
      final sug = Drafting.suggest(text, ts);
      final got = sug.template?.id ??
          (sug.choices.length <= 3 && sug.choices.any((t) => t.id == want)
              ? want
              : 'none');
      n++;
      if (got == want) {
        ok++;
      } else {
        final sc = ts.map((t) => '${t.id}=${Drafting.keywordScore(text, t)}').join(' ');
        print('EVAL intent wrong: want $want got $got | $text');
        print('EVAL   scores: $sc');
      }
    }
    print('EVAL intent accuracy ${(ok / n).toStringAsFixed(2)} ($ok/$n)');
    expect(ok / n, greaterThanOrEqualTo(0.90));
  });
}
