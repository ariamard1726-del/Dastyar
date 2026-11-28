// تولیدشده از dev/tools/contracts/priority.json — دستی ویرایش نکنید.
// تولید دوباره: python3 dev/tools/gen_priority.py --write
// بررسی تازگی:  python3 dev/tools/gen_priority.py --check

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/rent_texts_loader.dart';
import 'package:dastyar/domain/advocate/understanding.dart';
import 'package:dastyar/domain/draft_words.dart';
import 'package:dastyar/domain/understanding/topic_guess.dart';
import 'package:flutter_test/flutter_test.dart';

/// آزمونِ ماتریس اولویتِ ۲۶ کاندید (۳۲۵ جفت: ۲۳۱ هم‌پوشان + ۹۴ جداگانه).
///
/// تمام نوبت‌های پیش‌شرط با فراخوانی واقعی `Advocate.respond` ساخته می‌شوند،
/// نه با دست‌کاریِ وضعیت داخلی؛ هر تغییر در ترتیب یا پیش‌شرط کاندیدها
/// بی‌درنگ جفتِ متناظر را قرمز می‌کند.
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

  Advocate buildSetup(String id) {
    final a = fresh();
    switch (id) {
      case 'asked':
        a.respond('سلام');
        return a;
      case 'choices':
        a.respond('چک برگشتی دارم و صاحبخانه پول پیشم را نمی‌دهد و اول کدام را پیگیری کنم');
        return a;
      case 'idle':
        return a;
      case 'idle_rest':
        a.respond('فرق دادخواست و شکوائیه ۱ چیست');
        return a;
      case 'open_guessed':
        a.respond('مشکل خاصی برایم پیش آمده راهنمایی بدهید', guess: const TopicGuess('labor', 0.9, '', 0, confident: true, plausible: true));
        return a;
      case 'open_guessed_repeat':
        a.respond('منظورم این نبود اشتباه گرفتی دوست من', guess: const TopicGuess('labor', 0.9, '', 0, confident: true, plausible: true));
        return a;
      case 'open_guessed_rest_offer':
        a.respond('نامه ابلاغ شده و می‌خواهم توافق کنم', guess: const TopicGuess('admin', 0.9, '', 0, confident: true, plausible: true));
        return a;
      case 'open_offer':
        a.respond('با شرکت خارجی قرارداد داریم که شعبه در ایران ندارد');
        a.respond('ادامه بده');
        a.respond('شرط داوری نوشته شده و می‌خواهم توافق کنم');
        return a;
      case 'open_pend_offer':
        a.respond('با شرکت خارجی قرارداد داریم که شعبه در ایران ندارد');
        a.respond('ادامه بده');
        a.respond('شرط داوری نوشته شده و می‌خواهم توافق کنم');
        a.respond('چک صیادی برگشت خورده دارم چکار کنم؟');
        return a;
      case 'open_pend_rest':
        a.respond('آپارتمان اجاره کرده‌ام');
        a.respond('چک صیادی برگشت خورده دارم چکار کنم؟');
        a.respond('خانه نم و رطوبت دارد و چکه می‌کند و قابل سکونت نیست');
        return a;
      case 'open_pend_side':
        a.respond('آپارتمان اجاره داده‌ام');
        a.respond('چک صیادی برگشت خورده دارم چکار کنم؟');
        a.respond('فروشنده ماشین تحویل نداد');
        return a;
      case 'open_pending':
        a.respond('آپارتمان اجاره داده‌ام');
        a.respond('کتاب');
        a.respond('چک صیادی برگشت خورده دارم چکار کنم؟');
        return a;
      case 'open_rent':
        a.respond('آپارتمان اجاره داده‌ام');
        a.respond('کتاب');
        return a;
      case 'open_rent_filing14':
        a.respond('مستاجرم و صاحبخانه پول پیشم را نمی‌دهد');
        a.respond('صاحبخانه ادعای خسارت کرده و پولم را کم می‌کند');
        return a;
      case 'open_rest':
        a.respond('با شرکت خارجی قرارداد داریم که شعبه در ایران ندارد');
        return a;
      case 'open_rest_offer':
        a.respond('با شرکت خارجی قرارداد داریم و شرط داوری نوشته شده و می‌خواهم توافق کنم');
        return a;
      case 'open_side':
        a.respond('آپارتمان اجاره داده‌ام');
        a.respond('چک صیادی برگشت');
        return a;
      default:
        throw ArgumentError('Unknown setup: $id');
    }
  }

  group('پیش‌شرط وضعیت‌های گفتگوی واقعی (۱۷ حالت)', () {
    test('حالت‌های پایه، پرونده، حدس، ادامه، پیشنهاد، موضوع کناری و سند آماده‌اند', () {
      final idle = buildSetup('idle');
      expect(idle.hasCase, isFalse);
      expect(idle.dialog.loose, isEmpty);

      final asked = buildSetup('asked');
      expect(asked.hasCase, isFalse);
      expect(asked.dialog.branchAsked, isTrue);

      final choices = buildSetup('choices');
      expect(choices.hasCase, isFalse);
      expect(choices.dialog.choices, isNotEmpty);

      final idleRest = buildSetup('idle_rest');
      expect(idleRest.hasCase, isFalse);
      expect(idleRest.hasMore, isTrue);

      final openRent = buildSetup('open_rent');
      expect(openRent.file.topic, 'rent');
      expect(openRent.file.pending, isEmpty);
      expect(openRent.dialog.offer, isEmpty);
      expect(openRent.hasMore, isFalse);
      expect(openRent.dialog.side, isNull);

      final openPending = buildSetup('open_pending');
      expect(openPending.file.topic, 'rent');
      expect(openPending.dialog.pendingTopic, isNotNull);
      expect(openPending.file.pending, isEmpty);
      expect(openPending.dialog.offer, isEmpty);
      expect(openPending.hasMore, isFalse);

      final openGuessed = buildSetup('open_guessed');
      expect(openGuessed.file.topic, 'labor');
      expect(openGuessed.dialog.guessed, isTrue);
      expect(openGuessed.hasMore, isFalse);

      final openGuessedRepeat = buildSetup('open_guessed_repeat');
      expect(openGuessedRepeat.file.topic, 'labor');
      expect(openGuessedRepeat.dialog.guessed, isTrue);

      final openRest = buildSetup('open_rest');
      expect(openRest.file.topic, 'foreign_contract');
      expect(openRest.hasMore, isTrue);
      expect(openRest.dialog.offer, isEmpty);

      final openOffer = buildSetup('open_offer');
      expect(openOffer.file.topic, 'foreign_contract');
      expect(openOffer.dialog.offer, isNotEmpty);
      expect(openOffer.hasMore, isFalse);

      final openRestOffer = buildSetup('open_rest_offer');
      expect(openRestOffer.file.topic, 'foreign_contract');
      expect(openRestOffer.hasMore, isTrue);
      expect(openRestOffer.dialog.offer, isNotEmpty);

      final openGuessedRestOffer = buildSetup('open_guessed_rest_offer');
      expect(openGuessedRestOffer.file.topic, 'admin');
      expect(openGuessedRestOffer.dialog.guessed, isTrue);
      expect(openGuessedRestOffer.hasMore, isTrue);
      expect(openGuessedRestOffer.dialog.offer, isNotEmpty);

      final openSide = buildSetup('open_side');
      expect(openSide.file.topic, 'rent');
      expect(openSide.dialog.side, isNotNull);
      expect(openSide.hasMore, isFalse);

      final openPendRest = buildSetup('open_pend_rest');
      expect(openPendRest.file.topic, 'rent');
      expect(openPendRest.dialog.pendingTopic, isNotNull);
      expect(openPendRest.hasMore, isTrue);

      final openPendOffer = buildSetup('open_pend_offer');
      expect(openPendOffer.file.topic, 'foreign_contract');
      expect(openPendOffer.dialog.pendingTopic, isNotNull);
      expect(openPendOffer.dialog.offer, isNotEmpty);

      final openPendSide = buildSetup('open_pend_side');
      expect(openPendSide.file.topic, 'rent');
      expect(openPendSide.dialog.pendingTopic, isNotNull);
      expect(openPendSide.dialog.side, isNotNull);

      final openFiling = buildSetup('open_rent_filing14');
      expect(openFiling.file.topic, 'rent');
      expect(
        openFiling.filings.any(
          (g) => Sense.norm(g.chip) == Sense.norm('تنظیم لایحهٔ دفاع در برابر ادعای خسارت'),
        ),
        isTrue,
      );
    });
  });

  group('ماتریس جفت‌های هم‌پوشان (۲۳۱ جفت)' , () {
    test('(۰, ۱) موضوعِ تازه > «هیچ‌کدام»', () {
      final loser = buildSetup('idle');
      loser.respond('گزینه‌ای وجود ندارد');
      expect(loser.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'پایهٔ بازنده در (0, 1)');

      final winner = buildSetup('idle');
      winner.respond('موضوع تازه گزینه‌ای وجود ندارد');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 1)');
    });
    test('(۰, ۳) موضوعِ تازه > دکمهٔ دستهٔ مشکل', () {
      final loser = buildSetup('asked');
      loser.respond('خروج');
      expect(loser.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'پایهٔ بازنده در (0, 3)');

      final winner = buildSetup('asked');
      winner.respond('خروج موضوع تازه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 3)');
    });
    test('(۰, ۴) موضوعِ تازه > کنار گذاشتنِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('خروج از این موضوع');
      expect(loser.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'پایهٔ بازنده در (0, 4)');

      final winner = buildSetup('open_rent');
      winner.respond('خروج از موضوع تازه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 4)');
    });
    test('(۰, ۵) موضوعِ تازه > ایمنی', () {
      final loser = buildSetup('idle');
      loser.respond('الان در خطرم');
      expect(loser.lastDecision?.candidate.name, 'ایمنی',
          reason: 'پایهٔ بازنده در (0, 5)');

      final winner = buildSetup('idle');
      winner.respond('موضوع تازه الان در خطرم');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 5)');
    });
    test('(۰, ۷) موضوعِ تازه > دربارهٔ برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('تاریخچه کجاست؟');
      expect(loser.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'پایهٔ بازنده در (0, 7)');

      final winner = buildSetup('idle');
      winner.respond('تاریخچه موضوع تازه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 7)');
    });
    test('(۰, ۸) موضوعِ تازه > دعوا و شکایت', () {
      final loser = buildSetup('idle');
      loser.respond('دعوام شد');
      expect(loser.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'پایهٔ بازنده در (0, 8)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد موضوع تازه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 8)');
    });
    test('(۰, ۹) موضوعِ تازه > انتخابِ موضوع', () {
      final loser = buildSetup('choices');
      loser.respond('نه');
      expect(loser.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'پایهٔ بازنده در (0, 9)');

      final winner = buildSetup('choices');
      winner.respond('نه موضوع تازه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 9)');
    });
    test('(۰, ۱۰) موضوعِ تازه > حدسِ اشتباه', () {
      final loser = buildSetup('open_guessed');
      loser.respond('اشتباه گرفتی');
      expect(loser.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'پایهٔ بازنده در (0, 10)');

      final winner = buildSetup('open_guessed');
      winner.respond('اشتباه گرفتی موضوع تازه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 10)');
    });
    test('(۰, ۱۱) موضوعِ تازه > ادامهٔ حرفِ قبلی', () {
      final loser = buildSetup('open_rest');
      loser.respond('ادامه بده');
      expect(loser.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (0, 11)');

      final winner = buildSetup('open_rest');
      winner.respond('ادامه موضوع تازه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 11)');
    });
    test('(۰, ۱۳) موضوعِ تازه > پیشنهادِ پاسخ', () {
      final loser = buildSetup('open_offer');
      loser.respond('بله');
      expect(loser.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'پایهٔ بازنده در (0, 13)');

      final winner = buildSetup('open_offer');
      winner.respond('بله موضوع تازه هست');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 13)');
    });
    test('(۰, ۱۴) موضوعِ تازه > «باشه»', () {
      final loser = buildSetup('open_rent');
      loser.respond('بله');
      expect(loser.lastDecision?.candidate.name, '«باشه»',
          reason: 'پایهٔ بازنده در (0, 14)');

      final winner = buildSetup('open_rent');
      winner.respond('بله موضوع تازه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 14)');
    });
    test('(۰, ۱۵) موضوعِ تازه > موضوعِ کنارِ هم', () {
      final loser = buildSetup('open_side');
      loser.respond('این یک موضوع جداست');
      expect(loser.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'پایهٔ بازنده در (0, 15)');

      final winner = buildSetup('open_side');
      winner.respond('جداست موضوع تازه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 15)');
    });
    test('(۰, ۱۶) موضوعِ تازه > مهلت', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(loser.lastDecision?.candidate.name, 'مهلت',
          reason: 'پایهٔ بازنده در (0, 16)');

      final winner = buildSetup('idle');
      winner.respond('موضوع تازه مهلت رأی ۱۴۰۳.۱.۱ ۲۰روز');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 16)');
    });
    test('(۰, ۱۷) موضوعِ تازه > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (0, 17)');

      final winner = buildSetup('idle');
      winner.respond('موضوع تازه ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 17)');
    });
    test('(۰, ۱۸) موضوعِ تازه > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (0, 18)');

      final winner = buildSetup('open_rent');
      winner.respond('این پرونده درباره موضوع تازه است الان');
      winner.respond('این پرونده درباره موضوع تازه است');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 18)');
    });
    test('(۰, ۱۹) موضوعِ تازه > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (0, 19)');

      final winner = buildSetup('idle');
      winner.respond('موضوع تازه طلاق ثبت دفترخانه نمیشه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 19)');
    });
    test('(۰, ۲۰) موضوعِ تازه > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (0, 20)');

      final winner = buildSetup('idle');
      winner.respond('موضوع تازه مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 20)');
    });
    test('(۰, ۲۱) موضوعِ تازه > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (0, 21)');

      final winner = buildSetup('idle');
      winner.respond('موضوع تازه غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 21)');
    });
    test('(۰, ۲۲) موضوعِ تازه > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (0, 22)');

      final winner = buildSetup('idle');
      winner.respond('موضوع تازه قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 22)');
    });
    test('(۰, ۲۳) موضوعِ تازه > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (0, 23)');

      final winner = buildSetup('idle');
      winner.respond('موضوع تازه گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 23)');
    });
    test('(۰, ۲۴) موضوعِ تازه > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (0, 24)');

      final winner = buildSetup('open_rent');
      winner.respond('موضوع تازه اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 24)');
    });
    test('(۰, ۲۵) موضوعِ تازه > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (0, 25)');

      final winner = buildSetup('idle');
      winner.respond('موضوع تازه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 25)');
    });
    test('(۱, ۲) «هیچ‌کدام» > تازه است یا مربوط؟', () {
      final loser = buildSetup('open_pending');
      loser.respond('مربوط است');
      expect(loser.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'پایهٔ بازنده در (1, 2)');

      final winner = buildSetup('open_pending');
      winner.respond('گزینه نیست مربوط');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 2)');
    });
    test('(۱, ۳) «هیچ‌کدام» > دکمهٔ دستهٔ مشکل', () {
      final loser = buildSetup('asked');
      loser.respond('خروج');
      expect(loser.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'پایهٔ بازنده در (1, 3)');

      final winner = buildSetup('asked');
      winner.respond('گزینه نیست خروج');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 3)');
    });
    test('(۱, ۵) «هیچ‌کدام» > ایمنی', () {
      final loser = buildSetup('idle');
      loser.respond('الان در خطرم');
      expect(loser.lastDecision?.candidate.name, 'ایمنی',
          reason: 'پایهٔ بازنده در (1, 5)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد الان در خطرم');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 5)');
    });
    test('(۱, ۶) «هیچ‌کدام» > پرسش فرضی', () {
      final loser = buildSetup('idle');
      loser.respond('پرسشها درباره قرارداد بین الف و ب چیست و در قانون چه میشود');
      expect(loser.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'پایهٔ بازنده در (1, 6)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد و پرسشها درباره قرارداد بین الف و ب چیست و در قانون چه میشود');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 6)');
    });
    test('(۱, ۷) «هیچ‌کدام» > دربارهٔ برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('تاریخچه');
      expect(loser.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'پایهٔ بازنده در (1, 7)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد تاریخچه');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 7)');
    });
    test('(۱, ۸) «هیچ‌کدام» > دعوا و شکایت', () {
      final loser = buildSetup('idle');
      loser.respond('دعوام شد');
      expect(loser.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'پایهٔ بازنده در (1, 8)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد دعوام شد');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 8)');
    });
    test('(۱, ۹) «هیچ‌کدام» > انتخابِ موضوع', () {
      final loser = buildSetup('choices');
      loser.respond('نه');
      expect(loser.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'پایهٔ بازنده در (1, 9)');

      final winner = buildSetup('choices');
      winner.respond('نه گزینه نیست');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 9)');
    });
    test('(۱, ۱۰) «هیچ‌کدام» > حدسِ اشتباه', () {
      final loser = buildSetup('open_guessed');
      loser.respond('اشتباه گرفتی');
      expect(loser.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'پایهٔ بازنده در (1, 10)');

      final winner = buildSetup('open_guessed');
      winner.respond('گزینه‌ای وجود ندارد اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 10)');
    });
    test('(۱, ۱۱) «هیچ‌کدام» > ادامهٔ حرفِ قبلی', () {
      final loser = buildSetup('open_rest');
      loser.respond('ادامه بده');
      expect(loser.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (1, 11)');

      final winner = buildSetup('open_rest');
      winner.respond('گزینه نیست ادامه');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 11)');
    });
    test('(۱, ۱۳) «هیچ‌کدام» > پیشنهادِ پاسخ', () {
      final loser = buildSetup('open_offer');
      loser.respond('بله');
      expect(loser.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'پایهٔ بازنده در (1, 13)');

      final winner = buildSetup('open_offer');
      winner.respond('بله گزینه نیست');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 13)');
    });
    test('(۱, ۱۴) «هیچ‌کدام» > «باشه»', () {
      final loser = buildSetup('open_rent');
      loser.respond('بله');
      expect(loser.lastDecision?.candidate.name, '«باشه»',
          reason: 'پایهٔ بازنده در (1, 14)');

      final winner = buildSetup('open_rent');
      winner.respond('بله گزینه نیست');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 14)');
    });
    test('(۱, ۱۵) «هیچ‌کدام» > موضوعِ کنارِ هم', () {
      final loser = buildSetup('open_side');
      loser.respond('جداست');
      expect(loser.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'پایهٔ بازنده در (1, 15)');

      final winner = buildSetup('open_side');
      winner.respond('گزینه نیست جداست');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 15)');
    });
    test('(۱, ۱۶) «هیچ‌کدام» > مهلت', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(loser.lastDecision?.candidate.name, 'مهلت',
          reason: 'پایهٔ بازنده در (1, 16)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 16)');
    });
    test('(۱, ۱۷) «هیچ‌کدام» > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (1, 17)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد ربات هستی');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 17)');
    });
    test('(۱, ۱۸) «هیچ‌کدام» > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (1, 18)');

      final winner = buildSetup('open_rent');
      winner.respond('در این صفحه هیچ گزینه ای وجود ندارد متاسفانه');
      winner.respond('در این صفحه هیچ گزینه ای وجود ندارد متاسفانه');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 18)');
    });
    test('(۱, ۱۹) «هیچ‌کدام» > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (1, 19)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد طلاق ثبت دفترخانه نمیشه');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 19)');
    });
    test('(۱, ۲۰) «هیچ‌کدام» > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (1, 20)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 20)');
    });
    test('(۱, ۲۱) «هیچ‌کدام» > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (1, 21)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد غبن چیست');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 21)');
    });
    test('(۱, ۲۲) «هیچ‌کدام» > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (1, 22)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد قهر جریمه');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 22)');
    });
    test('(۱, ۲۳) «هیچ‌کدام» > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (1, 23)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 23)');
    });
    test('(۱, ۲۴) «هیچ‌کدام» > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (1, 24)');

      final winner = buildSetup('open_rent');
      winner.respond('گزینه‌ای وجود ندارد اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 24)');
    });
    test('(۱, ۲۵) «هیچ‌کدام» > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (1, 25)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 25)');
    });
    test('(۲, ۴) تازه است یا مربوط؟ > کنار گذاشتنِ موضوع', () {
      final loser = buildSetup('open_pending');
      loser.respond('خروج از بحث');
      expect(loser.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'پایهٔ بازنده در (2, 4)');

      final winner = buildSetup('open_pending');
      winner.respond('خروج از همین موضوع قبلی');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 4)');
    });
    test('(۲, ۵) تازه است یا مربوط؟ > ایمنی', () {
      final loser = buildSetup('open_pending');
      loser.respond('الان در خطرم');
      expect(loser.lastDecision?.candidate.name, 'ایمنی',
          reason: 'پایهٔ بازنده در (2, 5)');

      final winner = buildSetup('open_pending');
      winner.respond('مربوط است الان در خطرم');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 5)');
    });
    test('(۲, ۷) تازه است یا مربوط؟ > دربارهٔ برنامه', () {
      final loser = buildSetup('open_pending');
      loser.respond('تاریخچه');
      expect(loser.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'پایهٔ بازنده در (2, 7)');

      final winner = buildSetup('open_pending');
      winner.respond('مربوط است تاریخچه');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 7)');
    });
    test('(۲, ۱۱) تازه است یا مربوط؟ > ادامهٔ حرفِ قبلی', () {
      final loser = buildSetup('open_pend_rest');
      loser.respond('ادامه بده');
      expect(loser.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (2, 11)');

      final winner = buildSetup('open_pend_rest');
      winner.respond('مربوط ادامه');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 11)');
    });
    test('(۲, ۱۳) تازه است یا مربوط؟ > پیشنهادِ پاسخ', () {
      final loser = buildSetup('open_pend_offer');
      loser.respond('نمی‌دانم');
      expect(loser.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'پایهٔ بازنده در (2, 13)');

      final winner = buildSetup('open_pend_offer');
      winner.respond('بله');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 13)');
    });
    test('(۲, ۱۴) تازه است یا مربوط؟ > «باشه»', () {
      final loser = buildSetup('open_pending');
      loser.respond('آره');
      expect(loser.lastDecision?.candidate.name, '«باشه»',
          reason: 'پایهٔ بازنده در (2, 14)');

      final winner = buildSetup('open_pending');
      winner.respond('خیر مربوط است');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 14)');
    });
    test('(۲, ۱۵) تازه است یا مربوط؟ > موضوعِ کنارِ هم', () {
      final loser = buildSetup('open_side');
      loser.respond('جداست');
      expect(loser.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'پایهٔ بازنده در (2, 15)');

      final winner = buildSetup('open_pend_side');
      winner.respond('جداست');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 15)');
    });
    test('(۲, ۱۷) تازه است یا مربوط؟ > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (2, 17)');

      final winner = buildSetup('open_pending');
      winner.respond('مربوط است ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 17)');
    });
    test('(۲, ۱۸) تازه است یا مربوط؟ > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_pending');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (2, 18)');

      final winner = buildSetup('open_pending');
      winner.respond('کتاب دفتر موضوع دیگه است این الان');
      winner.respond('کتاب دفتر موضوع دیگه است این');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 18)');
    });
    test('(۲, ۱۹) تازه است یا مربوط؟ > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_pending');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (2, 19)');

      final winner = buildSetup('open_pending');
      winner.respond('موضوع دیگه طلاق ثبت دفترخانه نمیشه');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 19)');
    });
    test('(۲, ۲۲) تازه است یا مربوط؟ > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (2, 22)');

      final winner = buildSetup('open_pending');
      winner.respond('مربوط است قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 22)');
    });
    test('(۲, ۲۳) تازه است یا مربوط؟ > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (2, 23)');

      final winner = buildSetup('open_pending');
      winner.respond('مربوط است گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 23)');
    });
    test('(۲, ۲۴) تازه است یا مربوط؟ > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (2, 24)');

      final winner = buildSetup('open_pending');
      winner.respond('مربوط است اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 24)');
    });
    test('(۲, ۲۵) تازه است یا مربوط؟ > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('امروز در مورد پرونده سوال دارم');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (2, 25)');

      final winner = buildSetup('open_pending');
      winner.respond('مربوط است');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 25)');
    });
    test('(۳, ۴) دکمهٔ دستهٔ مشکل > کنار گذاشتنِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('انصراف');
      expect(loser.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'پایهٔ بازنده در (3, 4)');

      final winner = buildSetup('asked');
      winner.respond('انصراف');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 4)');
    });
    test('(۳, ۵) دکمهٔ دستهٔ مشکل > ایمنی', () {
      final loser = buildSetup('asked');
      loser.respond('الان در خطرم');
      expect(loser.lastDecision?.candidate.name, 'ایمنی',
          reason: 'پایهٔ بازنده در (3, 5)');

      final winner = buildSetup('asked');
      winner.respond('خروج الان در خطرم');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 5)');
    });
    test('(۳, ۷) دکمهٔ دستهٔ مشکل > دربارهٔ برنامه', () {
      final loser = buildSetup('asked');
      loser.respond('تاریخچه');
      expect(loser.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'پایهٔ بازنده در (3, 7)');

      final winner = buildSetup('asked');
      winner.respond('خروج تاریخچه');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 7)');
    });
    test('(۳, ۸) دکمهٔ دستهٔ مشکل > دعوا و شکایت', () {
      final loser = buildSetup('asked');
      loser.respond('دعوام شد');
      expect(loser.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'پایهٔ بازنده در (3, 8)');

      final winner = buildSetup('asked');
      winner.respond('دعوام شد خروج');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 8)');
    });
    test('(۳, ۱۷) دکمهٔ دستهٔ مشکل > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (3, 17)');

      final winner = buildSetup('asked');
      winner.respond('خروج ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 17)');
    });
    test('(۳, ۱۹) دکمهٔ دستهٔ مشکل > قاعدهٔ ثابت', () {
      final loser = buildSetup('asked');
      loser.respond('طلاق ثبت نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (3, 19)');

      final winner = buildSetup('asked');
      winner.respond('طلاق ثبت نمیشه خروج');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 19)');
    });
    test('(۳, ۲۰) دکمهٔ دستهٔ مشکل > مهلتِ اعتراض', () {
      final loser = buildSetup('asked');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (3, 20)');

      final winner = buildSetup('asked');
      winner.respond('خروج مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 20)');
    });
    test('(۳, ۲۱) دکمهٔ دستهٔ مشکل > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (3, 21)');

      final winner = buildSetup('asked');
      winner.respond('خروج غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 21)');
    });
    test('(۳, ۲۲) دکمهٔ دستهٔ مشکل > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (3, 22)');

      final winner = buildSetup('asked');
      winner.respond('خروج قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 22)');
    });
    test('(۳, ۲۳) دکمهٔ دستهٔ مشکل > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (3, 23)');

      final winner = buildSetup('asked');
      winner.respond('خروج گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 23)');
    });
    test('(۳, ۲۵) دکمهٔ دستهٔ مشکل > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (3, 25)');

      final winner = buildSetup('asked');
      winner.respond('خروج');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 25)');
    });
    test('(۴, ۵) کنار گذاشتنِ موضوع > ایمنی', () {
      final loser = buildSetup('idle');
      loser.respond('الان در خطرم');
      expect(loser.lastDecision?.candidate.name, 'ایمنی',
          reason: 'پایهٔ بازنده در (4, 5)');

      final winner = buildSetup('idle');
      winner.respond('انصراف الان در خطرم');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 5)');
    });
    test('(۴, ۶) کنار گذاشتنِ موضوع > پرسش فرضی', () {
      final loser = buildSetup('idle');
      loser.respond('پرسشها درباره قرارداد بین الف و ب چیست و در قانون چه میشود');
      expect(loser.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'پایهٔ بازنده در (4, 6)');

      final winner = buildSetup('idle');
      winner.respond('خروج از بحث و پرسشها درباره قرارداد بین الف و ب چیست و چه حکمی دارد');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 6)');
    });
    test('(۴, ۷) کنار گذاشتنِ موضوع > دربارهٔ برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('تاریخچه');
      expect(loser.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'پایهٔ بازنده در (4, 7)');

      final winner = buildSetup('idle');
      winner.respond('انصراف تاریخچه');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 7)');
    });
    test('(۴, ۸) کنار گذاشتنِ موضوع > دعوا و شکایت', () {
      final loser = buildSetup('idle');
      loser.respond('دعوام شد');
      expect(loser.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'پایهٔ بازنده در (4, 8)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد انصراف');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 8)');
    });
    test('(۴, ۹) کنار گذاشتنِ موضوع > انتخابِ موضوع', () {
      final loser = buildSetup('choices');
      loser.respond('نه');
      expect(loser.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'پایهٔ بازنده در (4, 9)');

      final winner = buildSetup('choices');
      winner.respond('نه انصراف');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 9)');
    });
    test('(۴, ۱۰) کنار گذاشتنِ موضوع > حدسِ اشتباه', () {
      final loser = buildSetup('open_guessed');
      loser.respond('اشتباه گرفتی');
      expect(loser.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'پایهٔ بازنده در (4, 10)');

      final winner = buildSetup('open_guessed');
      winner.respond('انصراف اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 10)');
    });
    test('(۴, ۱۱) کنار گذاشتنِ موضوع > ادامهٔ حرفِ قبلی', () {
      final loser = buildSetup('open_rest');
      loser.respond('ادامه بده');
      expect(loser.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (4, 11)');

      final winner = buildSetup('open_rest');
      winner.respond('انصراف ادامه');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 11)');
    });
    test('(۴, ۱۳) کنار گذاشتنِ موضوع > پیشنهادِ پاسخ', () {
      final loser = buildSetup('open_offer');
      loser.respond('بله');
      expect(loser.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'پایهٔ بازنده در (4, 13)');

      final winner = buildSetup('open_offer');
      winner.respond('بله انصراف');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 13)');
    });
    test('(۴, ۱۴) کنار گذاشتنِ موضوع > «باشه»', () {
      final loser = buildSetup('open_rent');
      loser.respond('بله');
      expect(loser.lastDecision?.candidate.name, '«باشه»',
          reason: 'پایهٔ بازنده در (4, 14)');

      final winner = buildSetup('open_rent');
      winner.respond('بله انصراف');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 14)');
    });
    test('(۴, ۱۵) کنار گذاشتنِ موضوع > موضوعِ کنارِ هم', () {
      final loser = buildSetup('open_side');
      loser.respond('جداست');
      expect(loser.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'پایهٔ بازنده در (4, 15)');

      final winner = buildSetup('open_side');
      winner.respond('انصراف جداست');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 15)');
    });
    test('(۴, ۱۶) کنار گذاشتنِ موضوع > مهلت', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(loser.lastDecision?.candidate.name, 'مهلت',
          reason: 'پایهٔ بازنده در (4, 16)');

      final winner = buildSetup('idle');
      winner.respond('خروج از بحث مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 16)');
    });
    test('(۴, ۱۷) کنار گذاشتنِ موضوع > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (4, 17)');

      final winner = buildSetup('idle');
      winner.respond('انصراف ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 17)');
    });
    test('(۴, ۱۸) کنار گذاشتنِ موضوع > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (4, 18)');

      final winner = buildSetup('open_rent');
      winner.respond('از این موضوع و بحث قبلی برای امروز بسه');
      winner.respond('خروج از این موضوع و بحث قبلی برای امروز بسه');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 18)');
    });
    test('(۴, ۱۹) کنار گذاشتنِ موضوع > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (4, 19)');

      final winner = buildSetup('idle');
      winner.respond('طلاق ثبت نمیشه انصراف');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 19)');
    });
    test('(۴, ۲۰) کنار گذاشتنِ موضوع > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (4, 20)');

      final winner = buildSetup('idle');
      winner.respond('انصراف مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 20)');
    });
    test('(۴, ۲۱) کنار گذاشتنِ موضوع > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (4, 21)');

      final winner = buildSetup('idle');
      winner.respond('انصراف غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 21)');
    });
    test('(۴, ۲۲) کنار گذاشتنِ موضوع > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (4, 22)');

      final winner = buildSetup('idle');
      winner.respond('انصراف قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 22)');
    });
    test('(۴, ۲۳) کنار گذاشتنِ موضوع > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (4, 23)');

      final winner = buildSetup('idle');
      winner.respond('انصراف گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 23)');
    });
    test('(۴, ۲۴) کنار گذاشتنِ موضوع > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (4, 24)');

      final winner = buildSetup('open_rent');
      winner.respond('انصراف اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 24)');
    });
    test('(۴, ۲۵) کنار گذاشتنِ موضوع > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (4, 25)');

      final winner = buildSetup('idle');
      winner.respond('انصراف');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 25)');
    });
    test('(۵, ۶) ایمنی > پرسش فرضی', () {
      final loser = buildSetup('idle');
      loser.respond('پرسشها درباره قرارداد بین الف و ب چیست و در قانون چه میشود');
      expect(loser.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'پایهٔ بازنده در (5, 6)');

      final winner = buildSetup('idle');
      winner.respond('الان در خطرم و پرسشها درباره قرارداد بین الف و ب چیست و چه میشود');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 6)');
    });
    test('(۵, ۷) ایمنی > دربارهٔ برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('سگم مرده');
      expect(loser.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'پایهٔ بازنده در (5, 7)');

      final winner = buildSetup('idle');
      winner.respond('سگم مرده الان در خطرم');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 7)');
    });
    test('(۵, ۸) ایمنی > دعوا و شکایت', () {
      final loser = buildSetup('idle');
      loser.respond('دعوام شد');
      expect(loser.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'پایهٔ بازنده در (5, 8)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد الان در خطرم');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 8)');
    });
    test('(۵, ۹) ایمنی > انتخابِ موضوع', () {
      final loser = buildSetup('choices');
      loser.respond('نه');
      expect(loser.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'پایهٔ بازنده در (5, 9)');

      final winner = buildSetup('choices');
      winner.respond('نه خودکشی');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 9)');
    });
    test('(۵, ۱۰) ایمنی > حدسِ اشتباه', () {
      final loser = buildSetup('open_guessed');
      loser.respond('اشتباه گرفتی');
      expect(loser.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'پایهٔ بازنده در (5, 10)');

      final winner = buildSetup('open_guessed');
      winner.respond('اشتباه گرفتی الان در خطرم');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 10)');
    });
    test('(۵, ۱۱) ایمنی > ادامهٔ حرفِ قبلی', () {
      final loser = buildSetup('open_rest');
      loser.respond('ادامه بده');
      expect(loser.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (5, 11)');

      final winner = buildSetup('open_rest');
      winner.respond('ادامه الان در خطرم');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 11)');
    });
    test('(۵, ۱۳) ایمنی > پیشنهادِ پاسخ', () {
      final loser = buildSetup('open_offer');
      loser.respond('بله');
      expect(loser.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'پایهٔ بازنده در (5, 13)');

      final winner = buildSetup('open_offer');
      winner.respond('بله الان در خطرم');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 13)');
    });
    test('(۵, ۱۴) ایمنی > «باشه»', () {
      final loser = buildSetup('open_rent');
      loser.respond('بله');
      expect(loser.lastDecision?.candidate.name, '«باشه»',
          reason: 'پایهٔ بازنده در (5, 14)');

      final winner = buildSetup('open_rent');
      winner.respond('بله خودکشی');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 14)');
    });
    test('(۵, ۱۵) ایمنی > موضوعِ کنارِ هم', () {
      final loser = buildSetup('open_side');
      loser.respond('جداست');
      expect(loser.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'پایهٔ بازنده در (5, 15)');

      final winner = buildSetup('open_side');
      winner.respond('جداست الان در خطرم');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 15)');
    });
    test('(۵, ۱۶) ایمنی > مهلت', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(loser.lastDecision?.candidate.name, 'مهلت',
          reason: 'پایهٔ بازنده در (5, 16)');

      final winner = buildSetup('idle');
      winner.respond('الان در خطرم مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 16)');
    });
    test('(۵, ۱۷) ایمنی > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (5, 17)');

      final winner = buildSetup('idle');
      winner.respond('الان در خطرم ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 17)');
    });
    test('(۵, ۱۸) ایمنی > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (5, 18)');

      final winner = buildSetup('open_rent');
      winner.respond('الان در خطر فوری هستم کمک کن من میترسم بسیار');
      winner.respond('الان در خطر فوری هستم کمک کن من میترسم خیلی');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 18)');
    });
    test('(۵, ۱۹) ایمنی > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (5, 19)');

      final winner = buildSetup('idle');
      winner.respond('الان در خطرم طلاق ثبت دفترخانه نمیشه');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 19)');
    });
    test('(۵, ۲۰) ایمنی > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (5, 20)');

      final winner = buildSetup('idle');
      winner.respond('الان در خطرم مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 20)');
    });
    test('(۵, ۲۱) ایمنی > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (5, 21)');

      final winner = buildSetup('idle');
      winner.respond('الان در خطرم غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 21)');
    });
    test('(۵, ۲۲) ایمنی > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (5, 22)');

      final winner = buildSetup('idle');
      winner.respond('الان در خطرم قهر کرده جریمه میشوم؟');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 22)');
    });
    test('(۵, ۲۳) ایمنی > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (5, 23)');

      final winner = buildSetup('idle');
      winner.respond('الان در خطرم گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 23)');
    });
    test('(۵, ۲۴) ایمنی > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (5, 24)');

      final winner = buildSetup('open_rent');
      winner.respond('الان در خطرم اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 24)');
    });
    test('(۵, ۲۵) ایمنی > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (5, 25)');

      final winner = buildSetup('idle');
      winner.respond('الان در خطرم');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 25)');
    });
    test('(۶, ۷) پرسش فرضی > دربارهٔ برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('چت قبلی');
      expect(loser.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'پایهٔ بازنده در (6, 7)');

      final winner = buildSetup('idle');
      winner.respond('چت قبلی پاک شد و پرسشها این است که میان الف و ب چه باید کرد');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 7)');
    });
    test('(۶, ۸) پرسش فرضی > دعوا و شکایت', () {
      final loser = buildSetup('idle');
      loser.respond('دعوام شد');
      expect(loser.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'پایهٔ بازنده در (6, 8)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد و پرسشها این است که میان الف و ب کدام یک مقصر بوده است');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 8)');
    });
    test('(۶, ۱۶) پرسش فرضی > مهلت', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(loser.lastDecision?.candidate.name, 'مهلت',
          reason: 'پایهٔ بازنده در (6, 16)');

      final winner = buildSetup('idle');
      winner.respond('در مهلت رأی ۱۴۰۳/۱/۱ و ۲۰ روز پرسشها این است که میان الف و ب چه میشود');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 16)');
    });
    test('(۶, ۱۷) پرسش فرضی > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (6, 17)');

      final winner = buildSetup('idle');
      winner.respond('پرسشها درباره دسترسی آزاد به اطلاعات بین الف و ب چیست و در قانون چه میشود');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 17)');
    });
    test('(۶, ۱۸) پرسش فرضی > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (6, 18)');

      final winner = buildSetup('open_rent');
      winner.respond('پرسشها این است که میان الف و ب چه قرارداد و تعهدی در جریان بوده');
      winner.respond('پرسشها این است که میان الف و ب چه قرارداد و تعهدی در جریان بوده');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 18)');
    });
    test('(۶, ۱۹) پرسش فرضی > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (6, 19)');

      final winner = buildSetup('idle');
      winner.respond('طلاق ثبت دفترخانه نمیشه و پرسشها این است که میان الف و ب چه میشود');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 19)');
    });
    test('(۶, ۲۰) پرسش فرضی > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (6, 20)');

      final winner = buildSetup('idle');
      winner.respond('در مهلت ابلاغ پرسشها این است که میان الف و ب چه تکلیفی وجود دارد');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 20)');
    });
    test('(۶, ۲۱) پرسش فرضی > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (6, 21)');

      final winner = buildSetup('idle');
      winner.respond('پرسشها درباره غبن بین الف و ب چیست و در قانون چه میشود');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 21)');
    });
    test('(۶, ۲۲) پرسش فرضی > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (6, 22)');

      final winner = buildSetup('idle');
      winner.respond('پرسشها درباره قهر جریمه بین الف و ب چیست و در قانون چه میشود');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 22)');
    });
    test('(۶, ۲۳) پرسش فرضی > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (6, 23)');

      final winner = buildSetup('idle');
      winner.respond('پرسشها درباره گفتگو با برنامه بین الف و ب چیست و در قانون چه میشود');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 23)');
    });
    test('(۶, ۲۴) پرسش فرضی > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (6, 24)');

      final winner = buildSetup('open_rent');
      winner.respond('پرسشها درباره اشتباه گرفتی بین الف و ب چیست و در قانون چه میشود');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 24)');
    });
    test('(۶, ۲۵) پرسش فرضی > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (6, 25)');

      final winner = buildSetup('idle');
      winner.respond('پرسشها درباره قرارداد بین الف و ب چیست و در قانون چه میشود');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 25)');
    });
    test('(۷, ۸) دربارهٔ برنامه > دعوا و شکایت', () {
      final loser = buildSetup('idle');
      loser.respond('دعوام شد');
      expect(loser.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'پایهٔ بازنده در (7, 8)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد تاریخچه');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 8)');
    });
    test('(۷, ۹) دربارهٔ برنامه > انتخابِ موضوع', () {
      final loser = buildSetup('choices');
      loser.respond('نه');
      expect(loser.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'پایهٔ بازنده در (7, 9)');

      final winner = buildSetup('choices');
      winner.respond('نه تاریخچه');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 9)');
    });
    test('(۷, ۱۰) دربارهٔ برنامه > حدسِ اشتباه', () {
      final loser = buildSetup('open_guessed');
      loser.respond('اشتباه گرفتی');
      expect(loser.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'پایهٔ بازنده در (7, 10)');

      final winner = buildSetup('open_guessed');
      winner.respond('اشتباه گرفتی تاریخچه');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 10)');
    });
    test('(۷, ۱۱) دربارهٔ برنامه > ادامهٔ حرفِ قبلی', () {
      final loser = buildSetup('open_rest');
      loser.respond('ادامه بده');
      expect(loser.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (7, 11)');

      final winner = buildSetup('open_rest');
      winner.respond('ادامه تاریخچه');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 11)');
    });
    test('(۷, ۱۳) دربارهٔ برنامه > پیشنهادِ پاسخ', () {
      final loser = buildSetup('open_offer');
      loser.respond('بله');
      expect(loser.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'پایهٔ بازنده در (7, 13)');

      final winner = buildSetup('open_offer');
      winner.respond('بله تاریخچه');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 13)');
    });
    test('(۷, ۱۴) دربارهٔ برنامه > «باشه»', () {
      final loser = buildSetup('open_rent');
      loser.respond('بله');
      expect(loser.lastDecision?.candidate.name, '«باشه»',
          reason: 'پایهٔ بازنده در (7, 14)');

      final winner = buildSetup('open_rent');
      winner.respond('بله تاریخچه');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 14)');
    });
    test('(۷, ۱۵) دربارهٔ برنامه > موضوعِ کنارِ هم', () {
      final loser = buildSetup('open_side');
      loser.respond('جداست');
      expect(loser.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'پایهٔ بازنده در (7, 15)');

      final winner = buildSetup('open_side');
      winner.respond('جداست تاریخچه');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 15)');
    });
    test('(۷, ۱۶) دربارهٔ برنامه > مهلت', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(loser.lastDecision?.candidate.name, 'مهلت',
          reason: 'پایهٔ بازنده در (7, 16)');

      final winner = buildSetup('idle');
      winner.respond('چت قبلی مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 16)');
    });
    test('(۷, ۱۷) دربارهٔ برنامه > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (7, 17)');

      final winner = buildSetup('idle');
      winner.respond('تاریخچه ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 17)');
    });
    test('(۷, ۱۸) دربارهٔ برنامه > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (7, 18)');

      final winner = buildSetup('open_rent');
      winner.respond('چت قبلی من کجا رفته و پاک شد');
      winner.respond('چت قبلی من کجا رفته و پاک شد');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 18)');
    });
    test('(۷, ۱۹) دربارهٔ برنامه > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('غبن فاحش اسقاط');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (7, 19)');

      final winner = buildSetup('idle');
      winner.respond('چت قبلی غبن فاحش اسقاط');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 19)');
    });
    test('(۷, ۲۰) دربارهٔ برنامه > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (7, 20)');

      final winner = buildSetup('idle');
      winner.respond('چت قبلی مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 20)');
    });
    test('(۷, ۲۱) دربارهٔ برنامه > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (7, 21)');

      final winner = buildSetup('idle');
      winner.respond('تاریخچه غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 21)');
    });
    test('(۷, ۲۲) دربارهٔ برنامه > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (7, 22)');

      final winner = buildSetup('idle');
      winner.respond('تاریخچه قهر کرده جریمه میشوم؟');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 22)');
    });
    test('(۷, ۲۳) دربارهٔ برنامه > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (7, 23)');

      final winner = buildSetup('idle');
      winner.respond('تاریخچه گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 23)');
    });
    test('(۷, ۲۴) دربارهٔ برنامه > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (7, 24)');

      final winner = buildSetup('open_rent');
      winner.respond('تاریخچه اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 24)');
    });
    test('(۷, ۲۵) دربارهٔ برنامه > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (7, 25)');

      final winner = buildSetup('idle');
      winner.respond('تاریخچه');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 25)');
    });
    test('(۸, ۹) دعوا و شکایت > انتخابِ موضوع', () {
      final loser = buildSetup('choices');
      loser.respond('نه');
      expect(loser.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'پایهٔ بازنده در (8, 9)');

      final winner = buildSetup('choices');
      winner.respond('نه دعوام شد');
      expect(winner.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'ترکیب برنده در (8, 9)');
    });
    test('(۸, ۱۱) دعوا و شکایت > ادامهٔ حرفِ قبلی', () {
      final loser = buildSetup('idle_rest');
      loser.respond('ادامه بده');
      expect(loser.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (8, 11)');

      final winner = buildSetup('idle_rest');
      winner.respond('ادامه دعوام شد');
      expect(winner.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'ترکیب برنده در (8, 11)');
    });
    test('(۸, ۱۶) دعوا و شکایت > مهلت', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(loser.lastDecision?.candidate.name, 'مهلت',
          reason: 'پایهٔ بازنده در (8, 16)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(winner.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'ترکیب برنده در (8, 16)');
    });
    test('(۸, ۱۷) دعوا و شکایت > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (8, 17)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'ترکیب برنده در (8, 17)');
    });
    test('(۸, ۱۹) دعوا و شکایت > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('غبن فاحش اسقاط');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (8, 19)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد غبن فاحش اسقاط');
      expect(winner.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'ترکیب برنده در (8, 19)');
    });
    test('(۸, ۲۰) دعوا و شکایت > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (8, 20)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'ترکیب برنده در (8, 20)');
    });
    test('(۸, ۲۱) دعوا و شکایت > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (8, 21)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'ترکیب برنده در (8, 21)');
    });
    test('(۸, ۲۲) دعوا و شکایت > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (8, 22)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'ترکیب برنده در (8, 22)');
    });
    test('(۸, ۲۳) دعوا و شکایت > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (8, 23)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'ترکیب برنده در (8, 23)');
    });
    test('(۸, ۲۵) دعوا و شکایت > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (8, 25)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد');
      expect(winner.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'ترکیب برنده در (8, 25)');
    });
    test('(۹, ۱۷) انتخابِ موضوع > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (9, 17)');

      final winner = buildSetup('choices');
      winner.respond('نه ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'ترکیب برنده در (9, 17)');
    });
    test('(۹, ۱۹) انتخابِ موضوع > قاعدهٔ ثابت', () {
      final loser = buildSetup('choices');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (9, 19)');

      final winner = buildSetup('choices');
      winner.respond('نمیخوام ثبت طلاق');
      expect(winner.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'ترکیب برنده در (9, 19)');
    });
    test('(۹, ۲۰) انتخابِ موضوع > مهلتِ اعتراض', () {
      final loser = buildSetup('choices');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (9, 20)');

      final winner = buildSetup('choices');
      winner.respond('نه مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'ترکیب برنده در (9, 20)');
    });
    test('(۹, ۲۱) انتخابِ موضوع > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (9, 21)');

      final winner = buildSetup('choices');
      winner.respond('نه غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'ترکیب برنده در (9, 21)');
    });
    test('(۹, ۲۲) انتخابِ موضوع > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (9, 22)');

      final winner = buildSetup('choices');
      winner.respond('نه قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'ترکیب برنده در (9, 22)');
    });
    test('(۹, ۲۳) انتخابِ موضوع > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (9, 23)');

      final winner = buildSetup('choices');
      winner.respond('نه گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'ترکیب برنده در (9, 23)');
    });
    test('(۹, ۲۵) انتخابِ موضوع > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (9, 25)');

      final winner = buildSetup('choices');
      winner.respond('نه');
      expect(winner.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'ترکیب برنده در (9, 25)');
    });
    test('(۱۰, ۱۱) حدسِ اشتباه > ادامهٔ حرفِ قبلی', () {
      final loser = buildSetup('open_rest');
      loser.respond('ادامه بده');
      expect(loser.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (10, 11)');

      final winner = buildSetup('open_guessed_rest_offer');
      winner.respond('اشتباه گرفتی ادامه');
      expect(winner.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'ترکیب برنده در (10, 11)');
    });
    test('(۱۰, ۱۳) حدسِ اشتباه > پیشنهادِ پاسخ', () {
      final loser = buildSetup('open_guessed_rest_offer');
      loser.respond('بله');
      expect(loser.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'پایهٔ بازنده در (10, 13)');

      final winner = buildSetup('open_guessed_rest_offer');
      winner.respond('بله اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'ترکیب برنده در (10, 13)');
    });
    test('(۱۰, ۱۷) حدسِ اشتباه > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (10, 17)');

      final winner = buildSetup('open_guessed');
      winner.respond('اشتباه گرفتی ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'ترکیب برنده در (10, 17)');
    });
    test('(۱۰, ۱۸) حدسِ اشتباه > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (10, 18)');

      final winner = buildSetup('open_guessed_repeat');
      winner.respond('منظورم این نبود اشتباه گرفتی دوست من');
      expect(winner.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'ترکیب برنده در (10, 18)');
    });
    test('(۱۰, ۱۹) حدسِ اشتباه > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_guessed');
      loser.respond('غبن فاحش اسقاط شرط');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (10, 19)');

      final winner = buildSetup('open_guessed');
      winner.respond('غبن فاحش اسقاط شرط اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'ترکیب برنده در (10, 19)');
    });
    test('(۱۰, ۲۲) حدسِ اشتباه > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (10, 22)');

      final winner = buildSetup('open_guessed');
      winner.respond('اشتباه گرفتی قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'ترکیب برنده در (10, 22)');
    });
    test('(۱۰, ۲۳) حدسِ اشتباه > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (10, 23)');

      final winner = buildSetup('open_guessed');
      winner.respond('اشتباه گرفتی گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'ترکیب برنده در (10, 23)');
    });
    test('(۱۰, ۲۴) حدسِ اشتباه > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (10, 24)');

      final winner = buildSetup('open_guessed');
      winner.respond('اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'ترکیب برنده در (10, 24)');
    });
    test('(۱۰, ۲۵) حدسِ اشتباه > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('امروز در مورد پرونده سوال دارم');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (10, 25)');

      final winner = buildSetup('open_guessed');
      winner.respond('اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'ترکیب برنده در (10, 25)');
    });
    test('(۱۱, ۱۳) ادامهٔ حرفِ قبلی > پیشنهادِ پاسخ', () {
      final loser = buildSetup('open_rest_offer');
      loser.respond('بله');
      expect(loser.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'پایهٔ بازنده در (11, 13)');

      final winner = buildSetup('open_rest_offer');
      winner.respond('ادامه بده');
      expect(winner.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'ترکیب برنده در (11, 13)');
    });
    test('(۱۱, ۱۷) ادامهٔ حرفِ قبلی > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (11, 17)');

      final winner = buildSetup('idle_rest');
      winner.respond('ادامه ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'ترکیب برنده در (11, 17)');
    });
    test('(۱۱, ۱۹) ادامهٔ حرفِ قبلی > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_rest');
      loser.respond('طلاق ثبت نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (11, 19)');

      final winner = buildSetup('open_rest');
      winner.respond('ادامه طلاق ثبت نمیشه');
      expect(winner.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'ترکیب برنده در (11, 19)');
    });
    test('(۱۱, ۲۰) ادامهٔ حرفِ قبلی > مهلتِ اعتراض', () {
      final loser = buildSetup('idle_rest');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (11, 20)');

      final winner = buildSetup('idle_rest');
      winner.respond('ادامه مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'ترکیب برنده در (11, 20)');
    });
    test('(۱۱, ۲۱) ادامهٔ حرفِ قبلی > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (11, 21)');

      final winner = buildSetup('idle_rest');
      winner.respond('ادامه غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'ترکیب برنده در (11, 21)');
    });
    test('(۱۱, ۲۲) ادامهٔ حرفِ قبلی > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (11, 22)');

      final winner = buildSetup('idle_rest');
      winner.respond('ادامه قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'ترکیب برنده در (11, 22)');
    });
    test('(۱۱, ۲۳) ادامهٔ حرفِ قبلی > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (11, 23)');

      final winner = buildSetup('idle_rest');
      winner.respond('ادامه گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'ترکیب برنده در (11, 23)');
    });
    test('(۱۱, ۲۴) ادامهٔ حرفِ قبلی > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (11, 24)');

      final winner = buildSetup('open_rest');
      winner.respond('ادامه اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'ترکیب برنده در (11, 24)');
    });
    test('(۱۱, ۲۵) ادامهٔ حرفِ قبلی > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (11, 25)');

      final winner = buildSetup('idle_rest');
      winner.respond('ادامه بده');
      expect(winner.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'ترکیب برنده در (11, 25)');
    });
    test('(۱۲, ۱۸) تنظیمِ سند > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent_filing14');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (12, 18)');

      final winner = buildSetup('open_rent_filing14');
      winner.respond('تنظیم لایحهٔ دفاع در برابر ادعای خسارت');
      winner.respond('تنظیم لایحهٔ دفاع در برابر ادعای خسارت');
      expect(winner.lastDecision?.candidate.name, 'تنظیمِ سند',
          reason: 'ترکیب برنده در (12, 18)');
    });
    test('(۱۲, ۲۵) تنظیمِ سند > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('اجاره نامه کتبی است');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (12, 25)');

      final winner = buildSetup('open_rent_filing14');
      winner.respond('تنظیم لایحهٔ دفاع در برابر ادعای خسارت');
      expect(winner.lastDecision?.candidate.name, 'تنظیمِ سند',
          reason: 'ترکیب برنده در (12, 25)');
    });
    test('(۱۳, ۱۷) پیشنهادِ پاسخ > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (13, 17)');

      final winner = buildSetup('open_offer');
      winner.respond('بله ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'ترکیب برنده در (13, 17)');
    });
    test('(۱۳, ۱۹) پیشنهادِ پاسخ > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_offer');
      loser.respond('طلاق ثبت نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (13, 19)');

      final winner = buildSetup('open_offer');
      winner.respond('بله طلاق ثبت نمیشه');
      expect(winner.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'ترکیب برنده در (13, 19)');
    });
    test('(۱۳, ۲۲) پیشنهادِ پاسخ > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (13, 22)');

      final winner = buildSetup('open_offer');
      winner.respond('بله قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'ترکیب برنده در (13, 22)');
    });
    test('(۱۳, ۲۳) پیشنهادِ پاسخ > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (13, 23)');

      final winner = buildSetup('open_offer');
      winner.respond('بله گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'ترکیب برنده در (13, 23)');
    });
    test('(۱۳, ۲۴) پیشنهادِ پاسخ > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (13, 24)');

      final winner = buildSetup('open_offer');
      winner.respond('بله اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'ترکیب برنده در (13, 24)');
    });
    test('(۱۳, ۲۵) پیشنهادِ پاسخ > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('امروز در مورد پرونده سوال دارم');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (13, 25)');

      final winner = buildSetup('open_offer');
      winner.respond('بله');
      expect(winner.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'ترکیب برنده در (13, 25)');
    });
    test('(۱۴, ۱۷) «باشه» > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (14, 17)');

      final winner = buildSetup('open_rent');
      winner.respond('بله ربات هستی');
      expect(winner.lastDecision?.candidate.name, '«باشه»',
          reason: 'ترکیب برنده در (14, 17)');
    });
    test('(۱۴, ۱۹) «باشه» > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_rent');
      loser.respond('طلاق ثبت نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (14, 19)');

      final winner = buildSetup('open_rent');
      winner.respond('نمیخوام ثبت طلاق');
      expect(winner.lastDecision?.candidate.name, '«باشه»',
          reason: 'ترکیب برنده در (14, 19)');
    });
    test('(۱۴, ۲۲) «باشه» > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (14, 22)');

      final winner = buildSetup('open_rent');
      winner.respond('بله قهر جریمه');
      expect(winner.lastDecision?.candidate.name, '«باشه»',
          reason: 'ترکیب برنده در (14, 22)');
    });
    test('(۱۴, ۲۳) «باشه» > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (14, 23)');

      final winner = buildSetup('open_rent');
      winner.respond('بله گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, '«باشه»',
          reason: 'ترکیب برنده در (14, 23)');
    });
    test('(۱۴, ۲۴) «باشه» > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (14, 24)');

      final winner = buildSetup('open_rent');
      winner.respond('بله اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, '«باشه»',
          reason: 'ترکیب برنده در (14, 24)');
    });
    test('(۱۴, ۲۵) «باشه» > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('امروز در مورد پرونده سوال دارم');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (14, 25)');

      final winner = buildSetup('open_rent');
      winner.respond('بله');
      expect(winner.lastDecision?.candidate.name, '«باشه»',
          reason: 'ترکیب برنده در (14, 25)');
    });
    test('(۱۵, ۱۷) موضوعِ کنارِ هم > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (15, 17)');

      final winner = buildSetup('open_side');
      winner.respond('جداست ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'ترکیب برنده در (15, 17)');
    });
    test('(۱۵, ۱۹) موضوعِ کنارِ هم > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_side');
      loser.respond('طلاق ثبت نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (15, 19)');

      final winner = buildSetup('open_side');
      winner.respond('طلاق ثبت نمیشه جداست');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'ترکیب برنده در (15, 19)');
    });
    test('(۱۵, ۲۲) موضوعِ کنارِ هم > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (15, 22)');

      final winner = buildSetup('open_side');
      winner.respond('جداست قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'ترکیب برنده در (15, 22)');
    });
    test('(۱۵, ۲۳) موضوعِ کنارِ هم > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (15, 23)');

      final winner = buildSetup('open_side');
      winner.respond('جداست گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'ترکیب برنده در (15, 23)');
    });
    test('(۱۵, ۲۴) موضوعِ کنارِ هم > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (15, 24)');

      final winner = buildSetup('open_side');
      winner.respond('جداست اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'ترکیب برنده در (15, 24)');
    });
    test('(۱۵, ۲۵) موضوعِ کنارِ هم > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('امروز در مورد پرونده سوال دارم');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (15, 25)');

      final winner = buildSetup('open_side');
      winner.respond('جداست');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'ترکیب برنده در (15, 25)');
    });
    test('(۱۶, ۱۷) مهلت > پاسخِ کلیِ مقدم', () {
      final loser = buildSetup('idle');
      loser.respond('ربات هستی');
      expect(loser.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'پایهٔ بازنده در (16, 17)');

      final winner = buildSetup('idle');
      winner.respond('دسترسی آزاد به اطلاعات مهلت ابلاغ ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(winner.lastDecision?.candidate.name, 'مهلت',
          reason: 'ترکیب برنده در (16, 17)');
    });
    test('(۱۶, ۱۹) مهلت > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (16, 19)');

      final winner = buildSetup('idle');
      winner.respond('طلاق ثبت دفترخانه نمیشه مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(winner.lastDecision?.candidate.name, 'مهلت',
          reason: 'ترکیب برنده در (16, 19)');
    });
    test('(۱۶, ۲۰) مهلت > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (16, 20)');

      final winner = buildSetup('idle');
      winner.respond('مهلت ابلاغ ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(winner.lastDecision?.candidate.name, 'مهلت',
          reason: 'ترکیب برنده در (16, 20)');
    });
    test('(۱۶, ۲۱) مهلت > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (16, 21)');

      final winner = buildSetup('idle');
      winner.respond('مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'مهلت',
          reason: 'ترکیب برنده در (16, 21)');
    });
    test('(۱۶, ۲۲) مهلت > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (16, 22)');

      final winner = buildSetup('idle');
      winner.respond('مهلت ابلاغ ۱۴۰۳/۱/۱ ۲۰ روز قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'مهلت',
          reason: 'ترکیب برنده در (16, 22)');
    });
    test('(۱۶, ۲۳) مهلت > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (16, 23)');

      final winner = buildSetup('idle');
      winner.respond('مهلت ابلاغ ۱۴۰۳/۱/۱ ۲۰ روز گفتگو با برنامه');
      expect(winner.lastDecision?.candidate.name, 'مهلت',
          reason: 'ترکیب برنده در (16, 23)');
    });
    test('(۱۶, ۲۵) مهلت > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (16, 25)');

      final winner = buildSetup('idle');
      winner.respond('مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(winner.lastDecision?.candidate.name, 'مهلت',
          reason: 'ترکیب برنده در (16, 25)');
    });
    test('(۱۷, ۱۸) پاسخِ کلیِ مقدم > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (17, 18)');

      final winner = buildSetup('open_rent');
      winner.respond('تو واقعا ربات هستی یا هوش مصنوعی واقعی؟');
      winner.respond('تو واقعا ربات هستی یا هوش مصنوعی واقعی؟');
      expect(winner.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'ترکیب برنده در (17, 18)');
    });
    test('(۱۷, ۱۹) پاسخِ کلیِ مقدم > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (17, 19)');

      final winner = buildSetup('idle');
      winner.respond('ربات هستی طلاق ثبت دفترخانه نمیشه');
      expect(winner.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'ترکیب برنده در (17, 19)');
    });
    test('(۱۷, ۲۰) پاسخِ کلیِ مقدم > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (17, 20)');

      final winner = buildSetup('idle');
      winner.respond('ربات هستی مهلت ابلاغ این نامه');
      expect(winner.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'ترکیب برنده در (17, 20)');
    });
    test('(۱۷, ۲۱) پاسخِ کلیِ مقدم > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (17, 21)');

      final winner = buildSetup('idle');
      winner.respond('ربات هستی غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'ترکیب برنده در (17, 21)');
    });
    test('(۱۷, ۲۲) پاسخِ کلیِ مقدم > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (17, 22)');

      final winner = buildSetup('idle');
      winner.respond('ربات هستی قهر کرده جریمه میشوم؟');
      expect(winner.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'ترکیب برنده در (17, 22)');
    });
    test('(۱۷, ۲۳) پاسخِ کلیِ مقدم > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (17, 23)');

      final winner = buildSetup('idle');
      winner.respond('ربات هستی گفتگو با برنامه چطور است');
      expect(winner.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'ترکیب برنده در (17, 23)');
    });
    test('(۱۷, ۲۴) پاسخِ کلیِ مقدم > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (17, 24)');

      final winner = buildSetup('open_rent');
      winner.respond('ربات هستی اشتباه گرفتی حرفم چیه');
      expect(winner.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'ترکیب برنده در (17, 24)');
    });
    test('(۱۷, ۲۵) پاسخِ کلیِ مقدم > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (17, 25)');

      final winner = buildSetup('idle');
      winner.respond('ربات هستی');
      expect(winner.lastDecision?.candidate.name, 'پاسخِ کلیِ مقدم',
          reason: 'ترکیب برنده در (17, 25)');
    });
    test('(۱۸, ۱۹) تکرارِ حرفِ قبلی > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_rent');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (18, 19)');

      final winner = buildSetup('open_rent');
      winner.respond('طلاق ثبت دفترخانه نمیشه و امتناع میکنه');
      winner.respond('طلاق ثبت دفترخانه نمیشه و امتناع میکنه');
      expect(winner.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'ترکیب برنده در (18, 19)');
    });
    test('(۱۸, ۲۲) تکرارِ حرفِ قبلی > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (18, 22)');

      final winner = buildSetup('open_rent');
      winner.respond('قهر کرده جریمه میشوم و خیلی نگرانم');
      winner.respond('قهر کرده جریمه میشوم و خیلی نگرانم');
      expect(winner.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'ترکیب برنده در (18, 22)');
    });
    test('(۱۸, ۲۳) تکرارِ حرفِ قبلی > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (18, 23)');

      final winner = buildSetup('open_rent');
      winner.respond('گفتگوی من با برنامه الان چطور است دوست من');
      winner.respond('گفتگوی من با برنامه الان چطور است دوست من');
      expect(winner.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'ترکیب برنده در (18, 23)');
    });
    test('(۱۸, ۲۴) تکرارِ حرفِ قبلی > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (18, 24)');

      final winner = buildSetup('open_rent');
      winner.respond('اشتباه گرفتی من در مورد چیز دیگه گفتم');
      winner.respond('اشتباه گرفتی من در مورد چیز دیگه گفتم');
      expect(winner.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'ترکیب برنده در (18, 24)');
    });
    test('(۱۸, ۲۵) تکرارِ حرفِ قبلی > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('امروز در مورد پرونده سوال دارم');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (18, 25)');

      final winner = buildSetup('open_rent');
      winner.respond('این پرونده قدیمی من هنوز حل نشده است');
      winner.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(winner.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'ترکیب برنده در (18, 25)');
    });
    test('(۱۹, ۲۰) قاعدهٔ ثابت > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (19, 20)');

      final winner = buildSetup('idle');
      winner.respond('طلاق ثبت دفترخانه نمیشه مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'ترکیب برنده در (19, 20)');
    });
    test('(۱۹, ۲۱) قاعدهٔ ثابت > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (19, 21)');

      final winner = buildSetup('idle');
      winner.respond('غبن فاحش با شرط اسقاط چیست');
      expect(winner.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'ترکیب برنده در (19, 21)');
    });
    test('(۱۹, ۲۲) قاعدهٔ ثابت > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (19, 22)');

      final winner = buildSetup('idle');
      winner.respond('غبن فاحش با شرط اسقاط قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'ترکیب برنده در (19, 22)');
    });
    test('(۱۹, ۲۳) قاعدهٔ ثابت > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (19, 23)');

      final winner = buildSetup('idle');
      winner.respond('غبن فاحش با شرط اسقاط گفتگوی من با برنامه');
      expect(winner.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'ترکیب برنده در (19, 23)');
    });
    test('(۱۹, ۲۴) قاعدهٔ ثابت > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (19, 24)');

      final winner = buildSetup('open_rent');
      winner.respond('طلاق ثبت دفترخانه نمیشه اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'ترکیب برنده در (19, 24)');
    });
    test('(۱۹, ۲۵) قاعدهٔ ثابت > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (19, 25)');

      final winner = buildSetup('idle');
      winner.respond('طلاق ثبت دفترخانه نمیشه');
      expect(winner.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'ترکیب برنده در (19, 25)');
    });
    test('(۲۰, ۲۱) مهلتِ اعتراض > واژهٔ قانون و پیوند', () {
      final loser = buildSetup('idle');
      loser.respond('غبن چیست');
      expect(loser.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'پایهٔ بازنده در (20, 21)');

      final winner = buildSetup('idle');
      winner.respond('مهلت ابلاغ غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'ترکیب برنده در (20, 21)');
    });
    test('(۲۰, ۲۲) مهلتِ اعتراض > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (20, 22)');

      final winner = buildSetup('idle');
      winner.respond('مهلت ابلاغ قهر کرده جریمه میشوم؟');
      expect(winner.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'ترکیب برنده در (20, 22)');
    });
    test('(۲۰, ۲۳) مهلتِ اعتراض > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (20, 23)');

      final winner = buildSetup('idle');
      winner.respond('مهلت ابلاغ گفتگوی من با برنامه');
      expect(winner.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'ترکیب برنده در (20, 23)');
    });
    test('(۲۰, ۲۵) مهلتِ اعتراض > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (20, 25)');

      final winner = buildSetup('idle');
      winner.respond('مهلت ابلاغ این نامه');
      expect(winner.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'ترکیب برنده در (20, 25)');
    });
    test('(۲۱, ۲۲) واژهٔ قانون و پیوند > هشدارِ قهر', () {
      final loser = buildSetup('idle');
      loser.respond('قهر کرده جریمه میشوم؟');
      expect(loser.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'پایهٔ بازنده در (21, 22)');

      final winner = buildSetup('idle');
      winner.respond('غبن بابت قهر جریمه دارد؟');
      expect(winner.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'ترکیب برنده در (21, 22)');
    });
    test('(۲۱, ۲۳) واژهٔ قانون و پیوند > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (21, 23)');

      final winner = buildSetup('idle');
      winner.respond('گفتگو با برنامه درباره غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'ترکیب برنده در (21, 23)');
    });
    test('(۲۱, ۲۵) واژهٔ قانون و پیوند > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (21, 25)');

      final winner = buildSetup('idle');
      winner.respond('غبن چیست');
      expect(winner.lastDecision?.candidate.name, 'واژهٔ قانون و پیوند',
          reason: 'ترکیب برنده در (21, 25)');
    });
    test('(۲۲, ۲۳) هشدارِ قهر > گفتگو با برنامه', () {
      final loser = buildSetup('idle');
      loser.respond('گفتگوی من با برنامه چطور است');
      expect(loser.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'پایهٔ بازنده در (22, 23)');

      final winner = buildSetup('idle');
      winner.respond('گفتگوی من با برنامه قهر جریمه');
      expect(winner.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'ترکیب برنده در (22, 23)');
    });
    test('(۲۲, ۲۴) هشدارِ قهر > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (22, 24)');

      final winner = buildSetup('open_rent');
      winner.respond('اشتباه گرفتی قهر کرده جریمه میشوم');
      expect(winner.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'ترکیب برنده در (22, 24)');
    });
    test('(۲۲, ۲۵) هشدارِ قهر > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (22, 25)');

      final winner = buildSetup('idle');
      winner.respond('قهر کرده جریمه میشوم؟');
      expect(winner.lastDecision?.candidate.name, 'هشدارِ قهر',
          reason: 'ترکیب برنده در (22, 25)');
    });
    test('(۲۳, ۲۴) گفتگو با برنامه > اصلاحِ موضوع', () {
      final loser = buildSetup('open_rent');
      loser.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(loser.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'پایهٔ بازنده در (23, 24)');

      final winner = buildSetup('open_rent');
      winner.respond('اشتباه گرفتی گفتگوی من با برنامه چطور است');
      expect(winner.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'ترکیب برنده در (23, 24)');
    });
    test('(۲۳, ۲۵) گفتگو با برنامه > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('idle');
      loser.respond('سلام');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (23, 25)');

      final winner = buildSetup('idle');
      winner.respond('گفتگوی من با برنامه چطور است');
      expect(winner.lastDecision?.candidate.name, 'گفتگو با برنامه',
          reason: 'ترکیب برنده در (23, 25)');
    });
    test('(۲۴, ۲۵) اصلاحِ موضوع > پرونده یا پاسخِ کلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('امروز در مورد پرونده سوال دارم');
      expect(loser.lastDecision?.candidate.name, 'پرونده یا پاسخِ کلی',
          reason: 'پایهٔ بازنده در (24, 25)');

      final winner = buildSetup('open_rent');
      winner.respond('اشتباه گرفتی حرفم در مورد چک صیادی بود');
      expect(winner.lastDecision?.candidate.name, 'اصلاحِ موضوع',
          reason: 'ترکیب برنده در (24, 25)');
    });
  });

  group('ناهم‌پوشانی جفت‌های جداگانه (۹۴ جفت)', () {
    test('همهٔ ۲۴ موضوع follow[next] دارند پس (۱۰, ۱۴) در عمل جداست', () {
      for (final Topic t in Advocate.topics) {
        expect(t.follow.containsKey('next'), isTrue, reason: t.id);
      }
    });

    test('عنوان موضوع‌ها حداکثر ۷ واژه است پس انتخاب موضوع (۹) از تکرار (۱۸) جداست', () {
      for (final Topic t in Advocate.topics) {
        expect(Sense.words(Sense.norm(t.title)), lessThanOrEqualTo(7),
            reason: t.title);
      }
    });

    test('برچسب‌های تنظیم سند کوتاه‌اند و با کلیدواژهٔ مسیرهای دیگر تداخل ندارند', () {
      for (var i = 0; i < 16; i++) {
        final chip = rentText('filing${i}_chip');
        expect(chip, isNotEmpty, reason: 'filing$i');
        final n = Sense.norm(chip);
        expect(Sense.words(n), lessThanOrEqualTo(7), reason: chip);
        expect(DraftWords.isLeave(chip), isFalse, reason: chip);
        expect(DraftWords.isComplaintNoOption(chip), isFalse, reason: chip);
        expect(Sense.has(n, 'پرسش|خودکش|تاریخچه|چت قبلی|دعوام|مهلت|طلاق|غبن|قهر|برنامه|ربات'),
            isFalse, reason: chip);
      }
    });

    test('واژه‌شمار دکمه‌های شاخه و انصراف با (۱, ۴) و (۱۸) و (۱۶) هم‌خوان است', () {
      for (final c in ChipTexts.branchChips) {
        expect(Sense.words(Sense.norm(c)), lessThanOrEqualTo(1), reason: c);
      }
      expect(DraftWords.isLeave('گزینه‌ای وجود ندارد'), isFalse);
      expect(Understanding.isRepeat('سلام', 'سلام'), isFalse);
    });
  });
}
