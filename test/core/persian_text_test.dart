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
}
