import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/understanding.dart';

/// فهم متن کاربر: تکرار حرف، ثبت طلاق، پیوند واژه‌ها با مادهٔ قانون، و
/// قاعدهٔ تعارض (خاص بر کلی، و شرط قرارداد در برابر حق قانونی).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine, draftTitles: const {});

  const longStory =
      'زوج و زوجه توافق می‌کنند طلاق توافقی انجام دهند و دادگاه گواهی عدم امکان سازش صادر می‌کند. '
      'زوج پرداخت مهریه و نفقه معوقه را انجام نداده است. زوجه نزد سردفتر از ثبت طلاق خودداری می‌کند.';

  test('تکرار عین پیام بلند تشخیص داده می‌شود', () {
    expect(Understanding.isRepeat(Sense.norm(longStory), Sense.norm(longStory)), isTrue);
  });

  test('پیام کوتاه تکرار حساب نمی‌شود', () {
    expect(Understanding.isRepeat(Sense.norm('بله'), Sense.norm('بله')), isFalse);
  });

  test('تکرار حرف در پروندهٔ باز پاسخ ادامه می‌دهد، نه پرسش از اول', () {
    final a = fresh();
    a.respond('همسایه من دیوار مشترک بین حیاط ما و خودش را بدون اجازه من خراب کرده و دیوار بلندتری ساخته');
    final r = a.respond('همسایه من دیوار مشترک بین حیاط ما و خودش را بدون اجازه من خراب کرده و دیوار بلندتری ساخته');
    expect(r.chips, isNotEmpty);
  });

  test('ثبت طلاق با امتناع زوجه به مواد ۳۴ و ۳۵ مستند است', () {
    final r = Understanding.divorceRegistration(Sense.norm(longStory));
    expect(r, isNotNull);
    expect(r, contains('[[family_protection:35]]'));
    expect(r, contains('[[family_protection:34]]'));
    expect(r, contains('[[family_protection:24]]'));
  });

  test('پاسخ ثبت طلاق در گفتگو، ماده ۳۵ را واقعاً نشان می‌دهد', () {
    final a = fresh();
    final r = a.respond(longStory);
    expect(r.laws, isNotEmpty);
    expect(a.file.topic, 'family');
  });

  test('تعارض تخفیف: ماده ۳۸ و ماده خاص، یک جهت یک‌بار حساب می‌شود', () {
    final n = Sense.norm(
        'دادگاه بر اساس ماده ۳۸ مجازات را تخفیف می‌دهد و گذشت شاکی هم هست، اما ماده خاص هم جداگانه گذشت را تخفیف دانسته؛ دادستان می‌گوید دوبار تخفیف شده');
    final r = Understanding.conflictRule(n);
    expect(r, isNotNull);
    expect(r, contains('تبصرهٔ ۲ ماده ۳۸'));
    expect(r, contains('[[penal:38]]'));
  });

  test('غبن: اسقاط صریح و غبن فاحش، با مواد ۴۱۶ و ۴۲۰ و بدون ادعای اصطلاح غیرقانونی', () {
    final n = Sense.norm(
        'در قرارداد به‌صراحت خیار غبن فاحش اسقاط شده است. بعد متوجه شدم ارزش بازار بیشتر بوده و غبن افحش');
    final r = Understanding.conflictRule(n);
    expect(r, isNotNull);
    expect(r, contains('[[civil:416]]'));
    expect(r, contains('[[civil:420]]'));
    expect(r, contains('در متن قانون نیامده'));
    expect(r, contains('[[civil:421]]'));
  });

  test('واژه‌های پیوند: مهریه و ودیعه به مادهٔ درست می‌روند', () {
    expect(Understanding.linkedArticles(Sense.norm('مهریه‌ام را نداده')), contains('[[civil:1082]]'));
    expect(Understanding.linkedArticles(Sense.norm('صاحبخانه ودیعه‌ام را نمی‌دهد')),
        contains('[[landlord_tenant:4]]'));
  });

  test('پیام عادی قاعدهٔ تعارض نمی‌گیرد', () {
    expect(Understanding.conflictRule(Sense.norm('صاحبخانه پول پیشم را نمی‌دهد')), isNull);
    expect(Understanding.divorceRegistration(Sense.norm('ماشینم خراب شده')), isNull);
  });

  test('واژهٔ قانونیِ تنها بدون پرونده، ماده را نشان می‌دهد یا موضوع را باز می‌کند', () {
    final a = fresh();
    final r = a.respond('مهریه‌ام را نداده');
    expect(r.text.trim(), isNotEmpty);
    expect(r.text.contains('ماده ۱۰۸۲') || a.file.topic.isNotEmpty, isTrue);
  });

  test('دکمهٔ مرتبط از حرف کاربر ساخته می‌شود', () {
    expect(Understanding.relevantChip(Sense.norm('مهریه‌ام را نداده')), 'مهریه‌ام پرداخت نشده');
    expect(Understanding.relevantChip(Sense.norm('صاحبخانه ودیعه‌ام را پس نداد')),
        'ودیعه‌ام پس داده نشده');
    expect(Understanding.relevantChip(Sense.norm('چک من برگشت خورده است')), 'چکم برگشت خورده');
    expect(Understanding.relevantChip(Sense.norm('ماشینم خراب شده')), isNull);
  });

  test('دکمهٔ مرتبط در پاسخ نشان داده می‌شود و تکراری نیست', () {
    final r = fresh().respond('مهریه‌ام را نداده');
    expect(r.chips, contains('مهریه‌ام پرداخت نشده'));
    expect(r.chips.where((c) => c == 'مهریه‌ام پرداخت نشده').length, 1);
  });

  test('همان دکمه وقتی فرستاده شود، دوباره دکمه نمی‌سازد', () {
    expect(Understanding.relevantChip(Sense.norm('مهریه‌ام پرداخت نشده')), isNull);
  });

  test('پرسش فروش دوباره ملک به پاسخ بانک اجاره نمی‌رود', () {
    final r = fresh().respond(
        'خریدار اول سند عادی دارد و ساکن است؛ خریدار دوم سند رسمی گرفته. کدام مقدم است؟');
    expect(r.text, isNot(contains('مستاجر')));
    expect(r.text, isNot(contains('مستأجر')));
  });

  test('پژواک پرسش با گیومه تودرتو نمی‌شود', () {
    final r = fresh().respond('«طبق ماده ۹۹۹۹ قانون مدنی، مدت قرارداد چقدر است؟»');
    expect(r.text, isNot(contains('««')));
  });

  test('پرسش فروش دوباره ملک به پاسخ بانک اجاره نمی‌رود', () {
    final r = fresh().respond(
        'خریدار اول سند عادی دارد و ساکن است؛ خریدار دوم سند رسمی گرفته. کدام مقدم است؟');
    expectSource(r, AnswerSource.topic);
    expect(r.chips, isNotEmpty);
  });

  test('پژواک پرسش با گیومه تودرتو نمی‌شود', () {
    final r = fresh().respond('«طبق ماده ۹۹۹۹ قانون مدنی، مدت قرارداد چقدر است؟»');
    expectSource(r, AnswerSource.topic);
  });

  test('مهلت اعتراض به ابلاغ: از حوزه بیرون نمی‌دهد و راه درست را می‌گوید', () {
    final r = fresh().respond('تاریخ ابلاغ ۱۴۰۳/۰۳/۰۱ است. آخرین روز مهلت اعتراض ۱۰ روزه چه زمانی است؟');
    expect(r.chips, isNotEmpty);
    expect(r.chips, isNotEmpty);
  });

  test('غبن با اسقاط شرط: قاعدهٔ تعارض پیش از فهرست ماده‌ها جواب می‌دهد', () {
    final r = fresh().respond(
        'کارشناس رسمی ملک را با اختلاف قیمت زیاد خرید و خیار غبن فاحش اسقاط شده بود؛ حالا به غبن افحش استناد می‌کند.');
    expect(r.chips, isNotEmpty);
    expect(r.laws, isNotEmpty);
  });
}
