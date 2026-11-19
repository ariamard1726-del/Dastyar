import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/intent_net.dart';

/// سناریوهای گفتگوی تعاملی برای سنجش تشخیص نیت.
///
/// هر سناریو چند پیام کاربر است؛ پاسخ کامل وکیل (با «ادامه بده»ها) بررسی
/// می‌شود. سناریوهای «سخت» رفتارهایی هستند که از پیش درست کار می‌کنند و
/// شکستشان یعنی رگرسیون. سناریوهای «نرم» هدف‌های تازه‌اند: شکستشان در
/// گزارش دیده می‌شود ولی CI را قرمز نمی‌کند.
///
/// گزارش کامل در `reports/intent_scenarios.md` نوشته می‌شود تا در artifact
/// گردش‌کار «Intent scenarios» دیده شود.
class _Case {
  final String name;
  final List<String> turns;

  /// `null`: بررسی نمی‌شود؛ `''`: باید پرونده‌ای باز نشده باشد؛ وگرنه شناسهٔ موضوع.
  final String? topic;
  final List<String> contains;
  final List<String> notContains;
  final bool hard;

  const _Case(
    this.name,
    this.turns, {
    this.topic,
    this.contains = const [],
    this.notContains = const [],
    this.hard = false,
  });
}

const List<_Case> _cases = [
  // ---- سخت: رفتارهای پایه و رگرسیون
  // ---- گفتگوی گزارش‌شده: هر خط یک باگ مشاهده‌شده است
  _Case('گزارش: کرایه عقب افتاده', ['کرایه ام عقب افتاده'],
      hard: true, topic: 'rent'),
  _Case('گزارش: شکایت دارم نباید متن معرفی را بدهد', ['شکایت دارم'],
      hard: true, notContains: ['معرفی دستیار', 'دانش عمومی']),
  _Case('گزارش: دعوا بی‌موضوع، پاسخ ثابت نیست',
      ['من با کسی دعوا کردم', 'تو نفهمی'],
      hard: true, notContains: ['تحلیل آماده‌ای ندارم و نمی‌خواهم حدسی حرف بزنم.\n\nبه کدام']),
  _Case('سلام', ['سلام'], hard: true, contains: ['سلام']),
  _Case('تشکر', ['ممنون'], hard: true, contains: ['خواهش']),
  _Case('هویت وکیل', ['تو وکیلی؟'],
      hard: true, contains: ['وکیل دادگستری نیستم']),
  _Case('خارج از حوزه', ['هوا چطوره'],
      hard: true, contains: ['حوزهٔ کار من'], notContains: ['گفتید']),
  _Case('توانایی‌های برنامه', ['چه کارهایی می‌توانی انجام بدهی؟'],
      hard: true, topic: '', contains: ['وکیل'], notContains: ['گفتید']),
  _Case('وکیل کجا؟', ['وکیل کجا پیدا کنم؟'],
      hard: true, contains: ['کانون وکلای دادگستری']),
  _Case('مهلت بدون پرونده', ['مهلت شکایت چقدره؟'],
      hard: true, topic: '', contains: ['ابلاغ']),
  _Case('طلب', ['طلب دارم'], hard: true, topic: 'debt'),
  _Case('چک برگشتی', ['چکم برگشت خورده'], hard: true, topic: 'cheque'),
  _Case('ودیعه اجاره', ['صاحبخونه پول پیشمو نمیده'],
      hard: true, topic: 'rent', contains: ['قانون روابط موجر و مستأجر']),
  _Case('هزینه وکیل وسط پرونده', ['طلب دارم', 'هزینه وکیل چقدره؟'],
      hard: true, topic: 'debt', contains: ['کانون وکلای دادگستری']),

  // ---- نرم: هدف‌های تشخیص نیت (گزارش می‌شوند)
  _Case('حقوق معوقه', ['کارفرما دو ماهه حقوقمو نداده'], topic: 'labor'),
  _Case('همسایه و دیوار', ['همسایه دیوار منو خراب کرده'], topic: 'neighbor'),
  _Case('کلاهبرداری اینترنتی', ['از من کلاهبرداری اینترنتی شده'],
      topic: 'cyber'),
  _Case('پول قرض‌داده', ['پولم رو به دوستم قرض دادم پس نمیده'],
      topic: 'debt'),
  _Case('ضامن بانک', ['ضامن شدم حالا بانک سراغم اومده'],
      topic: 'guarantee'),
  _Case('شریک و پول شرکت', ['شریکم پول شرکت را برداشته'], topic: 'partner'),
  _Case('ارث پدر', ['پدرم فوت کرد و می‌خواهم سهم الارثم را بگیرم'],
      topic: 'inherit'),
  _Case('اجارهٔ بدون قرارداد', ['اجاره‌نامه رو امضا نکرده‌ایم ولی ملک را گرفتم'],
      topic: 'rent'),
  _Case('مهریه', ['شوهرم مهریه‌ام را نمیده'], topic: 'family'),
  _Case('تصادف و خسارت', ['ماشینم رو یه نفر زد و فرار کرد'],
      topic: 'injury'),
  _Case('احضاریه', ['احضاریه برام اومده، چیکار کنم؟'],
      notContains: ['گفتید']),
  _Case('تهدید', ['یکی تهدیدم کرده که اذیتم کنه'], notContains: ['گفتید']),
  _Case('پرسش بدون موضوع', ['یه سؤال حقوقی دارم'], notContains: ['گفتید']),
  _Case('شکایت از کارفرما بعد از اخراج',
      ['بدون دلیل اخراج شدم', 'بیمه‌ام هم ندادن'], topic: 'labor'),
  // ---- دستهٔ دوم (نرم): گفتار عامیانه، چند موضوعی، خداحافظی و خارج از حوزه
  _Case('اخراج بدون حکم', ['از کارم بدون حکم اخراجم کردن'], topic: 'labor'),
  _Case('حقوق سه ماه معوق', ['حقوقم سه ماهه پرداخت نشده'], topic: 'labor'),
  _Case('طلاق', ['می‌خوام طلاق بگیرم'], topic: 'family'),
  _Case('طلاق با همسر در خانه', ['طلاق می‌خوام', 'شوهرم خونه رو ترک کرده'],
      topic: 'family'),
  _Case('حضانت بچه', ['بچه‌ام رو همسرم برده و نمیده'], topic: 'child'),
  _Case('چک داده و نمی‌تواند پرداخت کند', ['چک دادم و نمی‌تونم پرداخت کنم'],
      topic: 'cheque'),
  _Case('طلبکار بدهکار ول نمی‌کند', ['طلبکارم و بدهکار پولمو نمیده'],
      topic: 'debt'),
  _Case('تصرف ملک', ['خونه‌ام رو یکی تصرف کرده'], topic: 'property'),
  _Case('جنس معیوب', ['جنس خریدم خراب بود، فروشگاه پس نمی‌ده'],
      topic: 'consumer'),
  _Case('ورشکستگی شرکت', ['شرکتمون ورشکسته شد'], topic: 'company'),
  _Case('جریمه راهنمایی', ['جریمه راهنمایی و رانندگی گرفتم، می‌خوام اعتراض کنم'],
      topic: 'admin'),
  _Case('انتشار عکس خصوصی', ['عکس‌هایم را تو اینستاگرام پخش کردن'],
      topic: 'cyber'),
  _Case('اتهام کیفری', ['به من اتهام زده‌اند'], topic: 'accused'),
  _Case('اجرائیه', ['اجرای احکام برام اجرائیه فرستاده'], topic: 'enforce'),
  _Case('وصیت‌نامه', ['پدرم وصیت‌نامه گذاشته و برادرم قبول نمی‌کنه'],
      topic: 'inherit'),
  _Case('دیوار همسایه', ['همسایه پنجره‌اش رو به حیاط من باز کرده'],
      topic: 'neighbor'),
  _Case('شریک سهمش را نمی‌دهد', ['با دوستم شرکت زدیم، سهمش رو نمی‌ده'],
      topic: 'partner'),
  _Case('ضمانت‌نامه', ['یه ضمانت‌نامه دادم و حالا بانک زنگ می‌زنه'],
      topic: 'guarantee'),
  _Case('مهریه و اخراج', ['از کارم اخراج شدم و مهریه‌ام رو هم نمی‌دن'],
      notContains: ['گفتید']),
  _Case('خانه فروخته شده', ['مالک خونه رو فروخته و باید برم'],
      notContains: ['گفتید']),
  _Case('خداحافظی', ['خداحافظ'], contains: ['خدانگهدار']),
  _Case('حال پرسیدن', ['خوبی؟'], contains: ['ممنون که می‌پرسید']),
  _Case('تشکر دوم', ['ممنونم، خیلی کمک کردی'], contains: ['خواهش']),
  _Case('خارج از حوزه: آشپزی', ['طرز پخت قورمه سبزی چیه؟'],
      contains: ['حوزهٔ کار من']),
  _Case('خارج از حوزه: ورزش', ['نتیجه بازی فوتبال امشب کی برده؟'],
      contains: ['حوزهٔ کار من']),
  _Case('فحش و توهین', ['یکی بهم فحش داد تو خیابون'],
      notContains: ['گفتید']),
  _Case('دزدی ماشین', ['ماشینم رو دزدیدن'], notContains: ['گفتید']),
  _Case('باج‌خواهی آنلاین', ['یه نفر ازم پول می‌خواد که عکسام رو پخش نکنه'],
      notContains: ['گفتید']),
  _Case('تغییر موضوع وسط گفتگو',
      ['صاحبخونه پول پیشمو نمیده', 'راستی یه چک هم برگشت خورده'],
      hard: true, topic: 'cheque'),
];

/// مجموعهٔ نگه‌داشته: این جمله‌ها پیش از اجرا دیده نشده‌اند و هیچ نشانه‌ای
/// بر اساس آن‌ها تنظیم نشده است. نتیجه فقط گزارش می‌شود و CI را قرمز
/// نمی‌کند؛ اگر بعداً برای رفع شکست‌هایش چیزی تنظیم شود، دیگر «نگه‌داشته»
/// نیست و باید به مجموعهٔ اصلی منتقل شود.
const List<_Case> _holdout = [
  _Case('h: اضافه‌کاری', ['کارفرمام پول اضافه کاری منو نداده'], topic: 'labor'),
  _Case('h: جدایی', ['میخوام از شوهرم جدا شم'], topic: 'family'),
  _Case('h: چک برگشتی', ['چکی که بهم دادن برگشت خورد'], topic: 'cheque'),
  _Case('h: برداشت از حساب', ['یکی پولمو از حسابم برداشته'], topic: 'cyber'),
  _Case('h: مهریه', ['همسرم مهریه‌ام را نمی‌دهد'], topic: 'family'),
  _Case('h: تخلیه', ['صاحبخونه قرارداد رو تموم کرده و میخواد منو بیرون کنه'],
      topic: 'rent'),
  _Case('h: ارث بعد از فوت', ['بعد از فوت مادرم سر ارث دعوا شده'],
      topic: 'inherit'),
  _Case('h: پول خوردن دوست', ['دوستم پول منو خورده'], topic: 'debt'),
  _Case('h: کالای تقلبی', ['در مغازه کالای تقلبی بهم فروختن'],
      topic: 'consumer'),
  _Case('h: زمین به نام برادر', ['برادرم زمینمو به اسم خودش زده'],
      topic: 'property'),
  _Case('h: متهم شدن', ['من متهم به کلاهبرداری شدم و احضار شدم'],
      topic: 'accused'),
  _Case('h: حادثهٔ کاری بیمه‌نشده', ['کارفرما بیمه نکرده و حادثه کاری داشتم'],
      topic: 'injury'),
  _Case('h: بردن بچه', ['خانمم می‌خواد بچه رو ببره'], topic: 'child'),
  _Case('h: پول پیش بیش از قرارداد', ['مالک آپارتمان ازم پول پیش بیشتر از قرارداد خواسته'],
      topic: 'rent'),
  _Case('h: صبح بخیر', ['صبح بخیر'], contains: ['سلام']),
  _Case('h: ساعت', ['ساعت چنده؟'], contains: ['حوزهٔ کار من']),
  _Case('h: تاریخ امروز', ['تاریخ امروز چنده'], contains: ['حوزهٔ کار من']),
];

/// مجموعهٔ نگه‌داشتهٔ دوم: جمله‌ها پیش از دیدن نتیجه نوشته شده‌اند و
/// هیچ نشانه‌ای بر اساس آن‌ها تنظیم نشده است. فقط گزارش می‌شود.
const List<_Case> _holdout2 = [
  _Case('h2: حقوق معوق کارگاه', ['کارگاه حقوقم رو سه ماه نداده'], topic: 'labor'),
  _Case('h2: توقیف حقوق', ['بانک بخاطر بدهی وامم حقوقم رو توقیف کرده'],
      topic: 'enforce'),
  _Case('h2: بچه و مدرسه', ['بچه‌ام مدرسه نمیره و پدرش نمیذاره ببرمش'],
      topic: 'child'),
  _Case('h2: ماشین معیوب', ['ماشینی که خریدم بعد یک هفته خراب شد و فروشنده قبول نمیکنه'],
      topic: 'consumer'),
  _Case('h2: قفل کردن خانه', ['کلید خونه رو عوض کرده و وسایلمو ریخته بیرون'],
      topic: 'rent'),
  _Case('h2: مادرشوهر', ['مادرشوهرم دعوا راه انداخته و نمیذاره با همسرم زندگی کنم'],
      topic: 'family'),
  _Case('h2: همسایه و سروصدا', ['همسایه طبقه بالا هر شب سروصدا میکنه'],
      topic: 'neighbor'),
  _Case('h2: خانه پدری', ['یکی از برادرام بدون اجازه خونهٔ پدری رو فروخته'],
      topic: 'inherit'),
  _Case('h2: کفالت', ['کفیل شدم و حالا طلبکار زنگ میزنه بیا پول بده'],
      topic: 'guarantee'),
  _Case('h2: تاریخ', ['امروز چندم ماهه؟'], contains: ['حوزهٔ کار من']),
  _Case('h2: احوال‌پرسی', ['سلام، خوبی؟'], contains: ['سلام']),
];

/// مجموعهٔ نگه‌داشتهٔ سوم: پیش از هر تغییر نوشته شد و هیچ‌وقت برای تنظیم
/// نشانه‌ها یا نگاشت‌ها استفاده نمی‌شود. فقط گزارش می‌شود.
const List<_Case> _holdout3 = [
  _Case('h3: حقوق نداده و اخراج', ['کارفرمام دو ماهه حقوق نداده و اخراجم کرده'],
      topic: 'labor'),
  _Case('h3: برداشت با پیامک جعلی', ['مبلغی از کارتم با یک پیامک جعلی برداشت شد'],
      topic: 'cyber'),
  _Case('h3: چک پاس نشده', ['چکی که صادر کردم پاس نشد و اجرای ثبت دنبالمه'],
      topic: 'cheque'),
  _Case('h3: قطع برق و آب', ['صاحب خونه‌ای که اجاره کردم آب و برق رو قطع کرده'],
      topic: 'rent'),
  _Case('h3: کتک و طلاق', ['همسرم منو کتک میزنه و میخوام طلاق بگیرم'],
      topic: 'family'),
  _Case('h3: ارث بدون وصیت', ['پدرم بدون وصیت مرده و برادرم سهم منو نمیده'],
      topic: 'inherit'),
  _Case('h3: درخت همسایه', ['همسایه‌ام درخت حیاط منو بریده'], topic: 'neighbor'),
  _Case('h3: جنس خراب', ['از فروشگاه جنس خراب خریدم و پس نمیدن'],
      topic: 'consumer'),
  _Case('h3: سلام', ['سلام، روز خوبی داشته باشی'], contains: ['سلام']),
];

/// مجموعهٔ نگه‌داشتهٔ چهارم: پیش از تغییر ترتیب نظر دوم نوشته شد و فقط برای
/// سنجش است. بعد از این، مجموعه‌های ۲ و ۳ دیگر «تازه» نیستند.
const List<_Case> _holdout4 = [
  _Case('h4: حق سنوات بعد از اخراج', ['بعد از اخراج از کار حق سنواتم را نمیدن'],
      topic: 'labor'),
  _Case('h4: هک کارت', ['کارت بانکی‌ام را هک کردند و پولم رفت'], topic: 'cyber'),
  _Case('h4: بیعانه و معامله بهم خورده', ['خریدار ملکم بیعانه داده و معامله را بهم زده'],
      topic: 'property'),
  _Case('h4: افزایش اجاره', ['موجر اجاره‌ام را دو برابر کرده'], topic: 'rent'),
  _Case('h4: بردن بچه از کشور', ['زنم بدون اجازه از کشور خارج شده و بچه را برده'],
      topic: 'child'),
  _Case('h4: سهم ارث عمو', ['بعد از فوت پدرم عمویم مغازه را فروخته و سهم منو نداده'],
      topic: 'inherit'),
  _Case('h4: فروش خانه توسط بانک', ['وام گرفتم و حالا بانک میخواد خونه‌ام را بفروشد'],
      topic: 'enforce'),
  _Case('h4: تصادف و فرار', ['تصادف کردم و طرف مقابل فرار کرده'], topic: 'injury'),
  _Case('h4: خداحافظی', ['ممنون، خداحافظ'], contains: ['خدانگهدار']),
];

/// مجموعهٔ نگه‌داشتهٔ پنجم: پیش از هر تغییر در ترتیب تصمیم نوشته شد و
/// فقط برای سنجش آن تغییر است؛ بعد از این، همهٔ مجموعه‌ها برای تنظیم دیده شده‌اند.
const List<_Case> _holdout5 = [
  _Case('h5: سنگ به شیشه', ['بعد از دعوا با همسایه‌ام سنگ زد به شیشه ماشینم'],
      topic: 'neighbor'),
  _Case('h5: عکس جعلی از اینستاگرام', ['یکی از اینستاگرام عکسامو برداشته و جعلی درست کرده'],
      topic: 'cyber'),
  _Case('h5: اجرائیه و توقیف', ['دادگاه بهم اجرائیه داده و اموالم داره توقیف میشه'],
      topic: 'enforce'),
  _Case('h5: شوهر و نفقه', ['شوهرم رفته و طلاق نمیده و نفقه هم نمیده'], topic: 'family'),
  _Case('h5: اخراج و حقوق آخر ماه', ['اخراجم کردن و هنوز حقوق آخر ماهمو ندادن'],
      topic: 'labor'),
  _Case('h5: بعد از زایمان', ['بعد از زایمان کارفرما منو بیرون کرد'], topic: 'labor'),
  _Case('h5: قفل کردن کرایه‌خونه', ['کرایه‌خونه‌ام رو صاحبخونه قفل کرده'], topic: 'rent'),
  _Case('h5: تشکر', ['ممنون از کمکت، روزت خوش'], contains: ['خواهش']),
];

/// پاسخ کامل: همهٔ «ادامه بده»ها کنار هم.
AdvocateReply _full(Advocate a, String t) {
  final r = a.respond(t);
  final sb = StringBuffer(r.text);
  var guard = 0;
  while (a.hasMore && guard < 8) {
    guard++;
    sb.write('\n${a.respond(Advocate.moreChip).text}');
  }
  return AdvocateReply(sb.toString(), chips: r.chips, laws: r.laws);
}

String _short(String s, [int n = 260]) {
  final one = s.replaceAll('\n', ' ⏎ ');
  return one.length <= n ? one : '${one.substring(0, n)}…';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh({IntentNet? net}) => Advocate(engine,
      intentNet: net,
      draftTitles: const {
        'demand_money': 'دادخواست مطالبه وجه',
        'defense_brief': 'لایحه دفاعیه',
      });

  /// IntentNet واقعی اپ از همان فایل مدل؛ برای سنجش مسیر «نظر دوم».
  IntentNet loadNet() => IntentNet.fromJson(jsonDecode(
          File('assets/brain/intent_model.json').readAsStringSync())
      as Map<String, dynamic>);

  test('سناریوهای گفتگو', () {
    final rows = <String>[];
    final details = <String>[];
    final hardFails = <String>[];
    var passed = 0;

    for (final c in _cases) {
      final a = fresh();
      final transcript = <String>[];
      var last = '';
      for (final t in c.turns) {
        final r = _full(a, t);
        last = r.text;
        transcript.add('- **کاربر:** $t');
        transcript.add('- **وکیل:** ${_short(r.text)}');
      }
      final reasons = <String>[];
      if (c.topic != null && a.file.topic != c.topic) {
        reasons.add('موضوع «${a.file.topic}» به‌جای «${c.topic}»');
      }
      for (final s in c.contains) {
        if (!last.contains(s)) reasons.add('پاسخ شامل «$s» نیست');
      }
      for (final s in c.notContains) {
        if (last.contains(s)) reasons.add('پاسخ نباید «$s» داشته باشد');
      }
      final ok = reasons.isEmpty;
      if (ok) passed++;
      rows.add('| ${c.name} | ${c.hard ? 'سخت' : 'نرم'} | '
          '${ok ? 'درست' : 'نادرست'} | ${a.file.topic.isEmpty ? '—' : a.file.topic} | '
          '${reasons.isEmpty ? '' : reasons.join('؛')} |');
      details.add('### ${c.name} (${ok ? 'درست' : 'نادرست'})');
      details.addAll(transcript);
      details.add('');
      if (!ok && c.hard) {
        hardFails.add('${c.name}: ${reasons.join('؛')}');
      }
    }

    // ---- بررسی QA: هر پرسش بانک که به پاسخ QA می‌رسد باید همان پاسخ را
    // با استناد و دکمه‌های هم‌موضوع بدهد.
    final qaRouted = <String>[];
    final qaNotRouted = <String>[];
    final qaProblems = <String>[];
    for (final it in engine.qa.items) {
      final a = fresh();
      final r = a.respond(it.question);
      final head = it.answer.length > 30 ? it.answer.substring(0, 30) : it.answer;
      if (r.text.contains(head)) {
        qaRouted.add(it.id);
        if (!r.text.contains('مستند:')) {
          qaProblems.add('${it.id}: استناد «مستند» ندارد');
        }
        if (r.chips.isEmpty) {
          qaProblems.add('${it.id}: دکمه‌های هم‌موضوع ندارد');
        }
      } else {
        qaNotRouted.add('${it.id} (${a.file.topic.isEmpty ? 'بدون موضوع' : a.file.topic})');
      }
    }

    final report = StringBuffer()
      ..writeln('# گزارش سناریوهای تشخیص نیت')
      ..writeln()
      ..writeln('نتیجه: ${passed.toString()} از ${_cases.length} سناریو درست است.')
      ..writeln()
      ..writeln('| سناریو | نوع | نتیجه | موضوع | دلیل |')
      ..writeln('|---|---|---|---|---|')
      ..writeln(rows.join('\n'))
      ..writeln()
      ..writeln('## بررسی پاسخ QA')
      ..writeln()
      ..writeln('- پرسش‌های بانک: ${engine.qa.items.length}')
      ..writeln('- رسیده به پاسخ QA: ${qaRouted.length}')
      ..writeln('- رسیده به موضوع یا جای دیگر: ${qaNotRouted.length}')
      ..writeln('- مشکلات پاسخ QA: ${qaProblems.isEmpty ? 'ندارد' : qaProblems.join('؛ ')}')
      ..writeln()
      ..writeln('شناسه‌های رسیده به QA: ${qaRouted.join('، ')}')
      ..writeln()
      ..writeln('## گفتگوها')
      ..writeln()
      ..writeln(details.join('\n'));
    Directory('reports').createSync(recursive: true);
    File('reports/intent_scenarios.md').writeAsStringSync(report.toString());

    // هشدارهای GitHub Actions: نتیجهٔ سناریوهای نرمِ شکست‌خورده را هم قابل
    // دیدن می‌کند (از طریق annotations) بی‌آنکه CI را قرمز کند.
    final softFails = rows.where((r) => r.contains('| نرم | نادرست |')).toList();
    debugPrint('::notice title=intent::${passed.toString()} از ${_cases.length} سناریو درست است');
    for (final r in softFails.take(9)) {
      debugPrint('::warning title=intent-soft::${r.replaceAll('|', ' ').replaceAll('\n', ' ')}');
    }

    expect(hardFails, isEmpty, reason: hardFails.join('\n'));
  });

  test('مجموعه‌های نگه‌داشته: سنجش تعمیم (بدون شکست CI)', () {
    String runSet(List<_Case> set, {bool withNet = false}) {
      final net = withNet ? loadNet() : null;
      final rows = <String>[];
      var ok = 0;
      for (final c in set) {
        final a = fresh(net: net);
        var last = '';
        for (final t in c.turns) {
          last = _full(a, t).text;
        }
        final reasons = <String>[];
        if (c.topic != null && a.file.topic != c.topic) {
          reasons.add('موضوع «${a.file.topic}» به‌جای «${c.topic}»');
        }
        for (final s in c.contains) {
          if (!last.contains(s)) reasons.add('پاسخ شامل «$s» نیست');
        }
        final pass = reasons.isEmpty;
        if (pass) ok++;
        final head = last.replaceAll('|', ' ').replaceAll('\n', ' ');
        final hint = net == null
            ? '—'
            : () {
                final top = net.classify(c.turns.first);
                return '${top.label}:${top.score.toStringAsFixed(2)}';
              }();
        rows.add('| ${c.name} | ${pass ? 'درست' : 'نادرست'} | '
            '${a.file.topic.isEmpty ? '—' : a.file.topic} | ${reasons.join('؛')} | '
            '$hint | ${head.length > 70 ? head.substring(0, 70) : head} |');
      }
      return '**نتیجه: $ok از ${set.length} درست.**\n\n'
          '| جمله | نتیجه | موضوع | دلیل | نظر دوم | ابتدای پاسخ |\n|---|---|---|---|---|---|\n${rows.join('\n')}\n';
    }

    final report = StringBuffer()
      ..writeln('# مجموعه‌های نگه‌داشته: سنجش تعمیم تشخیص نیت')
      ..writeln()
      ..writeln('## مجموعهٔ اول (۱۷ جمله)')
      ..writeln('این مجموعه پس از اولین اندازه‌گیری، برای رفع شکست‌ها تنظیم شد؛ '
          'دیگر نگه‌داشته نیست و فقط برای پیگیری نگه داشته شده است.')
      ..writeln()
      ..writeln('### بدون IntentNet')
      ..writeln(runSet(_holdout))
      ..writeln('## مجموعهٔ دوم (تازه، پیش از دیدن نتیجه نوشته شده)')
      ..writeln()
      ..writeln(runSet(_holdout2))
      ..writeln('### با IntentNet (همان مسیر اپ)')
      ..writeln(runSet(_holdout2, withNet: true))
      ..writeln()
      ..writeln('## مجموعهٔ سوم (تازه، هرگز برای تنظیم استفاده نشده)')
      ..writeln()
      ..writeln(runSet(_holdout3))
      ..writeln('### با IntentNet (همان مسیر اپ)')
      ..writeln(runSet(_holdout3, withNet: true))
      ..writeln()
      ..writeln('## مجموعهٔ چهارم (تازه؛ پیش از تغییر ترتیب نظر دوم نوشته شد)')
      ..writeln()
      ..writeln('### بدون IntentNet')
      ..writeln(runSet(_holdout4))
      ..writeln('### با IntentNet (همان مسیر اپ)')
      ..writeln(runSet(_holdout4, withNet: true))
      ..writeln()
      ..writeln('## مجموعهٔ پنجم (تازه؛ پیش از تغییر تصمیم واحد نوشته شد)')
      ..writeln()
      ..writeln('### بدون IntentNet')
      ..writeln(runSet(_holdout5))
      ..writeln('### با IntentNet (همان مسیر اپ)')
      ..writeln(runSet(_holdout5, withNet: true));
    Directory('reports').createSync(recursive: true);
    File('reports/intent_holdout.md').writeAsStringSync(report.toString());
    debugPrint('::notice title=intent-holdout::مجموعهٔ دوم: '
        '${RegExp(r'نتیجه: (\d+) از (\d+)').firstMatch(report.toString())?.group(0) ?? ''}');
  });

  test('پرسش بانک QA به پاسخ و استناد و دکمه‌های مرتبط می‌رسد', () {
    // گرفتن یک پرسش که واقعاً به مسیر QA می‌رسد. اگر هیچ‌کدام نرسد، یعنی
    // مسیر QA در عمل بی‌استفاده است و باید دیده شود.
    final routed = <QaItemRoute>[];
    for (final it in engine.qa.items) {
      final a = fresh();
      final r = a.respond(it.question);
      final head = it.answer.length > 30 ? it.answer.substring(0, 30) : it.answer;
      if (r.text.contains(head)) {
        routed.add(QaItemRoute(it.id, r));
      }
    }
    expect(routed, isNotEmpty,
        reason: 'هیچ پرسش بانک به مسیر QA نمی‌رسد؛ مسیر QA بی‌استفاده است.');
    for (final x in routed) {
      expect(x.reply.text, contains('مستند:'), reason: x.id);
      expect(x.reply.chips, isNotEmpty, reason: x.id);
    }
  });
}

class QaItemRoute {
  final String id;
  final AdvocateReply reply;
  QaItemRoute(this.id, this.reply);
}
