import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/assistant.dart';
import 'package:dastyar/chat_page.dart';
import 'package:dastyar/drafting.dart';
import 'package:dastyar/engine.dart';
import 'package:dastyar/history.dart';
import 'package:dastyar/settings.dart';
import 'package:dastyar/templates.dart';

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

      await sendMessage(tester, 'دوستم پول قرض گرفته و پس نمی‌دهد');
      expect(find.textContaining('می‌خواهید همین حالا آماده‌اش کنم؟'), findsOneWidget);

      await sendMessage(tester, 'بله');
      expect(find.textContaining('چند سؤال کوتاه می‌پرسم'), findsOneWidget);
      expect(find.textContaining('لطفاً پرسش خود را کامل‌تر بنویسید'), findsNothing);
    });

    testWidgets('تایپ «نه» برای تک‌قالب پیشنهادی، به پرسش اصلی پاسخ می‌دهد',
        (tester) async {
      const q = 'توان پرداخت محکومیت مالی ندارم';
      await tester.pumpWidget(buildApp());

      await sendMessage(tester, q);
      expect(find.textContaining('می‌خواهید همین حالا آماده‌اش کنم؟'), findsOneWidget);

      await sendMessage(tester, 'نه');
      expect(find.text(engine.answer(q)), findsOneWidget);
      expect(find.textContaining('محکومیت‌های مالی'), findsWidgets);
    });

    testWidgets(
        'تایپ «بله» در پیشنهاد چندقالبی، پرسش اصلی را حفظ می‌کند و بعد با «نه» جواب می‌دهد',
        (tester) async {
      const q = 'چکم برگشت خورد';
      await tester.pumpWidget(buildApp());

      await sendMessage(tester, q);
      expect(find.text(Drafting.suggestChooseText), findsOneWidget);

      await sendMessage(tester, 'بله');
      expect(
        find.text('لطفاً مشخص کنید کدام‌یک از این قالب‌ها را آماده کنم:'),
        findsOneWidget,
      );
      expect(find.textContaining('لطفاً پرسش خود را کامل‌تر بنویسید'), findsNothing);

      await sendMessage(tester, 'نه');
      expect(find.text(engine.answer(q)), findsOneWidget);
      expect(find.textContaining('قانون صدور چک'), findsWidgets);
    });

    testWidgets('تایپ «اجراییه» در پیشنهاد چندقالبی، قالب اجرائیه چک را باز می‌کند',
        (tester) async {
      await tester.pumpWidget(buildApp());

      await sendMessage(tester, 'چکم برگشت خورد');
      expect(find.text(Drafting.suggestChooseText), findsOneWidget);

      await sendMessage(tester, 'اجراییه');
      expect(
        find.textContaining('برای «درخواست صدور اجرائیه چک» چند سؤال کوتاه می‌پرسم'),
        findsOneWidget,
      );
    });
  });
}
