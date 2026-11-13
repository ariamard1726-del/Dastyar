import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// آزمون وکیل بدون مدل: فهم محاوره، حافظهٔ پرونده و درستی استنادها.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine, draftTitles: const {
        'demand_money': 'دادخواست مطالبه وجه',
        'defense_brief': 'لایحه دفاعیه',
      });

  /// گفتگو را اجرا می‌کند و پاسخ‌ها را برمی‌گرداند.
  List<AdvocateReply> talk(Advocate a, List<String> turns) =>
      [for (final t in turns) a.respond(t)];

  test('هر ماده‌ای که در دانش وکیل نام برده شده واقعاً در بانک قوانین هست', () {
    final ref = RegExp(r'\[\[([a-z_0-9]+):([0-9]+)(m?)\]\]');
    final missing = <String>{};
    var count = 0;
    for (final f in Directory('lib/domain/advocate').listSync()) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in ref.allMatches(f.readAsStringSync())) {
        count++;
        final art = 'ماده ${m[2]}${m[3] == 'm' ? ' مکرر' : ''}';
        final c = engine.findArticle(m[1]!, art);
        if (c == null || c.lawId != m[1]) missing.add('${m[1]}:$art');
      }
    }
    expect(count, greaterThan(100));
    expect(missing, isEmpty);
  });

  test('ودیعهٔ اجاره: مبلغ را می‌فهمد و سؤال قبلی را تکرار نمی‌کند', () {
    final a = fresh();
    final r = talk(a, [
      'صاحبخونه پول پیشمو نمیده',
      '۱۵۰ میلیون',
      'آره قرارداد تموم شده، یه ماهه خونه رو خالی کردم',
    ]);
    expect(a.file.topic, 'rent');
    expect(a.file.get('role'), 'tenant');
    expect(a.file.n('amount'), 150000000);
    expect(a.file.yes('vacated'), isTrue);
    expect(a.file.yes('ended'), isTrue);
    expect(r[0].text, contains('قانون روابط موجر و مستأجر'));
    expect(r[0].laws, isNotEmpty);
    expect(r[1].text, isNot(r[0].text));
    expect(r[1].text, contains('دادگاه عمومی'));
    expect(a.unresolved, isEmpty);
  });

  test('پرسش وسط پرونده جواب می‌گیرد، نه تکرار سؤال', () {
    final a = fresh();
    final r = talk(a, [
      'کارفرمام گفته از فردا نیا',
      '۴ ساله اونجا کار میکنم، قرارداد ندارم',
      'سنوات بهم تعلق میگیره؟',
      'چقدر میشه؟ حقوقم ۱۵ میلیون بود',
    ]);
    expect(a.file.topic, 'labor');
    expect(a.file.n('months'), 48);
    expect(a.file.n('salary'), 15000000);
    expect(r[2].text, contains('سنوات'));
    expect(r[2].text, contains('ماده ۲۴'));
    // ۴ سال × ۱۵ میلیون = ۶۰ میلیون تومان
    expect(r[3].text, contains('۶۰ میلیون'));
    expect(a.unresolved, isEmpty);
  });

  test('صادرکنندهٔ چک را با دارنده اشتباه نمی‌گیرد', () {
    final a = fresh();
    final r = talk(a, [
      'چکم برگشت خورده',
      'نه من خودم چک رو کشیدم، طرف رفته برگشت زده',
    ]);
    expect(a.file.topic, 'cheque');
    expect(a.file.get('role'), 'issuer');
    expect(a.file.yes('cert'), isFalse);
    expect(r[1].text, isNot(contains('اجرائیه بگیرید')));
    expect(a.unresolved, isEmpty);
  });

  test('خشونت خانگی به پروندهٔ خانواده می‌رود، نه کار', () {
    final a = fresh();
    final r = talk(a, [
      'شوهرم منو زده و از خونه بیرونم کرده',
      'میتونم طلاق بگیرم؟',
      'مهریه ام چی میشه؟',
      'بچه ۵ ساله دارم، حضانتش با کیه؟',
    ]);
    expect(a.file.topic, 'family');
    expect(a.file.get('role'), 'wife');
    expect(r[1].text, contains('طلاق'));
    expect(r[2].text, contains('مهریه'));
    expect(r[3].text, contains('حضانت'));
    expect({for (final x in r) x.text}.length, 4);
    expect(a.unresolved, isEmpty);
  });

  test('متهم: «اگه نرم چی میشه؟» جواب مشخص می‌گیرد', () {
    final a = fresh();
    final r = talk(a, [
      'ازم شکایت کردن به جرم کلاهبرداری ولی من کاری نکردم',
      'ابلاغیه اومده برای هفته بعد',
      'اگه نرم چی میشه؟',
    ]);
    expect(a.file.topic, 'accused');
    expect(a.file.get('charge'), 'fraud');
    expect(r[2].text, contains('جلب'));
    expect(a.draftIds, contains('defense_brief'));
    expect(a.unresolved, isEmpty);
  });

  test('اجارهٔ مشترک مغازه با شریک به موجر و مستأجر نمی‌رود', () {
    final a = fresh();
    talk(a, [
      'با شریکم به مشکل خوردم',
      'مغازه رو با هم اجاره کردیم ولی اون همه سود رو برمیداره',
    ]);
    expect(a.file.topic, 'partner');
    expect(a.unresolved, isEmpty);
  });

  test('پرسش‌های انسانی: هویت، اعتماد، چرا می‌پرسی، خلاصه', () {
    final a = fresh();
    final who = a.respond('تو وکیلی؟');
    expect(who.text, contains('وکیل دادگستری نیستم'));
    expect(who.laws, isEmpty);
    final trust = a.respond('میشه به حرفات اعتماد کرد؟');
    expect(trust.text, contains('محدودیت'));
    final term = a.respond('یعنی چی اعسار؟');
    expect(term.text, contains('اعسار'));
    a.respond('طلب دارم');
    expect(a.file.topic, 'debt');
    final why = a.respond('چرا اینو میپرسی؟');
    expect(why.text, contains('سؤالم این بود'));
    final sum = a.respond('خلاصه بگو');
    expect(sum.text, contains('خلاصه'));
    expect(a.unresolved, isEmpty);
  });

  test('بدهکارِ بی‌مدرک: «هیچ راهی نیست؟» ناامید رها نمی‌شود', () {
    final a = fresh();
    final r = talk(a, [
      'طلب دارم',
      '۳۰ تومن',
      'نه مدرکی ندارم',
      'فقط خودم و خودش میدونیم',
      'پس هیچ راهی نیست؟',
    ]);
    expect(a.file.topic, 'debt');
    expect(a.file.n('amount'), 30000000);
    expect(a.file.get('proof'), 'none');
    expect(r[1].text, contains('۳۰ میلیون تومان'));
    expect(r[3].text.length, lessThan(r[2].text.length));
    expect(r[4].text, contains('بن‌بست نیست'));
    expect(a.unresolved, isEmpty);
  });

  test('موضوع تازه وسط گفتگو: پروندهٔ قبلی بسته و پروندهٔ نو باز می‌شود', () {
    final a = fresh();
    talk(a, ['صاحبخونه پول پیشمو نمیده', '۵۰ میلیون']);
    expect(a.file.topic, 'rent');
    a.respond('راستی کارفرمام هم سه ماهه حقوقمو نداده');
    expect(a.file.topic, 'labor');
    expect(a.file.has('amount'), isFalse);
    a.respond(Advocate.newCaseChip);
    expect(a.hasCase, isFalse);
  });

  test('هیچ‌وقت بی‌جواب نمی‌ماند و حرف نامفهوم را صادقانه می‌گوید', () {
    final a = fresh();
    for (final t in ['asdf qwer', 'هوا چطوره', '؟', 'سلام', 'ممنون']) {
      expect(a.respond(t).text.trim(), isNotEmpty, reason: t);
    }
    a.respond('چکم برگشت خورده');
    final r = a.respond('بنفش قورباغه دیروز');
    expect(r.text.trim(), isNotEmpty);
    expect(r.chips, isNotEmpty);
    expect(a.file.topic, 'cheque');
  });

  test('بازسازی حافظه از پیام‌های قبلی همان پرونده را می‌سازد', () {
    final a = fresh();
    a.replay(['صاحبخونه پول پیشمو نمیده', '۱۵۰ میلیون']);
    expect(a.file.topic, 'rent');
    expect(a.file.n('amount'), 150000000);
    a.reset();
    expect(a.hasCase, isFalse);
    expect(a.file.turns, 0);
  });

  test('موجر را با مستأجر اشتباه نمی‌گیرد و «آره» را به پرسش درست می‌دهد', () {
    final a = fresh();
    final r = talk(a, [
      'مستاجرم سه ماهه اجاره نداده و خونه رو هم خالی نمیکنه',
      'آره مدتش تموم شده',
    ]);
    expect(a.file.topic, 'rent');
    expect(a.file.get('role'), 'landlord');
    expect(a.file.yes('ended'), isTrue);
    expect(a.file.touched('vacated'), isFalse);
    expect(r[0].text, contains('دستور تخلیه'));
    final b = fresh();
    b.respond('من مستاجرم صاحبخونه پول پیشمو نمیده');
    expect(b.file.get('role'), 'tenant');
    expect(a.unresolved, isEmpty);
  });

  test('واژه‌های شبیه هم گمراهش نمی‌کند (خونه≠نه، صیادیه≠دیه، خرجش≠هزینه)', () {
    final a = fresh();
    talk(a, [
      'صاحبخونه پول پیشمو نمیده',
      'آره قرارداد تموم شده، یه ماهه خونه رو خالی کردم',
    ]);
    expect(a.file.yes('vacated'), isTrue);
    final b = fresh();
    final r = talk(b, [
      'یه چک ۲۰۰ میلیونی دارم برگشت خورده',
      'گواهی عدم پرداخت گرفتم',
      'صیادیه',
      'هیچی به نامش نیست',
    ]);
    expect(b.file.topic, 'cheque');
    expect(b.file.get('role'), 'holder');
    expect(r[2].text, contains('صیاد'));
    expect(r[3].text, contains('توقیف'));
    final c = fresh();
    final rc = talk(c, [
      'چکم برگشت خورده',
      'نه من خودم چک رو کشیدم، طرف رفته برگشت زده',
      'ضمانت بوده، قرار نبود خرجش کنه',
      'روی چک ننوشتم بابت ضمانت ولی قرارداد داریم',
    ]);
    expect(c.file.get('kind'), 'guarantee');
    expect(rc[2].text, isNot(contains('هزینهٔ دادرسی')));
    expect(rc[2].text, contains('تعقیب کیفری'));
    expect(rc[3].text, contains('توقف عملیات اجرایی'));
    expect(b.unresolved, isEmpty);
    expect(c.unresolved, isEmpty);
  });

  test('شوهرِ بدهکار مهریه: سکه و ناتوانی از پرداخت را می‌فهمد', () {
    final a = fresh();
    final r = talk(a, [
      'زنم رفته خونه باباش مهریه شو گذاشته اجرا',
      '۳۰۰ تا سکه',
      'ندارم بدم',
    ]);
    expect(a.file.topic, 'family');
    expect(a.file.get('role'), 'husband');
    expect(a.file.n('coins'), 300);
    expect(r[1].text, contains('۱۹۰'));
    expect(r[1].text, isNot(r[0].text));
    expect(r[2].text, contains('اعسار'));
    expect(a.unresolved, isEmpty);
  });

  test('مدتِ نپرداختن حقوق را سابقهٔ کار حساب نمی‌کند؛ «نمی‌دانم … یا نه» را می‌فهمد', () {
    final a = fresh();
    talk(a, ['سه ماهه حقوقمو ندادن']);
    expect(a.file.topic, 'labor');
    expect(a.file.touched('months'), isFalse);
    a.respond('نمیدونم بیمه رد میشه یا نه');
    expect(a.file.get('insured'), '?');
    expect(a.file.touched('months'), isFalse);
  });

  test('پرسش بی‌ربط به حقوق را به متن قانون وصل نمی‌کند', () {
    final a = fresh();
    final r = a.respond('هوا چطوره');
    expect(r.laws, isEmpty);
    expect(r.text, contains('حوزهٔ کار من'));
    final art = a.respond('ماده ۱۰ قانون مدنی چی میگه');
    expect(art.text, contains('قراردادهای خصوصی'));
  });

  test('تشخیص درخواست صریح نوشتن سند', () {
    expect(Advocate.wantsDraft('برام دادخواست بنویس'), isTrue);
    expect(Advocate.wantsDraft('یه متن آماده کن'), isTrue);
    expect(Advocate.wantsDraft('اجرا بهتره یا شکایت کیفری کنم؟'), isFalse);
    expect(Advocate.wantsDraft('صاحبخونه پول پیشمو نمیده'), isFalse);
  });
}
