import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/dialogue/dialogue_planner.dart';

void main() {
  const planner = DialoguePlanner();

  group('generateClarificationPrompt', () {
    test('اطمینان بالا: شفاف‌سازی لازم نیست', () {
      expect(
          planner.generateClarificationPrompt('x', {'complaint': 0.8}), isNull);
    });

    test('زیر ۰٫۴۰: عذرخواهی، بازگویی کوتاه و درخواست جزئیات', () {
      const text = 'یک چیزی شده که نمی‌دانم اصلاً از کجا شروع کنم و چه بگویم';
      final t = planner.generateClarificationPrompt(
          text, {'complaint': 0.3, 'none': 0.6})!;
      expect(t, contains('ببخشید'));
      expect(t, contains('«یک چیزی شده که نمی‌دانم اصلاً از کجا…»'));
      expect(t, contains('چه اتفاقی افتاده'));
      expect(t, contains('طرف مقابل کیست'));
      expect(t, contains('چه می‌خواهید'));
    });

    test('بازگویی حداکثر ۸ واژه است', () {
      final s = DialoguePlanner.snippetOf('۱ ۲ ۳ ۴ ۵ ۶ ۷ ۸ ۹ ۱۰');
      expect(s, '۱ ۲ ۳ ۴ ۵ ۶ ۷ ۸…');
      expect(DialoguePlanner.snippetOf('کوتاه'), 'کوتاه');
    });

    test('none حذف می‌شود حتی اگر بیشترین احتمال را داشته باشد', () {
      final p = planner.buildClarification(
          'متن', {'none': 0.9, 'complaint': 0.5, 'demand_money': 0.45})!;
      expect(p.kind, ClarificationKind.choice);
      expect(p.options, ['complaint', 'demand_money']);
    });

    test('۰٫۴۰ تا ۰٫۶۵: پرسش دوگزینه‌ای با ایموجی و راهنمای ۱ یا ۲', () {
      final t = planner.generateClarificationPrompt(
          'متن', {'demand_money': 0.5, 'complaint': 0.48})!;
      expect(t, contains('1️⃣ 💰 مطالبهٔ پول'));
      expect(t, contains('2️⃣ ⚖️ شکایت کیفری'));
      expect(t, contains('۱ یا ۲'));
      expect(t, contains('راستش هر دو احتمال تقریباً برابره'));
    });

    test('جملهٔ ربطی به فاصلهٔ دو احتمال بستگی دارد', () {
      final mid = planner.generateClarificationPrompt(
          'x', {'demand_money': 0.5, 'complaint': 0.4})!;
      final far = planner.generateClarificationPrompt(
          'x', {'demand_money': 0.6, 'complaint': 0.2})!;
      expect(mid, contains('کمی پررنگ‌تر'));
      expect(far, contains('بیشتر گزینهٔ اول'));
    });

    test('تنها یک قصد معتبر: گزینهٔ دوم «موضوع دیگری است»', () {
      final p = planner.buildClarification('x', {'legal_aid': 0.5})!;
      expect(p.text, contains('2️⃣ 🤔 موضوع دیگری است'));
      expect(p.resolveChoice('2'), isNull);
      expect(p.resolveChoice('1'), 'legal_aid');
    });

    test('پاسخ ۱/۲ به قصد برمی‌گردد (فارسی، عربی، کلمه، ایموجی)', () {
      final p = planner.buildClarification(
          'x', {'demand_money': 0.5, 'complaint': 0.45})!;
      expect(p.resolveChoice('۱'), 'demand_money');
      expect(p.resolveChoice('1️⃣'), 'demand_money');
      expect(p.resolveChoice('دومی'), 'complaint');
      expect(p.resolveChoice('٢.'), 'complaint');
      expect(p.resolveChoice('نمی‌دانم'), isNull);
    });

    test('نبود هیچ احتمالی: درخواست توضیح', () {
      final p = planner.buildClarification('', const {})!;
      expect(p.kind, ClarificationKind.rephrase);
      expect(p.text, isNot(contains('«')));
    });
  });

  group('ClarificationPromptGenerator', () {
    test('شمارنده تنوع قطعی می‌دهد و تکرارپذیر است', () {
      final g1 = ClarificationPromptGenerator();
      final g2 = ClarificationPromptGenerator();
      final a1 = g1.next('x', {'complaint': 0.2})!.text;
      final a2 = g1.next('x', {'complaint': 0.2})!.text;
      expect(a1, isNot(a2));
      expect(g2.next('x', {'complaint': 0.2})!.text, a1);
      expect(g1.counter, 2);
    });

    test('وقتی شفاف‌سازی لازم نیست، شمارنده جلو نمی‌رود', () {
      final g = ClarificationPromptGenerator();
      expect(g.next('x', {'complaint': 0.9}), isNull);
      expect(g.counter, 0);
    });
  });
}
