import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/ui/chat_controller.dart';
import 'package:dastyar/ui/chat_page.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';

import '../support/keystore_mock.dart';

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
  late TemplateRepository repo;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
    repo = TemplateRepository()..templates.addAll(_loadTemplatesSync());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    mockKeystore();
  });

  group('۱. تکمیل ۱۰۰٪ بانک قوانین رسمی و پشتیبانی از اصول قانون اساسی', () {
    test('تمام قوانین فهرست کاتالوگ (۲۴ قانون، بیش از ۵۶۰۰ ماده/اصل) بارگذاری شده‌اند', () {
      expect(engine.catalog.length, greaterThanOrEqualTo(24));
      for (final law in engine.catalog) {
        expect(
          engine.isLoaded(law.id),
          isTrue,
          reason: 'قانون ${law.id} (${law.title}) باید کامل بارگذاری شده باشد',
        );
      }
      expect(engine.size, greaterThan(5500));
    });

    test('جستجوی مستقیم اصول قانون اساسی با واژهٔ «اصل» کار می‌کند', () {
      final r22 = engine.answer('اصل ۲۲ قانون اساسی چه می‌گوید؟');
      expect(r22, contains('اصل 22'));
      expect(r22, contains('حیثیت'));

      final r37 = engine.answer('اصل ۳۷ قانون اساسی');
      expect(r37, contains('اصل 37'));
      expect(r37, contains('برائت'));

      final missing = engine.answer('اصل ۳۰۰ قانون اساسی');
      expect(missing, contains('پیدا نشد'));
    });

    test('گسترش فرهنگ لغات محاوره‌ای روی قوانین جدید دقیق کار می‌کند', () {
      final cyber =
          engine.rank('مجازات برداشت اینترنتی از حساب و فیشینگ چیست', k: 3);
      expect(cyber.hits.first.chunk.lawId, 'cybercrime');
      expect(cyber.hits.first.chunk.title, 'ماده 13');

      final vakhoahi =
          engine.rank('مهلت واخواهی از حکم غیابی در دادگاه حقوقی چقدر است', k: 3);
      expect(vakhoahi.hits.first.chunk.lawId, 'civil_procedure');
      expect(vakhoahi.hits.first.chunk.title, 'ماده 306');

      final mehrieh =
          engine.rank('مهریه تا چند سکه ضمانت اجرای جلب دارد', k: 3);
      expect(mehrieh.hits.first.chunk.lawId, 'family_protection');
      expect(mehrieh.hits.first.chunk.title, 'ماده 22');
    });
  });

  group('۲. گفتگوی دوطرفه، استدلال تشخیصی بدون مدل زبانی و تنظیم لایحه/اظهارنامه', () {
    ChatController makeCtrl() {
      final assistant = Assistant(engine);
      return ChatController(
        engine: engine,
        assistant: assistant,
        repo: repo,
        history: HistoryStore(),
        settings: AppSettings()..saveHistory = false,
      );
    }

    test('استخراج هوشمند اطلاعات اولیه بدون تکرار سؤال زاید در دعوای اجاره و تخلیه', () async {
      final ctrl = makeCtrl();

      // کاربر در همان جملهٔ اول نقش (موجر) و انقضای مدت را بیان کرده است
      await ctrl.submit('مستأجرم مدت قراردادش تمام شده ولی خانه را تخلیه نمی‌کند');
      expect(ctrl.isCounseling, isTrue);
      // نباید دوباره بپرسد موجر هستید یا مستأجر؛ مستقیم سراغ سؤال امضای دو شاهد می‌رود
      expect(ctrl.messages.last.text, contains('دو شاهد'));

      await ctrl.submit('قرارداد کتبی با امضای دو شاهد داریم');
      expect(ctrl.isCounseling, isFalse);
      expect(ctrl.messages.last.text, contains('دستور تخلیهٔ فوری'));
      expect(ctrl.messages.last.text, contains('ماده ۳'));
      expect(
        ctrl.messages.last.chips.any((c) => c.contains('اظهارنامه')),
        isTrue,
      );
      ctrl.dispose();
    });

    test('جریان دفاع در برابر حکم غیابی و انتقال یک‌ضرب به فرم تنظیم «لایحهٔ دفاعیه»', () async {
      final ctrl = makeCtrl();

      await ctrl.submit('حکم غیابی علیه من صادر شده چه کار کنم؟');
      expect(ctrl.isCounseling, isTrue);
      expect(ctrl.messages.last.text, contains('۲۰ روز'));

      await ctrl.submit('کمتر از ۲۰ روز گذشته است');
      expect(ctrl.messages.last.text, contains('واخواهی'));
      expect(ctrl.messages.last.text, contains('ماده ۳۰۵'));

      final defenseChip = ctrl.messages.last.chips
          .firstWhere((c) => c.contains('لایحهٔ دفاعیه'));
      await ctrl.submit(defenseChip);
      expect(ctrl.isDrafting, isTrue);
      expect(ctrl.draft?.template.id, 'defense_brief');
      ctrl.dispose();
    });

    test('استدلال تفکیکی چک تضمینی برای صادرکننده بر پایهٔ مادهٔ ۱۳ قانون صدور چک', () async {
      final ctrl = makeCtrl();

      await ctrl.submit('چک دادم بابت ضمانت الان برگشت زده و می‌خواهم بدانم چه کار کنم');
      // هم نقش صادرکننده و هم تضمینی بودن چک استخراج شده است؛ فقط سؤال زمان باقی مانده
      expect(ctrl.isCounseling, isTrue);
      expect(ctrl.messages.last.text, contains('گواهی عدم پرداخت'));

      await ctrl.submit('بله، گواهی دارم و زیر ۶ ماه است');
      expect(ctrl.messages.last.text, contains('مادهٔ ۱۳ قانون صدور چک'));
      expect(ctrl.messages.last.text, contains('لایحهٔ دفاعیه'));
      ctrl.dispose();
    });

    test('حافظهٔ زمینه‌ای گفتگو پرسش «اصل بعدی‌اش» را به اصل بعدی همان قانون متصل می‌کند', () async {
      final ctrl = makeCtrl();

      await ctrl.submit('اصل ۳۵ قانون اساسی');
      expect(ctrl.messages.last.text, contains('اصل 35'));
      expect(ctrl.messages.last.text, contains('انتخاب وکیل'));

      await ctrl.submit('اصل بعدی‌اش چی میگه؟');
      expect(ctrl.messages.last.text, contains('اصل 36'));
      ctrl.dispose();
    });

    test('انتخاب دکمهٔ مشاوره در میانهٔ پیشنهاد قالب، گفتگوی تشخیصی را روی همان موضوع آغاز می‌کند', () async {
      final ctrl = makeCtrl();

      await ctrl.submit('دوستم پول قرض گرفته و پس نمی‌دهد');
      expect(ctrl.messages.last.chips, contains(DraftCmd.offerCounsel));

      await ctrl.submit(DraftCmd.offerCounsel);
      expect(ctrl.isCounseling, isTrue);
      // گفتگو باید روی همان موضوع قبلی (طلب/بدهی) آغاز شود: نخستین پرسش،
      // تشخیص نقش کاربر (طلبکار یا بدهکار) است.
      expect(ctrl.messages.last.text, contains('طلبکار'));
      expect(ctrl.messages.last.text, contains('بدهکار'));
      ctrl.dispose();
    });

    testWidgets('دکمهٔ «مشاورهٔ حقوقی گام‌به‌گام» در صفحهٔ آغازین گفتگوی دوطرفه را فعال می‌کند',
        (tester) async {
      final settings = AppSettings()..saveHistory = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ChatPage(
              engine: engine,
              assistant: Assistant(engine),
              repo: repo,
              history: HistoryStore(),
              settings: settings,
            ),
          ),
        ),
      );

      // صفحهٔ آغازین فقط خوش‌آمدگویی و فیلد تایپ دارد؛ مشاوره با نوشتن
      // فرمان در همان فیلد آغاز می‌شود (هیچ منو/دکمه‌ای در Home نیست).
      expect(find.text('سلام، چه کمکی از من برمی‌آید؟'), findsOneWidget);
      expect(find.byType(ActionChip), findsNothing);
      await tester.enterText(
        find.byType(TextField),
        LegalCounselor.startCounselCmd,
      );
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.textContaining('با کمال میل همراه شما هستم'), findsOneWidget);
      expect(find.text('اخراج از کار، حقوق و بیمه'), findsOneWidget);
    });
  });
}
