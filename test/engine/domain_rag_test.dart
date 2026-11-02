import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  group('مأموریت ۵: RAG دومرحله\u200cای (اول حوزه، بعد جست\u200cوجو)', () {
    test('مرحلهٔ نخست حوزهٔ چک را تشخیص می\u200cدهد و قوانین بی\u200cربط را مجاز نمی\u200cداند',
        () {
      final d = engine.detectDomain('چک و ماده 541');
      expect(d.uncertain, isFalse);
      expect(d.id, 'cheque');
      expect(d.lawIds, contains('cheque'));
      expect(d.lawIds, isNot(contains('civil')));
      expect(d.lawIds, isNot(contains('penal')));
      expect(d.lawIds, isNot(contains('criminal_procedure')));
    });

    test('نام صریح قانون بر تشخیص حوزه مقدم است', () {
      const q = 'ماده 541 قانون تجارت';
      final d = engine.detectDomain(q, mentioned: engine.mentionedLaws(q));
      expect(d.id, isNull);
      expect(d.uncertain, isFalse);
      expect(d.lawIds, isEmpty);
    });

    test('خطای «چک ← ماده ۵۴۱ قانون مدنی» دیگر رخ نمی\u200cدهد', () {
      final a = engine.answer('چک و ماده 541');
      // مادهٔ ۵۴۱ قانون مدنی دربارهٔ «مساقات» است و ربطی به چک ندارد.
      expect(a, isNot(contains('مساقات')));
      expect(a, isNot(contains('قانون مدنی')));
      expect(a, isNot(contains('ماده 541')));

      // همان شماره با نام صریح قانون همچنان دقیقاً پیدا می\u200cشود.
      final explicit = engine.answer('ماده 541 قانون تجارت');
      expect(explicit, contains('قانون تجارت'));
      expect(explicit, contains('مدیر تصفیه'));
    });

    test('پرسش عادی چک همچنان فقط از قانون صدور چک پاسخ می\u200cگیرد', () {
      final a = engine.answer('چک من پاس نشد');
      expect(a, contains('قانون صدور چک'));
      expect(a, isNot(contains('قانون مدنی')));
      expect(a, isNot(contains('قانون مجازات اسلامی')));
    });

    test('وقتی هیچ نشانهٔ حوزه\u200cای نباشد، رفتار قدیمی حفظ می\u200cشود', () {
      expect(engine.detectDomain('معسر کیست').id, isNull);
      expect(engine.answer('معسر کیست'), contains('ماده 6'));
      expect(engine.answer('شماره اضطراری ایران'), contains('۱۱۵'));
    });

    test('ابهام میان دو حوزه: «مطمئن نیستم» و حداکثر سه گزینهٔ برتر', () {
      const q = 'چک و کلاهبرداری';
      final d = engine.detectDomain(q);
      expect(d.uncertain, isTrue);
      expect(d.candidates, containsAll(<String>['cheque', 'penal']));

      final reply = engine.query(q);
      expect(reply.text, contains('مطمئن نیستم'));
      expect(reply.alternatives.length, lessThanOrEqualTo(3));
      expect(reply.alternatives, isNotEmpty);
      // گزینه\u200cها باید به مادهٔ واقعی برگردند.
      for (final a in reply.alternatives) {
        final r = engine.rank(a, k: 3);
        expect(r.hits, isNotEmpty, reason: a);
        expect(r.hits.first.score, greaterThanOrEqualTo(99), reason: a);
      }
      // پاسخ مستند موتور همچنان زیر جملهٔ تردید آمده است.
      expect(reply.text, contains('\n\n'));
      expect(engine.answer(q), contains('مطمئن نیستم'));
      expect(engine.alternatives(q), reply.alternatives);
    });
  });
}
