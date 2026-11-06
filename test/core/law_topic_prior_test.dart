import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/law_topic_prior.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LawTopicPrior (واحد)', () {
    final prior = LawTopicPrior.fromJson({
      'specialistPenalty': 0.5,
      'specialist': {
        'direct_taxes': ['مالیات'],
      },
      'topics': [
        {
          'id': 'lease',
          'signals': ['اجاره', 'مستاجر'],
          'laws': {'landlord_tenant': 1.4},
        },
      ],
    });

    test('بدون نشانهٔ مالیات، قانون مالیات جریمه می‌شود', () {
      final f = prior.factors('شرایط فسخ قرارداد اجاره خانه چیست؟');
      expect(f['direct_taxes'], 0.5);
      expect(f['landlord_tenant'], 1.4);
    });

    test('با نشانهٔ مالیات، جریمه برداشته می‌شود', () {
      final f = prior.factors('مالیات اجاره خانه چقدر است');
      expect(f.containsKey('direct_taxes'), isFalse);
      expect(f['landlord_tenant'], 1.4);
    });

    test('تطبیق آغاز واژه و حروف عربی', () {
      expect(prior.factors('اجاره‌نامه را امضا کردم')['landlord_tenant'], 1.4);
      expect(prior.factors('مستاجري دارم')['landlord_tenant'], 1.4);
      // «ماجاره» آغاز واژه نیست.
      expect(prior.factors('ماجاره')['landlord_tenant'], isNull);
    });

    test('ورودی نامعتبر: نقشهٔ خالی و بدون خطا', () {
      expect(LawTopicPrior.fromJson(null).factors('هر چیزی'), isEmpty);
      expect(LawTopicPrior.fromJson('x').isEmpty, isTrue);
    });
  });

  group('رتبه‌بندی موتور با ضریب موضوعی', () {
    late KnowledgeEngine engine;
    setUpAll(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      engine = KnowledgeEngine();
      await engine.load();
    });

    String topLaw(String q) => engine.rank(q, k: 1).hits.first.chunk.lawId;

    test('فسخ اجاره → قانون موجر و مستأجر یا مدنی، نه مالیات/تجارت', () {
      expect(
        topLaw('شرایط فسخ قرارداد اجاره خانه چیست؟'),
        anyOf('landlord_tenant', 'civil'),
      );
    });

    test('حقوق معوقه → قانون کار، نه تأمین اجتماعی', () {
      expect(topLaw('کارفرما حقوقم را نداده'), 'labor');
    });

    test('مجازات چک بی‌محل → قانون صدور چک', () {
      expect(topLaw('مجازات صدور چک بی‌محل چیست'), 'cheque');
    });

    test('پرسش مالیاتی همچنان به قانون مالیات می‌رود', () {
      expect(topLaw('مالیات اجاره خانه چقدر است'), 'direct_taxes');
    });
  });
}
