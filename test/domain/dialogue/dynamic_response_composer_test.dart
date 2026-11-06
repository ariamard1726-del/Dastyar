import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/dialogue/response_composer.dart';

void main() {
  group('detectMood', () {
    test('نگرانی', () {
      expect(DynamicResponseComposer.detectMood('خیلی نگرانم، چه کار کنم؟'),
          UserMood.anxious);
      expect(DynamicResponseComposer.detectMood('میترسم زندان بروم 😟'),
          UserMood.anxious);
    });

    test('خشم با واژه و علامت تعجب', () {
      expect(DynamicResponseComposer.detectMood('حقم را خورد!!!'),
          UserMood.angry);
      expect(DynamicResponseComposer.detectMood('واقعاً عصبانی‌ام'),
          UserMood.angry);
    });

    test('خنثی', () {
      expect(DynamicResponseComposer.detectMood('مهلت تجدیدنظر چند روز است؟'),
          UserMood.neutral);
      expect(DynamicResponseComposer.detectMood(''), UserMood.neutral);
      expect(DynamicResponseComposer.detectMood('سلام!'), UserMood.neutral);
    });
  });

  group('compose', () {
    test('ساختار ساندویچ: همدلی، ماده، قدم‌ها، پرسش', () {
      final c = DynamicResponseComposer();
      final out = c.compose(
        userText: 'خیلی نگرانم',
        lawArticle: 'ماده ۷ - ...',
        lawSource: 'قانون صدور چک',
        actionPlan: ['۱. گواهی عدم پرداخت بگیرید', '- اظهارنامه بفرستید', ''],
        nextQuestion: 'مبلغ چک چقدر است؟',
      );
      final iEmp = out.indexOf('نگران');
      final iLaw = out.indexOf('📜');
      final iPlan = out.indexOf('✅');
      final iQ = out.indexOf('❓');
      expect(iEmp, greaterThanOrEqualTo(0));
      expect(iEmp < iLaw && iLaw < iPlan && iPlan < iQ, isTrue,
          reason: out);
      expect(out, contains('«قانون صدور چک»'));
      expect(out, contains('• گواهی عدم پرداخت بگیرید'));
      expect(out, contains('• اظهارنامه بفرستید'));
      expect(out, contains('❓ مبلغ چک چقدر است؟'));
      expect(out, contains('\n\n'));
    });

    test('بدون ماده: متن ثابت و پیشنهاد وکیل؛ هیچ قانونی ساخته نمی‌شود', () {
      final c = DynamicResponseComposer();
      for (final art in [null, '', '   ']) {
        final out = c.compose(userText: 'سؤال', lawArticle: art);
        expect(out, contains(DynamicResponseComposer.noArticleText));
        expect(out, contains('وکیل'));
        expect(out, isNot(contains('طبق متن قانون')));
        expect(out, isNot(matches(RegExp(r'ماده\s*[0-9۰-۹]'))));
      }
    });

    test('سه تنوع همدلی و انتقال، چرخشی و قطعی', () {
      final c = DynamicResponseComposer();
      final outs = [
        for (var i = 0; i < 4; i++)
          c.compose(userText: 'x', lawArticle: 'متن', mood: UserMood.angry),
      ];
      expect(outs.take(3).toSet().length, 3);
      expect(outs[3], outs[0]);
      expect(c.counter, 4);
      expect(DynamicResponseComposer().compose(
              userText: 'x', lawArticle: 'متن', mood: UserMood.angry),
          outs[0]);
    });

    test('بخش‌های خالی حذف می‌شوند', () {
      final out = DynamicResponseComposer()
          .compose(userText: 'x', lawArticle: 'متن');
      expect(out, isNot(contains('✅')));
      expect(out, isNot(contains('❓')));
    });
  });
}
