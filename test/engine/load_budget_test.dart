import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

int _dirBytes(String root, {bool Function(String path)? where}) {
  var total = 0;
  for (final entity in Directory(root).listSync(recursive: true)) {
    if (entity is File) {
      if (where == null || where(entity.path)) {
        total += entity.lengthSync();
      }
    }
  }
  return total;
}

/// نگهبان هزینهٔ استارت‌آپ و حافظه (فاز ۵، docs/PHASES.md).
///
/// بارگذاری ۲۴ فایل قانون (~۳٫۲ مگابایت) با `cache: false` روی `rootBundle`
/// انجام می‌شود تا رشته‌های خام در حافظه دوبله نشوند، و مدل ۱۲٫۹ مگابایتی
/// Noql فقط در صورت نیاز بار می‌شود. این آزمون زمان بارگذاری سرد، worker،
/// نخستین پرسش و اندازهٔ حافظه/دارایی را در `reports/startup.txt` ثبت می‌کند.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('بارگذاری کامل بانک قوانین و worker زیر سقف بودجهٔ زمان می‌ماند', () async {
    final sw = Stopwatch()..start();
    final engine = KnowledgeEngine();
    await engine.load();
    sw.stop();

    final m = engine.startupMetrics;
    expect(m, isNotNull);
    if (m == null) return;
    expect(engine.size, greaterThan(5000),
        reason: 'کل بخش‌های دانش باید بارگذاری شود');
    expect(m.lawsCount, greaterThanOrEqualTo(24));
    expect(m.vocabSize, greaterThan(1000));
    expect(m.withWorker, isFalse);
    expect(sw.elapsedMilliseconds, lessThan(15000),
        reason: 'ساخت نمایه از ${sw.elapsedMilliseconds}ms فراتر رفت؛ '
            'docs/ARCHITECTURE.md (بند هزینهٔ استارت‌آپ) را ببینید');

    final qSw = Stopwatch()..start();
    final reply = Advocate(engine).respond('صاحبخانه پول پیشم را پس نمی‌دهد');
    qSw.stop();
    expect(reply.text, isNotEmpty);
    expect(qSw.elapsedMilliseconds, lessThan(5000));

    final workerEngine = KnowledgeEngine();
    await workerEngine.load(startWorker: true);
    addTearDown(workerEngine.dispose);
    final wm = workerEngine.startupMetrics;
    expect(wm, isNotNull);
    if (wm == null) return;
    expect(wm.withWorker, isTrue);
    expect(wm.totalMillis, lessThan(15000));

    const mb = 1024 * 1024;
    final assetsMb = _dirBytes('assets') / mb;
    final lawsMb = _dirBytes('assets/laws') / mb;
    final noqlMb = _dirBytes(
          'assets/brain',
          where: (p) => p.split(Platform.pathSeparator).last.startsWith('noql'),
        ) /
        mb;
    final rssMb = ProcessInfo.currentRss / mb;

    Directory('reports').createSync(recursive: true);
    File('reports/startup.txt').writeAsStringSync(
      'STARTUP-BASELINE '
      'load_ms=${m.totalMillis} '
      'assets_ms=${m.assetsMillis} '
      'index_ms=${m.indexMillis} '
      'worker_load_ms=${wm.totalMillis} '
      'first_query_ms=${qSw.elapsedMilliseconds} '
      'laws=${m.lawsCount} '
      'chunks=${m.chunksCount} '
      'vocab=${m.vocabSize} '
      'assets_mb=${assetsMb.toStringAsFixed(2)} '
      'laws_mb=${lawsMb.toStringAsFixed(2)} '
      'lazy_noql_mb=${noqlMb.toStringAsFixed(2)} '
      'rss_mb=${rssMb.toStringAsFixed(1)}\n'
      'LOAD_BUDGET_MS=15000\n'
      'WORKER_LOAD_BUDGET_MS=15000\n'
      'FIRST_QUERY_BUDGET_MS=5000\n',
    );
  });
}
