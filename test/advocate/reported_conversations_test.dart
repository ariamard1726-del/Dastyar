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

  test('پرسش فرضی با طرفهای نامدار، پروندهٔ شخصی باز نمیکند', () {
    final a = Advocate(engine);
    final r = a.respond('الف مالک خودرو است. ب بدون اذن او خودرو را به ج میفروشد و ثمن را میگیرد. '
        'پرسشها: ۱) وضعیت معامله چیست؟ ۲) آیا کلاهبرداری محقق است؟ ۳) تنفیذ بعدی چه اثری دارد؟');
    expectSource(r, AnswerSource.engine);
    expect(a.file.topic, isEmpty);
    expectNoText(r, 'خریدار یا فروشنده');
  });
}
