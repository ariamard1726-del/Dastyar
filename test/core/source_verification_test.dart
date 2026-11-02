import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/about_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> meta;
  late Map<String, dynamic> dataInfo;
  late KnowledgeEngine engine;

  setUpAll(() async {
    meta = jsonDecode(File('assets/laws/_meta.json').readAsStringSync())
        as Map<String, dynamic>;
    dataInfo = jsonDecode(File('assets/data_info.json').readAsStringSync())
        as Map<String, dynamic>;
    engine = KnowledgeEngine();
    await engine.load();
  });

  group('مأموریت ۲: حذف منابع مبهم و تاریخ\u200cهای ساختگی', () {
    test('همهٔ ۲۴ قانون منبع تأییدنشده دارند و هیچ ادعای منبع/تاریخی ندارند', () {
      expect(meta.length, 24);
      for (final entry in meta.entries) {
        final info = entry.value as Map<String, dynamic>;
        expect(info.containsKey('source_verified'), isTrue,
            reason: '${entry.key} فیلد source_verified ندارد');
        expect(info['source_verified'], false,
            reason: '${entry.key} تا تأیید منبع رسمی باید false باشد');
        for (final k in const ['source', 'date', 'amended']) {
          expect(info.containsKey(k), isFalse,
              reason: '${entry.key} هنوز $k تأییدنشده دارد');
        }
        expect((info['title'] as String).trim(), isNotEmpty);
        expect((info['path'] as String).trim(), isNotEmpty);
        expect(info['articles'], isA<int>());
      }
      final raw = File('assets/laws/_meta.json').readAsStringSync();
      for (final bad in const [
        'سایت اختبار',
        'سامانه ملی قوانین',
        'مرکز پژوهش\u200cهای مجلس',
        '۱۴۰۵/',
        '1405/',
      ]) {
        expect(raw.contains(bad), isFalse, reason: 'عبارت مبهم باقی\u200cمانده: $bad');
      }
    });

    test('data_info دیگر تاریخ ساختگی منتشر نمی\u200cکند', () {
      expect(dataInfo.containsKey('lawsUpdated'), isFalse);
      expect(dataInfo['sourceStatus'], 'تأیید نشده');
      final raw = File('assets/data_info.json').readAsStringSync();
      expect(raw.contains('۱۴۰۵/'), isFalse);
      expect(raw.contains('1405/'), isFalse);
    });

    test('موتور هیچ تاریخ دریافت متنی چاپ نمی\u200cکند و اعلام عدم تأیید می\u200cکند', () {
      final c = engine.findArticle('قانون مدنی', '10');
      expect(c, isNotNull);
      final text = engine.format(c!);
      expect(text, contains('منبع رسمی این متن هنوز تأیید نشده است.'));
      expect(text.contains('تاریخ دریافت متن'), isFalse);
      expect(text.contains('۱۴۰۵/'), isFalse);
      expect(engine.meta.length, 24);
      expect(engine.meta.values.every((m) => m['source_verified'] == false), isTrue);
    });

    testWidgets('صفحهٔ اطلاعات، منابع تأییدنشده را نشان می\u200cدهد و تاریخ جعلی ندارد',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AboutPage(
              engine: engine,
              repo: TemplateRepository(),
              initialInfo: dataInfo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('وضعیت منابع رسمی'), findsOneWidget);
      expect(find.text('تأیید نشده'), findsWidgets);
      await tester.scrollUntilVisible(
          find.textContaining('منبع رسمی تأیید نشده').first, 200);
      await tester.pumpAndSettle();
      expect(find.textContaining('منبع رسمی تأیید نشده'), findsWidgets);
      expect(find.textContaining('تاریخ دریافت متن'), findsNothing);
      expect(find.textContaining('۱۴۰۵/'), findsNothing);
    });
  });
}
