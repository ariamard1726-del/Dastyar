import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/legal_facts.dart';
import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/ui/chat_controller.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/templates.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> doc;
  late KnowledgeEngine engine;

  setUpAll(() async {
    doc = jsonDecode(
      File('assets/legal_facts.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    engine = KnowledgeEngine();
    await engine.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('مأموریت ۱: خروج ادعاهای حقوقی از کد', () {
    test('تمام رکوردها چهار فیلد الزامی و شناسهٔ یکتا دارند', () {
      final facts = (doc['facts'] as List).cast<Map<String, dynamic>>();
      expect(facts.length, greaterThan(40));
      final ids = <String>{};
      for (final f in facts) {
        for (final k in [
          'id',
          'claim_text',
          'law_name',
          'article_number',
          'block',
          'order',
          'separator_after'
        ]) {
          expect(f.containsKey(k), isTrue, reason: '$k در ${f['id']} نیست');
        }
        expect((f['claim_text'] as String).trim(), isNotEmpty);
        expect((f['law_name'] as String).trim(), isNotEmpty);
        expect((f['article_number'] as String).trim(), isNotEmpty);
        expect(ids.add(f['id'] as String), isTrue,
            reason: 'شناسهٔ تکراری: ${f['id']}');
      }
      expect(
        facts.every((f) => !f['claim_text'].toString().contains('۱۵۷ قانون کار')),
        isTrue,
        reason: 'ادعای نادرست مادهٔ ۱۵۷ قانون کار باید حذف شده باشد',
      );
    });

    test('تمام بلاک\u200cهای ارجاع\u200cشده در کد در JSON وجود دارند', () {
      final source = File('lib/domain/legal_counselor.dart').readAsStringSync();
      final ids = RegExp(r"_facts\('([^']+)'\)")
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toSet();
      expect(ids.length, greaterThan(25));
      final blocks = (doc['facts'] as List)
          .map((f) => (f as Map<String, dynamic>)['block'].toString())
          .toSet();
      for (final id in ids) {
        expect(blocks, contains(id),
            reason: 'بلاک $id در legal_facts.json تعریف نشده است');
      }
      LegalFacts.instance.loadFromJson(
        File('assets/legal_facts.json').readAsStringSync(),
      );
      for (final id in ids) {
        expect(LegalFacts.instance.hasBlock(id), isTrue);
        expect(LegalFacts.instance.block(id), isNot(LegalFacts.unverified));
      }
    });

    test('engine.load فایل حقوقی را بارگذاری می\u200cکند و کد وابسته به داده است',
        () async {
      final e = KnowledgeEngine();
      await e.load();
      expect(e.warnings, isEmpty);
      expect(LegalFacts.instance.isLoaded, isTrue);
      expect(LegalFacts.instance.length, greaterThan(40));

      // جملهٔ حذف\u200cشدهٔ مادهٔ ۱۵۷ دیگر در هیچ\u200cکدام از منابع برنامه نیست
      final counselor = File('lib/domain/legal_counselor.dart').readAsStringSync();
      final factsRaw = File('assets/legal_facts.json').readAsStringSync();
      expect(counselor.contains('مادهٔ ۱۵۷ قانون کار'), isFalse);
      expect(factsRaw.contains('مادهٔ ۱۵۷ قانون کار'), isFalse);
      expect(LegalFacts.instance.block('labor_dismissal_action'),
          contains('هیأت تشخیص'));
      expect(LegalFacts.instance.block('labor_dismissal_action'),
          isNot(contains('۱۵۷')));
    });

    test('جمع\u200cبندی مشاوره ادعاها را از JSON می\u200cخواند، نه از کد', () async {
      LegalFacts.instance.loadFromJson(
        File('assets/legal_facts.json').readAsStringSync(),
      );
      ChatController makeCtrl() => ChatController(
            engine: engine,
            assistant: Assistant(engine),
            repo: TemplateRepository(),
            history: HistoryStore(),
            settings: AppSettings()..saveHistory = false,
          );

      // مسیر صادرکنندهٔ چک → بلاک cheque_issuer
      final ctrl = makeCtrl();
      await ctrl.submit('چک دادم بابت ضمانت الان برگشت زده و می\u200cخواهم بدانم چه کار کنم');
      await ctrl.submit('بله، گواهی دارم و زیر ۶ ماه است');
      final withFacts = ctrl.messages.last.text;
      expect(withFacts, contains('مادهٔ ۱۳ قانون صدور چک'));
      expect(withFacts,
          contains(LegalFacts.instance.block('cheque_issuer').split('\n').first));
      ctrl.dispose();

      // بدون دادهٔ JSON هیچ ادعای حقوقی\u200cای در متن ظاهر نمی\u200cشود
      LegalFacts.instance.clear();
      final ctrl2 = makeCtrl();
      await ctrl2.submit('چک دادم بابت ضمانت الان برگشت زده و می\u200cخواهم بدانم چه کار کنم');
      await ctrl2.submit('بله، گواهی دارم و زیر ۶ ماه است');
      final withoutFacts = ctrl2.messages.last.text;
      expect(withoutFacts, contains(LegalFacts.unverified));
      expect(withoutFacts, isNot(contains('مادهٔ ۱۳ قانون صدور چک')));
      ctrl2.dispose();

      LegalFacts.instance.loadFromJson(
        File('assets/legal_facts.json').readAsStringSync(),
      );
    });

    test('پرسش\u200cهای حاوی مهلت/استناد هم از legal_facts.json خوانده می\u200cشوند',
        () {
      LegalFacts.instance.loadFromJson(
        File('assets/legal_facts.json').readAsStringSync(),
      );
      expect(LegalFacts.instance.block('cq_litigation_defense_deadline'),
          contains('۲۰ روز'));
      expect(LegalFacts.instance.block('cq_cheque_nature'),
          contains('مادهٔ ۱۳ قانون صدور چک'));
      final source = File('lib/domain/legal_counselor.dart').readAsStringSync();
      expect(source.contains('مهلت واخواهی و تجدیدنظر ۲۰ روز'), isFalse);
    });
  });
}
