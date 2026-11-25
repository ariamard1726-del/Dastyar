import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/persian_text.dart';

/// نرمال‌سازی متن، هم در دارت هست هم در پایتون (`brain/common.py`).
///
/// دو پیاده‌سازی داشتن یک بدهی است؛ کمترین کار این است که هر دو با یک فایل
/// نمونهٔ مشترک سنجیده شوند تا از هم جدا نیفتند.
/// آزمون پایتون: `tests/python/test_normalize_parity.py`.
void main() {
  final data = jsonDecode(
    File('tests/normalize_cases.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = (data['cases'] as List).cast<Map<String, dynamic>>();

  test('نمونه‌های مشترک با پایتون، در دارت همان خروجی را می‌دهند', () {
    expect(cases.length, greaterThanOrEqualTo(10));
    for (final c in cases) {
      final input = c['in'] as String;
      expect(PersianText.normalize(input), c['out'], reason: input);
    }
  });

  test('نیم‌فاصله و ارقام، یکدست می‌شوند', () {
    expect(PersianText.normalize('مي‌خواهم'), 'می خواهم');
    expect(PersianText.normalize('ماده ۱۰'), 'ماده 10');
    expect(PersianText.normalize('ماده ١٢٣'), 'ماده 123');
    expect(PersianText.normalize('Test'), 'test');
  });
}
