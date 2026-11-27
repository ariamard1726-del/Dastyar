import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/text_norm_rules.dart';
import 'package:dastyar/domain/advocate/law_terms.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topic_flow.dart';

/// لایهٔ متن: قاعده‌ها از `dev/tools/contracts/text_norm.json` تولید می‌شوند و
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

  final contract = jsonDecode(
    File('dev/tools/contracts/text_norm.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  test('normalize با نمونه‌های پایتون یکی است', () {
    final rows = (golden['normalize'] as List).cast<Map<String, dynamic>>();
    expect(rows.length, greaterThanOrEqualTo(10));
    for (final row in rows) {
      final input = row['in'] as String;
      expect(PersianText.normalize(input), row['out'], reason: input);
    }
  });

  test('TopicFlow.spaced و LawTerms.spaced با نمونه‌های پایتون یکی است', () {
    final toolsRows = (golden['spaced'] as List).cast<Map<String, dynamic>>();
    expect(toolsRows.length, greaterThanOrEqualTo(5));
    for (final row in toolsRows) {
      final input = row['in'] as String;
      expect(TopicFlow.spaced(input), row['out'], reason: input);
    }
    final termsRows =
        (golden['spaced_terms'] as List).cast<Map<String, dynamic>>();
    expect(termsRows.length, greaterThanOrEqualTo(5));
    for (final row in termsRows) {
      final input = row['in'] as String;
      expect(LawTerms.spaced(input), row['out'], reason: input);
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

    final tok = contract['tokenize'] as Map<String, dynamic>;
    expect(TextNormRules.nonWord, tok['nonWord']);
    expect(TextNormRules.stemMinStem, tok['stemMinStem']);
    expect(TextNormRules.suffixes, (tok['suffixes'] as List).cast<String>());
    expect(
      TextNormRules.suffixesIndex,
      (tok['suffixesIndex'] as List).cast<String>(),
    );
    expect(TextNormRules.stop, (tok['stop'] as List).cast<String>().toSet());

    // قاعده‌های قدیمی نباید دوباره در سورس دستی تکرار شوند.
    final src = File('lib/core/persian_text.dart').readAsStringSync();
    expect(src.contains("'ي': 'ی'"), isFalse,
        reason: 'نگاشت نویسه باید فقط در text_norm_rules.dart باشد');
    expect(src.contains("static const Set<String> _stop = {"), isFalse);
  });

  test('نیم‌فاصله، ارقام و بازنویسی‌ها', () {
    expect(PersianText.normalize('مي‌خواهم'), 'می خواهم');
    expect(PersianText.normalize('ماده ١٢٣'), 'ماده 123');
    expect(Sense.norm('می خواهم'), ' میخواهم ');
    expect(Sense.norm('چکار کنم؟'), ' چه کار کنم ؟ ');
  });
}
