import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  group('زنجیرهٔ تعارض/ارتباط مواد در موتور', () {
    test('conflictChainsFor و EngineReply زنجیرهٔ ثبت‌شده در relationships.json را استخراج می‌کنند', () {
      final c101 = engine.findArticle('قانون مدنی', '101');
      expect(c101, isNotNull);
      if (c101 != null) {
        final chains = engine.conflictChainsFor(c101);
        expect(chains, contains('۱۰۱ -> ۱۰۵ -> ۱۰۸ -> ۱۰۹'));
      }

      final reply = engine.query('ماده ۱۰۱ قانون مدنی');
      expect(reply.conflictChains, contains('۱۰۱ -> ۱۰۵ -> ۱۰۸ -> ۱۰۹'));

      final normalReply = engine.query('ماده ۱۰ قانون مدنی');
      expect(normalReply.conflictChains, isEmpty);
    });
  });
}
