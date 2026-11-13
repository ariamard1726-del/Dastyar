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

  /// پاسخ کامل به یک پیام: وکیل حرفش را کوتاه می‌زند و بقیه را فقط وقتی
  /// می‌گوید که کاربر «ادامه بده» بگوید؛ این‌جا همه را کنار هم می‌گذاریم تا
  /// درستیِ محتوا سنجیده شود.
  AdvocateReply say(Advocate a, String t) {
    final r = a.respond(t);
    final sb = StringBuffer(r.text);
    var guard = 0;
    while (a.hasMore && guard < 8) {
      guard++;
      sb.write('\n${a.respond(Advocate.moreChip).text}');
    }
    return AdvocateReply(sb.toString(), chips: r.chips, laws: r.laws);
  }

  /// گفتگو را اجرا می‌کند و پاسخ‌های کامل را برمی‌گرداند.
  List<AdvocateReply> talk(Advocate a, List<String> turns) =>
      [for (final t in turns) say(a, t)];

  test('هر ماده‌ای که در دانش وکیل نام برده شده واقعاً در بانک قوانین هست', () {
    final ref = RegExp(r'\[\[([a-z_0-9]+):([0-9]+)(m?)\]\]');
    final missing = <String>{};
    var count = 0;
    for (final f in Directory('lib/domain/advocate').listSync()) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in ref.allMatches(f.readAsStringSync())) {
        count++;
        final art =
            '${m[1] == 'constitution' ? 'اصل' : 'ماده'} ${m[2]}${m[3] == 'm' ? ' مکرر' : ''}';
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
    final who = say(a, 'تو وکیلی؟');
    expect(who.text, contains('وکیل دادگستری نیستم'));
    expect(who.laws, isEmpty);
    final trust = say(a, 'میشه به حرفات اعتماد کرد؟');
    expect(trust.text, contains('محدودیت'));
    final term = say(a, 'یعنی چی اعسار؟');
    expect(term.text, contains('اعسار'));
    a.respond('طلب دارم');
    expect(a.file.topic, 'debt');
    final why = say(a, 'چرا اینو میپرسی؟');
    expect(why.text, contains('سؤالم این بود'));
    final sum = say(a, 'خلاصه بگو');
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
    final r = say(a, 'بنفش قورباغه دیروز');
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
    final r = say(a, 'هوا چطوره');
    expect(r.laws, isEmpty);
    expect(r.text, contains('حوزهٔ کار من'));
    final art = say(a, 'ماده ۱۰ قانون مدنی چی میگه');
    expect(art.text, contains('قراردادهای خصوصی'));
  });

  test('نقشهٔ راه را دو بار پشت هم تکرار نمی‌کند', () {
    final a = fresh();
    final r = talk(a, [
      'مستاجرم سه ماهه اجاره نداده و خونه رو هم خالی نمیکنه',
      'آره مدتش تموم شده',
      'اجاره نامه رو بنگاه نوشته، دو تا شاهد داره',
    ]);
    expect(r[0].text, contains('دستور تخلیه'));
    // نقشهٔ راه و استدلال را سرِ خود روی سر کاربر نمی‌ریزد.
    expect('۱)'.allMatches(r[2].text).length, 0);
    expect(r[2].text, isNot(contains('شرط اول')));
    // ولی وقتی خودش بخواهد، شرط‌ها روی واقعیت‌های پرونده سنجیده می‌شود.
    final arg = say(a, 'استدلالت چیه؟');
    expect(arg.text, contains('شرط اول'));
    expect(arg.text, contains('نتیجه'));
    expect(a.unresolved, isEmpty);
  });

  test('احضاریهٔ بی‌عنوان: از ماجرایی که نمی‌داند سؤال نمی‌پرسد', () {
    final a = fresh();
    final r = talk(a, ['برام احضاریه اومده نمیدونم برای چیه']);
    expect(a.file.topic, 'accused');
    expect(r[0].text, contains('ثنا'));
    expect(r[0].text, isNot(contains('قولنامه')));
    expect(r[0].chips, isNot(contains('می‌گوید جنس ایراد داشته')));
    expect(a.unresolved, isEmpty);
  });

  test('استدلال: شرط‌های قانونی روی واقعیت‌های همین پرونده سنجیده می‌شود', () {
    final a = fresh();
    talk(a, [
      'صاحبخونه پول پیشمو نمیده',
      '۱۵۰ میلیون',
      'آره قرارداد تموم شده ولی هنوز خونه رو خالی نکردم',
    ]);
    expect(a.file.no('vacated'), isTrue);
    final weak = say(a, 'استدلالت چیه؟');
    expect(weak.text, contains('شرط اول'));
    expect(weak.text, contains('✓'));
    expect(weak.text, contains('✗'));
    expect(weak.text, contains('برقرار نیست'));
    // همان پرونده، با واقعیتِ عوض‌شده، نتیجهٔ دیگری می‌دهد.
    final b = fresh();
    talk(b, [
      'صاحبخونه پول پیشمو نمیده',
      '۱۵۰ میلیون',
      'آره قرارداد تموم شده، یه ماهه خونه رو خالی کردم',
    ]);
    final strong = say(b, 'استدلالت چیه؟');
    expect(strong.text, contains('شرط اول'));
    expect(strong.text, isNot(contains('✗')));
    expect(strong.text, isNot(weak.text));
    expect(strong.laws, isNotEmpty);
  });

  test('برداشتش از حرف کاربر را بازگو می‌کند («چی فهمیدی؟»)', () {
    final a = fresh();
    final r = say(a, 'مستاجرم سه ماهه اجاره نداده و خونه رو هم خالی نمیکنه');
    // نقشی که از حرف کاربر برداشت کرده همان اول گفته می‌شود تا قابل اصلاح باشد.
    expect(r.text, contains('موجر (صاحب ملک) هستید'));
    final got = say(a, 'چی فهمیدی؟');
    expect(got.text, contains('موجر'));
    expect(got.text, contains('اصلاح'));
    final b = fresh();
    talk(b, [
      'صاحبخونه پول پیشمو نمیده',
      '۱۵۰ میلیون',
      'آره قرارداد تموم شده ولی هنوز خونه رو خالی نکردم',
    ]);
    final all = say(b, 'چی فهمیدی؟').text;
    expect(all, contains('مستأجر هستید'));
    expect(all, contains('مدت اجاره تمام شده'));
    expect(all, contains('ملک هنوز تخلیه نشده'));
    expect(all, contains('۱۵۰ میلیون'));
    final none = fresh().respond('چی فهمیدی؟');
    expect(none.text.trim(), isNotEmpty);
  });

  test('دامنهٔ تازه: هر ده موضوع جدید درست تشخیص داده می‌شود', () {
    const cases = {
      'یه یخچال خریدم خراب در اومد، فروشنده پس نمیگیره': 'consumer',
      'از حسابم بی خبر ۲۰ میلیون برداشت شده، فکر کنم فیشینگ بود': 'cyber',
      'پدرم فوت کرده و برادرم سهم ارث ما رو نمیده': 'inherit',
      'همسایه مون هر شب بچه شو کتک میزنه': 'child',
      'حکم گرفتم ولی طرف پول رو نمیده': 'enforce',
      'یه آپارتمان خریدم ولی فروشنده سند نمیزنه': 'property',
      'سهامدار یه شرکت سهامی هستم و مدیرعامل سود سهام نمیده': 'company',
      'ضامن وام دوستم شدم و حالا قسط نمیده': 'guarantee',
      'بانک وام ازدواج نمیده': 'marriage',
      'سر کار از داربست افتادم و پام شکست': 'injury',
    };
    for (final e in cases.entries) {
      final a = fresh();
      final r = say(a, e.key);
      expect(a.file.topic, e.value, reason: e.key);
      expect(r.laws, isNotEmpty, reason: e.key);
      expect(a.unresolved, isEmpty, reason: e.key);
      final arg = say(a, 'استدلالت چیه؟');
      expect(arg.text.trim(), isNotEmpty, reason: e.key);
      expect(a.unresolved, isEmpty, reason: e.key);
    }
  });

  test('همهٔ ۲۴ قانون بانک در دانش وکیل استناد شده است', () {
    final ref = RegExp(r'\[\[([a-z_0-9]+):[0-9]+m?\]\]');
    final used = <String>{};
    for (final f in Directory('lib/domain/advocate').listSync()) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      for (final m in ref.allMatches(f.readAsStringSync())) {
        used.add(m[1]!);
      }
    }
    const all = {
      'civil', 'cheque', 'financial_sentences', 'commerce', 'commerce_1347',
      'landlord_tenant', 'labor', 'constitution', 'family_protection',
      'civil_liability', 'child_protection', 'marriage', 'consumer_protection',
      'penal', 'penal_taazirat', 'fraud_intensify', 'cybercrime',
      'civil_procedure', 'civil_execution', 'dispute_councils',
      'criminal_procedure', 'registration', 'direct_taxes', 'social_security',
    };
    expect(all.difference(used), isEmpty);
  });

  test('موضوع‌های تازه: واقعیت‌ها را می‌فهمد و نتیجه را با آن‌ها عوض می‌کند', () {
    final a = fresh();
    final r = talk(a, [
      'یه آپارتمان خریدم ولی فروشنده سند نمیزنه',
      'آره قولنامه داریم',
      'همه پول رو دادم',
      'به نام خودشه',
    ]);
    expect(a.file.topic, 'property');
    expect(a.file.get('role'), 'buyer');
    expect(a.file.yes('written'), isTrue);
    expect(a.file.yes('paid'), isTrue);
    expect(a.file.yes('registered'), isTrue);
    expect(r.last.text, isNot(contains('ارزیابی من')));
    final arg = say(a, 'استدلالت چیه؟');
    expect(arg.text, contains('شرط'));
    expect(arg.text, contains('ارزیابی من'));
    final c = fresh();
    talk(c, [
      'سر کار از داربست افتادم و پام شکست',
      'نه هیچی ندادن، کمربند نداشتم',
    ]);
    expect(c.file.get('kind'), 'work');
    expect(c.file.no('safe'), isTrue);
    final e = fresh();
    talk(e, ['حسابمو بستن چون محکوم شدم', 'ندارم بدم، میشه قسطی بدم؟']);
    expect(e.file.topic, 'enforce');
    expect(e.file.get('side'), 'loser');
    expect(e.draftIds, contains('insolvency'));
  });

  test('وسط پرونده با هر اشاره‌ای موضوع را عوض نمی‌کند؛ در حالت مبهم می‌پرسد', () {
    // جوابِ پرسشِ وکیل، هرچند واژه‌اش به موضوع دیگری بخورد، همان پرونده می‌ماند.
    final a = fresh();
    talk(a, ['صاحبخونه پول پیشمو نمیده', 'قولنامه داریم']);
    expect(a.file.topic, 'rent');
    expect(a.file.yes('contract'), isTrue);
    // متهم دارد ماجرای پشتِ شکایت را تعریف می‌کند، نه پروندهٔ تازه.
    final b = fresh();
    talk(b, [
      'ازم شکایت کردن به جرم کلاهبرداری ولی من کاری نکردم',
      'ملک رو بهش فروختم سند نزدم',
    ]);
    expect(b.file.topic, 'accused');
    // اشارهٔ کوتاه به ماجرایی دیگر: نمی‌پرد، می‌پرسد؛ با تأیید کاربر می‌رود.
    final c = fresh();
    c.respond('یه یخچال خریدم خراب در اومد، فروشنده پس نمیگیره');
    final ask = say(c, 'سگ همسایه گازم گرفت');
    expect(c.file.topic, 'consumer');
    expect(ask.chips, contains(Advocate.sideChip));
    expect(ask.text, contains('ماجرای جداگانه'));
    c.respond(Advocate.sideChip);
    expect(c.file.topic, 'injury');
    expect(c.file.get('kind'), 'other');
    // ولی وقتی خودِ کاربر موضوع را عوض می‌کند، بی‌معطلی می‌رود.
    final d = fresh();
    talk(d, [
      'ضامن وام دوستم شدم و حالا قسط نمیده',
      'راستی یکی عکسامو تو تلگرام پخش کرده',
    ]);
    expect(d.file.topic, 'cyber');
    expect(d.file.get('kind'), 'expose');
  });

  group('گفتگوی دوطرفه', () {
    const openers = [
      'صاحبخونه پول پیشمو نمیده',
      'کارفرما اخراجم کرده',
      'چکم برگشت خورده',
      'میخوام از شوهرم جدا بشم ولی مهریه مو میخوام',
      'دوستم ازم پول قرض گرفته پس نمیده',
      'همسایه بالایی نصف شب سروصدا میکنه خسته شدیم',
      'ماشینمو فروختم طرف سند نمیزنه بره به نامش',
    ];

    test('جواب اول کوتاه است، با پرسش تمام می‌شود و به دکمه‌ها حواله نمی‌دهد',
        () {
      for (final o in openers) {
        final a = fresh();
        final r = a.respond(o);
        expect(a.file.topic, isNotEmpty, reason: o);
        expect(r.text.length, lessThan(700), reason: o);
        expect(r.text.trimRight(), endsWith('؟'), reason: o);
        expect(r.text, isNot(contains('گزینه')), reason: o);
        expect(r.text, isNot(contains('دکمه')), reason: o);
        expect(r.text, isNot(contains('متن قانون، برای اینکه')), reason: o);
      }
    });

    test('بقیهٔ حرف فقط وقتی می‌آید که کاربر بخواهد', () {
      final a = fresh();
      final r = a.respond('کارفرما اخراجم کرده');
      if (a.hasMore) {
        expect(r.chips, contains(Advocate.moreChip));
        final m = a.respond(Advocate.moreChip);
        expect(m.text.trim(), isNotEmpty);
        expect(m.text, isNot(r.text));
      }
      expect(a.file.topic, 'labor');
    });

    test('متن ماده را وقتی نشان می‌دهد که کاربر بخواهد', () {
      final a = fresh();
      final r = a.respond('صاحبخونه پول پیشمو نمیده');
      expect(r.laws, isNotEmpty);
      expect(r.text, isNot(contains('«')));
      final law = a.respond(Advocate.lawChip);
      expect(law.text, contains('ماده'));
      expect(law.text, contains('«'));
      expect(a.file.topic, 'rent');
    });

    test('بعد از پرسش‌های پرونده، از برخورد طرف مقابل و خواستهٔ کاربر می‌پرسد',
        () {
      final a = fresh();
      a.respond('دوستم ازم پول قرض گرفته پس نمیده');
      expect(a.file.topic, 'debt');
      var guard = 0;
      while (!a.file.pending.startsWith('q:') && guard < 12) {
        guard++;
        a.respond('نمیدونم');
      }
      expect(a.file.pending, 'q:reply');
      final r = a.respond('میگه امروز و فردا');
      expect(r.text.trimRight(), endsWith('؟'));
      expect(a.file.pending, 'q:goal');
      final g = a.respond('میخوام با توافق تموم بشه');
      expect(g.text.trimRight(), endsWith('؟'));
      expect(a.file.topic, 'debt');
      expect(a.unresolved, isEmpty);
    });

    test('تحلیل و نقشهٔ راه را پیشنهاد می‌کند و با «بله» همان را می‌گوید', () {
      final a = fresh();
      talk(a, [
        'صاحبخونه پول پیشمو نمیده',
        '۱۵۰ میلیون',
        'آره قرارداد تموم شده، یه ماهه خونه رو خالی کردم',
      ]);
      var guard = 0;
      var last = a.respond('نمیدونم');
      while (!last.chips.contains('بله، بگو') && guard < 14) {
        guard++;
        last = a.respond('نمیدونم');
      }
      expect(last.chips, contains('بله، بگو'));
      expect(last.text.trimRight(), endsWith('؟'));
      final yes = say(a, 'بله، بگو');
      expect(yes.text, anyOf(contains('شرط'), contains('۱)')));
      expect(a.file.topic, 'rent');
    });

    test('حرفی که موضوعش را نمی‌شناسد: نمونه‌های بی‌ربط نشان نمی‌دهد و می‌پرسد',
        () {
      final a = fresh();
      final r = a.respond('یه نفر وسایلمو از انباری برده و جواب نمیده');
      expect(r.text.trimRight(), endsWith('؟'));
      for (final c in Advocate.starterChips) {
        expect(r.chips, isNot(contains(c)));
      }
    });

    test('دو پیام کوتاهِ پشت‌سرهم روی‌هم موضوع را روشن می‌کنند', () {
      final a = fresh();
      a.respond('یه گرفتاری با صاحبخونه پیدا کردم');
      expect(a.file.topic, isEmpty);
      a.respond('کرایه رو میخواد ببره بالا');
      expect(a.file.topic, 'rent');
    });
  });

  test('تشخیص درخواست صریح نوشتن سند', () {
    expect(Advocate.wantsDraft('برام دادخواست بنویس'), isTrue);
    expect(Advocate.wantsDraft('یه متن آماده کن'), isTrue);
    expect(Advocate.wantsDraft('اجرا بهتره یا شکایت کیفری کنم؟'), isFalse);
    expect(Advocate.wantsDraft('صاحبخونه پول پیشمو نمیده'), isFalse);
  });
}
