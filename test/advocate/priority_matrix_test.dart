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

/// آزمونِ ماتریس اولویتِ ۲۰ کاندید (۱۹۰ جفت: ۱۱۳ هم‌پوشان + ۷۷ جداگانه).
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

  group('ماتریس جفت‌های هم‌پوشان (۱۱۳ جفت)' , () {
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
    test('(۰, ۱۷) موضوعِ تازه > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (0, 17)');

      final winner = buildSetup('open_rent');
      winner.respond('این پرونده درباره موضوع تازه است الان');
      winner.respond('این پرونده درباره موضوع تازه است');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 17)');
    });
    test('(۰, ۱۸) موضوعِ تازه > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (0, 18)');

      final winner = buildSetup('idle');
      winner.respond('موضوع تازه طلاق ثبت دفترخانه نمیشه');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 18)');
    });
    test('(۰, ۱۹) موضوعِ تازه > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (0, 19)');

      final winner = buildSetup('idle');
      winner.respond('موضوع تازه مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ تازه',
          reason: 'ترکیب برنده در (0, 19)');
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
    test('(۱, ۱۷) «هیچ‌کدام» > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (1, 17)');

      final winner = buildSetup('open_rent');
      winner.respond('در این صفحه هیچ گزینه ای وجود ندارد متاسفانه');
      winner.respond('در این صفحه هیچ گزینه ای وجود ندارد متاسفانه');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 17)');
    });
    test('(۱, ۱۸) «هیچ‌کدام» > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (1, 18)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد طلاق ثبت دفترخانه نمیشه');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 18)');
    });
    test('(۱, ۱۹) «هیچ‌کدام» > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (1, 19)');

      final winner = buildSetup('idle');
      winner.respond('گزینه‌ای وجود ندارد مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, '«هیچ‌کدام»',
          reason: 'ترکیب برنده در (1, 19)');
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
    test('(۲, ۱۷) تازه است یا مربوط؟ > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_pending');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (2, 17)');

      final winner = buildSetup('open_pending');
      winner.respond('کتاب دفتر موضوع دیگه است این الان');
      winner.respond('کتاب دفتر موضوع دیگه است این');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 17)');
    });
    test('(۲, ۱۸) تازه است یا مربوط؟ > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_pending');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (2, 18)');

      final winner = buildSetup('open_pending');
      winner.respond('موضوع دیگه طلاق ثبت دفترخانه نمیشه');
      expect(winner.lastDecision?.candidate.name, 'تازه است یا مربوط؟',
          reason: 'ترکیب برنده در (2, 18)');
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
    test('(۳, ۱۸) دکمهٔ دستهٔ مشکل > قاعدهٔ ثابت', () {
      final loser = buildSetup('asked');
      loser.respond('طلاق ثبت نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (3, 18)');

      final winner = buildSetup('asked');
      winner.respond('طلاق ثبت نمیشه خروج');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 18)');
    });
    test('(۳, ۱۹) دکمهٔ دستهٔ مشکل > مهلتِ اعتراض', () {
      final loser = buildSetup('asked');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (3, 19)');

      final winner = buildSetup('asked');
      winner.respond('خروج مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'دکمهٔ دستهٔ مشکل',
          reason: 'ترکیب برنده در (3, 19)');
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
    test('(۴, ۱۷) کنار گذاشتنِ موضوع > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (4, 17)');

      final winner = buildSetup('open_rent');
      winner.respond('از این موضوع و بحث قبلی برای امروز بسه');
      winner.respond('خروج از این موضوع و بحث قبلی برای امروز بسه');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 17)');
    });
    test('(۴, ۱۸) کنار گذاشتنِ موضوع > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (4, 18)');

      final winner = buildSetup('idle');
      winner.respond('طلاق ثبت نمیشه انصراف');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 18)');
    });
    test('(۴, ۱۹) کنار گذاشتنِ موضوع > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (4, 19)');

      final winner = buildSetup('idle');
      winner.respond('انصراف مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'کنار گذاشتنِ موضوع',
          reason: 'ترکیب برنده در (4, 19)');
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
    test('(۵, ۱۷) ایمنی > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (5, 17)');

      final winner = buildSetup('open_rent');
      winner.respond('الان در خطر فوری هستم کمک کن من میترسم بسیار');
      winner.respond('الان در خطر فوری هستم کمک کن من میترسم خیلی');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 17)');
    });
    test('(۵, ۱۸) ایمنی > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (5, 18)');

      final winner = buildSetup('idle');
      winner.respond('الان در خطرم طلاق ثبت دفترخانه نمیشه');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 18)');
    });
    test('(۵, ۱۹) ایمنی > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (5, 19)');

      final winner = buildSetup('idle');
      winner.respond('الان در خطرم مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'ایمنی',
          reason: 'ترکیب برنده در (5, 19)');
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
    test('(۶, ۱۷) پرسش فرضی > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (6, 17)');

      final winner = buildSetup('open_rent');
      winner.respond('پرسشها این است که میان الف و ب چه قرارداد و تعهدی در جریان بوده');
      winner.respond('پرسشها این است که میان الف و ب چه قرارداد و تعهدی در جریان بوده');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 17)');
    });
    test('(۶, ۱۸) پرسش فرضی > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (6, 18)');

      final winner = buildSetup('idle');
      winner.respond('طلاق ثبت دفترخانه نمیشه و پرسشها این است که میان الف و ب چه میشود');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 18)');
    });
    test('(۶, ۱۹) پرسش فرضی > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (6, 19)');

      final winner = buildSetup('idle');
      winner.respond('در مهلت ابلاغ پرسشها این است که میان الف و ب چه تکلیفی وجود دارد');
      expect(winner.lastDecision?.candidate.name, 'پرسش فرضی',
          reason: 'ترکیب برنده در (6, 19)');
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
    test('(۷, ۱۷) دربارهٔ برنامه > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (7, 17)');

      final winner = buildSetup('open_rent');
      winner.respond('چت قبلی من کجا رفته و پاک شد');
      winner.respond('چت قبلی من کجا رفته و پاک شد');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 17)');
    });
    test('(۷, ۱۸) دربارهٔ برنامه > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('غبن فاحش اسقاط');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (7, 18)');

      final winner = buildSetup('idle');
      winner.respond('چت قبلی غبن فاحش اسقاط');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 18)');
    });
    test('(۷, ۱۹) دربارهٔ برنامه > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (7, 19)');

      final winner = buildSetup('idle');
      winner.respond('چت قبلی مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'دربارهٔ برنامه',
          reason: 'ترکیب برنده در (7, 19)');
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
    test('(۸, ۱۸) دعوا و شکایت > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('غبن فاحش اسقاط');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (8, 18)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد غبن فاحش اسقاط');
      expect(winner.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'ترکیب برنده در (8, 18)');
    });
    test('(۸, ۱۹) دعوا و شکایت > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (8, 19)');

      final winner = buildSetup('idle');
      winner.respond('دعوام شد مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'دعوا و شکایت',
          reason: 'ترکیب برنده در (8, 19)');
    });
    test('(۹, ۱۸) انتخابِ موضوع > قاعدهٔ ثابت', () {
      final loser = buildSetup('choices');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (9, 18)');

      final winner = buildSetup('choices');
      winner.respond('نمیخوام ثبت طلاق');
      expect(winner.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'ترکیب برنده در (9, 18)');
    });
    test('(۹, ۱۹) انتخابِ موضوع > مهلتِ اعتراض', () {
      final loser = buildSetup('choices');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (9, 19)');

      final winner = buildSetup('choices');
      winner.respond('نه مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'انتخابِ موضوع',
          reason: 'ترکیب برنده در (9, 19)');
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
    test('(۱۰, ۱۷) حدسِ اشتباه > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (10, 17)');

      final winner = buildSetup('open_guessed_repeat');
      winner.respond('منظورم این نبود اشتباه گرفتی دوست من');
      expect(winner.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'ترکیب برنده در (10, 17)');
    });
    test('(۱۰, ۱۸) حدسِ اشتباه > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_guessed');
      loser.respond('غبن فاحش اسقاط شرط');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (10, 18)');

      final winner = buildSetup('open_guessed');
      winner.respond('غبن فاحش اسقاط شرط اشتباه گرفتی');
      expect(winner.lastDecision?.candidate.name, 'حدسِ اشتباه',
          reason: 'ترکیب برنده در (10, 18)');
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
    test('(۱۱, ۱۸) ادامهٔ حرفِ قبلی > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_rest');
      loser.respond('طلاق ثبت نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (11, 18)');

      final winner = buildSetup('open_rest');
      winner.respond('ادامه طلاق ثبت نمیشه');
      expect(winner.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'ترکیب برنده در (11, 18)');
    });
    test('(۱۱, ۱۹) ادامهٔ حرفِ قبلی > مهلتِ اعتراض', () {
      final loser = buildSetup('idle_rest');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (11, 19)');

      final winner = buildSetup('idle_rest');
      winner.respond('ادامه مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'ادامهٔ حرفِ قبلی',
          reason: 'ترکیب برنده در (11, 19)');
    });
    test('(۱۲, ۱۷) تنظیمِ سند > تکرارِ حرفِ قبلی', () {
      final loser = buildSetup('open_rent_filing14');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      loser.respond('این پرونده قدیمی من هنوز حل نشده است');
      expect(loser.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'پایهٔ بازنده در (12, 17)');

      final winner = buildSetup('open_rent_filing14');
      winner.respond('تنظیم لایحهٔ دفاع در برابر ادعای خسارت');
      winner.respond('تنظیم لایحهٔ دفاع در برابر ادعای خسارت');
      expect(winner.lastDecision?.candidate.name, 'تنظیمِ سند',
          reason: 'ترکیب برنده در (12, 17)');
    });
    test('(۱۳, ۱۸) پیشنهادِ پاسخ > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_offer');
      loser.respond('طلاق ثبت نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (13, 18)');

      final winner = buildSetup('open_offer');
      winner.respond('بله طلاق ثبت نمیشه');
      expect(winner.lastDecision?.candidate.name, 'پیشنهادِ پاسخ',
          reason: 'ترکیب برنده در (13, 18)');
    });
    test('(۱۴, ۱۸) «باشه» > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_rent');
      loser.respond('طلاق ثبت نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (14, 18)');

      final winner = buildSetup('open_rent');
      winner.respond('نمیخوام ثبت طلاق');
      expect(winner.lastDecision?.candidate.name, '«باشه»',
          reason: 'ترکیب برنده در (14, 18)');
    });
    test('(۱۵, ۱۸) موضوعِ کنارِ هم > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_side');
      loser.respond('طلاق ثبت نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (15, 18)');

      final winner = buildSetup('open_side');
      winner.respond('طلاق ثبت نمیشه جداست');
      expect(winner.lastDecision?.candidate.name, 'موضوعِ کنارِ هم',
          reason: 'ترکیب برنده در (15, 18)');
    });
    test('(۱۶, ۱۸) مهلت > قاعدهٔ ثابت', () {
      final loser = buildSetup('idle');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (16, 18)');

      final winner = buildSetup('idle');
      winner.respond('طلاق ثبت دفترخانه نمیشه مهلت رأی ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(winner.lastDecision?.candidate.name, 'مهلت',
          reason: 'ترکیب برنده در (16, 18)');
    });
    test('(۱۶, ۱۹) مهلت > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (16, 19)');

      final winner = buildSetup('idle');
      winner.respond('مهلت ابلاغ ۱۴۰۳/۱/۱ ۲۰ روز');
      expect(winner.lastDecision?.candidate.name, 'مهلت',
          reason: 'ترکیب برنده در (16, 19)');
    });
    test('(۱۷, ۱۸) تکرارِ حرفِ قبلی > قاعدهٔ ثابت', () {
      final loser = buildSetup('open_rent');
      loser.respond('طلاق ثبت دفترخانه نمیشه');
      expect(loser.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'پایهٔ بازنده در (17, 18)');

      final winner = buildSetup('open_rent');
      winner.respond('طلاق ثبت دفترخانه نمیشه و امتناع میکنه');
      winner.respond('طلاق ثبت دفترخانه نمیشه و امتناع میکنه');
      expect(winner.lastDecision?.candidate.name, 'تکرارِ حرفِ قبلی',
          reason: 'ترکیب برنده در (17, 18)');
    });
    test('(۱۸, ۱۹) قاعدهٔ ثابت > مهلتِ اعتراض', () {
      final loser = buildSetup('idle');
      loser.respond('مهلت ابلاغ این نامه');
      expect(loser.lastDecision?.candidate.name, 'مهلتِ اعتراض',
          reason: 'پایهٔ بازنده در (18, 19)');

      final winner = buildSetup('idle');
      winner.respond('طلاق ثبت دفترخانه نمیشه مهلت ابلاغ');
      expect(winner.lastDecision?.candidate.name, 'قاعدهٔ ثابت',
          reason: 'ترکیب برنده در (18, 19)');
    });
  });

  group('ناهم‌پوشانی جفت‌های جداگانه (۷۷ جفت)', () {
    test('همهٔ ۲۴ موضوع follow[next] دارند پس (۱۰, ۱۴) در عمل جداست', () {
      for (final Topic t in Advocate.topics) {
        expect(t.follow.containsKey('next'), isTrue, reason: t.id);
      }
    });

    test('عنوان موضوع‌ها حداکثر ۷ واژه است پس انتخاب موضوع (۹) از تکرار (۱۷) جداست', () {
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
        expect(Sense.has(n, 'پرسش|خودکش|تاریخچه|چت قبلی|دعوام|مهلت|طلاق|غبن'),
            isFalse, reason: chip);
      }
    });

    test('واژه‌شمار دکمه‌های شاخه و انصراف با (۱, ۴) و (۱۷) و (۱۶) هم‌خوان است', () {
      for (final c in ChipTexts.branchChips) {
        expect(Sense.words(Sense.norm(c)), lessThanOrEqualTo(1), reason: c);
      }
      expect(DraftWords.isLeave('گزینه‌ای وجود ندارد'), isFalse);
      expect(Understanding.isRepeat('سلام', 'سلام'), isFalse);
    });
  });
}
