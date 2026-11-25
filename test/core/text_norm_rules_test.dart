import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/text_norm_rules.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';

/// لایهٔ متن: قاعده‌ها از `tools/contracts/text_norm.json` تولید می‌شوند و
/// خروجی‌شان با نمونه‌های مشترک قفل است.
///
/// نمونه‌ها در پایتون تولید و این‌جا سنجیده می‌شوند؛ اگر یک طرف عوض شود و
/// طرف دیگر نه، این آزمون یا `tests/python/test_text_norm_parity.py` قرمز
/// می‌شود. مقادیر طلایی از کدِ پیش از یکسان‌سازی گرفته شده‌اند تا رفتار
/// عوض نشده باشد.
void main() {
  final golden = jsonDecode(
    File('tests/text_norm_golden.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final normCases = jsonDecode(
    File('tests/text_norm_norm_cases.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('normalize با نمونه‌های پایتون یکی است', () {
    final rows = (golden['normalize'] as List).cast<Map<String, dynamic>>();
    expect(rows.length, greaterThanOrEqualTo(10));
    for (final row in rows) {
      final input = row['in'] as String;
      expect(PersianText.normalize(input), row['out'], reason: input);
    }
  });

  test('Sense.norm با نمونه‌های پایتون یکی است', () {
    final rows = (normCases['cases'] as List).cast<Map<String, dynamic>>();
    expect(rows.length, greaterThanOrEqualTo(10));
    for (final row in rows) {
      final input = row['in'] as String;
      expect(Sense.norm(input), row['out'], reason: input);
    }
  });

  test('قاعده‌ها از قرارداد می‌آیند، نه از کد دستی', () {
    expect(TextNormRules.charMap['ي'], 'ی');
    expect(TextNormRules.lowercase, isTrue);
    expect(TextNormRules.normPunct, contains('«'));
    expect(TextNormRules.canon.length, greaterThan(5));
    // قاعده‌های قدیمی نباید دوباره در سورس دستی تکرار شوند.
    final src = File('lib/core/persian_text.dart').readAsStringSync();
    expect(src.contains("'ي': 'ی'"), isFalse,
        reason: 'نگاشت نویسه باید فقط در text_norm_rules.dart باشد');
  });

  test('نیم‌فاصله، ارقام و بازنویسی‌ها', () {
    expect(PersianText.normalize('مي‌خواهم'), 'می خواهم');
    expect(PersianText.normalize('ماده ١٢٣'), 'ماده 123');
    expect(Sense.norm('می خواهم'), ' میخواهم ');
    expect(Sense.norm('چکار کنم؟'), ' چه کار کنم ؟ ');
  });
}
