import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/router.dart';

void main() {
  final router = HybridIntentRouter();

  group('عبارت‌های قطعی پیش از شبکه', () {
    test('«سرقت چک» همیشه complaint است، حتی اگر شبکه مطمئن باشد', () {
      final d = router.route('سرقت چک داشتم',
          networkProbabilities: {'demand_money': 0.97, 'complaint': 0.03});
      expect(d.intent, 'complaint');
      expect(d.confidence, 0.99);
      expect(d.source, RoutingSource.strictPhrase);
    });

    test('«چک برگشتی» همیشه demand_money است', () {
      final d = router.route('یک چک برگشتی دارم',
          networkProbabilities: {'complaint': 0.9});
      expect(d.intent, 'demand_money');
      expect(d.source, RoutingSource.strictPhrase);
    });

    test('اولویت بالاتر برنده است', () {
      final d = router.route('چک برگشتی‌ام را سرقت چک حساب کردند');
      expect(d.intent, 'complaint');
    });

    test('ورودی با ي و ك عربی هم تطبیق می‌خورد', () {
      expect(router.route('سرقت چك').intent, 'complaint');
    });
  });

  group('امتیازدهی کلیدواژه‌ها', () {
    test('بلندترین عبارت اول؛ «مطالبه وجه» دوباره شمرده نمی‌شود', () {
      final k = router.scoreKeywords('مطالبه وجه از دوستم');
      expect(k.raw['demand_money'], closeTo(1.2, 1e-9));
      expect(k.matched.length, 1);
    });

    test('سهم نرمال‌شده جمعش یک است', () {
      final k = router.scoreKeywords('قرض دادم و حالا تهدید می‌کند');
      final sum = k.normalized.values.fold(0.0, (a, b) => a + b);
      expect(sum, closeTo(1.0, 1e-9));
      expect(k.raw.keys, containsAll(['demand_money', 'complaint']));
    });

    test('متن بی‌ربط امتیازی ندارد', () {
      expect(router.scoreKeywords('هوا امروز آفتابی است').isEmpty, isTrue);
    });
  });

  group('مسیریابی پس از شبکه', () {
    test('اطمینان بالا بدون تعارض: اعتماد به شبکه', () {
      final d = router.route('دوستم پولم را پس نمی‌دهد',
          networkProbabilities: {'demand_money': 0.9, 'complaint': 0.1});
      expect(d.intent, 'demand_money');
      expect(d.source, RoutingSource.network);
      expect(d.confidence, 0.9);
    });

    test('اطمینان بالا با تعارض شدید کلیدواژه: جایگزینی', () {
      final d = router.route('از کسی که کلاهبرداری کرده شکایت دارم',
          networkProbabilities: {'demand_money': 0.85, 'complaint': 0.15});
      expect(d.intent, 'complaint');
      expect(d.source, RoutingSource.keywordConflictOverride);
    });

    test('اطمینان بالا با یک واژهٔ کلی ضعیف: شبکه می‌ماند', () {
      final d = router.route('دربارهٔ چک سؤال دارم',
          networkProbabilities: {'complaint': 0.9});
      expect(d.intent, 'complaint');
      expect(d.source, RoutingSource.network);
    });

    test('اطمینان متوسط و کلیدواژه‌های قوی مخالف: جایگزینی', () {
      final d = router.route('می‌خواهم اعسار و تقسیط بگیرم چون پول ندارم',
          networkProbabilities: {'demand_money': 0.7, 'insolvency': 0.2});
      expect(d.intent, 'insolvency');
      expect(d.source, RoutingSource.keywordOverride);
    });

    test('اطمینان متوسط و کلیدواژهٔ موافق: شبکه', () {
      final d = router.route('سفته دارم و طلبکارم',
          networkProbabilities: {'demand_money': 0.7, 'complaint': 0.3});
      expect(d.intent, 'demand_money');
      expect(d.source, RoutingSource.network);
    });

    test('اطمینان پایین: ترکیب ۷۵٪ کلیدواژه + ۲۵٪ شبکه', () {
      final d = router.route('اظهارنامه بفرستم',
          networkProbabilities: {'complaint': 0.5, 'formal_notice': 0.3});
      expect(d.source, RoutingSource.blended);
      expect(d.intent, 'formal_notice');
      expect(d.confidence, closeTo(0.75 * 1.0 + 0.25 * 0.3, 1e-9));
      expect(d.probabilities['complaint'], closeTo(0.25 * 0.5, 1e-9));
    });

    test('اطمینان پایین بدون کلیدواژه: خروجی کم‌اطمینان شبکه حفظ می‌شود', () {
      final d = router.route('سلام وقت بخیر',
          networkProbabilities: {'complaint': 0.3, 'demand_money': 0.25});
      expect(d.intent, 'complaint');
      expect(d.confidence, 0.3);
    });

    test('بدون شبکه و بدون کلیدواژه: none', () {
      final d = router.route('هوا امروز آفتابی است');
      expect(d.isNone, isTrue);
      expect(d.source, RoutingSource.none);
    });

    test('ورودی نامعتبر شبکه پاک‌سازی می‌شود', () {
      final d = router.route('هوا خوب است',
          networkProbabilities: {'complaint': double.nan, 'x': -1});
      expect(d.isNone, isTrue);
    });

    test('قطعی است: ورودی یکسان، خروجی یکسان', () {
      const p = {'complaint': 0.5, 'demand_money': 0.5};
      final a = router.route('قرض و تهدید', networkProbabilities: p);
      final b = router.route('قرض و تهدید', networkProbabilities: p);
      expect(a.intent, b.intent);
      expect(a.confidence, b.confidence);
    });
  });

  test('QueryRouter قبلی دست‌نخورده می‌ماند', () {
    expect(QueryRouter.asksCapabilities('چه کاری می‌توانی انجام بدهی'), isTrue);
  });
}
