import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// مرزهای خطِ تولیدِ پاسخ، پس از جدا شدنِ سه بخش
/// (`advocate_reply` = ترتیب، `advocate_reply_guard` = نگهبان‌ها،
/// `advocate_reply_case` = دو شاخهٔ پرونده).
///
/// این آزمون رفتار را با عدد و ترتیب می‌سنجد، نه با متنِ جمله‌ها: هر مرحله که
/// جایش را عوض کند، یکی از این پنج ادعا قرمز می‌شود.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine);

  test('۱. ایمنی پیش از هر قاعدهٔ دیگر: پرونده بی‌صدا باز می‌شود', () {
    final a = fresh();
    final r = a.respond('شوهرم منو زد و می‌خوام طلاق بگیرم');
    expect(r.source, AnswerSource.safety, reason: r.text);
    // نگهبانِ ایمنی پیش از شاخهٔ «پرونده باز است» اجرا می‌شود، ولی پرونده را
    // باز می‌کند تا نوبتِ بعد از سرِ همان موضوع ادامه یابد.
    expect(a.hasCase, isTrue);
    expect(a.file.topic, 'family');
  });

  test('۲. انصراف پرونده را کامل پاک می‌کند، نه نصفه', () {
    final a = fresh();
    a.respond('صاحبخونه پول پیشمو نمیده');
    expect(a.file.topic, isNotEmpty, reason: 'پرونده باز نشد');
    final r = a.respond('انصراف');
    expect(r.chips, [ChipTexts.leaveChip]);
    expect(a.hasCase, isFalse);
    expect(a.file.topic, isEmpty);
    expect(a.file.facts, isEmpty);
    expect(a.file.covered, isEmpty);
    expect(a.file.pending, isEmpty);
    expect(a.dialog.pendingTopic, isNull);
  });

  test('۳. پرسشِ تغییرِ موضوع، پروندهٔ جاری را عوض نمی‌کند', () {
    final a = fresh();
    a.respond('همسایه‌ام دیوار مشترک را خراب کرده');
    expect(a.file.topic, 'neighbor');
    final r = a.respond('کارفرمای من دو ماه است حقوقم را نداده و بیمه هم رد نکرده');
    expect(r.text, contains('فرق دارد'), reason: r.text);
    expect(r.chips, contains(ChipTexts.newTopicYesChip));
    expect(a.file.topic, 'neighbor');
    expect(a.dialog.pendingTopic?.id, 'labor');
  });

  test('۴. اصلاحِ کاربر پروندهٔ اشتباه را دور می‌ریزد و از نو باز می‌کند', () {
    final a = fresh();
    a.respond('چطور طلاق بگیرم؟');
    expect(a.hasCase, isTrue);
    final r = a.respond('من اصلا در مورد طلاق صحبت نکردم، در مورد دستبرد مغازه بود');
    expect(r.text.trim(), isNotEmpty);
    expect(a.file.topic, 'theft', reason: r.text);
    // واقعیت‌های پروندهٔ قبلی با خودِ پرونده رفته‌اند.
    expect(a.file.topic, isNot('family'));
  });

  test('۵. هیچ پاسخِ این مراحل بی‌متن نمی‌ماند و هیچ استنادِ بی‌متنی', () {
    const stages = <String>[
      'سلام',
      'صاحبخونه پول پیشمو نمیده',
      'مهلت اعتراض به رأی چقدره؟ ابلاغ ۱۴۰۳/۰۱/۱۵ بود',
      'کارفرما حقوقمو نداده',
      'لاک‌پشت بنفش دارم',
      'انصراف',
    ];
    for (final m in stages) {
      final a = fresh();
      final r = a.respond(m);
      expect(r.text.trim(), isNotEmpty, reason: m);
      expect(a.unresolved, isEmpty, reason: 'استنادِ بی‌متن در: $m');
    }
  });
}
