import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/utils/persian_normalizer.dart';

void main() {
  group('PersianNormalizer.normalize', () {
    test('ي و ك عربی به ی و ک فارسی', () {
      expect(PersianNormalizer.normalize('علي كتاب'), 'علی کتاب');
      expect(PersianNormalizer.normalize('مسئله اجرائيه'), 'مسیله اجراییه');
    });

    test('ارقام فارسی و عربی به انگلیسی', () {
      expect(PersianNormalizer.normalize('ماده ۱۲۳ و ٤٥'), 'ماده 123 و 45');
    });

    test('نیم‌فاصله و اعراب و کشیده حذف می‌شوند', () {
      expect(PersianNormalizer.normalize('می‌خواهم'), 'میخواهم');
      expect(PersianNormalizer.normalize('حَقّ'), 'حق');
      expect(PersianNormalizer.normalize('چـــک'), 'چک');
    });

    test('ورودی خالی', () {
      expect(PersianNormalizer.normalize(''), '');
      expect(PersianNormalizer.normalizeForMatching('  ،؟ '), '');
    });
  });

  group('PersianNormalizer.normalizeForMatching', () {
    test('نشانه‌گذاری و ایموجی به فاصله', () {
      expect(PersianNormalizer.normalizeForMatching('چک،برگشتی؟! «سفته» 💰'),
          'چک برگشتی سفته');
    });

    test('«نمی دهد» و «نمی‌دهد» یکی می‌شوند', () {
      expect(PersianNormalizer.normalizeForMatching('پس نمی دهد'),
          PersianNormalizer.normalizeForMatching('پس نمی‌دهد'));
    });
  });

  group('PersianNormalizer.containsPhrase', () {
    test('تطبیق روی مرز واژه', () {
      expect(PersianNormalizer.containsPhrase('چک برگشتی دارم', 'چک'), isTrue);
      expect(PersianNormalizer.containsPhrase('قله چکاد', 'چک'), isFalse);
    });

    test('پسوندهای رایج پذیرفته می‌شوند', () {
      expect(PersianNormalizer.containsPhrase('چکم برگشت خورد', 'چک'), isTrue);
      expect(PersianNormalizer.containsPhrase('چک‌هایم', 'چک'), isTrue);
      expect(
          PersianNormalizer.containsPhrase('چکم', 'چک', allowSuffixes: false),
          isFalse);
    });

    test('ورودی عربی با کلیدواژهٔ فارسی تطبیق می‌خورد', () {
      expect(PersianNormalizer.containsPhrase('شكايت كيفري', 'شکایت کیفری'),
          isTrue);
    });
  });
}
