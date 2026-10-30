import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/feedback.dart';

void main() {
  test('export: 👎 به سطر ارزیابی و 👍 به توضیح تبدیل می‌شود', () {
    final t = FeedbackStore.exportText([
      FeedbackEntry('ولی قهری بچه کیه', 'ماده 1184 ...', -1, 1),
      FeedbackEntry('چک چیست', 'ماده 1 ...', 1, 2),
    ]);
    expect(t.contains('ولی قهری بچه کیه | ؟ | ؟'), isTrue);
    expect(t.contains('# 👍 چک چیست'), isTrue);
    final rows = t
        .split('\n')
        .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
        .toList();
    expect(rows.length, 1);
  });

  test('snippet فاصله‌ها را فشرده و طول را محدود می‌کند', () {
    expect(FeedbackStore.snippet('الف   ب\nج'), 'الف ب ج');
    expect(FeedbackStore.snippet('ا' * 500).length, 120);
  });

  test('نویسهٔ | در پرسش، سطر ارزیابی را خراب نمی‌کند', () {
    final t = FeedbackStore.exportText([
      FeedbackEntry('الف|ب', 'پاسخ', -1, 1),
    ]);
    final row = t.split('\n').firstWhere((l) => l.contains('؟'));
    expect(row.split('|').length, 3);
  });
}
