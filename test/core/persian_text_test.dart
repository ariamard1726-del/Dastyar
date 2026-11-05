import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/templates.dart';

void main() {
  test('normalize: حروف عربی و ارقام یکدست می‌شوند', () {
    expect(PersianText.normalize('كتاب ي ۱۲٣'), 'کتاب ی 123');
  });

  test('collapse: فاصله‌های اضافه یکی می‌شوند', () {
    expect(PersianText.collapse('  الف   ب '), 'الف ب');
  });

  test('phrase: نشانه‌ها و نیم‌فاصله حذف می‌شوند', () {
    expect(PersianText.phrase('  قانون‌ مدنی! '), 'قانون مدنی');
  });

  test('tokenizeIndex: کلمهٔ ایست حذف و ارقام لاتین می‌شوند', () {
    expect(PersianText.tokenizeIndex('ماده ۱۰ قانون مدنی'), ['10', 'مدنی']);
  });

  test('ریشه‌یابی نمایه محافظه‌کار است، ریشه‌یابی پرسش سبک‌تر', () {
    expect(PersianText.tokenizeIndex('کتابها'), ['کتاب']);
    expect(PersianText.tokenizeIndex('مالی'), ['مالی']);
    expect(PersianText.tokenize('مالی'), ['مال']);
  });

  test('نام‌های قدیمی KnowledgeEngine همان خروجی PersianText را می‌دهند', () {
    const samples = [
      'ماده ۱۰ قانون مدنی',
      'چک من پاس نشد',
      'كتاب ي ۱۲٣',
      'قوانین‌های مالی',
      '',
    ];
    for (final s in samples) {
      expect(KnowledgeEngine.normalize(s), PersianText.normalize(s));
      expect(KnowledgeEngine.tokenize(s), PersianText.tokenize(s));
      expect(KnowledgeEngine.tokenizeIndex(s), PersianText.tokenizeIndex(s));
    }
  });

  test('toFaDigits و asciiDigits روی ارقام لاتین، عربی و ایموجی ایمن کار می‌کنند', () {
    expect(PersianText.toFaDigits('Year 2026 / ١٤٠٥ 😀'), 'Year ۲۰۲۶ / ۱۴۰۵ 😀');
    expect(PersianText.asciiDigits('مبلغ ۵۰،۰۰۰ و ١٢٣ ریال'), '50000123');
    expect(PersianText.toFaDigits('42'), '۴۲');
    expect(PersianText.asciiDigits('۴۲'), '42');
    expect(TemplateRenderer.toFa('1397'), '۱۳۹۷');
  });

  test('اعتبارسنجی کد ملی ۱۰ رقمی و شماره تلفن ایران (با ارقام فارسی، عربی و لاتین)', () {
    expect(PersianText.isValidIranianNationalId('0013542419'), isTrue);
    expect(PersianText.isValidIranianNationalId('۰۰۱۳۵۴۲۴۱۹'), isTrue);
    expect(PersianText.isValidIranianNationalId('0499370899'), isTrue);
    expect(PersianText.isValidIranianNationalId('0013542418'), isFalse);
    expect(PersianText.isValidIranianNationalId('1111111111'), isFalse);
    expect(PersianText.isValidIranianNationalId('12345'), isFalse);

    expect(PersianText.normalizeIranianPhone('+98 912-345-6789'), '09123456789');
    expect(PersianText.normalizeIranianPhone('۰۰۹۸۹۱۲۳۴۵۶۷۸۹'), '09123456789');
    expect(PersianText.isValidIranianPhone('۰۲۱-۸۸۷۷۶۶۵۵'), isTrue);
    expect(PersianText.isValidIranianPhone('12345'), isFalse);
  });

  // ── Phase 1: مرز واژهٔ فارسی ────────────────────────────────────────
  group('wordRe', () {
    test('مرز واژه: «چک» فقط به عنوان واژهٔ مستقل/صرفشده', () {
      final re = PersianText.wordRe(['چک']);
      expect(re.hasMatch('چک برگشتی دارم'), isTrue);
      expect(re.hasMatch('چک!'), isTrue);
      expect(re.hasMatch('چکها'), isTrue);
      expect(re.hasMatch('چکم'), isTrue);
      expect(re.hasMatch('چکشان'), isTrue);
      // باگ اصلی: «چک» نباید در «چکار» یا واژهٔ مرکب دیده شود.
      expect(re.hasMatch('چکار کنم'), isFalse);
      expect(re.hasMatch('چكار كنم'), isFalse);
      expect(re.hasMatch('چکباز'), isFalse);
    });

    test('یکدستسازی نویسهها: اشکال عربی هم تطبیق میکنند', () {
      final re = PersianText.wordRe(['چک', 'مدنی']);
      expect(re.hasMatch('چك برگشتى دارم'), isTrue); // ك / ي
      expect(re.hasMatch('مدنى'), isTrue); // ى
      expect(PersianText.wordRe(['نامه']).hasMatch('نامة'), isTrue); // ة
      expect(PersianText.wordRe(['چک']).hasMatch('چكار'), isFalse);
    });

    test('یکدستسازی ارقام فارسی، عربی و لاتین', () {
      final re = PersianText.wordRe(['ماده ۱۰']);
      expect(re.hasMatch('ماده 10 قانون مدنی'), isTrue);
      expect(re.hasMatch('ماده ۱۰ قانون مدنی'), isTrue);
      expect(re.hasMatch('ماده ١٠ قانون مدنی'), isTrue);
      expect(re.hasMatch('ماده ۱۱ قانون مدنی'), isFalse);
    });

    test('اصلاح فاصلهها و نیمفاصلهها در عبارتهای چندواژهای', () {
      final re = PersianText.wordRe(['صبح بخیر']);
      expect(re.hasMatch('صبح بخیر'), isTrue);
      expect(re.hasMatch('صبح  بخیر'), isTrue);
      expect(re.hasMatch('صبح\u200Cبخیر'), isTrue);
      expect(re.hasMatch('صبح\nبخیر'), isTrue);
      expect(re.hasMatch('صبح\u200Cبخير'), isTrue); // نیمفاصله + ي عربی
      expect(re.hasMatch('صبحبخیر'), isFalse);
    });

    test('پسوندها از بلند به کوتاه بررسی میشوند', () {
      final re = PersianText.wordRe(['کتاب']);
      expect(re.hasMatch('کتابهایی'), isTrue);
      expect(re.hasMatch('کتابترین'), isTrue);
      expect(re.hasMatch('کتابها'), isTrue);
      expect(re.hasMatch('کتابباز'), isFalse);
    });

    test('نویسههای ویژهٔ RegExp گریز داده میشوند', () {
      final re = PersianText.wordRe(['C++', 'ماده (۱)']);
      expect(re.hasMatch('C++ چیست'), isTrue);
      expect(re.hasMatch('c++ چیست'), isTrue);
      expect(re.hasMatch('CCC'), isFalse);
      expect(re.hasMatch('ماده (1) قانون مدنی'), isTrue);
      expect(re.hasMatch('ماده 1 قانون مدنی'), isFalse);
    });

    test('ورودی خالی / تکراری / تهی ایمن است', () {
      final never = PersianText.wordRe(<String>[]);
      expect(never.hasMatch(''), isFalse);
      expect(never.hasMatch('چک'), isFalse);
      final re = PersianText.wordRe(['', '  ', 'چک', 'چك', ' چک ']);
      expect(re.hasMatch('چک برگشتی'), isTrue);
      expect(re.hasMatch('چکار'), isFalse);
    });
  });
}
