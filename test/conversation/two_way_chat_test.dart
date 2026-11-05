import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/llm.dart';
import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/domain/dialogue/conversation_router.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/chat_controller.dart';

List<LegalTemplate> _loadTemplatesSync() {
  final out = <LegalTemplate>[];
  for (final f in Directory('assets/templates').listSync()) {
    if (f is File && f.path.endsWith('.json')) {
      final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      out.add(LegalTemplate.fromJson(m));
    }
  }
  out.sort((a, b) => a.id.compareTo(b.id));
  return out;
}

/// گفتگوی دوسویهٔ کاربر و برنامه.
///
/// این مجموعه رفتار «چت حقوقی» را قفل می‌کند: پرسش کاربر باید پاسخ بگیرد،
/// نه اینکه به کارت انتخاب موضوع، پیشنهاد تنظیم سند یا سؤال بعدی مصاحبه
/// تبدیل شود. شکست این تست‌ها یعنی برنامه دوباره «به چیزهای دیگر اشاره
/// می‌کند» و پاسخ منطقی نمی‌دهد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  late TemplateRepository repo;
  late IntentNet net;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
    repo = TemplateRepository()..templates.addAll(_loadTemplatesSync());
    net = IntentNet.fromJson(
      jsonDecode(
        File('assets/brain/intent_model.json').readAsStringSync(),
      ) as Map<String, dynamic>,
    );
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  ChatController makeCtrl() {
    final assistant = Assistant(engine);
    expect(assistant.llm, isA<NoLlm>());
    return ChatController(
      engine: engine,
      assistant: assistant,
      repo: repo,
      history: HistoryStore(),
      settings: AppSettings()
        ..saveHistory = false
        ..saveDraftProgress = false,
      intentNet: net,
      random: Random(11),
    );
  }

  group('۰. تشخیص شکل پیام', () {
    test('پرسش اطلاعاتی از شرح پروندهٔ شخصی جدا می‌شود', () {
      expect(ConversationRouter.isInformationalQuestion('اجاره چیست؟'), isTrue);
      expect(
          ConversationRouter.isInformationalQuestion(
              'مهلت واخواهی چقدر است؟'),
          isTrue);
      expect(
          ConversationRouter.isInformationalQuestion(
              'چک برگشتی دارم چه کار کنم؟'),
          isFalse,
          reason: 'این شرح پروندهٔ شخصی است و مشاوره برای آن ساخته شده');
      expect(
          ConversationRouter.isInformationalQuestion('کارفرما اخراجم کرده'),
          isFalse,
          reason: 'جملهٔ خبری، پرسش نیست');
      expect(ConversationRouter.hasLegalTerm('چک برگشتی'), isTrue);
      expect(ConversationRouter.hasLegalTerm('قرارداد اجاره'), isTrue);
      expect(ConversationRouter.hasLegalTerm('سلام، خوبی؟'), isFalse);
    });
  });

  group('۱. پرسش حقوقی اول پاسخ می‌گیرد', () {
    test('«اجاره چیست؟» با متن ماده پاسخ می‌گیرد و وارد مصاحبه نمی‌شود',
        () async {
      final ctrl = makeCtrl();
      await ctrl.submit('اجاره چیست؟');
      final t = ctrl.messages.last.text;
      expect(ctrl.isCounseling, isFalse,
          reason: 'پرسش اطلاعاتی نباید به مصاحبه تبدیل شود');
      expect(t, isNot(contains('پیدا نکردم')));
      expect(t, isNot(contains('کدام دسته')));
      expect(t, contains('ماده'),
          reason: 'پاسخ باید مستند به متن ماده باشد، نه سؤال بعدی ربات');
      ctrl.dispose();
    });

    test('پرسش دربارهٔ مهلت قانونی، پاسخ مستند می‌گیرد نه کارت موضوع', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('مهلت واخواهی چقدر است؟');
      final t = ctrl.messages.last.text;
      expect(ctrl.isCounseling, isFalse);
      expect(t, isNot(contains('کدام دسته')));
      expect(t, isNot(contains('موضوع اصلی را با یک جمله')));
      ctrl.dispose();
    });

    test('پرسش حقوقی، پیشنهاد تنظیم سند را جایگزین پاسخ نمی‌کند', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('برای وصول چک برگشتی چه مدرکی لازم است؟');
      expect(ctrl.isDrafting, isFalse,
          reason: 'پیشنهاد «متنش را بسازم؟» نباید جای پاسخ را بگیرد');
      expect(ctrl.messages.last.text, isNot(contains('تنظیم کنم')));
      expect(ctrl.messages.last.text, isNot(contains('کدام دسته')));
      ctrl.dispose();
    });

    test('شرح پروندهٔ شخصی همچنان مسیر مشاورهٔ گام‌به‌گام را می‌رود', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('چک دادم بابت ضمانت الان برگشت زده و می‌خواهم بدانم چه کار کنم');
      expect(ctrl.isCounseling, isTrue,
          reason: 'مرز «پرسش اطلاعاتی» و «پروندهٔ شخصی» نباید جابه‌جا شود');
      ctrl.dispose();
    });
  });

  group('۲. گفتگو بن‌بست نمی‌شود', () {
    test('پرسش بیرون از بانک قوانین، پاسخ محاوره‌ای و پیشنهاد نزدیک‌ترین مواد می‌گیرد',
        () async {
      final ctrl = makeCtrl();
      await ctrl.submit('قانون استفاده از پهپاد کشاورزی در ایران چیست؟');
      final t = ctrl.messages.last.text;
      expect(t, isNot(contains('برویم سراغ ادامهٔ بررسی وضعیت')),
          reason: 'پاسخ نباید کاربر را به «ادامهٔ مشاوره» ارجاع دهد');
      expect(t, isNot(contains('کدام دسته')));
      // اگر موتور چیزی یافت، همان ماده است؛ وگرنه پاسخ محاوره‌ای با
      // نزدیک‌ترین مواد یا درخواست روشن‌سازی.
      expect(
        t.contains('ماده') || t.contains('نزدیک‌ترین') || t.contains('یک جمله'),
        isTrue,
        reason: 'در هر حالت باید مسیر ادامهٔ گفتگو روشن باشد',
      );
      ctrl.dispose();
    });

    test('در پذیرش عمومی، پاسخ RAG با درخواست انتخاب موضوع قطع نمی‌شود',
        () async {
      final ctrl = makeCtrl();
      await ctrl.submit('مشاوره');
      expect(ctrl.isCounseling, isTrue);
      await ctrl.submit('قانون چک چه می‌گوید؟');
      final t = ctrl.messages.last.text;
      expect(t, contains('چک'));
      expect(t, isNot(contains('کدام دسته')));
      expect(t, isNot(contains('موضوع اصلی را با یک جمله')));
      expect(ctrl.isCounseling, isTrue, reason: 'جلسه نباید بشکند');
      ctrl.dispose();
    });

    test('میان مصاحبه، پرسش کوتاه تعریفی هم از بانک قوانین پاسخ می‌گیرد', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('مستأجرم مدت قراردادش تمام شده ولی خانه را تخلیه نمی‌کند');
      expect(ctrl.isCounseling, isTrue);
      await ctrl.submit('سرقفلی چیست؟');
      final t = ctrl.messages.last.text;
      expect(t, isNot(contains('متوجه شدم. برای اینکه دقیق‌تر راهنمایی کنم')),
          reason: 'پرسش تعریفی نباید به «گیر کردن» تعبیر شود');
      expect(
        t.contains('ماده') || t.contains('نزدیک‌ترین'),
        isTrue,
        reason: 'باید پاسخ مستند یا پیشنهاد نزدیک‌ترین مواد بیاید',
      );
      ctrl.dispose();
    });
  });

  group('۳. لحن شروع گفتگو', () {
    test('پذیرش عمومی، کاربر را به پرسیدن سؤال دعوت می‌کند', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('مشاوره');
      final t = ctrl.messages.last.text;
      expect(t, contains('سؤال'));
      expect(t, contains('با کمال میل همراه شما هستم'));
      expect(ctrl.isCounseling, isTrue);
      ctrl.dispose();
    });
  });
}
