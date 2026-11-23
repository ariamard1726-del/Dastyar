import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
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

  test('دوباره نامفهوم‌ماندن، به بن‌بست «در پایگاه نیست» نمی‌رسد', () {
    final a = fresh();
    a.respond('من دیروز با کسی در گیر شدم');
    // پیام دوم هم واقعاً نامفهوم است (یک کلمه، بی‌هیچ نشانهٔ موضوعی).
    final r = a.respond('هیچی');
    expect(r.text, isNot(contains('پایگاه داده')), reason: r.text);
    // حرفِ پیامِ قبلی هم نباید نقل شود؛ جواب باید دربارهٔ همین نوبت باشد.
    expect(r.text, isNot(contains('در گیر')), reason: r.text);
    expect(r.text, contains('موضوع'), reason: r.text);
    expect(r.chips, isNotEmpty, reason: 'کاربر نباید بی‌راه بماند');
  });

  test('«جر و بحث» دعوای لفظی است، نه «دفاع در برابر شکایت»', () {
    final a = fresh();
    final r = a.respond('من کسی با کسی جر و بحث کردم');
    expect(r.text, isNot(contains('دفاع در برابر شکایت')), reason: r.text);
    expect(r.text, contains('جرم نیست'), reason: r.text);
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

  test('«قرارداد کتبی دارید» بدون اینکه کاربر گفته باشد، گفته نمی‌شود', () {
    final f = CaseFile();
    f.facts['contract'] = 'yes';
    expect(laborRecap(f).join(' '), isNot(contains('کتبی')));
    f.facts['contract'] = 'no';
    expect(laborRecap(f).join(' '), isNot(contains('کتبی')));
  });
}
