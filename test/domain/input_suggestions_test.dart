import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/input_suggestions.dart';
import 'package:dastyar/domain/lawyer/phrase_variator.dart';
import 'package:dastyar/domain/legal_counselor.dart';

void main() {
  group('InputSuggestions', () {
    List<String> texts(String q) =>
        InputSuggestions.forTyping(q).map((s) => s.text).toList();

    test('متن خالی یا خیلی کوتاه پیشنهادی ندارد', () {
      expect(InputSuggestions.forTyping(''), isEmpty);
      expect(InputSuggestions.forTyping('  '), isEmpty);
      expect(InputSuggestions.forTyping('م'), isEmpty);
    });

    test('پیشنهادها به موضوع پیام مربوط‌اند', () {
      expect(texts('مهریه'), contains('مهریه را چطور بگیرم؟'));
      expect(texts('چک برگشت خورده'), contains('چک برگشتی دارم؛ چه کار کنم؟'));
      expect(texts('صاحبخانه ودیعه'), contains('صاحبخانه ودیعه‌ام را پس نمی‌دهد'));
    });

    test('تکمیل پیشوند واژه‌ها', () {
      expect(texts('کارفرما حقو'), contains('کارفرما حقوقم را نداده؛ چه کنم؟'));
    });

    test('ی و ک عربی هم کار می‌کند', () {
      expect(texts('مهريه'), contains('مهریه را چطور بگیرم؟'));
      expect(texts('كارفرما حقو'), contains('کارفرما حقوقم را نداده؛ چه کنم؟'));
    });

    test('حداکثر چهار پیشنهاد، بدون تکرار و قطعی', () {
      for (final q in ['مهریه', 'تهدید', 'کارفرما', 'چک']) {
        final a = texts(q);
        expect(a.length, lessThanOrEqualTo(InputSuggestions.maxItems));
        expect(a.toSet().length, a.length);
        expect(texts(q), a);
      }
    });

    test('برای موضوع شناخته‌شده مشاورهٔ گام‌به‌گام هم پیشنهاد می‌شود', () {
      expect(texts('کارفرما حقوقم را نداده'),
          contains(LegalCounselor.startCounselCmd));
    });

    test('همهٔ موضوعات راهنماها پرسش دارند', () {
      for (final t in InputSuggestions.guideTopic.values) {
        expect(InputSuggestions.topicQuestions[t], isNotEmpty, reason: t);
      }
    });
  });

  group('PhraseVariator', () {
    const vs = ['الف', 'ب', 'ج'];

    test('دو بار پشت سر هم یک عبارت تکرار نمی‌شود و همه می‌چرخند', () {
      final v = PhraseVariator(seed: 7);
      final seen = <String>[];
      for (var i = 0; i < 9; i++) {
        seen.add(v.pick('k', vs));
      }
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], isNot(seen[i - 1]));
      }
      expect(seen.take(3).toSet(), vs.toSet());
    });

    test('با بذر یکسان قطعی است', () {
      final a = PhraseVariator(seed: 3);
      final b = PhraseVariator(seed: 3);
      for (var i = 0; i < 5; i++) {
        expect(a.pick('x', vs), b.pick('x', vs));
      }
      expect(a.counterOf('x'), 5);
      a.reset();
      expect(a.counterOf('x'), 0);
    });

    test('کلیدهای جدا شمارندهٔ جدا دارند', () {
      final v = PhraseVariator();
      v.pick('a', vs);
      v.pick('a', vs);
      expect(v.counterOf('a'), 2);
      expect(v.counterOf('b'), 0);
    });
  });
}
