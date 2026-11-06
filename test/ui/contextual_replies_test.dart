import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/domain/lawyer/lawyer_voice.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/chat_controller.dart';
import 'package:dastyar/ui/chat_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;
  late TemplateRepository repo;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    engine = KnowledgeEngine();
    await engine.load();
    repo = TemplateRepository();
    await repo.load();
  });

  ChatController make() => ChatController(
        engine: engine,
        assistant: Assistant(engine),
        repo: repo,
        history: HistoryStore(),
        settings: AppSettings()
          ..saveHistory = false
          ..saveDraftProgress = false,
        random: Random(1),
        phraseSeed: 1,
      );

  Future<ChatMessage> say(ChatController c, String t) async {
    await c.submit(t);
    return c.messages.lastWhere((m) => !m.fromUser);
  }

  test('پیام مبهم: پرسش روشن‌کننده به‌جای «پیدا نکردم»', () async {
    final c = make();
    for (final t in ['یه سوال حقوقی داشتم', 'حقوق من چیه؟']) {
      final m = await say(c, t);
      expect(m.text, contains('مدرک'), reason: t);
      expect(m.text, isNot(contains('پیدا نکردم')), reason: t);
      expect(m.chips, LawyerVoice.notFoundChips);
    }
  });

  test('جزئیات گفته‌شده تکرار می‌شود و دوباره پرسیده نمی‌شود', () async {
    final c = make();
    final m = await say(c,
        'صاحبخانه ام ۲۰۰ میلیون ودیعه منو پس نمیده و قراردادم دو ماه پیش تموم شده');
    expect(m.text, contains('۲۰۰ میلیون'));
    expect(m.text, contains('مدت قرارداد تمام شده'));
    expect(m.text, isNot(contains('مدت قرارداد اجاره تمام شده یا هنوز ادامه دارد')));
  });

  test('ادامهٔ راهنما با مدرک تازه، پاسخ متناسب می‌گیرد', () async {
    final c = make();
    await say(c, 'همسایه بالایی لوله‌اش ترکیده و سقف خونه ما نم زده');
    final m = await say(c, 'از سقف عکس و فیلم دارم، مدیر ساختمان هم شاهده');
    expect(m.text, contains('خسارت همسایه'));
    expect(m.text, contains('شاهد'));
    expect(m.text, contains('تأمین دلیل'));
    expect(m.chips, contains('مشاورهٔ حقوقی گام‌به‌گام'));
  });

  test('مسیریابی درست: خرید معیوب، سرقت، مالیات بر ارث، بازداشت نوجوان',
      () async {
    final c = make();
    var m = await say(c, 'ماشین خریدم بعد یه هفته معلوم شد تصادفیه و فروشنده نگفته بود');
    expect(m.text, contains('ماده ۴۲۲'));
    expect(m.text, isNot(contains('بیمهٔ شخص ثالث')));
    m = await say(make(), 'دیروز گوشیمو دزدیدن');
    expect(m.text, contains('۱۱۰'));
    expect(m.text, contains('IMEI'));
    m = await say(make(), 'مالیات بر ارث چقدره؟');
    expect(m.text, isNot(contains('انحصار وراثت')));
    m = await say(make(), 'پسرم ۱۷ سالشه و دعوا کرده، الان بازداشته');
    expect(m.text, contains('نوجوانان'));
  });

  test('نکتهٔ شرطی: تصادف با مقصر بدون بیمه', () async {
    final m = await say(make(), 'تصادف کردم و طرف مقابل مقصر بود ولی بیمه نداره');
    expect(m.text, contains('صندوق تأمین خسارت‌های بدنی'));
  });

  test('پیام چندمسئله‌ای همهٔ موضوع‌ها را نام می‌برد و دکمهٔ موضوع کار می‌کند',
      () async {
    final c = make();
    final m = await say(c,
        'کارفرما سه ماهه حقوقم رو نداده و بیمه هم رد نکرده، الان هم اخراجم کرده');
    expect(m.text, contains('بیش از یک موضوع'));
    final topic = m.chips.firstWhere((x) => x.startsWith(LawyerVoice.topicChipPrefix));
    final n = await say(c, topic);
    expect(n.text, contains('یادداشت کردم'));
    expect(n.text, contains('کارفرما'));
  });

  test('تشکر همراه با ترس و دکمه‌های ادامهٔ پرونده', () async {
    final c = make();
    await say(c, 'یکی تو اینستاگرام عکسامو منتشر کرده و تهدیدم میکنه');
    final m = await say(c, 'مرسی خیلی ترسیدم');
    expect(m.text, contains('خواهش می‌کنم'));
    expect(m.text, contains('ترس'));
    final cont = await say(c, ChatController.continueCaseChip);
    expect(cont.text, contains('برمی‌گردیم'));
    final fresh = await say(c, ChatController.newQuestionChip);
    expect(fresh.chips, LawyerVoice.notFoundChips);
  });

  test('معرفی کلی قانون به‌جای مادهٔ تصادفی', () async {
    final m = await say(make(), 'درباره قانون کار بگو');
    expect(m.text, contains('قانون کار'));
    expect(m.text, contains('ماده'));
    expect(m.chips, isNotEmpty);
    expect(m.chips.first, isNot(startsWith('ماده')));
  });

  test('پرسش‌های وابسته به پرونده با توجه به جزئیات جواب می‌گیرند', () async {
    final c = make();
    await say(c, 'صاحبخونه ودیعه منو پس نمیده');
    await say(c, '۳۰۰ میلیون');
    final where = await say(c, 'کجا باید شکایت کنم؟');
    expect(where.text, contains('دادگاه'));
    expect(where.text, contains('۳۰۰ میلیون تومان'));
    final now = await say(c, 'حالا چیکار کنم؟');
    expect(now.text, contains('۱.'));
    expect(now.text, isNot(contains('پیدا نکردم')));
    final deny = await say(c, 'اگه انکار کنه چی؟');
    expect(deny.text, contains('بار اثبات'));
  });

  test('«بله»/«نه»/«نمی‌دانم» به پرسش پرونده', () async {
    final c = make();
    await say(c, 'صاحبخونه ودیعه منو پس نمیده');
    final q = await say(c, '۳۰۰ میلیون');
    expect(q.text, contains('مدت قرارداد اجاره تمام شده است؟'));
    final yes = await say(c, 'آره');
    expect(yes.text, contains('مدت قرارداد تمام شده'));
    final dk = await say(c, 'نمیدونم');
    expect(dk.text, contains('اشکالی ندارد'));
    expect(dk.text, contains('ارزیابی'));
  });

  test('پس از جمع‌بندی مشاوره، «حق با منه؟» تحلیل را تکرار نمی‌کند', () async {
    final c = make();
    final first = await say(c, 'شوهرم نفقه نمیده');
    final again = await say(c, 'حق با منه؟');
    expect(again.text, isNot(first.text));
    expect(again.text, contains('ارزیابی'));
  });

  test('نفی: «اخراجم نکرده» اخراج ثبت نمی‌شود', () async {
    final c = make();
    final m = await say(c, 'کارفرما دو ماهه حقوقمو نمیده ولی اخراجم نکرده');
    expect(m.text, isNot(contains('اخراج شده‌اید')));
  });
}
