import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/input_suggestions.dart';

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

    test('موضوع پیشنهادها از همان تشخیص موضوعِ وکیل می‌آید', () {
      expect(Advocate.topicOf('کارفرما حقوقم را نداده'), 'labor');
      expect(InputSuggestions.topicOf('کارفرما حقوقم را نداده'), 'labor');
      expect(Advocate.topicOf('سلام خوبی'), isNull);
      final ids = Advocate.topics.map((t) => t.id).toSet();
      InputSuggestions.advocateTopic.forEach((id, key) {
        expect(ids, contains(id), reason: 'موضوع $id در وکیل نیست');
        expect(InputSuggestions.topicQuestions[key], isNotEmpty, reason: key);
      });
    });

    test('فقط پرسش و قالب سند پیشنهاد می‌شود', () {
      for (final q in ['کارفرما حقوقم را نداده', 'چک برگشت خورده', 'مهریه']) {
        for (final s in InputSuggestions.forTyping(q)) {
          expect(
            s.kind,
            anyOf(SuggestionKind.question, SuggestionKind.template),
          );
        }
      }
    });

    test('همهٔ موضوعات راهنماها پرسش دارند', () {
      for (final t in InputSuggestions.guideTopic.values) {
        expect(InputSuggestions.topicQuestions[t], isNotEmpty, reason: t);
      }
    });
  });
}
