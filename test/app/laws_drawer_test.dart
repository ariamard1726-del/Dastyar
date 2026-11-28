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

    test('legal_terms مادهٔ متناظر را با تگ اولِ مرتبط‌ها می‌آورد', () {
      final testLaws = [
        _law('landlord_tenant', 'قانون روابط موجر و مستأجر',
            [_article(3, 'موجر پس از انقضای مدت می‌تواند تخلیه بخواهد')]),
        _law('civil', 'قانون مدنی',
            [_article(3, 'متن آزمایشی سادهٔ مدنی')]),
      ];
      final terms = [
        {
          'phrases': ['تخلیه ملک'],
          'law': 'landlord_tenant',
          'title': 'ماده 3',
          'anchor': 'تخلیه',
        },
      ];
      final hits = searchLaws(testLaws, 'تخلیه ملک', legalTerms: terms);
      expect(hits.first.law.id, 'landlord_tenant');
      expect(hits.first.article.number, 3);
      expect(hits.first.tag, 'تخلیه');
    });

    test('legal_terms با ورودی صرفاً عددی اثر نمی‌گذارد', () {
      final testLaws = [
        _law('landlord_tenant', 'قانون روابط موجر و مستأجر',
            [_article(3, 'متن مادهٔ سه')]),
      ];
      final terms = [
        {
          'phrases': ['تخلیه ملک'],
          'law': 'landlord_tenant',
          'title': 'ماده 3',
          'anchor': 'تخلیه',
        },
      ];
      final hits = searchLaws(testLaws, '3', legalTerms: terms);
      expect(hits.where((h) => h.exact), hasLength(1));
      expect(hits.where((h) => h.tag != null), isEmpty);
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
    // helper مشترک: باز کردن دراور با دکمهٔ سه‌نقطه و انتظار برای بارگذاری ۲۴ قانون.
    Future<void> openDrawer(WidgetTester tester) async {
      await tester.tap(find.byTooltip('فهرست قوانین'));
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // توجه: pumpAndSettle هرگز به سکون نمی‌رسد چون CircularProgressIndicator
      // (حالت لودینگ) یک انیمیشنِ تکرارشونده است؛ از پمپ‌های ثابت استفاده می‌شود.
      final err = tester.takeException();
      expect(err, isNull, reason: 'Error: DRW-open exception: $err');
    }

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

      await openDrawer(tester);
      expect(find.text('شماره ماده را وارد کنید...'), findsOneWidget,
          reason: 'Error: DRW-light placeholder missing');
      expect(find.text('قانون مدنی'), findsOneWidget,
          reason: 'Error: DRW-light civil law not listed');

      final cheque = find.text('قانون صدور چک');
      await tester.ensureVisible(cheque);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byTooltip('کپی کل قانون'), findsNothing,
          reason: 'Error: DRW-light copy button visible before expand');
      await tester.tap(cheque);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byTooltip('کپی کل قانون'), findsOneWidget,
          reason: 'Error: DRW-light copy button missing after expand');

      await tester.tap(find.byTooltip('کپی کل قانون'));
      await tester.pump();
      expect(find.text('کل قانون کپی شد'), findsOneWidget,
          reason: 'Error: DRW-light toast missing');
      expect(copied, isNotNull, reason: 'Error: DRW-light clipboard empty');
      expect(copied, contains('قانون صدور چک'),
          reason: 'Error: DRW-light clipboard lacks law title');
      expect(copied, contains('ماده ۱'),
          reason: 'Error: DRW-light clipboard lacks article 1');
      expect(copied, contains('ماده ۲۷'),
          reason: 'Error: DRW-light clipboard lacks article 27');
    }, timeout: const Timeout(Duration(minutes: 3)));

    testWidgets('دراور در تم تیرهٔ RTL بدون خطا رندر می‌شود و دکمهٔ X جست‌وجو را پاک می‌کند',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData.dark(useMaterial3: true),
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Builder(
              builder: (context) => Scaffold(
                appBar: AppBar(
                  title: const Text('دستیار'),
                  leading: IconButton(
                    tooltip: 'فهرست قوانین',
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => showLawsDrawer(context, legalTerms: const {}),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await openDrawer(tester);

      expect(find.text('شماره ماده را وارد کنید...'), findsOneWidget,
          reason: 'Error: DRW-dark placeholder missing');

      await tester.enterText(find.byType(TextField), 'ماده ۱۰');
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byTooltip('پاک کردن جست‌وجو'), findsOneWidget,
          reason: 'Error: DRW-dark clear button missing after typing');

      await tester.tap(find.byTooltip('پاک کردن جست‌وجو'));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('قانون مدنی'), findsOneWidget,
          reason: 'Error: DRW-dark law list missing after clear');
      expect(find.byTooltip('پاک کردن جست‌وجو'), findsNothing,
          reason: 'Error: DRW-dark clear button still visible');
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
