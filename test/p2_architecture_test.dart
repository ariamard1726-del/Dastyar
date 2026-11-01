import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/about_page.dart';
import 'package:dastyar/assistant.dart';
import 'package:dastyar/chat_controller.dart';
import 'package:dastyar/chat_page.dart';
import 'package:dastyar/core/text_utils.dart';
import 'package:dastyar/engine.dart';
import 'package:dastyar/history.dart';
import 'package:dastyar/history_page.dart';
import 'package:dastyar/llm.dart';
import 'package:dastyar/persian_text.dart';
import 'package:dastyar/services/conflicts_service.dart';
import 'package:dastyar/settings.dart';
import 'package:dastyar/settings_page.dart';
import 'package:dastyar/templates.dart';

class _ControllableLlm extends LlmBackend {
  final List<Completer<String?>> _steps = [];
  bool cancelled = false;

  void emit(String token) {
    if (_steps.isNotEmpty && !_steps.last.isCompleted) {
      _steps.last.complete(token);
    }
  }

  void finish() {
    if (_steps.isNotEmpty && !_steps.last.isCompleted) {
      _steps.last.complete(null);
    }
  }

  @override
  String get name => 'controllable';

  @override
  Future<bool> isReady() async => true;

  @override
  Stream<String> generate(
    String prompt, {
    LlmOptions options = const LlmOptions(),
  }) async* {
    while (!cancelled) {
      final c = Completer<String?>();
      _steps.add(c);
      final next = await c.future;
      if (next == null || cancelled) break;
      yield next;
    }
  }

  @override
  void cancel() {
    cancelled = true;
    finish();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('P2-1: کنترلر مستقل گفتگو و مدیریت چرخهٔ حیات استریم', () {
    test('ChatController بدون ویجت، پرسش عادی و ذخیرهٔ تاریخچه را مدیریت می‌کند', () async {
      final settings = AppSettings()..saveHistory = true;
      final history = HistoryStore();
      await history.load();
      final repo = TemplateRepository();
      final ctrl = ChatController(
        engine: engine,
        assistant: Assistant(engine),
        repo: repo,
        history: history,
        settings: settings,
      );

      await ctrl.submit('ماده ۱۰ قانون مدنی');
      expect(ctrl.busy, isFalse);
      expect(ctrl.messages.length, 2);
      expect(ctrl.messages.first.fromUser, isTrue);
      expect(ctrl.messages.last.text, contains('قراردادهای خصوصی'));
      expect(history.sessions.length, 1);

      ctrl.dispose();
    });

    test('لغو پاسخ در میانهٔ استریم مدل را متوقف و رویدادهای کهنه را مسدود می‌کند', () async {
      final llm = _ControllableLlm();
      final settings = AppSettings()..saveHistory = false;
      final ctrl = ChatController(
        engine: engine,
        assistant: Assistant(engine, llm: llm),
        repo: TemplateRepository(),
        history: HistoryStore(),
        settings: settings,
      );

      final future = ctrl.submit('ماده ۱۰ قانون مدنی');
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.busy, isTrue);

      llm.emit('طبق ماده ۱۰ ');
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.messages.last.text, 'طبق ماده ۱۰ ');

      ctrl.cancelActiveAsk();
      expect(ctrl.busy, isFalse);
      expect(llm.cancelled, isTrue);

      await future;
      expect(ctrl.messages.last.text, 'طبق ماده ۱۰ ');
      ctrl.dispose();
    });

    test('dispose در میانهٔ استریم، مدل را لغو می‌کند و خطا نمی‌اندازد', () async {
      final llm = _ControllableLlm();
      final ctrl = ChatController(
        engine: engine,
        assistant: Assistant(engine, llm: llm),
        repo: TemplateRepository(),
        history: HistoryStore(),
        settings: AppSettings()..saveHistory = false,
      );

      final future = ctrl.submit('ماده ۱۰ قانون مدنی');
      await Future<void>.delayed(Duration.zero);
      expect(ctrl.busy, isTrue);

      expect(ctrl.dispose, returnsNormally);
      expect(llm.cancelled, isTrue);
      await future;
    });

    testWidgets('دکمهٔ توقف پاسخ در حین استریم نمایش داده می‌شود و کار می‌کند',
        (tester) async {
      final llm = _ControllableLlm();
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ChatPage(
              engine: engine,
              assistant: Assistant(engine, llm: llm),
              repo: TemplateRepository(),
              history: HistoryStore(),
              settings: AppSettings()..saveHistory = false,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ماده ۱۰ قانون مدنی');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();

      expect(llm.cancelled, isTrue);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.text('پاسخ متوقف شد.'), findsOneWidget);
    });
  });

  group('P2-2: یکپارچه‌سازی لایهٔ متن فارسی، سرویس تضادها و صفحهٔ وضعیت داده‌ها', () {
    test('toFaDigits و asciiDigits روی ارقام لاتین، عربی و ایموجی ایمن کار می‌کنند', () {
      expect(PersianText.toFaDigits('Year 2026 / ١٤٠٥ 😀'), 'Year ۲۰۲۶ / ۱۴۰۵ 😀');
      expect(PersianText.asciiDigits('مبلغ ۵۰،۰۰۰ و ١٢٣ ریال'), '50000123');
      expect(TextUtils.toFaDigits('42'), '۴۲');
      expect(TextUtils.asciiDigits('۴۲'), '42');
      expect(TemplateRenderer.toFa('1397'), '۱۳۹۷');
    });

    test('ConflictsService زنجیره، حلقه و سقف عمق را به‌درستی مدیریت می‌کند', () async {
      final svc = ConflictsService();
      final assetData = await svc.loadData();
      final chains = svc.getConflictsChain('101', assetData);
      expect(chains, contains('101 -> 105 -> 108 -> 109'));
      expect(svc.getTitle('101', assetData), 'ماده ۱۰۱');

      final cyclic = <String, dynamic>{
        'articles': <String, dynamic>{
          '1': <String, dynamic>{
            'conflicts_with': <String>['2'],
          },
          '2': <String, dynamic>{
            'conflicts_with': <String>['1'],
          },
        },
      };
      final cycChains = svc.getConflictsChain('1', cyclic);
      expect(cycChains.any((c) => c.contains('⚠️ (حلقه)')), isTrue);

      final capped = svc.getConflictsChain('101', assetData, maxDepth: 2);
      expect(capped, ['101 -> 105']);
    });

    testWidgets('AboutPage منبع قوانین و هشدارهای بارگذاری را نمایش می‌دهد',
        (tester) async {
      final repo = TemplateRepository()..problems.add('bad_template.json: خطا');
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: AboutPage(engine: engine, repo: repo),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('هشدارهای بارگذاری'), findsOneWidget);
      expect(find.textContaining('bad_template.json'), findsOneWidget);
    });
  });

  group('P2-5: حالت نمایش (ThemeMode) و جست‌وجو در تاریخچه', () {
    test('ThemeMode در AppSettings ذخیره و بازیابی می‌شود', () async {
      final s1 = await AppSettings.load();
      expect(s1.themeMode, ThemeMode.system);
      await s1.setThemeMode(ThemeMode.dark);

      final s2 = await AppSettings.load();
      expect(s2.themeMode, ThemeMode.dark);
    });

    testWidgets('انتخاب حالت تیره در SettingsPage تنظیمات را به‌روز می‌کند',
        (tester) async {
      final settings = await AppSettings.load();
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
      final history = HistoryStore();
      await history.load();
      await history.upsert(
        ChatSession(
          id: '1',
          title: 'سؤال درباره چک صیادی',
          updated: 1700000000000,
          messages: [StoredMsg('چک من برگشت خورد', true)],
        ),
      );
      await history.upsert(
        ChatSession(
          id: '2',
          title: 'قرارداد اجاره مسکونی',
          updated: 1700000050000,
          messages: [StoredMsg('ودیعه مستأجر', true)],
        ),
      );

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
  });
}
