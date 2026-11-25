import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// آزمونِ جهت‌دهیِ آغاز گفتگو: بعد از سلام، برنامه به‌جای نمونه‌های آمادهٔ
/// دیگران، شاخهٔ کار را می‌پرسد (حقوقی/کیفری/اداری/نمی‌دانم/انصراف) و بعد
/// می‌خواهد ماجرا کامل گفته شود.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine);

  test('سلام فقط پنج دکمهٔ دسته را نشان می‌دهد، نه نمونه‌های آماده', () {
    final a = fresh();
    final r = a.respond('سلام');
    expect(r.chips, ChipTexts.branchChips);
    expect(r.chips, hasLength(5));
    expect(r.chips, containsAll(<String>['حقوقی', 'کیفری', 'اداری', 'نمی‌دانم']));
    expect(r.chips, isNot(contains('کارفرما اخراجم کرده')));
    expect(r.chips, contains(ChipTexts.leaveChip));
  });

  test('انتخاب «حقوقی» ماجرا را کامل می‌پرسد و بعد پرونده باز می‌شود', () {
    final a = fresh();
    a.respond('سلام');
    final r = a.respond('حقوقی');
    expect(r.chips, contains('حقوقی'));
    expect(r.chips, contains(ChipTexts.leaveChip));
    expect(a.file.topic, isEmpty, reason: 'نباید بی‌ماجرا پرونده باز کند');
    expect(a.hasCase, isFalse);
    // و بعد از توضیح کاربر، همان مسیر عادی کار می‌کند.
    a.respond('صاحبخونه پول پیشمو نمیده');
    expect(a.file.topic, 'rent');
  });

  test('«کیفری» و «اداری» پرسشِ متناسب با همان شاخه دارند', () {
    final a = fresh();
    a.respond('سلام');
    expect(r.chips, contains('دادسرا'));
    final b = fresh();
    b.respond('سلام');
    expect(r.chips, contains('اداره'));
  });

  test('«نمی‌دانم» سرزنش نمی‌کند و ماجرا را می‌پرسد', () {
    final a = fresh();
    a.respond('سلام');
    final r = a.respond('نمی‌دانم');
    expect(r.text, contains('لازم نیست'), reason: r.text);
    expect(r.text, contains('چه کسی چه کاری کرد'), reason: r.text);
  });

  test('«انصراف» گفتگو را می‌بندد و فقط دکمهٔ خروج می‌ماند', () {
    final a = fresh();
    a.respond('سلام');
    final r = a.respond('انصراف');
    expect(r.chips, [ChipTexts.leaveChip], reason: r.chips.join('،'));
    expect(r.text, contains('هر وقت'), reason: r.text);
  });

  test('«نمی‌دانم» بعد از بازشدن پرونده، جوابِ پرونده است نه انتخابِ دسته', () {
    final a = fresh();
    a.respond('کارفرما اخراجم کرده');
    expect(a.file.topic, 'labor');
    final r = a.respond('نمی‌دانم');
    expect(r.text, isNot(contains('لازم نیست اسمش را بدانید')));
    expect(a.file.topic, 'labor');
  });

  test('کیفری انتخاب‌شده، پرسشِ دسته را در نوبت‌های بعد تکرار نمی‌کند', () {
    final a = fresh();
    a.respond('سلام');
    a.respond('کیفری');
    final r = a.respond('صاحبخونه پول پیشمو نمیده');
    expect(r.text, isNot(contains('مشکل کیفری')), reason: r.text);
    expect(a.file.topic, 'rent');
  });
}
