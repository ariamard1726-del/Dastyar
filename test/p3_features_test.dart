import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/assistant.dart';
import 'package:dastyar/chat_controller.dart';
import 'package:dastyar/chat_models.dart';
import 'package:dastyar/core/text_utils.dart';
import 'package:dastyar/drafting.dart';
import 'package:dastyar/engine.dart';
import 'package:dastyar/history.dart';
import 'package:dastyar/llm.dart';
import 'package:dastyar/persian_text.dart';
import 'package:dastyar/settings.dart';
import 'package:dastyar/settings_page.dart';
import 'package:dastyar/templates.dart';
import 'package:dastyar/widgets/chat_bubbles.dart';

List<LegalTemplate> _loadTemplatesSync() {
  final out = <LegalTemplate>[];
  for (final f in Directory('assets/templates').listSync()) {
    if (f is File && f.path.endsWith('.json')) {
      final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      out.add(LegalTemplate.fromJson(m));
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
    templates = _loadTemplatesSync();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('P3-1: دقت بازیابی تعاریف، مترادف‌های حقوقی و نگهبان حوزه‌های خارج از پوشش', () {
    test('پرسش «معسر کیست» و «مجازات چک برگشتی» دقیقاً مادهٔ اصلی را رتبهٔ ۱ می‌آورند', () {
      final r1 = engine.rank('معسر کیست', k: 3);
      expect(r1.hits, isNotEmpty);
      expect(r1.hits.first.chunk.lawId, 'financial_sentences');
      expect(r1.hits.first.chunk.title, 'ماده 6');

      final r2 = engine.rank('چک برگشتی چه مجازاتی دارد', k: 3);
      expect(r2.hits, isNotEmpty);
      expect(r2.hits.first.chunk.lawId, 'cheque');
      expect(r2.hits.first.chunk.title, 'ماده 7');

      final r3 = engine.rank('حداقل حقوق کارگر چقدر است', k: 3);
      expect(r3.hits, isNotEmpty);
      expect(r3.hits.first.chunk.lawId, 'labor');
    });

    test('پرسش‌های خارج از پوشش (کیفری عمومی، مالیات، تأمین اجتماعی، طلاق یک‌طرفه) پاسخ غلط نمی‌دهند', () {
      for (final q in const [
        'مجازات سرقت چیست',
        'مالیات بر درآمد حقوق چگونه محاسبه می‌شود',
        'حق بیمه تامین اجتماعی را چه کسی می‌پردازد',
        'شرایط طلاق یک‌طرفه از طرف زن چیست',
      ]) {
        final reply = engine.query(q);
        expect(reply.text, contains('پیدا نکردم'), reason: q);
      }

      // اما پرسش معتبر دربارهٔ طلاق خلع در قانون مدنی همچنان پاسخ درست می‌دهد
      final validDivorce = engine.query('طلاق خلع چیست');
      expect(validDivorce.text, contains('قانون مدنی'));
      expect(validDivorce.text, isNot(contains('پیدا نکردم')));
    });
  });

  group('P3-2: یکپارچه‌سازی زنجیرهٔ تعارض/ارتباط مواد در موتور و رابط کاربری', () {
    test('conflictChainsFor و EngineReply زنجیرهٔ ثبت‌شده در relationships.json را استخراج می‌کنند', () {
      final c101 = engine.findArticle('قانون مدنی', '101');
      expect(c101, isNotNull);
      if (c101 != null) {
        final chains = engine.conflictChainsFor(c101);
        expect(chains, contains('۱۰۱ -> ۱۰۵ -> ۱۰۸ -> ۱۰۹'));
      }

      final reply = engine.query('ماده ۱۰۱ قانون مدنی');
      expect(reply.conflictChains, contains('۱۰۱ -> ۱۰۵ -> ۱۰۸ -> ۱۰۹'));

      final normalReply = engine.query('ماده ۱۰ قانون مدنی');
      expect(normalReply.conflictChains, isEmpty);
    });

    testWidgets('BotMessageView کادر ارتباط یا تعارض مواد را نمایش می‌دهد',
        (tester) async {
      final msg = ChatMessage(
        'متن آزمایشی ماده ۱۰۱',
        false,
        conflictChains: const ['۱۰۱ -> ۱۰۵ -> ۱۰۸ -> ۱۰۹'],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: BotMessageView(
                message: msg,
                question: 'ماده ۱۰۱ قانون مدنی',
                onCopy: (_) {},
                onShare: (_) {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('ارتباط یا تعارض ثبت‌شدهٔ مواد:'), findsOneWidget);
      expect(find.textContaining('۱۰۱ ← ۱۰۵ ← ۱۰۸ ← ۱۰۹'), findsOneWidget);
    });
  });

  group('P3-3: اعتبارسنجی کد ملی و تلفن ایران و ذخیرهٔ رمزنگاری‌شدهٔ پیش‌نویس ناتمام', () {
    test('اعتبارسنجی کد ملی ۱۰ رقمی و شماره تلفن ایران (با ارقام فارسی، عربی و لاتین)', () {
      expect(PersianText.isValidIranianNationalId('0013542419'), isTrue);
      expect(PersianText.isValidIranianNationalId('۰۰۱۳۵۴۲۴۱۹'), isTrue);
      expect(TextUtils.isValidIranianNationalId('0499370899'), isTrue);
      expect(PersianText.isValidIranianNationalId('0013542418'), isFalse);
      expect(PersianText.isValidIranianNationalId('1111111111'), isFalse);
      expect(PersianText.isValidIranianNationalId('12345'), isFalse);

      expect(PersianText.normalizeIranianPhone('+98 912-345-6789'), '09123456789');
      expect(PersianText.normalizeIranianPhone('۰۰۹۸۹۱۲۳۴۵۶۷۸۹'), '09123456789');
      expect(TextUtils.isValidIranianPhone('۰۲۱-۸۸۷۷۶۶۵۵'), isTrue);
      expect(PersianText.isValidIranianPhone('12345'), isFalse);
    });

    test('فیلدهای phone و national_id در Drafting.answer اعتبارسنجی می‌شوند', () {
      final customTpl = LegalTemplate(
        id: 'verify_fields',
        title: 'آزمون اعتبارسنجی',
        description: '',
        version: 1,
        reviewed: true,
        reviewNote: '',
        tips: const [],
        keywords: const [],
        fields: [
          TemplateField(
            id: 'nid',
            label: 'کد ملی',
            type: 'national_id',
            required: true,
            hint: '',
            options: const [],
          ),
          TemplateField(
            id: 'tel',
            label: 'شماره همراه',
            type: 'phone',
            required: false,
            hint: '',
            options: const [],
          ),
        ],
        lawRefs: const [],
        body: 'کد ملی: {{nid}} - تلفن: {{tel}}',
      );

      final s = DraftSession(customTpl);
      final badNid = Drafting.answer(s, '1111111111');
      expect(badNid.text, contains('کد ملی واردشده معتبر نیست'));
      expect(s.index, 0);

      final okNid = Drafting.answer(s, '0013542419');
      expect(okNid.isDocument, isFalse);
      expect(s.values['nid'], '۰۰۱۳۵۴۲۴۱۹');

      final badPhone = Drafting.answer(s, 'abc123');
      expect(badPhone.text, contains('شماره تلفن معتبر'));

      final doc = Drafting.answer(s, '+989123456789');
      expect(doc.isDocument, isTrue);
      expect(doc.text, contains('۰۰۱۳۵۴۲۴۱۹'));
      expect(doc.text, contains('۰۹۱۲۳۴۵۶۷۸۹'));
    });

    test('DraftCheckpointStore و ChatController پیش‌نویس ناتمام را رمزنگاری، بازیابی و پاک می‌کنند', () async {
      final repo = TemplateRepository()..templates.addAll(templates);
      final settings = AppSettings()
        ..saveHistory = false
        ..saveDraftProgress = true;

      final ctrl1 = ChatController(
        engine: engine,
        assistant: Assistant(engine),
        repo: repo,
        history: HistoryStore(),
        settings: settings,
      );

      await ctrl1.submit('دادخواست مطالبهٔ وجه');
      expect(ctrl1.isDrafting, isTrue);
      await ctrl1.submit('تهران');
      final saved = await ctrl1.saveDraftCheckpoint();
      expect(saved, isTrue);

      final prefs = await SharedPreferences.getInstance();
      final rawCipher = prefs.getString('active_draft_v1') ?? '';
      expect(rawCipher, isNotEmpty);
      expect(rawCipher.contains('تهران'), isFalse); // رمزنگاری شده است

      ctrl1.dispose();

      final ctrl2 = ChatController(
        engine: engine,
        assistant: Assistant(engine),
        repo: repo,
        history: HistoryStore(),
        settings: settings,
      );
      final restored = await ctrl2
          .restoreDraftCheckpoint()
          .timeout(const Duration(seconds: 5));
      expect(restored, isTrue);
      expect(ctrl2.isDrafting, isTrue);
      expect(ctrl2.draft?.values['court_city'], 'تهران');
      expect(ctrl2.messages.last.text, contains('بازیابی شد'));

      await ctrl2.submit(DraftCmd.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await DraftCheckpointStore.load(templates), isNull);
      ctrl2.dispose();
    });
  });

  group('P3-4: بک‌اندهای مدل زبانی محلی و نگهبان امنیتی Loopback', () {
    test('LocalLoopbackLlm هر نشانی غیرمحلی را برای حفظ حریم خصوصی رد می‌کند', () {
      expect(
        () => LocalLoopbackLlm(
          endpoint: Uri.parse('https://api.openai.com/v1/chat/completions'),
        ),
        throwsArgumentError,
      );
      expect(
        () => LocalLoopbackLlm(
          endpoint: Uri.parse('http://192.168.1.20:8080/v1/chat/completions'),
        ),
        throwsArgumentError,
      );

      final local1 = LocalLoopbackLlm(
        endpoint: Uri.parse('http://127.0.0.1:11434/api/generate'),
      );
      expect(local1.name, 'local-loopback');
      local1.cancel();
    });

    test('extractTokenFromLine قالب‌های SSE (OpenAI/llama.cpp) و NDJSON (Ollama) را استخراج می‌کند', () {
      expect(
        LocalLoopbackLlm.extractTokenFromLine(
          'data: {"choices":[{"delta":{"content":"طبق ماده ۱۰ "}}]}',
        ),
        'طبق ماده ۱۰ ',
      );
      expect(LocalLoopbackLlm.extractTokenFromLine('data: [DONE]'), isNull);
      expect(
        LocalLoopbackLlm.extractTokenFromLine(
          '{"response":"قانون مدنی","done":false}',
        ),
        'قانون مدنی',
      );
    });

    test('LocalLoopbackLlm روی سرور محلی 127.0.0.1 استریم می‌کند و با Assistant راستی‌آزمایی می‌شود', () async {
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      try {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        unawaited(
          server.first.then((req) async {
            req.response.statusCode = 200;
            req.response.headers.contentType =
                ContentType('text', 'event-stream', charset: 'utf-8');
            req.response.writeln(
              'data: {"choices":[{"delta":{"content":"بر اساس ماده ۱۰ قانون مدنی، "}}]}',
            );
            await req.response.flush();
            req.response.writeln(
              'data: {"choices":[{"delta":{"content":"قراردادهای خصوصی نافذند."}}]}',
            );
            req.response.writeln('data: [DONE]');
            await req.response.close();
          }),
        );

        final llm = LocalLoopbackLlm(
          endpoint: Uri.parse(
            'http://127.0.0.1:${server.port}/v1/chat/completions',
          ),
        );
        try {
          expect(await llm.isReady(), isTrue);
          var enabled = true;
          final adaptive = AdaptiveLlm(
            candidates: [OnDeviceChannelLlm(), llm],
            isEnabled: () => enabled,
          );
          final assistant = Assistant(engine, llm: adaptive);
          final turns = await assistant
              .askWithAlternatives('ماده ۱۰ قانون مدنی')
              .toList()
              .timeout(const Duration(seconds: 5));

          expect(turns, isNotEmpty);
          expect(turns.last.text, contains('قراردادهای خصوصی نافذند.'));
          expect(turns.last.text, contains('منبع: قانون مدنی — ماده 10'));

          enabled = false;
          expect(await adaptive.isReady(), isFalse);
          await adaptive.dispose();
        } finally {
          llm.cancel();
          await server.close(force: true);
        }
      } finally {
        HttpOverrides.global = previousOverrides;
      }
    });

    testWidgets('تنظیمات جدید P3 در SettingsPage نمایش داده می‌شوند و کار می‌کنند',
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
        find.text('استفاده از مدل زبانی محلی (در صورت نصب)'),
        200,
      );
      await tester.pumpAndSettle();

      expect(find.text('ذخیرهٔ موقت پیش‌نویس ناتمام'), findsOneWidget);
      await tester.tap(find.text('استفاده از مدل زبانی محلی (در صورت نصب)'));
      await tester.pumpAndSettle();
      expect(settings.useLocalLlm, isTrue);
    });
  });
}
