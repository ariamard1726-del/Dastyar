import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';

const int _span = 3;

int? _num(String title) {
  final m =
      RegExp(r'ماده\s*(\d+)').firstMatch(KnowledgeEngine.normalize(title));
  return m == null ? null : int.parse(m.group(1)!);
}

bool _near(Chunk c, String law, String title) {
  if (c.lawId != law) return false;
  if (c.title == title) return true;
  final a = _num(c.title);
  final b = _num(title);
  if (a == null || b == null) return false;
  return (a - b).abs() <= _span;
}

String _f(int x, int n) => n == 0 ? '0.00' : (x / n).toStringAsFixed(2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('NEAR-MISS report (no assertions)', () async {
    final e = KnowledgeEngine();
    await e.load();

    const files = [
      'brain/eval.txt',
      'brain/eval_v2.txt',
      'brain/eval_v3.txt',
      'brain/eval_v4.txt',
      'brain/eval_extra.txt',
      'brain/eval_blind.txt',
    ];

    final far = <String>[];
    var tn = 0, tExact = 0, tNear = 0, tLaw = 0, tNear5 = 0;

    for (final path in files) {
      final f = File(path);
      if (!f.existsSync()) continue;
      var n = 0, exact = 0, near = 0, law = 0, near5 = 0;
      for (final l in f.readAsLinesSync()) {
        final t = l.trim();
        if (t.isEmpty || t.startsWith('#')) continue;
        final r = t.split('|').map((x) => x.trim()).toList();
        if (r.length < 3) continue;
        final q = r[0], wantLaw = r[1], wantTitle = r[2];
        final res = e.rank(q, k: 5);
        n++;
        if (res.hits.isNotEmpty) {
          final top = res.hits.first.chunk;
          if (top.lawId == wantLaw && top.title == wantTitle) exact++;
          if (_near(top, wantLaw, wantTitle)) near++;
          if (top.lawId == wantLaw) law++;
        }
        final in5 = res.hits.any((h) => _near(h.chunk, wantLaw, wantTitle));
        if (in5) {
          near5++;
        } else {
          final got = res.hits.isEmpty
              ? 'هیچ'
              : '${res.hits.first.chunk.lawId} ${res.hits.first.chunk.title}';
          far.add('$path | $q | want $wantLaw $wantTitle | got $got');
        }
      }
      print('NEAR $path n=$n exact@1 ${_f(exact, n)} near@1 ${_f(near, n)} '
          'law@1 ${_f(law, n)} near@5 ${_f(near5, n)}');
      tn += n;
      tExact += exact;
      tNear += near;
      tLaw += law;
      tNear5 += near5;
    }

    print('NEAR TOTAL n=$tn exact@1 ${_f(tExact, tn)} near@1 ${_f(tNear, tn)} '
        'law@1 ${_f(tLaw, tn)} near@5 ${_f(tNear5, tn)}');
    for (final x in far) {
      print('NEAR far | $x');
    }
    expect(tn, greaterThan(0));
  });
}
