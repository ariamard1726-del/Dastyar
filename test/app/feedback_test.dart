import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/domain/feedback.dart';

List<String> _rows(String t) => t
    .split('\n')
    .where((l) => l.trim().isNotEmpty && !l.startsWith('#'))
    .toList();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    PrivacyService.persistenceAllowed = true;
    FeedbackStore.lastError = null;
  });

  tearDown(() {
    PrivacyService.persistenceAllowed = true;
    FeedbackStore.lastError = null;
  });

  test('export: 👎 به سطر ارزیابی و 👍 به توضیح تبدیل می‌شود', () {
    final t = FeedbackStore.exportText([
      FeedbackEntry('ولی قهری بچه کیه', 'ماده 1184 ...', -1, 1),
      FeedbackEntry('چک چیست', 'ماده 1 ...', 1, 2),
    ]);
    expect(t.contains('ولی قهری بچه کیه | ؟ | ؟'), isTrue);
    expect(t.contains('# 👍 چک چیست'), isTrue);
    expect(_rows(t).length, 1);
  });

  test('snippet فاصله‌ها را فشرده و طول را محدود می‌کند', () {
    expect(FeedbackStore.snippet('الف   ب\nج'), 'الف ب ج');
    expect(FeedbackStore.snippet('ا' * 500).length, 120);
  });

  test('نویسهٔ | در پرسش، سطر ارزیابی را خراب نمی‌کند', () {
    final t = FeedbackStore.exportText([
      FeedbackEntry('الف|ب', 'پاسخ', -1, 1),
    ]);
    final rows = _rows(t);
    expect(rows.length, 1);
    expect(rows.first.split('|').length, 3);
  });

  test('مقدار نامعتبر تاریخ در یک رکورد، بقیهٔ بازخوردها را از بین نمی‌برد', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'feedback_v1': jsonEncode({
        'v': 1,
        'entries': [
          {'q': 'سؤال سالم', 'a': 'پاسخ سالم', 'v': 1, 't': 100},
          {'q': 'سؤال با تاریخ بد', 'a': 'پاسخ', 'v': -1, 't': 'bad-ts'},
          {'q': 'سؤال با تاریخ اعشاری', 'a': 'پاسخ', 'v': 1, 't': 42.9},
        ],
      }),
    });
    PrivacyService.persistenceAllowed = true;
    final list = await FeedbackStore.all();
    expect(list.length, 3);
    expect(list[0].at, 100);
    expect(list[1].at, 0);
    expect(list[2].at, 42);
    expect(FeedbackStore.lastError, isNull);
  });

  test('قفل‌بودن ذخیره یا JSON خراب در FeedbackStore.lastError ثبت می‌شود و clear bool برمی‌گرداند',
      () async {
    PrivacyService.persistenceAllowed = false;
    expect(await FeedbackStore.add('پرسش تازه', 'پاسخ تازه', -1), isFalse);
    expect(FeedbackStore.lastError, isNotNull);

    PrivacyService.persistenceAllowed = true;
    expect(await FeedbackStore.add('پرسش تازه', 'پاسخ تازه', 1), isTrue);
    expect(FeedbackStore.lastError, isNull);
    expect(await FeedbackStore.clear(), isTrue);
    expect(FeedbackStore.lastError, isNull);

    SharedPreferences.setMockInitialValues(<String, Object>{
      'feedback_v1': '{invalid-json',
    });
    expect(await FeedbackStore.all(), isEmpty);
    expect(FeedbackStore.lastError, isNotNull);
  });
}
