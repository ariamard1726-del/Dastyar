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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));
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

  group('مأموریت ۷: قالبها فقط در نوار بالای فیلد تایپ', () {
    testWidgets(
        'توصیف مشکل، پاسخ موتور را مینویسد ولی هیچ متن پیشنهاد قالبی داخل چت نیست',
        (tester) async {
      await tester.pumpWidget(buildApp());

      await sendMessage(tester, 'چکم برگشت خورد');

      // هیچ متن پیشنهادی در گفتگو نوشته نشده است.
      expect(find.text(Drafting.suggestChooseText), findsNothing);
      expect(find.text(Drafting.chooseText), findsNothing);
      expect(
        find.textContaining('می‌خواهید همین حالا آماده‌اش کنم؟'),
        findsNothing,
      );
      expect(find.textContaining('شکوائیه چک برگشتی'), findsNothing);
      // پاسخ مستند موتور جایگزین پیام پیشنهاد شده است.
      expect(find.textContaining('قانون صدور چک'), findsWidgets);

      // بهجای متن، برچسبهای کوتاه در نوار ChoiceChip دیده میشوند.
      String diag() =>
          'chips=${find.byType(ChoiceChip).evaluate().length} '
          'stop=${find.byIcon(Icons.stop_rounded).evaluate().length} '
          'sv=${find.byType(SingleChildScrollView).evaluate().length}';
      expect(
        find.widgetWithText(ChoiceChip, 'شکوائیه چک'),
        findsOneWidget,
        reason: diag(),
      );
      expect(
        find.widgetWithText(ChoiceChip, 'درخواست اجرائیه'),
        findsOneWidget,
        reason: diag(),
      );
      final sv = tester.widget<SingleChildScrollView>(
        find.byType(SingleChildScrollView),
      );
      expect(sv.scrollDirection, Axis.horizontal);
    });

    testWidgets('لمس «درخواست اجرائیه» مستقیم قالب اجرائیه چک را باز میکند',
        (tester) async {
      await tester.pumpWidget(buildApp());

      await sendMessage(tester, 'چکم برگشت خورد');
      await tester.tap(
        find.widgetWithText(
          ChoiceChip,
          'درخواست اجرائیه',
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
            'برای «درخواست صدور اجرائیه چک» چند سؤال کوتاه می‌پرسم'),
        findsOneWidget,
      );
    });

    testWidgets('تکقالب: پاسخ فوراً داده میشود و برچسب کوتاه آغاز پیشنویس است',
        (tester) async {
      const q = 'دوستم پول قرض گرفته و پس نمی‌دهد';
      await tester.pumpWidget(buildApp());

      await sendMessage(tester, q);
      expect(
        find.textContaining('می‌خواهید همین حالا آماده‌اش کنم؟'),
        findsNothing,
      );
      expect(
        find.widgetWithText(ChoiceChip, 'دادخواست وجه'),
        findsOneWidget,
      );

      await tester.tap(
        find.widgetWithText(
          ChoiceChip,
          'دادخواست وجه',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('چند سؤال کوتاه می‌پرسم'), findsOneWidget);
    });

    testWidgets('پرسش «محکومیت مالی» بدون متن پیشنهاد، پاسخ موتور را دارد',
        (tester) async {
      const q = 'توان پرداخت محکومیت مالی ندارم';
      await tester.pumpWidget(buildApp());

      await sendMessage(tester, q);
      expect(find.text(engine.answer(q)), findsOneWidget);
      expect(find.textContaining('محکومیت‌های مالی'), findsWidgets);
      expect(
        find.textContaining('می‌خواهید همین حالا آماده‌اش کنم؟'),
        findsNothing,
      );
    });
  });
}
