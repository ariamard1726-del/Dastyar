import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/ui/history_page.dart';
import 'package:dastyar/ui/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('حالت نمایش (ThemeMode) و جست‌وجو در تاریخچه', () {
    test('ThemeMode در AppSettings ذخیره و بازیابی می‌شود', () async {
      final s1 = await AppSettings.load();
      expect(s1.themeMode, ThemeMode.system);
      await s1.setThemeMode(ThemeMode.dark);

      final s2 = await AppSettings.load();
      expect(s2.themeMode, ThemeMode.dark);
    });

    testWidgets('انتخاب حالت تیره در SettingsPage تنظیمات را به‌روز می‌کند',
        (tester) async {
      final settings = AppSettings();
      final history = HistoryStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SettingsPage(settings: settings, history: history),
          ),
        ),
      );

      await tester.tap(find.text('تیره'));
      await tester.pumpAndSettle();
      expect(settings.themeMode, ThemeMode.dark);
    });

    testWidgets('جست‌وجو در HistoryPage با نرمال‌سازی حروف عربی/فارسی فیلتر می‌کند',
        (tester) async {
      final history = HistoryStore()
        ..sessions.addAll([
          ChatSession(
            id: '2',
            title: 'قرارداد اجاره مسکونی',
            updated: 1700000050000,
            messages: [StoredMsg('ودیعه مستأجر', true)],
          ),
          ChatSession(
            id: '1',
            title: 'سؤال درباره چک صیادی',
            updated: 1700000000000,
            messages: [StoredMsg('چک من برگشت خورد', true)],
          ),
        ]);

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: HistoryPage(history: history),
          ),
        ),
      );

      expect(find.text('سؤال درباره چک صیادی'), findsOneWidget);
      expect(find.text('قرارداد اجاره مسکونی'), findsOneWidget);

      // جست‌وجو با کاف عربی «چك» باید «چک» فارسی را بیابد
      await tester.enterText(find.byType(TextField), 'چك');
      await tester.pump();

      expect(find.text('سؤال درباره چک صیادی'), findsOneWidget);
      expect(find.text('قرارداد اجاره مسکونی'), findsNothing);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      expect(find.text('قرارداد اجاره مسکونی'), findsOneWidget);
    });

    testWidgets('SettingsPage بدون وابستگی به مدل زبانی، گزینهٔ پیش‌نویس ناتمام را نمایش می‌دهد',
        (tester) async {
      final settings = AppSettings();
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: SettingsPage(settings: settings, history: HistoryStore()),
          ),
        ),
      );

      await tester.scrollUntilVisible(
        find.text('ذخیرهٔ موقت پیش‌نویس ناتمام'),
        200,
      );
      await tester.pumpAndSettle();

      expect(find.text('ذخیرهٔ موقت پیش‌نویس ناتمام'), findsOneWidget);
      expect(find.text('استفاده از مدل زبانی محلی (در صورت نصب)'), findsNothing);
      await tester.tap(find.text('ذخیرهٔ موقت پیش‌نویس ناتمام'));
      await tester.pumpAndSettle();
      expect(settings.saveDraftProgress, isTrue);
    });
  });
}
