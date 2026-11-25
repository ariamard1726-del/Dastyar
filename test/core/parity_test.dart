import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/conflicts_service.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/advocate/law_terms.dart';

/// برابری دوطرفهٔ پایتون↔دارت.
///
/// استاندارد طلایی با `python3 dev/tools/parity.py --write` از سمت پایتون
/// (dev/brain/common.py + dev/tools/eval_py.py + dev/brain/engine.py) تولید می‌شود و
/// `python3 dev/tools/check.py parity` در CI تازگی آن را تضمین می‌کند.
/// این تست همان ورودی‌ها را به سمت دارت می‌دهد و خروجی دقیقاً یکسان می‌خواهد؛
/// پس اگر یکی از دو موتور بدون دیگری تغییر کند، CI قرمز می‌شود.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> golden;
  late KnowledgeEngine engine;

  setUpAll(() async {
    golden = jsonDecode(
      File('dev/brain/parity_expected.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    engine = KnowledgeEngine();
    await engine.load();
  });

  test('لایهٔ متن: normalize/collapse/phrase/tokenizeIndex با آینهٔ پایتون یکسان است', () {
    final samples = (golden['text'] as List).cast<Map<String, dynamic>>();
    expect(samples, isNotEmpty);
    for (final m in samples) {
      final input = m['in'] as String;
      expect(PersianText.normalize(input), m['normalize'], reason: input);
      expect(
        PersianText.collapse(PersianText.normalize(input)),
        m['collapse'],
        reason: input,
      );
      expect(PersianText.phrase(input), m['phrase'], reason: input);
      expect(
        PersianText.tokenizeIndex(input),
        (m['tok'] as List).cast<String>(),
        reason: input,
      );
    }
  });

  test('زنجیرهٔ تضادها: ConflictsService با dev/brain/engine.py یکسان است', () {
    final data = jsonDecode(
      File('assets/relationships.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final svc = ConflictsService();
    final conflicts = (golden['conflicts'] as Map).cast<String, dynamic>();
    expect(conflicts, isNotEmpty);
    conflicts.forEach((id, chains) {
      expect(
        svc.getConflictsChain(id, data),
        (chains as List).cast<String>(),
        reason: 'مادهٔ $id',
      );
    });
  });

  test('رتبه‌بندی: top-3 موتور دارت با آینهٔ پایتون (dev/tools/eval_py.py) یکسان است', () {
    final rows = (golden['rank'] as List).cast<Map<String, dynamic>>();
    expect(rows, isNotEmpty);
    for (final m in rows) {
      final q = m['q'] as String;
      final want = (m['top'] as List)
          .map((t) => (t as List).cast<String>())
          .toList();
      final got = engine
          .rank(q, k: 3)
          .hits
          .map((h) => [h.chunk.lawId, h.chunk.title])
          .toList();
      expect(got, want, reason: q);
    }
  });

  test('تطبیق واژه‌ها با متن قوانین: LawTerms با dev/tools/law_terms.py یکسان است', () {
    final rows = (golden['terms'] as List).cast<Map<String, dynamic>>();
    expect(rows, isNotEmpty);
    final terms = LawTerms(engine);
    for (final m in rows) {
      final q = m['q'] as String;
      final got = terms.match(q);
      expect(got.accepted, m['accepted'], reason: q);
      expect(got.chunk?.lawId, m['law'], reason: q);
      expect(got.chunk?.title, m['title'], reason: q);
      expect(got.cover, closeTo((m['cover'] as num).toDouble(), 0.0005), reason: q);
      expect(got.matched, (m['matched'] as List).cast<String>(), reason: q);
      expect(got.missing, (m['missing'] as List).cast<String>(), reason: q);
      expect(got.phrases, (m['phrases'] as List).cast<String>(), reason: q);
      expect(got.unknown, (m['unknown'] as List).cast<String>(), reason: q);
    }
  });
}
