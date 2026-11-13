import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('تنظیم سند در ChatPage', () {
    testWidgets('صفحهٔ گفتگو بالا می‌آید و شرح ماجرا پاسخ وکیل می‌گیرد، نه فرم',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      // دکمهٔ «توقف پاسخ» مخصوص مدل زبانی بود و دیگر وجود ندارد.
      expect(find.byIcon(Icons.stop_rounded), findsNothing);

      await sendMessage(tester, 'چکم برگشت خورد');
      expect(find.text('چکم برگشت خورد'), findsOneWidget);
      expect(find.text(Drafting.chooseText), findsNothing);
      expect(find.textContaining('چند سؤال کوتاه می‌پرسم'), findsNothing);
      expect(find.textContaining('چک'), findsWidgets);
    });

    testWidgets('«برام بنویسش» بدون پرونده می‌پرسد کدام متن، و «نه» آن را می‌بندد',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await sendMessage(tester, 'برام بنویسش');
      expect(find.text(Drafting.chooseText), findsOneWidget);

      await sendMessage(tester, 'نه');
      expect(find.textContaining('فعلاً متنی نمی‌نویسم'), findsOneWidget);
      expect(find.textContaining('چند سؤال کوتاه می‌پرسم'), findsNothing);
    });

    testWidgets('نام‌بردن از یک قالب، فرم همان را شروع می‌کند',
        (tester) async {
      await tester.pumpWidget(buildApp());
      await tester.pumpAndSettle();

      await sendMessage(tester, 'دادخواست مطالبهٔ وجه');
      expect(find.textContaining('چند سؤال کوتاه می‌پرسم'), findsOneWidget);
      expect(find.textContaining('شهر دادگاه'), findsWidgets);
    });
  });
}
