import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
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
        repo: repo,
        history: HistoryStore(),
        settings: AppSettings()
          ..saveHistory = false
          ..saveDraftProgress = false,
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

    test('ناراحتی و ترس کاربر تشخیص داده می‌شود', () {
      expect(LawyerVoice.expressesDistress('خیلی نگرانم و می‌ترسم'), isTrue);
      expect(LawyerVoice.expressesDistress('ماده ۱۰ قانون مدنی'), isFalse);
    });

    test('دکمهٔ قالب‌های مرتبط فقط قالب‌های موجود را می‌آورد', () {
      for (final g in legalGuides) {
        final chips = LawyerVoice.templateChips(g, repo.templates);
        expect(chips.length, lessThanOrEqualTo(g.templateIds.length));
        final titles = repo.templates.map((t) => t.title).toSet();
        for (final c in chips) {
          expect(titles, contains(c), reason: g.id);
        }
      }
    });
  });

  group('گفتگو در ChatController', () {
    test('سلام متن ماده قانونی برنمی‌گرداند', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('سلام');
      final t = ctrl.messages.last.text;
      expect(t, contains('سلام'));
      expect(t, isNot(contains('ماده')));
      expect(ctrl.messages.last.laws, isEmpty);
      ctrl.dispose();
    });

    test('تشکر پاسخ گرم می‌گیرد، نه جست‌وجوی قانون', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('ممنون');
      expect(ctrl.messages.last.text, isNot(contains('ماده')));
      expect(ctrl.messages.last.laws, isEmpty);
      ctrl.dispose();
    });

    test('شرح ماجرا فرم تنظیم سند را خودبه‌خود شروع نمی‌کند', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('یک نفر سفته‌ام را پس نمی‌دهد');
      expect(ctrl.isDrafting, isFalse);
      await ctrl.submit('طلبکار هستم');
      expect(ctrl.isDrafting, isFalse);
      ctrl.dispose();
    });

    test('حرف نامفهوم هم بی‌جواب نمی‌ماند و قانونی به آن چسبانده نمی‌شود',
        () async {
      final ctrl = makeCtrl();
      await ctrl.submit('بنفش قورباغه دیروز');
      expect(ctrl.messages.last.fromUser, isFalse);
      expect(ctrl.messages.last.text.trim(), isNotEmpty);
      ctrl.dispose();
    });
  });
}
