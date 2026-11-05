import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/dialogue/small_talk_layer.dart';
import 'package:dastyar/domain/legal_counselor.dart';
import 'package:dastyar/domain/templates.dart';

const SmallTalkLayer layer = SmallTalkLayer();

SmallTalkReply? route(String text, {bool active = false}) =>
    layer.tryHandle(text, hasActiveLegalContext: active);

CounselingSession _intakeSession() =>
    CounselingSession(topicId: 'general_intake', initialMessage: '');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final engine = KnowledgeEngine();
  const templates = <LegalTemplate>[];

  group('نگهبان حقوقی — مهمترین قرارداد لایه', () {
    test('«سلام» احوالپرسی است ولی «سلام، چک من برگشت خورده» نیست', () {
      final greeting = route('سلام');
      expect(greeting, isNotNull);
      expect(greeting!.intent, SmallTalkIntent.greeting);

      // همان جمله با یک نشانهٔ حقوقی باید به جریان حقوقی واگذار شود.
      expect(route('سلام، چک من برگشت خورده'), isNull);
    });

    test('نشانهٔ حقوقی در هر جای پیام، لایه را خاموش میکند', () {
      const samples = <String>[
        'سلام، چک من برگشت خورده',
        'سلام مهریهام رو میخوام',
        'ممنون، ماده ۱۳ قانون صدور چک را توضیح بده',
        'سلام، مستأجرم خانه را تخلیه نمیکند',
        'هوا چطوره؟ راستی حکم غیابی من چی شد',
        'سلام، کارفرما اخراجم کرده',
        'سلام، مشاوره حقوقی میخوام',
        'قانون چک چه میگوید؟',
        'دارنده چک هستم',
        'لعنتی چکم برگشت خورده',
      ];
      for (final s in samples) {
        expect(route(s), isNull, reason: 'باید حقوقی تشخیص داده شود: $s');
        expect(SmallTalkLayer.hasLegalSignal(s), isTrue,
            reason: 'نگهبان باید علامت بدهد: $s');
      }
    });

    test('hasLegalSignal روی گفتگوی کوتاه خالص false است', () {
      for (final s in <String>[
        'سلام', 'خوبی', 'ممنون', 'هوا چطوره', 'جوک بگو', 'حالم بده'
      ]) {
        expect(SmallTalkLayer.hasLegalSignal(s), isFalse, reason: s);
      }
    });

    test('ارجاع صریح به ماده/اصل هم حقوقی است', () {
      expect(route('ماده ۲۲ قانون اساسی چیست؟'), isNull);
      expect(SmallTalkLayer.hasLegalSignal('اصل ۳۷'), isTrue);
    });
  });

  group('تشخیص احوالپرسی', () {
    test('درودها، شامل واژههای کوتاه ۴ حرفی «سلام» و «خوبی»', () {
      const samples = <String>[
        'سلام', 'درود', 'وقت بخیر', 'صبح بخیر', 'عصر بخیر',
        'شب بخیر', 'سلام علیکم', 'hello',
      ];
      for (final s in samples) {
        expect(route(s)?.intent, SmallTalkIntent.greeting, reason: s);
      }
    });

    test('احوالپرسی دوباره و احوالجویی', () {
      const samples = <String>[
        'خوبی؟', 'چطوری', 'حالت چطوره', 'چه خبر', 'چطورید'
      ];
      for (final s in samples) {
        expect(route(s)?.intent, SmallTalkIntent.howAreYou, reason: s);
      }
    });

    test('تشکر', () {
      const samples = <String>[
        'ممنون', 'مرسی', 'متشکرم', 'دستت درد نکنه'
      ];
      for (final s in samples) {
        expect(route(s)?.intent, SmallTalkIntent.thanks, reason: s);
      }
    });

    test('خداحافظی (فراخوان مستقیم لایه)', () {
      expect(route('خداحافظ')?.intent, SmallTalkIntent.farewell);
      expect(route('بدرود')?.intent, SmallTalkIntent.farewell);
    });
  });

  group('تخلیهٔ هیجانی، ناسزا و موضوعات نامرتبط', () {
    test('دلدرد و خستگی، با هدایت ملایم به اصل ماجرا', () {
      const samples = <String>[
        'حالم خوب نیست', 'خستهام', 'خسته ام', 'استرس دارم',
        'ناراحتم', 'کلافهام', 'نگرانم',
      ];
      for (final s in samples) {
        final r = route(s);
        expect(r?.intent, SmallTalkIntent.distress, reason: s);
        expect(r!.text, anyOf(contains('درکتان'), contains('عجله'), contains('حق دارید')));
      }
    });

    test('ناسزا بدون قضاوت و بدون پاسخ حقوقی', () {
      const samples = <String>['لعنتی', 'احمق', 'بیشرف', 'خفه شو', 'کثافت'];
      for (final s in samples) {
        final r = route(s);
        expect(r?.intent, SmallTalkIntent.profanity, reason: s);
        expect(r!.text, contains('ناراحت'));
      }
    });

    test('موضوعات کاملاً نامرتبط (هوا، ساعت، سرگرمی، ورزش)', () {
      const samples = <String>[
        'هوا چطوره؟', 'امروز هوا چطور است', 'ساعت چنده',
        'جوک بگو', 'شعر بگو', 'چه فیلمی پیشنهاد میکنی',
        'فوتبال امروز چی شد', 'what is the weather',
      ];
      for (final s in samples) {
        final r = route(s);
        expect(r?.intent, SmallTalkIntent.offTopic, reason: s);
        expect(r!.text, anyOf(contains('حدس نمیزنم'), contains('تخصص من خارج')));
      }
    });

    test('پرسش «قدم بعدی چیه» به جای جواب حقوقی، راهنمایی کوتاه میگیرد', () {
      for (final s in <String>['الان چکار کنم', 'قدم بعدی چیه', 'حالا چی']) {
        expect(route(s)?.intent, SmallTalkIntent.metaNextStep, reason: s);
      }
    });
  });

  group('زمینهٔ گفتگو و جداسازی', () {
    test('پاسخها بسته به زمینهٔ حقوقی فعال متفاوت و چیپها متناسباند', () {
      final fresh = route('سلام');
      final active = route('سلام', active: true);
      expect(fresh!.text, isNot(active!.text));
      expect(fresh.chips, SmallTalkLayer.defaultIntakeChips);
      expect(active.chips, SmallTalkLayer.activeSessionChips);
      expect(active.text, contains('همان'));
    });

    test('پاسخ تأییدی «بله ممنون» در جلسهٔ فعال بلعیده نمیشود', () {
      expect(route('بله ممنون', active: true), isNull);
      expect(route('بله ممنون')?.intent, SmallTalkIntent.thanks);
    });

    test('هیچ پاسخی شامل استناد یا تحلیل حقوقی نمیشود', () {
      const samples = <String>[
        'سلام', 'خوبی', 'ممنون', 'حالم بده', 'لعنتی',
        'هوا چطوره', 'الان چکار کنم', 'خداحافظ',
      ];
      for (final s in samples) {
        final r = route(s);
        expect(r, isNotNull, reason: s);
        for (final forbidden in <String>[
          'ماده ', 'قانون ', 'دادگاه', 'چک ', 'بانک قوانین'
        ]) {
          expect(r!.text, isNot(contains(forbidden)),
              reason: 'پاسخ «$s» نباید $forbidden داشته باشد');
        }
        expect(r.text.length, lessThan(260), reason: 'پاسخ باید کوتاه باشد');
      }
    });

    test('تابع خالص و پایدار است', () {
      final a = route('سلام');
      final b = route('سلام');
      expect(a!.intent, b!.intent);
      expect(a.text, b.text);
      expect(a.chips, b.chips);
    });

    test('ورودی تهی یا فقط فاصله به جریان حقوقی واگذار میشود', () {
      expect(route(''), isNull);
      expect(route('   '), isNull);
    });

    test('یکدستسازی نویسهها، اعراب و نیمفاصله', () {
      expect(route('سلام عليكم')?.intent, SmallTalkIntent.greeting);
      expect(route('صبح\u200Cبخیر')?.intent, SmallTalkIntent.greeting);
      expect(route('سَلام')?.intent, SmallTalkIntent.greeting);
      expect(SmallTalkLayer.hasLegalSignal('چك برگشتى'), isTrue);
    });
  });

  group('یکپارچگی با LegalCounselor.step', () {
    test('«سلام» پیش از planner/RAG با پاسخ ثابت متوقف میشود', () {
      final s = _intakeSession();
      final turn = LegalCounselor.step(s, 'سلام', engine, templates);
      expect(turn.text, contains('سلام'));
      expect(turn.ragQuery, isNull);
      expect(turn.ragReply, isNull);
      expect(turn.completed, isFalse);
      expect(s.topicId, 'general_intake');
    });

    test('«سلام، چک من برگشت خورده» به درخت تصمیم حقوقی میرود', () {
      final s = _intakeSession();
      final turn = LegalCounselor.step(s, 'سلام، چک من برگشت خورده', engine, templates);
      expect(s.topicId, 'cheque');
      expect(turn.text, contains('نقش'));
      expect(turn.text, isNot(contains('سلام و وقت بخیر')));
    });

    test('پرسش نامرتبط در جلسهٔ عمومی RAG را فعال نمیکند', () {
      final s = _intakeSession();
      final turn = LegalCounselor.step(s, 'هوا چطوره؟', engine, templates);
      expect(turn.text, contains('حدس نمیزنم'));
      expect(turn.ragQuery, isNull);
      expect(turn.ragReply, isNull);
      expect(s.topicId, 'general_intake');
    });

    test('در جلسهٔ حقوقی فعال، احوالپرسی چیپهای همان جلسه را میدهد', () {
      final s = CounselingSession(
        topicId: 'cheque',
        initialMessage: 'چک برگشتی دارم',
      );
      final turn = LegalCounselor.step(s, 'سلام', engine, templates);
      expect(turn.text, contains('خوش برگشتید'));
      expect(turn.chips, SmallTalkLayer.activeSessionChips);
      expect(s.topicId, 'cheque');
    });
  });
}
