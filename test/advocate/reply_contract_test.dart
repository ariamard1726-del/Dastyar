import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// قرارداد «شکل» پاسخ‌ها، مستقل از متنِ جمله‌ها.
///
/// آزمون‌های `contains` می‌گویند «این جمله در پاسخ هست»؛ این آزمون می‌گوید
/// پاسخ به‌عنوان یک شیء سالم است: برچسب دارد، خالی نیست، دکمهٔ تکراری و
/// رشتهٔ خالی ندارد، و هر ماده‌ای که آورده متن دارد. تغییر جمله‌ها این
/// آزمون را نمی‌شکند؛ خراب‌شدن ساختار را می‌شکند.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  const messages = <String>[
    'سلام',
    'چطوری؟',
    'چکم برگشت خورد',
    'صاحبخونه پول پیشمو نمیده',
    'کارفرما حقوقمو نداده',
    'مهریه‌ام رو نمیده',
    'همسایه دیوار مشترک رو خراب کرده',
    'ماشینمو نفروخت تحویلم بده',
    'ماده ۱۰ قانون مدنی',
    'مهلت اعتراض به رأی چقدره؟ ابلاغ ۱۴۰۳/۰۱/۱۵ بود و مهلت ۲۰ روزه',
    'می‌خوام دادخواست بنویسم',
    'انصراف',
    'نمی‌دونم',
    'یک سؤال کاملاً بی‌ربط دربارهٔ هوای فردا',
  ];

  test('هیچ پاسخی بی‌برچسب، خالی یا با رشتهٔ خالی نیست', () {
    for (final m in messages) {
      final a = Advocate(engine);
      final r = a.respond(m);
      expect(r.text.trim(), isNotEmpty, reason: m);
      expect(r.source, isNot(AnswerSource.unknown), reason: m);
      for (final c in r.chips) {
        expect(c.trim(), isNotEmpty, reason: 'دکمهٔ خالی در: $m');
      }
      expect(r.chips.toSet().length, r.chips.length,
          reason: 'دکمهٔ تکراری در: $m');
      expect(r.chips.toSet().length, r.chips.length, reason: m);
    }
  });

  test('هر ماده‌ای که در پاسخ می‌آید، متن و عنوان دارد', () {
    for (final m in messages) {
      final a = Advocate(engine);
      final r = a.respond(m);
      for (final l in r.laws) {
        expect(l.title.trim(), isNotEmpty, reason: m);
        expect(l.body.trim(), isNotEmpty, reason: '${m} → ${l.title}');
        expect(l.verified || l.status.isEmpty || l.status == 'unverified',
            isTrue,
            reason: 'وضعیت ناشناختهٔ ${l.status} برای ${l.title}');
      }
    }
  });

  test('راه خروج همیشه در دسترس است: «انصراف» آخرین دکمه', () {
    for (final m in messages) {
      final a = Advocate(engine);
      final r = a.respond(m);
      if (r.chips.isEmpty) continue;
      expect(r.chips.last, ChipTexts.leaveChip, reason: m);
    }
  });

  test('هیچ استنادی بی‌متن نمی‌ماند (unresolved خالی است)', () {
    for (final m in messages) {
      final a = Advocate(engine);
      final r = a.respond(m);
      for (final l in r.laws) {
        expect(l.body.trim(), isNotEmpty, reason: '${m} → ${l.title}');
      }
      expect(a.unresolved, isEmpty, reason: m);
    }
  });

  test('ترتیب خط لوله بدون تکرار و با ایمنی در ابتدا', () {
    expect(pipelineOrder.first, AnswerSource.safety);
    expect(pipelineOrder.toSet().length,
        pipelineOrder.length);
    expect(pipelineOrder.last, AnswerSource.engine);
  });
}
