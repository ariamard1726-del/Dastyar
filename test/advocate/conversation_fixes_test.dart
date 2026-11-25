import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/topics/labor.dart';

/// آزمون گفتگویی که کاربر فرستاد؛ هر بند یک ایراد واقعی همان گفتگو است:
/// بن‌بستِ «در پایگاه نیست»، حدسِ نادرستِ «دفاع در برابر شکایت» برای «جر و
/// بحث»، جواب‌ندادن به حساب سادهٔ مهلت، ارقام لاتین در عنوان ماده، و ادعای
/// «قرارداد کتبی» که کاربر نگفته بود.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine);

  test('«متن قانون را ببینم» متن همان مواد را کامل و با ارقام فارسی می‌آورد',
      () {
    final a = fresh();
    final r = a.respond('صاحبخونه پول پیشمو نمیده');
    expect(r.laws, isNotEmpty, reason: 'پاسخ باید به ماده استناد کند');
    final law = a.respond(ChipTexts.lawChip);
    final title = r.laws.first.title;
    expect(law.laws, isNotEmpty);
    if (title != PersianText.toFaDigits(title)) {
      expect(law.text, isNot(contains(title)),
          reason: 'عنوان ماده نباید با ارقام لاتین بیاید: ${law.text}');
    }
    // متن ماده، نه چکیدهٔ «…»دار.
    expect(law.text, isNot(contains('…')), reason: law.text);
  });

  test('وقتی ماجرای کاربر معلوم است، جواب ماده «چه شده؟» نمی‌پرسد', () {
    final a = fresh();
    a.respond('کارفرما اخراجم کرده');
    final r = a.respond('ماده ۱۰ قانون مدنی چیست؟');
    expect(r.text.trim(), isNotEmpty);
    expect(r.text, isNot(contains('اگر بگویید چه شده')), reason: r.text);
  });

  test('وقتی ماجرایی در میان نیست، پرسیدنِ «چه شده؟» درست است', () {
    final a = fresh();
    final r = a.respond('ماده ۱۰ قانون مدنی چیست؟');
    expect(r.chips, isNotEmpty);
  });

  test('پیام چندموضوعی: موضوع‌ها را نام می‌برد و می‌پرسد از کدام شروع کنیم', () {
    final a = fresh();
    final r = a.respond('چک برگشتی دارم و شوهرم هم نفقه نمی‌دهد و '
        'صاحبخانه هم ودیعه را پس نمی‌دهد، اول کدام را پیگیری کنم؟');
    expect(r.chips, isNotEmpty);
    expect(r.chips.length, greaterThanOrEqualTo(2), reason: r.chips.join('،'));
    expect(a.file.topic, isEmpty, reason: 'نباید بی‌صدا یکی را انتخاب کند');
    // با انتخاب یکی از دکمه‌ها همان پرونده باز می‌شود.
    final pick = r.chips.first;
    a.respond(pick);
    expect(a.file.topic, isNotEmpty, reason: 'انتخاب «$pick» پرونده باز نکرد');
  });

  test('«جر و بحث» دعوای لفظی است، نه «دفاع در برابر شکایت»', () {
    final a = fresh();
    final r = a.respond('من کسی با کسی جر و بحث کردم');
    expect(r.text, isNot(contains('دفاع در برابر شکایت')), reason: r.text);
    expect(r.chips, contains('برخورد فیزیکی شد'));
    expect(r.chips, contains('برخورد فیزیکی شد'));
    expect(a.hasCase, isFalse);
  });

  test('جر و بحث همراه کتک، به پاسخِ دعوای لفظی بسنده نمی‌کند', () {
    final a = fresh();
    final r = a.respond('با هم جر و بحث کردیم و بعد کتکم زد');
    expect(r.text, isNot(contains('جرم نیست')), reason: r.text);
    expect(r.chips, isNot(contains('فقط حرف بود')));
  });

  test('مهلت با تاریخ و مدت، حساب می‌شود', () {
    final a = fresh();
    final r = a.respond(
        'اگر تاریخ ابلاغ ۱۴۰۳/۰۱/۱۵ باشد، آخرین روز مهلت ۲ ماهه چه تاریخی است؟');
    expect(r.text, contains('۱۴۰۳/۰۳/۱۵'), reason: r.text);
    expect(r.text, contains('۱۴۰۳/۰۱/۱۶'), reason: r.text);
    // هشدار حقوقی هم می‌ماند: این حساب است، نه فتوا.
    expect(r.text, contains('قانون'), reason: r.text);
    expect(r.chips, isNotEmpty);
  });

  test('سؤال مهلت بدون تاریخ، به حساب‌کردن نمی‌پرد', () {
    final a = fresh();
    final r = a.respond('مهلت اعتراض چقدر است؟');
    expect(r.text, isNot(contains('حساب تقویمی')), reason: r.text);
  });

  test('عنوان ماده در متن نمایش‌داده‌شده ارقام فارسی دارد', () {
    final c = engine.findArticle('civil', 'ماده 10');
    expect(c, isNotNull);
    final text = engine.format(c!);
    expect(text, contains('ماده ۱۰'), reason: text);
    expect(text, isNot(contains('ماده 10')));
  });

  test('«قرارداد یک‌ساله» به معنی «قرارداد کتبی» گرفته نمی‌شود', () {
    final a = fresh();
    a.respond('کارفرما اخراجم کرده');
    expect(a.file.topic, 'labor');
    // فقط از مدت قرارداد حرف زده، نه از کتبی‌بودنش.
    a.respond('چهار سال با قراردادهای یک‌ساله کار کردم');
    expect(a.file.has('contract'), isFalse, reason: a.file.get('contract'));
    // و در جمع‌بندی هم ادعای «قرارداد کتبی» نیاید.
    final recap = laborRecap(CaseFile()..facts['contract'] = 'yes').join(' ');
    expect(recap, contains('کتبی')); // با گفتن صریح «کتبی»، همان می‌ماند
  });
}
