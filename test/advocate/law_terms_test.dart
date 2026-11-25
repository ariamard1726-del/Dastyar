import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/law_terms.dart';

/// آزمون رگرسیون تطبیق واژه‌های متن کاربر با متن قوانین.
///
/// دو سطح: (۱) خودِ [LawTerms] روی همان نمونه‌های tests/law_terms/cases.json
/// که نسخهٔ پایتون هم با آن‌ها می‌سنجد؛ (۲) پاسخ کامل وکیل برای پرسش‌های
/// گزارش‌شده: پاسخ نباید «کدام نزدیک‌تر است؟» باشد و باید یا ماده را نشان دهد
/// یا بگوید کدام واژه‌ها در قوانین هست.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine, draftTitles: const {});

  test('همهٔ نمونه‌های tests/law_terms/cases.json با LawTerms یکسان است', () {
    final cases = (jsonDecode(
      File('tests/law_terms/cases.json').readAsStringSync(),
    ) as List).cast<Map<String, dynamic>>();
    expect(cases.length, greaterThanOrEqualTo(30));
    final terms = LawTerms(engine);
    for (final c in cases) {
      final q = c['q'] as String;
      final exp = c['expect'] as Map<String, dynamic>;
      final got = terms.match(q);
      expect(got.accepted, exp['accepted'], reason: q);
      if (exp.containsKey('law')) {
        expect(got.chunk?.lawId, exp['law'], reason: q);
      }
      if (exp.containsKey('title')) {
        expect(got.chunk?.title, exp['title'], reason: q);
      }
      for (final w in (exp['missing'] as List? ?? const [])) {
        expect(got.missing, contains(w), reason: q);
      }
    }
  });

  test('قرارداد: عبارت «متن کوتاه» در قوانین نیست و پاسخ کلی ندارد', () {
    final r = fresh().respond('متن کوتاه قرارداد شامل طرفین، مبلغ و تاریخ');
    expect(r.text, isNot(contains('کدام نزدیک‌تر')));
    expect(r.chips, isNotEmpty);
    expect(r.laws, isNotEmpty);
  });

  test('بیع شرط و رهن: پاسخ به «کدام نزدیک‌تر» نمی‌رسد', () {
    // این پیام به موضوع فروش می‌رسد و پاسخ آن از همان موضوع است؛ ماده‌ای که
    // عبارت «بیع شرط» را دارد در [LawTerms] آزمون شده است.
    final r = fresh().respond('بیع شرط رهن');
    expect(r.text, isNot(contains('کدام نزدیک‌تر')));
    expect(r.text.isNotEmpty, isTrue);
  });

  test('غبن افحش: جملهٔ استناد کامل است و ماده ۴۱۶ نشان داده می‌شود', () {
    final r = fresh().respond('کارشناس غبن افحش');
    expect(r.text, isNot(contains('کدام نزدیک‌تر')));
    expect(r.text, contains('ماده ۴۱۶'));
    expect(r.text, contains('«غبن»'));
  });
}
