import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/domain/lawyer/lawyer_voice.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/chat_controller.dart';

/// اتصال لایه‌های تازه (مسیریاب ترکیبی، شفاف‌سازی، اسلات‌ها، همدلی و افت
/// تدریجی) به جریان واقعی گفتگو در ChatController.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  late TemplateRepository repo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    engine = KnowledgeEngine();
    await engine.load();
    repo = TemplateRepository();
    await repo.load();
  });

  ChatController makeCtrl() => ChatController(
        engine: engine,
        assistant: Assistant(engine),
        repo: repo,
        history: HistoryStore(),
        settings: AppSettings()
          ..saveHistory = false
          ..saveDraftProgress = false,
        random: Random(1),
      );

  group('مسیریاب ترکیبی در گفتگو', () {
    test('«سرقت چک» به شکوائیه می‌رود، نه راهنمای دیگر', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('سرقت چک همکارم را گزارش دادم');
      final t = ctrl.messages.last.text;
      expect(t, contains('شکوائیه'));
      expect(t, contains('آماده‌اش کنم'));
      // اسلات‌های استخراج‌شده یادداشت می‌شوند.
      expect(t, contains('نوع اتفاق: سرقت'));
      ctrl.dispose();
    });

    test('«ی» و «ک» عربی هم همان مسیر را می‌روند', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('همكارم سرقت چك كرده');
      expect(ctrl.messages.last.text, contains('شکوائیه'));
      ctrl.dispose();
    });
  });

  group('پرسش شفاف‌سازی', () {
    test('دو قالب هم‌وزن → پرسش «۱ یا ۲»، و «۲» قالب دوم را شروع می‌کند',
        () async {
      final ctrl = makeCtrl();
      await ctrl.submit('همکارم مرا متهم کرده و اخطار داده');
      final q = ctrl.messages.last;
      expect(q.text, contains('1️⃣'));
      expect(q.text, contains('2️⃣'));
      expect(q.text, contains('۱ یا ۲'));
      expect(ctrl.isDrafting, isFalse);
      await ctrl.submit('۲');
      expect(ctrl.isDrafting, isTrue);
      expect(ctrl.messages.last.text, contains('اظهارنامه'));
      ctrl.dispose();
    });

    test('پاسخ نامربوط به شفاف‌سازی، پیش‌نویس شروع نمی‌کند', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('همکارم مرا متهم کرده و اخطار داده');
      await ctrl.submit('مهلت تجدیدنظر چند روز است؟');
      expect(ctrl.isDrafting, isFalse);
      ctrl.dispose();
    });
  });

  group('پرکردن اسلات‌ها', () {
    test('مبلغ گفته‌شده در گفتگو، در فیلد مبلغ به ریال پیشنهاد می‌شود',
        () async {
      final ctrl = makeCtrl();
      await ctrl.submit('دوستم ۵۰ میلیون تومان قرض گرفته و پس نمی‌دهد');
      await ctrl.submit('دادخواست مطالبهٔ وجه');
      expect(ctrl.isDrafting, isTrue);
      for (final a in [
        'تهران',
        'علی رضایی',
        'تهران خیابان آزادی',
        '09121234567',
        'رضا محمدی',
        'تهران',
      ]) {
        await ctrl.submit(a);
      }
      final m = ctrl.messages.last;
      expect(m.text, contains('مبلغ'));
      expect(m.chips.first, '۵۰۰۰۰۰۰۰۰');
      await ctrl.submit(m.chips.first);
      expect(ctrl.messages.last.text, isNot(contains('فقط عدد')));
      ctrl.dispose();
    });
  });

  group('افت تدریجی و همدلی', () {
    test('پرسش بی‌پاسخ: عذرخواهی صادقانه و ارجاع به وکیل/معاضدت', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('قانون پرتاب فضاپیما به مریخ با موتور یونی');
      final m = ctrl.messages.last;
      expect(m.text, contains('نمی‌خواهم با حدس زدن'));
      expect(m.text, contains('معاضدت کانون وکلا'));
      expect(m.chips, isNotEmpty);
      ctrl.dispose();
    });

    test('ارجاع مستقیم به ماده بدون «پاسخ پل» نمایش داده می‌شود', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('ماده ۱۰ قانون مدنی');
      final t = ctrl.messages.last.text;
      expect(t, contains('قراردادهای خصوصی'));
      expect(t, isNot(contains(LawyerVoice.bridgeLeadIn)));
      ctrl.dispose();
    });

    test('خروجی برای ورودی یکسان قطعی است', () async {
      Future<String> run() async {
        final c = makeCtrl();
        await c.submit('همکارم مرا متهم کرده و اخطار داده');
        final t = c.messages.last.text;
        c.dispose();
        return t;
      }

      expect(await run(), await run());
    });
  });
}
