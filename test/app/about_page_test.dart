import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/about_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  group('صفحهٔ وضعیت داده‌ها', () {
    testWidgets('AboutPage منبع قوانین و هشدارهای بارگذاری را نمایش می‌دهد',
        (tester) async {
      final repo = TemplateRepository()..problems.add('bad_template.json: خطا');
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AboutPage(
              engine: engine,
              repo: repo,
              initialInfo: const <String, dynamic>{
                'dataVersion': '0.2',
                'lawsUpdated': '۱۴۰۵/۰۸/۰۸',
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('هشدارهای بارگذاری'),
        200,
      );
      await tester.pumpAndSettle();

      expect(find.text('هشدارهای بارگذاری'), findsOneWidget);
      expect(find.textContaining('bad_template.json'), findsOneWidget);
    });
  });
}
