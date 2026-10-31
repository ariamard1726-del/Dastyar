import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';
import 'package:dastyar/persian_text.dart';

String _name(File f) => f.path.split(Platform.pathSeparator).last;

List<File> _templateFiles() {
  final dir = Directory('assets/templates');
  if (!dir.existsSync()) fail('پوشهٔ assets/templates پیدا نشد');
  final files = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();
  files.sort((a, b) => a.path.compareTo(b.path));
  return files;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine e;

  setUpAll(() async {
    e = KnowledgeEngine();
    await e.load();
  });

  test('هر ماده در lawRefs قالب‌ها در متن برنامه موجود است', () {
    final missing = <String>[];
    var checked = 0;
    for (final f in _templateFiles()) {
      final raw = jsonDecode(f.readAsStringSync());
      if (raw is! Map) continue;
      final refs = (raw['lawRefs'] as List?) ?? const [];
      for (final r in refs) {
        if (r is! Map) continue;
        final law = (r['law'] ?? '').toString();
        final art = (r['article'] ?? '').toString();
        checked++;
        if (law.isEmpty || art.isEmpty || e.findArticle(law, art) == null) {
          missing.add('${_name(f)}: ماده $art «$law» پیدا نشد');
        }
      }
    }
    expect(checked, greaterThan(0), reason: 'هیچ lawRefs ای پیدا نشد');
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('مواد ذکرشده در tips در قوانین همان قالب موجودند', () {
    final bad = <String>[];
    final cite = RegExp(r'(?:ماده|مواد)\s*(\d+(?:\s*(?:و|،)\s*\d+)*)');
    for (final f in _templateFiles()) {
      final raw = jsonDecode(f.readAsStringSync());
      if (raw is! Map) continue;
      final laws = <String>{};
      for (final r in (raw['lawRefs'] as List?) ?? const []) {
        if (r is Map && r['law'] != null) laws.add(r['law'].toString());
      }
      if (laws.isEmpty) continue;
      for (final t in (raw['tips'] as List?) ?? const []) {
        final text = PersianText.normalize(t.toString());
        for (final m in cite.allMatches(text)) {
          for (final n in RegExp(r'\d+').allMatches(m.group(1)!)) {
            final num = n.group(0)!;
            final ok = laws.any((law) => e.findArticle(law, num) != null);
            if (!ok) {
              bad.add(
                  '${_name(f)}: ماده $num در tips آمده، ولی در ${laws.join(" / ")} پیدا نشد');
            }
          }
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
