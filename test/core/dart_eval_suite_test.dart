// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/advocate/law_terms.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topic_flow.dart';

/// اجراگر یکپارچهٔ سنجش‌های واقعی Dart روی تمام مجموعه‌های ارزیابی و رگرسیون:
///   ۱) PersianText / Sense روی `tests/text_norm_golden.json`،
///      `tests/text_norm_norm_cases.json` و `dev/brain/parity_expected.json`
///   ۲) KnowledgeEngine روی `eval/*.txt` (`eval`, `eval_extra`, `eval_blind`,
///      `eval_all_laws`, `eval_everyday_laws`, `eval_none`, و `eval_feedback` در صورت وجود)
///   ۳) LawTerms روی `tests/law_terms/cases.json` و `tests/law_terms/audit.json`
///   ۴) TopicFlow روی `tests/topics/*.json` (شامل `_gold` و `_heldout`)
///
/// گزارش خلاصه در `reports/dart_eval.txt` نوشته می‌شود تا CI و `dev/tools/dart_eval.py`
/// خروجی مستقیم موتور Dart را بدون بازنویسی پایتونی تایید کنند.
List<List<String>> _pipeRows(String path) {
  final out = <List<String>>[];
  for (final line in File(path).readAsLinesSync()) {
    final t = line.trim();
    if (t.isEmpty || t.startsWith('#')) continue;
    out.add(t.split('|').map((e) => e.trim()).toList());
  }
  return out;
}

({double r1, double r5, double mrr, int n}) _evalRanking(
  KnowledgeEngine engine,
  String path,
) {
  final rows = _pipeRows(path);
  var r1 = 0;
  var r5 = 0;
  var mrr = 0.0;
  for (final row in rows) {
    final q = row[0];
    final wantLaw = row[1];
    final wantTitle = row[2];
    final hits = engine.rank(q, k: 60).hits;
    var rank = 0;
    for (var i = 0; i < hits.length; i++) {
      final c = hits[i].chunk;
      if (c.lawId == wantLaw && c.title == wantTitle) {
        rank = i + 1;
        break;
      }
    }
    if (rank == 1) r1++;
    if (rank >= 1 && rank <= 5) r5++;
    if (rank > 0) mrr += 1.0 / rank;
  }
  final n = rows.length;
  return (r1: r1 / n, r5: r5 / n, mrr: mrr / n, n: n);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  final reportLines = <String>[
    '# گزارش ارزیابی مستقیم کد واقعی Dart (PersianText / KnowledgeEngine / LawTerms / TopicFlow)',
  ];

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  tearDownAll(() {
    Directory('reports').createSync(recursive: true);
    File('reports/dart_eval.txt').writeAsStringSync(
      '${reportLines.join('\n')}\n',
    );
  });

  test('PersianText و Sense روی نمونه‌های مرجع یکپارچه', () {
    final golden = jsonDecode(
      File('tests/text_norm_golden.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final normCases = jsonDecode(
      File('tests/text_norm_norm_cases.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final parity = jsonDecode(
      File('dev/brain/parity_expected.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    final normRows =
        (golden['normalize'] as List).cast<Map<String, dynamic>>();
    for (final row in normRows) {
      expect(PersianText.normalize(row['in'] as String), row['out']);
    }
    final toolsRows = (golden['spaced'] as List).cast<Map<String, dynamic>>();
    for (final row in toolsRows) {
      expect(TopicFlow.spaced(row['in'] as String), row['out']);
    }
    final termsRows =
        (golden['spaced_terms'] as List).cast<Map<String, dynamic>>();
    for (final row in termsRows) {
      expect(LawTerms.spaced(row['in'] as String), row['out']);
    }
    final senseRows =
        (normCases['cases'] as List).cast<Map<String, dynamic>>();
    for (final row in senseRows) {
      expect(Sense.norm(row['in'] as String), row['out']);
    }
    final parityText = (parity['text'] as List).cast<Map<String, dynamic>>();
    for (final row in parityText) {
      final input = row['in'] as String;
      expect(PersianText.normalize(input), row['normalize']);
      expect(
        PersianText.collapse(PersianText.normalize(input)),
        row['collapse'],
      );
      expect(PersianText.phrase(input), row['phrase']);
      expect(
        PersianText.tokenizeIndex(input),
        (row['tok'] as List).cast<String>(),
      );
    }

    final line =
        'DART_EVAL text_norm ok: golden=${normRows.length + toolsRows.length + termsRows.length} '
        'sense=${senseRows.length} parity=${parityText.length}';
    print(line);
    reportLines.add(line);
  });

  test('KnowledgeEngine روی مجموعهٔ کامل eval/*.txt از آستانه‌ها می‌گذرد', () {
    const thresholds = <String, ({double r1, double r5, double mrr})>{
      'eval.txt': (r1: 0.75, r5: 0.85, mrr: 0.80),
      'eval_extra.txt': (r1: 0.70, r5: 0.90, mrr: 0.78),
      'eval_blind.txt': (r1: 0.55, r5: 0.80, mrr: 0.65),
      'eval_all_laws.txt': (r1: 0.75, r5: 0.90, mrr: 0.80),
      'eval_feedback.txt': (r1: 0.45, r5: 0.78, mrr: 0.60),
    };

    for (final name in thresholds.keys) {
      final file = File('eval/$name');
      if (!file.existsSync()) continue;
      final res = _evalRanking(engine, file.path);
      final min = thresholds[name]!;
      final line = 'DART_EVAL $name: n=${res.n} '
          'recall@1=${res.r1.toStringAsFixed(2)} '
          'recall@5=${res.r5.toStringAsFixed(2)} '
          'MRR=${res.mrr.toStringAsFixed(3)}';
      print(line);
      reportLines.add(line);
      expect(res.r1, greaterThanOrEqualTo(min.r1), reason: name);
      expect(res.r5, greaterThanOrEqualTo(min.r5), reason: name);
      expect(res.mrr, greaterThanOrEqualTo(min.mrr), reason: name);
    }

    final everydayRows = _pipeRows('eval/eval_everyday_laws.txt');
    var lawOk = 0;
    for (final row in everydayRows) {
      final allowed = row[1]
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      final hits = engine.rank(row[0], k: 1).hits;
      if (hits.isNotEmpty && allowed.contains(hits.first.chunk.lawId)) {
        lawOk++;
      }
    }
    final lawAcc = lawOk / everydayRows.length;
    final everydayLine =
        'DART_EVAL eval_everyday_laws.txt: n=${everydayRows.length} '
        'law@1=${lawAcc.toStringAsFixed(2)}';
    print(everydayLine);
    reportLines.add(everydayLine);
    expect(lawAcc, greaterThanOrEqualTo(0.90));
  });

  test('KnowledgeEngine روی eval/eval_none.txt نرخ پاسخ غلط <= ۱۰٪ دارد', () {
    final qs = <String>[
      for (final raw in File('eval/eval_none.txt').readAsLinesSync())
        if (raw.trim().isNotEmpty && !raw.trim().startsWith('#')) raw.trim(),
    ];
    final falseConfident = <String>[];
    for (final q in qs) {
      final reply = engine.query(q, maxAlternatives: 0);
      if (reply.answered) {
        falseConfident.add(q);
      }
    }
    final rate = qs.isEmpty ? 0.0 : (100.0 * falseConfident.length / qs.length);
    final line =
        'DART_EVAL eval_none.txt: n=${qs.length} rejected=${qs.length - falseConfident.length} '
        'false_confident=${falseConfident.length} (${rate.toStringAsFixed(1)}%)';
    print(line);
    reportLines.add(line);
    expect(
      rate,
      lessThanOrEqualTo(10.0),
      reason: 'پاسخ غلط روی بی‌پاسخ‌ها: ${falseConfident.join(' | ')}',
    );
  });

  test('LawTerms روی tests/law_terms/cases.json و audit.json بدون رگرسیون است', () {
    final terms = LawTerms(engine);
    final cases = (jsonDecode(
      File('tests/law_terms/cases.json').readAsStringSync(),
    ) as List).cast<Map<String, dynamic>>();
    for (final c in cases) {
      final q = c['q'] as String;
      final exp = c['expect'] as Map<String, dynamic>;
      final got = terms.match(q);
      expect(got.accepted, exp['accepted'], reason: q);
      if (exp.containsKey('law')) {
        expect(got.chunk?.lawId, exp['law'], reason: q);
      }
      if (exp.containsKey('title')) {
        expect(got.chunk?.title, exp['title'], reason: q);
      }
      for (final w in (exp['missing'] as List? ?? const [])) {
        expect(got.missing, contains(w), reason: q);
      }
    }

    final audit = (jsonDecode(
      File('tests/law_terms/audit.json').readAsStringSync(),
    ) as List).cast<Map<String, dynamic>>();
    var okCount = 0;
    var openCount = 0;
    final bodyFails = <String>[];
    for (final item in audit) {
      final q = item['q'] as String;
      final status = item['status'] as String;
      final got = terms.match(q);
      if (status == 'open') {
        openCount++;
        continue;
      }
      okCount++;
      expect(got.accepted, item['accepted'], reason: 'audit ok: $q');
      if (item.containsKey('law')) {
        expect(got.chunk?.lawId, item['law'], reason: 'audit ok: $q');
      }
      if (item.containsKey('title')) {
        expect(got.chunk?.title, item['title'], reason: 'audit ok: $q');
      }
      final forbidden = (item['not_law'] as List? ?? const []).cast<String>();
      if (got.accepted && got.chunk != null) {
        expect(forbidden, isNot(contains(got.chunk!.lawId)), reason: q);
        final body = '${got.chunk!.body} ${got.chunk!.title}';
        for (final w in (item['body_has'] as List? ?? const []).cast<String>()) {
          if (!body.contains(w)) {
            bodyFails.add('$q: نبود «$w»');
          }
        }
      }
    }
    expect(bodyFails, isEmpty);
    final line =
        'DART_EVAL law_terms: cases=${cases.length}/${cases.length} '
        'audit_ok=$okCount audit_open=$openCount';
    print(line);
    reportLines.add(line);
  });

  test('TopicFlow روی تمام نمونه‌های tests/topics/*_gold.json و heldout درست است', () {
    final index = jsonDecode(
      File('assets/brain/topics/index.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final flows = <String, Map<String, dynamic>>{};
    for (final name in (index['topics'] as List).cast<String>()) {
      final stem = name.replaceAll('.json', '');
      flows[stem] = jsonDecode(
        File('assets/brain/topics/$name').readAsStringSync(),
      ) as Map<String, dynamic>;
    }
    final labDir = Directory('lab/topics');
    if (labDir.existsSync()) {
      for (final f in labDir.listSync().whereType<File>()) {
        if (!f.path.endsWith('.json')) continue;
        final stem = f.uri.pathSegments.last.replaceAll('.json', '');
        flows.putIfAbsent(
          stem,
          () => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
        );
      }
    }

    var total = 0;
    final bad = <String>[];
    final files = Directory('tests/topics')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final file in files) {
      final base = file.uri.pathSegments.last;
      final stem = base
          .replaceAll('_gold.json', '')
          .replaceAll('_heldout.json', '');
      final flow = flows[stem];
      if (flow == null) {
        bad.add('جریان پیدا نشد: $base');
        continue;
      }
      final rows = (jsonDecode(file.readAsStringSync()) as List)
          .cast<Map<String, dynamic>>();
      for (final row in rows) {
        total++;
        final got = TopicFlow.route(flow, row['q'] as String);
        final want = row['leaf'] as String;
        if (got != want) {
          bad.add('[$base] ${row['q']}: want=$want got=$got');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join(' | '));
    final line =
        'DART_EVAL topic_flow: files=${files.length} cases=$total/$total';
    print(line);
    reportLines.add(line);
  });
}
