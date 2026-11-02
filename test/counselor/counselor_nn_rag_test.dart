import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/ui/chat_controller.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/domain/intent_net.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/core/llm.dart';
import 'package:dastyar/core/replies.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';

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

  ChatController makeCtrl({
    bool save = false,
    CounselingSession? initialCounsel,
    bool withNet = true,
  }) {
    final assistant = Assistant(engine);
    expect(assistant.llm, isA<NoLlm>());
    return ChatController(
      engine: engine,
      assistant: assistant,
      repo: repo,
      history: HistoryStore(),
      settings: AppSettings()
        ..saveHistory = false
        ..saveDraftProgress = save,
      intentNet: withNet ? net : null,
      random: Random(7),
      initialCounsel: initialCounsel,
    );
  }

  group('۱. مسیریابی با شبکهٔ عصبی (بدون IF/ELSE کلیدواژه‌ای)', () {
    test('نیت‌های مشاوره‌ای شروع گفتگو می‌دهند و غیرمشاوره‌ای نه', () {
      expect(LegalCounselor.shouldStartCounseling('چک برگشتی دارم', net: net),
          isTrue);
      expect(LegalCounselor.shouldStartCounseling('کارفرما اخراجم کرده', net: net),
          isTrue);
      expect(LegalCounselor.shouldStartCounseling('سلام', net: net), isFalse);
      expect(
          LegalCounselor.shouldStartCounseling('امروز هوا چطور است', net: net),
          isFalse);
      // پرسش صرفاً اطلاعاتی → پاسخ موتور دانش، نه درخت مشاوره
      expect(
          LegalCounselor.shouldStartCounseling('مجازات کلاهبرداری چیست',
              net: net),
          isFalse);
    });

    test('detectTopic با شبکهٔ عصبی حوزهٔ درست را برمی‌گرداند', () {
      expect(LegalCounselor.detectTopic('کارفرما اخراجم کرده', net: net),
          'labor');
      expect(LegalCounselor.detectTopic('چک برگشتی دارم', net: net), 'cheque');
      expect(LegalCounselor.detectTopic('مشاوره', net: net), 'general_intake');
      expect(
          LegalCounselor.detectTopic('قانون چک چه می‌گوید؟', net: net), isNull);
    });

    test('detectTopicHint برای پرسش اطلاعاتی، دکمهٔ مشاورهٔ حوزهٔ مرتبط می‌دهد', () {
      expect(
          LegalCounselor.detectTopicHint('مجازات کلاهبرداری چیست', net: net),
          'fraud_cyber');
      expect(LegalCounselor.detectTopicHint('قانون چک چه می‌گوید؟', net: net),
          'cheque');
      expect(LegalCounselor.detectTopicHint('سلام', net: net), isNull);
      // بدون شبکه، همان مسیر نمادین قدیمی
      expect(LegalCounselor.detectTopicHint('مجازات کلاهبرداری چیست'),
          'fraud_cyber');
    });

    test('گشایندهٔ مشاوره با شبکهٔ عصبی، درست مثل مسیر نمادین عمل می‌کند', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('چک دادم بابت ضمانت الان برگشت زده و می‌خواهم بدانم چه کار کنم');
      expect(ctrl.isCounseling, isTrue);
      expect(ctrl.messages.last.text, contains('گواهی عدم پرداخت'));
      ctrl.dispose();
    });
  });

  group('۲. RAG در میانهٔ مشاوره', () {
    test('پرسش قانونی میان جلسه، ماده را از بانک قوانین در پاسخ می‌آورد و جلسه نمی‌شکند',
        () async {
      final ctrl = makeCtrl();
      await ctrl.submit('مستأجرم مدت قراردادش تمام شده ولی خانه را تخلیه نمی‌کند');
      expect(ctrl.isCounseling, isTrue);
      expect(ctrl.messages.last.text, contains('دو شاهد'));

      await ctrl.submit('ماده ۳ قانون روابط موجر و مستأجر چه می‌گوید؟');
      expect(ctrl.isCounseling, isTrue,
          reason: 'پرسش حقوقی نباید جلسهٔ مشاوره را خراب کند');
      final t = ctrl.messages.last.text;
      expect(t, contains('ماده 3'), reason: 'متن ماده باید در پاسخ بیاید');
      expect(t, contains('دو شاهد'),
          reason: 'پس از پاسخ RAG باید به پرسش باز مشاوره برگردیم');
      expect(ctrl.messages.last.chips, contains(LegalCounselor.cancelCounselCmd));
      ctrl.dispose();
    });

    test('پاسخ خبریِ خانهٔ پرسش، گفتگو را به RAG نمی‌کشاند (درگاه نشانهٔ پرسش)',
        () async {
      final ctrl = makeCtrl();
      await ctrl.submit('مستأجرم مدت قراردادش تمام شده ولی خانه را تخلیه نمی‌کند');
      // شبکه ممکن است این جملهٔ خبری را legal_question بزند؛ درگاه نشانهٔ
      // پرسش جلوی ربودن جریان را می‌گیرد و جلسه روی ریل می‌ماند.
      await ctrl.submit('خودم موجرم و مستأجر مشکل دارد');
      final t = ctrl.messages.last.text;
      expect(t, isNot(contains('بانک قوانین برنامه نشان بدهم')));
      expect(t, contains('دادخواست صدور حکم تخلیه'));
      expect(ctrl.isCounseling, isFalse);
      ctrl.dispose();
    });

    test('در حالت پذیرش عمومی هم پرسش قانونی با RAG پاسخ می‌گیرد', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('مشاوره');
      expect(ctrl.isCounseling, isTrue);
      expect(ctrl.messages.last.text, contains('با کمال میل همراه شما هستم'));

      await ctrl.submit('قانون چک چه می‌گوید؟');
      expect(ctrl.isCounseling, isTrue);
      final t = ctrl.messages.last.text;
      expect(t, contains('چک'));
      expect(t, isNot(contains('پیدا نکردم')));
      expect(t, contains('یک جمله'),
          reason: 'پس از RAG باید کارت پذیرش دوباره پرسیده شود');
      ctrl.dispose();
    });
  });

  group('۳. حافظهٔ گفتگو در مشاوره', () {
    test('«ماده بعدی‌اش چی میگه؟» در میانهٔ جلسه به مادهٔ بعد همان قانون می‌رود',
        () async {
      final ctrl = makeCtrl();
      await ctrl.submit('مستأجرم مدت قراردادش تمام شده ولی خانه را تخلیه نمی‌کند');
      await ctrl.submit('ماده ۳ قانون روابط موجر و مستأجر چه می‌گوید؟');
      expect(ctrl.messages.last.text, contains('ماده 3'));

      await ctrl.submit('ماده بعدی‌اش چی میگه؟');
      expect(ctrl.isCounseling, isTrue);
      final t = ctrl.messages.last.text;
      expect(t, contains('ماده 4'),
          reason: 'حافظه باید موضوع قبلی را به مادهٔ بعدی پیوند بزند');
      expect(t, contains('دو شاهد'));
      ctrl.dispose();
    });
  });

  group('۴. ادامهٔ مشاورهٔ جمع‌بندی‌شده', () {
    test('«ادامه مشاوره» جلسهٔ همان موضوع را از نو باز می‌کند', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('چک دادم بابت ضمانت الان برگشت زده و می‌خواهم بدانم چه کار کنم');
      await ctrl.submit('بله، گواهی دارم و زیر ۶ ماه است');
      expect(ctrl.isCounseling, isFalse, reason: 'جلسه جمع‌بندی شده است');

      await ctrl.submit('ادامه مشاوره');
      expect(ctrl.isCounseling, isTrue);
      final t = ctrl.messages.last.text;
      expect(t, contains('چک و دعاوی بانکی'));
      expect(t, contains('دارنده'),
          reason: 'درخت تصمیم از نخستین پرسش (نقش کاربر) شروع می‌شود');
      ctrl.dispose();
    });

    test('«انصراف» در میانهٔ جلسه آن را می‌بندد', () async {
      final ctrl = makeCtrl();
      await ctrl.submit('چک دادم بابت ضمانت الان برگشت زده و می‌خواهم بدانم چه کار کنم');
      await ctrl.submit('انصراف');
      expect(ctrl.isCounseling, isFalse);
      expect(ctrl.messages.last.text, contains('پایان یافت'));
      ctrl.dispose();
    });
  });

  group('۵. نقطهٔ بازیابی مشاوره (رمزنگاری‌شده)', () {
    test('جلسهٔ ناتمام ذخیره، رمزنگاری و در اجرای بعد بازیابی می‌شود', () async {
      final ctrl1 = makeCtrl(save: true);
      await ctrl1.submit('چک دادم بابت ضمانت الان برگشت زده و می‌خواهم بدانم چه کار کنم');
      expect(ctrl1.isCounseling, isTrue);
      expect(await ctrl1.saveCounselCheckpoint(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      final rawCipher = prefs.getString('active_counsel_v1') ?? '';
      expect(rawCipher, isNotEmpty);
      expect(rawCipher.contains('cheque'), isFalse,
          reason: 'دادهٔ حساس باید رمزنگاری شده باشد');
      ctrl1.dispose();

      final restored = await CounselCheckpointStore.load();
      expect(restored, isNotNull);
      expect(restored!.topicId, 'cheque');
      expect(restored.facts['role'], 'issuer');
      expect(restored.facts['nature'], 'conditional');

      final ctrl2 = makeCtrl(save: true, initialCounsel: restored);
      expect(ctrl2.isCounseling, isTrue);
      expect(ctrl2.messages.last.text, contains('مشاورهٔ'));
      expect(ctrl2.messages.last.text, contains('گواهی عدم پرداخت'),
          reason: 'باید از همان پرسش ناتمام ادامه یابد');

      await ctrl2.submit('بله، گواهی دارم و زیر ۶ ماه است');
      expect(ctrl2.messages.last.text, contains('مادهٔ ۱۳ قانون صدور چک'));
      expect(ctrl2.isCounseling, isFalse);

      // پس از جمع‌بندی، نقطهٔ بازیابی پاک می‌شود
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(await CounselCheckpointStore.load(), isNull);
      ctrl2.dispose();
    });
  });

  group('۶. پاسخ طبیعی با قالب‌های متنوع (بدون LLM)', () {
    test('Replies: get نخستین قالب است و pick میان قالب‌ها تصادفی است', () {
      final r = Replies();
      r.setOverridesRaw({
        'greeting': 'سلام الف',
        'multi': ['یک', 'دو', 'سه'],
        'vars': ['نام من {name} است', 'اسمم {name} هست'],
      });
      expect(r.get('greeting'), 'سلام الف');
      expect(r.get('multi'), 'یک');
      expect(r.variants('multi').length, 3);

      final seen = <String>{};
      final rnd = Random(3);
      for (var i = 0; i < 80; i++) {
        seen.add(r.pick('multi', rnd: rnd));
      }
      expect(seen.length, greaterThan(1),
          reason: 'pick باید بین قالب‌ها بچرخد');
      expect(seen.every({'یک', 'دو', 'سه'}.contains), isTrue);

      final v = r.pick('vars', vars: {'name': 'دستیار'}, rnd: Random(1));
      expect(v, anyOf('نام من دستیار است', 'اسمم دستیار هست'));

      // کلیدهای پیش‌فرض بدون override هم کار می‌کنند
      expect(r.get('ask_more'), 'لطفاً پرسش خود را کامل‌تر بنویسید.');
    });

    test('قالب‌های replies.json همهٔ زیررشته‌های حیاتی تست‌ها را نگه داشته‌اند', () {
      final m = jsonDecode(
        File('assets/replies.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final r = Replies()..setOverridesRaw(m);

      // هر قالب پرسش حیاتی در همهٔ نسخه‌ها زیررشتهٔ کلیدی دارد
      const invariants = {
        'cq_lease_witnesses': ['دو شاهد'],
        'cq_litigation_defense_deadline': ['۲۰ روز'],
        'cq_cheque_cert_time': ['گواهی عدم پرداخت'],
        'cq_debt_role': ['طلبکار', 'بدهکار'],
        'cq_labor_issue': ['کارفرما'],
        'counselor_intake_greeting': ['با کمال میل همراه شما هستم'],
      };
      invariants.forEach((key, subs) {
        for (final v in r.variants(key)) {
          for (final s in subs) {
            expect(v, contains(s), reason: '$key باید «$s» داشته باشد');
          }
        }
        expect(r.variants(key).length, greaterThan(1),
            reason: '$key باید چند قالب داشته باشد');
      });

      // تصدیق‌ها {answer} و پیام‌های بازیابی {topic} دارند
      for (final v in r.variants('counselor_ack')) {
        expect(v, contains('{answer}'));
      }
      for (final k in ['counsel_resumed', 'counsel_resumed_note']) {
        for (final v in r.variants(k)) {
          expect(v, contains('{topic}'));
        }
      }
    });

    test('انتخاب تصادفی قالب‌ها با دانه‌های گوناگون همیشه زیررشتهٔ حیاتی دارد', () {
      final r = engine.replies;
      for (var seed = 1; seed <= 40; seed++) {
        final rnd = Random(seed);
        expect(r.pick('cq_lease_witnesses', rnd: rnd), contains('دو شاهد'));
        expect(r.pick('cq_litigation_defense_deadline', rnd: rnd),
            contains('۲۰ روز'));
        expect(r.pick('cq_cheque_cert_time', rnd: rnd),
            contains('گواهی عدم پرداخت'));
        final role = r.pick('cq_debt_role', rnd: rnd);
        expect(role, contains('طلبکار'));
        expect(role, contains('بدهکار'));
        expect(r.pick('counselor_intake_greeting', rnd: rnd),
            contains('با کمال میل همراه شما هستم'));
      }
    });
  });
}
