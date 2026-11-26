import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import '../support/reply_shape.dart';

/// الگوی شکستی که از گفتگوهای گزارششده آمد:
///   - «تازه هست» و «موضوع جدیدی هست» به پرسشِ نامفهوم میخورد؛
///   - پرسش فرضی با طرفهای الف/ب/ج به یک ماجرای شخصی تبدیل میشد و وکیل
///     میپرسید «شما خریدار هستید یا فروشنده؟».
/// این آزمون فقط ساختار پاسخ را میسنجد، نه عبارت دقیق آنرا.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  test('«تازه هست» بعد از انصراف، درخواست موضوع تازه است', () {
    final a = Advocate(engine);
    a.respond('انصراف');
    final r = a.respond('تازه هست');
    expect(a.dialog.unclearPhrase, isEmpty);
    expect(r.ask, isNotEmpty);
    expect(a.file.topic, isEmpty);
  });

  test('«موضوع جدیدی هست» هم درخواست موضوع تازه است', () {
    final a = Advocate(engine);
    a.respond('انصراف');
    final r = a.respond('موضوع جدیدی هست');
    expect(a.dialog.unclearPhrase, isEmpty);
    expect(r.ask, isNotEmpty);
  });

  for (final scenario in <String>[
    'الف مالک خودرو است. ب بدون اذن او خودرو را به ج میفروشد و ثمن را میگیرد. '
        'پرسشها: ۱) وضعیت معامله چیست؟ ۲) آیا کلاهبرداری محقق است؟ ۳) تنفیذ بعدی چه اثری دارد؟',
    'الف ملکی را با مبایعنامه عادی به ب میفروشد. ب بدون سند رسمی ملک را به ج اجاره میدهد. '
        'پرسشها: ۱) خریدار با سند عادی مالک شناخته میشود؟ ۲) آیا ب اجرتالمثل میخواهد؟',
    'کارمند دولتی الف مال دولتی را به ب میسپارد. ب آن را تصاحب میکند. '
        'پرسشها: ۱) رفتار ب خیانت در امانت است؟ ۲) مسئولیت کیفری چگونه است؟',
  ]) {
    test('پرسش فرضی با طرفهای نامدار، پروندهٔ شخصی باز نمیکند', () {
      final a = Advocate(engine);
      final r = a.respond(scenario);
      expectDecisionName(a, 'پرسش فرضی');
      expectSource(r, AnswerSource.engine);
      expect(a.file.topic, isEmpty);
      expectNoText(r, 'خریدار یا فروشنده');
    });
  }
}
