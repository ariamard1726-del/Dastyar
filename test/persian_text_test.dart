import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/engine.dart';
import 'package:dastyar/persian_text.dart';

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
}
