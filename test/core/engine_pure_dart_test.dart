import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';

void main() {
  // آگاهانه بدون TestWidgetsFlutterBinding: ثابت می‌کند موتور بدون rootBundle
  // فلاتر و فقط با AssetTextLoaderِ خالص Dart تمام ۲۴ قانون را می‌خواند.
  test('KnowledgeEngine با AssetTextLoader خالص و بدون rootBundle بارگذاری و پاسخ می‌دهد',
      () async {
    final engine = KnowledgeEngine(
      assetLoader: (path) => File(path).readAsString(),
    );
    await engine.load();

    expect(engine.warnings, isEmpty);
    expect(engine.startupMetrics?.lawsCount, 24);
    expect(engine.size, greaterThan(5000));
    expect(engine.findArticle('قانون مدنی', '۱۰۴۱'), isNotNull);

    final reply = engine.query('موجر ودیعه را پس نمی‌دهد');
    expect(reply.answered, isTrue);
    expect(reply.contextHits, isNotEmpty);
    expect(engine.rank('موجر ودیعه را پس نمی‌دهد').hits, isNotEmpty);
    expect(reply.text.trim(), isNotEmpty);
  });
}
