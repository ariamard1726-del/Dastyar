import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/assistant.dart';

class _CountingEngine extends KnowledgeEngine {
  int queryCalls = 0;
  int rankCalls = 0;

  @override
  EngineReply query(String question, {int maxAlternatives = 3}) {
    queryCalls++;
    return super.query(question, maxAlternatives: maxAlternatives);
  }

  @override
  RankResult rank(String question, {int k = 3}) {
    rankCalls++;
    return super.rank(question, k: k);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _CountingEngine engine;

  setUpAll(() async {
    engine = _CountingEngine();
    await engine.load();
  });

  group('نمایهٔ معکوس، جستجوی دودویی پیشوند و پرس‌وجوی تک‌مرحله‌ای', () {
    test('normTitle و normSource از پیش محاسبه می‌شوند و با نرمال‌سازی یکسان‌اند', () {
      final c = Chunk(
        'cheque',
        'قانون صدور چک',
        '',
        'ماده ۲۱ مکرر',
        'متن آزمایشی',
        false,
        const {},
        const {},
        const {},
        2,
      );
      expect(c.normTitle, 'ماده 21 مکرر');
      expect(c.normSource, 'قانون صدور چک');
    });

    test('جستجوی مادهٔ مکرر و پیشوند واژگان از روی نمایهٔ معکوس دقیق کار می‌کند', () {
      final hit = engine.findArticle('cheque', '۲۱ مکرر');
      expect(hit, isNotNull);
      expect(hit!.normTitle, 'ماده 21 مکرر');

      final ans = engine.answer('ماده ۲۱ مکرر قانون صدور چک');
      expect(ans, startsWith('ماده 21 مکرر'));
      expect(ans, contains('قانون صدور چک'));

      // بررسی تطابق خروجی query تک‌مرحله‌ای با answer و alternatives
      const q = 'شرایط صحت معامله در قانون مدنی';
      final unified = engine.query(q);
      expect(unified.text, engine.answer(q));
      expect(unified.alternatives, engine.alternatives(q));
      expect(unified.contextHits, isNotEmpty);
    });

    test('askWithAlternatives فقط یک بار query را فراخوانی می‌کند و rank اضافی نمی‌زند', () async {
      const q = 'ماده ۱۹۰ قانون مدنی';
      final expectedAnswer = engine.answer(q);

      engine.queryCalls = 0;
      engine.rankCalls = 0;

      final turns = await Assistant(engine).askWithAlternatives(q).toList();
      expect(turns, isNotEmpty);
      expect(turns.last.text, expectedAnswer);
      expect(engine.queryCalls, 1);
      expect(engine.rankCalls, 0);
    });
  });
}
