import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/domain/lawyer/lawyer_voice.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/chat_controller.dart';

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

  group('راهنماهای حقوقی', () {
    test('هر استناد قانونی راهنماها در بانک قوانین وجود دارد', () {
      for (final g in legalGuides) {
        for (final r in g.refs) {
          expect(engine.findArticle(r.lawId, 'ماده ${r.article}'), isNotNull,
              reason: '${g.id}: ${r.lawId} ماده ${r.article} یافت نشد');
        }
      }
    });

    test('شناسهٔ راهنماها یکتا و قالب‌های پیشنهادی موجودند', () {
      final ids = legalGuides.map((g) => g.id).toList();
      expect(ids.toSet().length, ids.length);
      final tplIds = repo.templates.map((t) => t.id).toSet();
      for (final g in legalGuides) {
        for (final t in g.templateIds) {
          expect(tplIds, contains(t), reason: '${g.id}: قالب $t وجود ندارد');
        }
      }
    });

    test('پرسش‌های رایج به راهنمای درست می‌رسند', () {
      const cases = {
        'چک ۵۰ میلیونی دارم که برگشت خورده چه کار کنم؟': 'cheque_bounced',
        'چک تضمینی دادم حالا طرف میخواد اجرا بذاره': 'cheque_guarantee',
        'کارفرما بدون دلیل اخراجم کرد و حقوق سه ماهم را نداده': 'dismissal',
        'صاحبخانه پول پیشم را پس نمی‌دهد': 'deposit_return',
        'سن حضانت فرزند چند سال است؟': 'custody',
        'مهلت تجدیدنظر چند روز است؟': 'appeal',
        'یکی عکسهامو تهدید کرده پخش کنه': 'private_media',
        'خیانت در امانت چیست؟': 'trust_breach',
      };
      cases.forEach((q, id) {
        expect(LawyerVoice.matchGuide(q)?.id, id, reason: q);
      });
    });

    test('ارجاع مستقیم به ماده، راهنما را فعال نمی‌کند', () {
      expect(LawyerVoice.matchGuide('ماده ۷ قانون صدور چک چه می‌گوید؟'), isNull);
    });

    test('پاسخ راهنما همدلانه، مستند و با پرسش پیگیری است', () {
      final g = LawyerVoice.guideById('deposit_return')!;
      final r = LawyerVoice.composeGuide(
        g,
        'صاحبخانه پول پیشم را پس نمی‌دهد',
        engine,
        templates: repo.templates,
        counselChip: 'مشاوره',
      );
      expect(r.text, contains('مبنای قانونی'));
      expect(r.text, contains(g.followUp));
      expect(r.chips, contains('مشاوره'));
    });
  });

  group('گفتگو در ChatController', () {
    test('سلام دیگر متن ماده قانونی برنمی‌گرداند', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('سلام');
      final t = ctrl.messages.last.text;
      expect(t, contains('سلام'));
      expect(t, isNot(contains('ماده')));
      ctrl.dispose();
    });

    test('تشکر پاسخ گرم می‌گیرد، نه جست‌وجوی قانون', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('ممنون');
      expect(ctrl.messages.last.text, isNot(contains('ماده')));
      ctrl.dispose();
    });

    test('«طلبکار هستم» پس از پیشنهاد تک‌قالب، فرم تنظیم را شروع نمی‌کند',
        () async {
      final ctrl = makeCtrl();
      await ctrl.submit('یک نفر سفته‌ام را پس نمی‌دهد');
      expect(ctrl.messages.last.text, contains('آماده‌اش کنم'));
      await ctrl.submit('طلبکار هستم');
      expect(ctrl.isDrafting, isFalse);
      ctrl.dispose();
    });

    test('سلام همراه پرسش، هم احوال‌پرسی و هم پاسخ دارد', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('سلام، مهلت تجدیدنظر چند روز است؟');
      final t = ctrl.messages.last.text;
      expect(t, startsWith('سلام'));
      expect(t, contains('بیست روز'));
      ctrl.dispose();
    });

    test('وقتی پاسخی پیدا نشود، صادقانه می‌گوید و حدس نمی‌زند', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('قانون پرتاب فضاپیما به مریخ با موتور یونی');
      expect(ctrl.messages.last.text, contains(LawyerVoice.notFoundText));
      ctrl.dispose();
    });
  });
}
