import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/ui/laws_drawer.dart';
import 'package:dastyar/ui/laws_library.dart';

ArticleEntry _article(int n, String text, {bool mokarrar = false}) =>
    ArticleEntry(
      kind: 'ماده',
      number: n,
      mokarrar: mokarrar,
      title:
          'ماده ${PersianText.toFaDigits(n.toString())}${mokarrar ? ' مکرر' : ''}',
      text: text,
    );

LawEntry _law(String id, String title, List<ArticleEntry> articles) =>
    LawEntry(id: id, title: title, articles: articles);

void main() {
  group('LawsLibrary.debugParseArticles', () {
    test('سربرگ ماده/اصل و مکرر تشخیص داده می‌شوند', () {
      final arts = LawsLibrary.debugParseArticles(
        '# قانون آزمایشی\n\n'
        'ماده 1\nمتن یک.\nادامهٔ یک.\n\n'
        'ماده 2 مکرر (اصلاحی 1400)\nمتن دوم.\n',
      );
      expect(arts.length, 2);
      expect(arts[0].number, 1);
      expect(arts[0].mokarrar, isFalse);
      expect(arts[0].title, 'ماده ۱');
      expect(arts[0].text, equals('متن یک.\nادامهٔ یک.'));
      expect(arts[1].mokarrar, isTrue);
      expect(arts[1].title, 'ماده ۲ مکرر');
      expect(arts[1].text, equals('متن دوم.'));
    });

    test('عنوان فایل پیش از اولین ماده نادیده گرفته می‌شود', () {
      final arts = LawsLibrary.debugParseArticles(
        '# قانون آزمایشی\n## فصل اول\n\nاصل 3\nالف متن.\n',
      );
      expect(arts.single.kind, 'اصل');
      expect(arts.single.title, 'اصل ۳');
      expect(arts.single.text, 'الف متن.');
    });

    test('خطوط سربرگِ ناقصِ نسخ‌شده مادهٔ جدا محسوب نمی‌شوند', () {
      // نسخهٔ مخزن: «ماده ۴۱ (اصلاحی …)- از کلیه…» چسبیده است؛ پارسر باید آن را
      // دنباله‌ٔ مادهٔ قبل بداند، نه ماده‌ای تازه.
      final arts = LawsLibrary.debugParseArticles(
        'ماده 40 مکرر\nمتن 40 مکرر.\n'
        'ماده ۴۱ (اصلاحی ۱۴۰۴/۴/۸)- متنِ چسبیده.\n',
      );
      expect(arts.length, 1);
      expect(arts.single.mokarrar, isTrue);
      expect(arts.single.text,
          equals('متن 40 مکرر.\nماده ۴۱ (اصلاحی ۱۴۰۴/۴/۸)- متنِ چسبیده.'));
    });
  });

  group('searchLaws', () {
    final laws = [
      _law('civil', 'قانون مدنی', [
        _article(10, 'قراردادهای خصوصی نسبت به کسانی که آن را بسته‌اند نافذ است'),
        _article(1167, 'طفل متولد از زنا ملحق به زانی نمی‌شود'),
      ]),
      _law('penal', 'قانون مجازات اسلامی', [
        _article(10, 'هرکس شرط‌بندی کند مجازات می‌شود؛ موضوع معاملات نیست'),
      ]),
    ];

    test('شمارهٔ ماده با ارقام فارسی تطابق دقیق می‌دهد', () {
      final hits = searchLaws(laws, 'ماده ۱۰');
      final exact =
          hits.where((h) => h.exact).map((h) => h.law.id).toList();
      expect(exact, containsAll(['civil', 'penal']));
    });

    test('تطابق دقیق، مکرر بودن را هم می‌سنجد', () {
      final withMak = [
        _law('x', 'قانون آزمایشی', [_article(4, 'الف', mokarrar: true)]),
      ];
      expect(searchLaws(withMak, 'ماده 4 مکرر').where((h) => h.exact), hasLength(1));
      expect(searchLaws(withMak, 'ماده 4').where((h) => h.exact), isEmpty);
    });

    test('واژهٔ غیرعددی مواد مرتبط می‌سازد و واژه‌های ربطی نادیده گرفته می‌شوند',
        () {
      final hits = searchLaws(laws, 'قراردادهای خصوصی');
      expect(hits, isNotEmpty);
      expect(hits.every((h) => !h.exact), isTrue);
      expect(hits.first.law.id, 'civil');
    });

    test('query خالی نتیجه ندارد', () {
      expect(searchLaws(laws, '   '), isEmpty);
    });
  });

  group('LawsLibrary.load', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    test('۲۴ قانون با شمار موادِ هم‌خوان با _meta.json بار می‌شوند', () async {
      final laws = await LawsLibrary.load();
      expect(laws.length, 24);
      expect(laws.first.title, 'قانون مدنی');
      final metaRaw = await rootBundle.loadString('assets/laws/_meta.json');
      final meta = jsonDecode(metaRaw) as Map<String, dynamic>;
      final want = meta.values
          .whereType<Map<String, dynamic>>()
          .fold<int>(0, (s, m) => s + (m['articles'] as int));
      final got =
          laws.fold<int>(0, (s, l) => s + l.articles.length);
      expect(got, want);
      // مادهٔ جداشدهٔ ۱۱۶۷ مدنی باید مادهٔ مستقل باشد.
      final civil = laws.firstWhere((l) => l.id == 'civil');
      expect(civil.articles.any((a) => a.number == 1167), isTrue);
    });
  });

  group('دراور فهرست قوانین', () {
    testWidgets('باز شدن با سه‌نقطه، آکاردئون و کپی کل قانون', (tester) async {
      String? copied;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      });

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('fa'),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: const Text('دستیار'),
                  leading: IconButton(
                    tooltip: 'فهرست قوانین',
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => showLawsDrawer(context),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byTooltip('فهرست قوانین'));
      // بارگذاری ۵۶۹۱ ماده در پس‌زمینه + انیمیشن ورود
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();

      // نوار جست‌وجوی ثابت در بالای دراور
      expect(find.text('شماره ماده را وارد کنید...'), findsOneWidget);
      // قانون مدنی اولین قانون است و با کلیک باز می‌شود
      expect(find.text('قانون مدنی'), findsOneWidget);
      expect(find.byTooltip('کپی کل قانون'), findsNothing);
      await tester.ensureVisible(find.text('قانون مدنی'));
      await tester.tap(find.text('قانون مدنی'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('کپی کل قانون'), findsOneWidget);

      await tester.tap(find.byTooltip('کپی کل قانون'));
      await tester.pump();
      expect(find.text('کل قانون کپی شد'), findsOneWidget);
      expect(copied, contains('قانون مدنی'));
      expect(copied, contains('ماده ۱۱۶۷'));
    });
  });
}
