// رگرسیونِ واقعیِ ۱۰۰٪ برای هر ۲۴ قانونِ بسته‌بندی‌شده.
//
// به‌جای عبارت‌های دستی (که با بازنگریِ رسمیِ متنِ قانون می‌پوسند)، هر تست در
// زمانِ اجرا از خودِ فایل `assets/laws/...` متنِ ماده را می‌خواند، یک واژهٔ
// متمایز (طولانی‌ترین واژهٔ ≥۶ حرفی) استخراج می‌کند و بررسی می‌کند موتور همان
// ماده را با همان واژه برگرداند. سه نوع پرونده برای هر قانون:
//
// ۱. واکشی مستقیم ماده با عنوان کامل قانون (تطابق دقیق شماره + واژهٔ متمایز)؛
// ۲. «مادهٔ ناموجود» هرگز ساخته نمی‌شود (شماره = بیشترین + ۱۰۰۰ ⇒ «پیدا نشد»)؛
// ۳. نوعِ سربرگ («ماده» / «اصل» برای قانون اساسی) درست است.
//
// پوششِ «همهٔ ۲۴ قانون» با خودِ `_meta.json` سنجیده می‌شود؛ جا افتادنِ هر
// قانونی، آزمون را قرمز می‌کند (۱۰۰٪ واقعی، نه اسمی).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/ui/laws_library.dart';

import 'law_regress_cases.dart';

String _faDigits(int n) => PersianText.toFaDigits(n.toString());

String _kindOf(String lawId) => lawId == 'constitution' ? 'اصل' : 'ماده';

/// طولانی‌ترین واژهٔ فارسیِ خالص (بدون اعراب/نیم‌فاصله) با ۶+ حرف.
String _distinctiveWord(String text) {
  final cleaned = text
      .replaceAll(RegExp(r'[ً-ٰٟـ]'), '')
      .replaceAll('\u200c', ' ');
  final words = cleaned
      .split(RegExp(r'\s+'))
      .where((w) =>
          RegExp(r'^[آابپتثجچحخدذرزژسشصضطظعغفقکگلمنوهی]{6,}$').hasMatch(w))
      .toList();
  if (words.isEmpty) return '';
  words.sort((a, b) => b.length.compareTo(a.length));
  return words.first;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  late Map<String, dynamic> meta;
  late Map<String, List<ArticleEntry>> parsed;
  late Map<String, String> lawTitles;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
    meta = jsonDecode(
            File('assets/laws/_meta.json').readAsStringSync())
        as Map<String, dynamic>;
    lawTitles = {
      for (final e in meta.entries)
        e.key: (e.value as Map<String, dynamic>)['title'] as String,
    };
    parsed = {
      for (final e in meta.entries)
        e.key: LawsLibrary.debugParseArticles(
          File('assets/laws/${(e.value as Map<String, dynamic>)['path']}')
              .readAsStringSync(),
        ),
    };
  });

  test('جدول رگرسیون دقیقاً ۲۴ قانون دارد و همهٔ شناسه‌های _meta.json در آن هستند',
      () {
    final ids = kLawRegressCases.map((c) => c.lawId).toSet();
    expect(ids.length, 24);
    expect(ids, meta.keys.toSet());
  });

  test('هر مادهٔ جدول در متنِ بسته‌بندی‌شده وجود دارد (تست روباز)', () {
    for (final c in kLawRegressCases) {
      final kind = _kindOf(c.lawId);
      final found = parsed[c.lawId]!
          .any((a) => a.kind == kind && a.number == c.article);
      expect(found, isTrue,
          reason: '${c.lawId} مادهٔ ${c.article} در متن بسته‌بندی‌شده نیست');
    }
  });

  for (final c in kLawRegressCases) {
    final kind = _kindOf(c.lawId);
    final label = '$kind ${_faDigits(c.article)}';
    String titleOf() => lawTitles[c.lawId]!;

    group('$label — ${c.lawId}', () {
      test('واکشی مستقیم ماده با عنوان کامل قانون، متن واقعی خودِ ماده را می‌دهد',
          () {
        final articles = parsed[c.lawId]!;
        final article = articles.firstWhere(
            (a) => a.kind == kind && a.number == c.article);
        final word = _distinctiveWord(article.text);
        expect(word.length, greaterThanOrEqualTo(6),
            reason: 'واژهٔ متمایزی در متن مادهٔ ${c.article} پیدا نشد');

        final answer = engine.answer('$label ${titleOf()} چه می‌گوید؟');
        expect(answer, contains(label));
        expect(answer, contains(word));
      });

      test('«مادهٔ ناموجود» هرگز ساخته نمی‌شود', () {
        final articles = parsed[c.lawId]!;
        final maxNumber = articles.fold<int>(
            0, (m, a) => a.number > m ? a.number : m);
        final answer =
            engine.answer('$kind ${_faDigits(maxNumber + 1000)} ${titleOf()} چه می‌گوید؟');
        expect(answer, contains('پیدا نشد'));
      });

      test('نوعِ سربرگ (ماده/اصل) درست است', () {
        final answer = engine.answer('$label ${titleOf()}');
        if (kind == 'اصل') {
          expect(answer, contains('اصل ${_faDigits(c.article)}'));
          expect(answer.contains('ماده ${_faDigits(c.article)}'), isFalse);
        } else {
          expect(answer, contains('ماده ${_faDigits(c.article)}'));
        }
      });
    });
  }
}
