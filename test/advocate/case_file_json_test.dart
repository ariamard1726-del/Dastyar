import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/case_file.dart';

/// پروندهٔ گفتگو باید بدون پخش دوبارهٔ پیام‌ها ذخیره و بازیابی شود.
///
/// پیش از این [CaseFile] فقط در حافظه بود و سه‌حالته‌های «بله/نه/نمی‌دانم»
/// با بسته‌شدن اپ از دست می‌رفت. این آزمون قرارداد JSON را قفل می‌کند.
void main() {
  Map<String, dynamic> roundTrip(CaseFile f) =>
      jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>;

  test('رفت‌وبرگشت، همهٔ واقعیت‌ها را نگه می‌دارد', () {
    final f = CaseFile()
      ..topic = 'rent'
      ..pending = 'deposit'
      ..lastKey = 'eviction'
      ..turns = 4
      ..disclaimed = true;
    f.facts['tenant'] = 'yes';
    f.facts['amount'] = '15000000';
    f.facts['unknown_thing'] = '?';
    f.askCount['deposit'] = 2;
    f.covered.addAll({'eviction', 'deposit'});

    final g = CaseFile.fromJson(roundTrip(f));

    expect(g.topic, 'rent');
    expect(g.facts, f.facts);
    expect(g.askCount, f.askCount);
    expect(g.pending, 'deposit');
    expect(g.covered, f.covered);
    expect(g.lastKey, 'eviction');
    expect(g.turns, 4);
    expect(g.disclaimed, isTrue);
    expect(g.yes('tenant'), isTrue);
    expect(g.n('amount'), 15000000);
    expect(g.has('unknown_thing'), isFalse);
  });

  test('پروندهٔ خالی هم سالم می‌چرخد', () {
    final g = CaseFile.fromJson(roundTrip(CaseFile()));
    expect(g.topic, '');
    expect(g.facts, isEmpty);
    expect(g.turns, 0);
    expect(g.disclaimed, isFalse);
  });

  test('نسخهٔ ناشناخته پروندهٔ خالی می‌دهد، نه کرش', () {
    final g = CaseFile.fromJson({'v': 999, 'topic': 'rent', 'facts': {'a': 'yes'}});
    expect(g.topic, '');
    expect(g.facts, isEmpty);
  });

  test('ورودی بدشکل پروندهٔ خالی می‌دهد، نه کرش', () {
    final g = CaseFile.fromJson({
      'v': CaseFile.schemaVersion,
      'topic': null,
      'facts': 'not-a-map',
      'askCount': {'x': 'not-int'},
      'covered': 'not-a-list',
      'turns': 'not-int',
    });
    expect(g.topic, '');
    expect(g.facts, isEmpty);
    expect(g.askCount, isEmpty);
    expect(g.covered, isEmpty);
    expect(g.turns, 0);
  });

  test('مقدارهای عددی واقعیت به رشته تبدیل می‌شوند', () {
    final g = CaseFile.fromJson({
      'v': CaseFile.schemaVersion,
      'facts': {'amount': 1200},
    });
    expect(g.facts['amount'], '1200');
    expect(g.n('amount'), 1200);
  });
}
