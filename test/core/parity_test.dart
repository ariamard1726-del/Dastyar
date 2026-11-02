import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/conflicts_service.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';

/// برابری دوطرفهٔ پایتون↔دارت.
///
/// استاندارد طلایی با `python3 tools/parity.py --write` از سمت پایتون
/// (brain/common.py + tools/eval_py.py + brain/engine.py) تولید می‌شود و
/// `python3 tools/check.py parity` در CI تازگی آن را تضمین می‌کند.
/// این تست همان ورودی‌ها را به سمت دارت می‌دهد و خروجی دقیقاً یکسان می‌خواهد؛
/// پس اگر یکی از دو موتور بدون دیگری تغییر کند، CI قرمز می‌شود.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> golden;
  late KnowledgeEngine engine;

  setUpAll(() async {
    golden = jsonDecode(
      File('brain/parity_expected.json').readAsStringSync(),
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

  test('زنجیرهٔ تضادها: ConflictsService با brain/engine.py یکسان است', () {
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

  test('رتبه‌بندی: top-3 موتور دارت با آینهٔ پایتون (tools/eval_py.py) یکسان است', () {
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
}
