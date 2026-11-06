import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/ui/chat_page.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';

List<LegalTemplate> _loadTemplates() {
  final out = <LegalTemplate>[];
  for (final f in Directory('assets/templates').listSync()) {
    if (f is File && f.path.endsWith('.json')) {
      final map = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      out.add(LegalTemplate.fromJson(map));
    }
  }
  out.sort((a, b) => a.id.compareTo(b.id));
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  late List<LegalTemplate> templates;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
    templates = _loadTemplates();
  });

  Widget buildApp() {
    final repo = TemplateRepository()..templates.addAll(templates);
    final settings = AppSettings()..saveHistory = false;
    final history = HistoryStore();
    return MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: ChatPage(
          engine: engine,
          assistant: Assistant(engine),
          repo: repo,
          history: history,
          settings: settings,
        ),
      ),
    );
  }

  Future<void> sendMessage(WidgetTester tester, String msg) async {
    await tester.enterText(find.byType(TextField), msg);
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
  }

  group('Drafting.pickChoice و تشخیص بله/نه', () {
    test('اشکال طبیعی بله و نه شناخته می‌شوند', () {
      expect(Drafting.isYes('بله!'), isTrue);
      expect(Drafting.isYes('آره، آماده کن'), isTrue);
      expect(Drafting.isNo('نه ممنون'), isTrue);
      expect(Drafting.isNo('نه، فقط توضیح بده'), isTrue);
    });

    test('انتخاب قالب با زیررشته، یکسان‌سازی ئ/ی و شماره گزینه', () {
      final chequeChoices = templates
          .where((t) => t.id == 'cheque_complaint' || t.id == 'cheque_execution')
          .toList();
      expect(
        Drafting.pickChoice('اجراییه', chequeChoices)?.id,
        'cheque_execution',
      );
      expect(
        Drafting.pickChoice('شکایت کیفری', chequeChoices)?.id,
        'cheque_complaint',
      );
      expect(
        Drafting.pickChoice('۲', chequeChoices)?.id,
        chequeChoices[1].id,
      );
      expect(
        Drafting.pickChoice('مجازات چک برگشتی چیست؟', chequeChoices),
        isNull,
      );
    });
  });

  group('جریان پیشنهاد قالب در ChatPage', () {
    testWidgets('تایپ «بله» برای تک‌قالب پیشنهادی، فرم را شروع می‌کند',
        (tester) async {
      await tester.pumpWidget(buildApp());

      await sendMessage(tester, 'یک نفر سفته‌ام را پس نمی‌دهد');
      expect(find.textContaining('می‌خواهید همین حالا آماده‌اش کنم؟'), findsOneWidget);

      await sendMessage(tester, 'بله');
      expect(find.textContaining('چند سؤال کوتاه می‌پرسم'), findsOneWidget);
      expect(find.textContaining('لطفاً پرسش خود را کامل‌تر بنویسید'), findsNothing);
    });

    testWidgets('تایپ «نه» برای تک‌قالب پیشنهادی، به پرسش اصلی پاسخ می‌دهد',
        (tester) async {
      const q = 'برای دادگاه پول وکیل ندارم';
      await tester.pumpWidget(buildApp());

      await sendMessage(tester, q);
      expect(find.textContaining('می‌خواهید همین حالا آماده‌اش کنم؟'), findsOneWidget);

      await sendMessage(tester, 'نه');
      expect(find.textContaining('چند سؤال کوتاه می‌پرسم'), findsNothing);
      expect(find.textContaining('ماده'), findsWidgets);
    });

    testWidgets('پاسخ نامرتبط به پیشنهاد تک‌قالب، به‌اشتباه «بله» تلقی نمی‌شود',
        (tester) async {
      await tester.pumpWidget(buildApp());

      await sendMessage(tester, 'یک نفر سفته‌ام را پس نمی‌دهد');
      expect(find.textContaining('می‌خواهید همین حالا آماده‌اش کنم؟'), findsOneWidget);

      await sendMessage(tester, 'طلبکار هستم');
      expect(find.textContaining('چند سؤال کوتاه می‌پرسم'), findsNothing);
    });

    testWidgets('شرح ماجرای چک برگشتی، به‌جای پیشنهاد خشک قالب، پاسخ همدلانه و مستند می‌دهد',
        (tester) async {
      await tester.pumpWidget(buildApp());

      await sendMessage(tester, 'چکم برگشت خورد');
      expect(find.text(Drafting.suggestChooseText), findsNothing);
      expect(find.textContaining('می‌فهمم'), findsWidgets);
      expect(find.textContaining('گواهی عدم پرداخت'), findsWidgets);
    });
  });
}
