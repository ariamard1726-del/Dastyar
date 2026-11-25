import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// آزمون موضوع اجاره: فهم سه زبان (کوچه، رسمی، حقوقی)، ثابت‌ماندن محور
/// پرونده، چینش دکمه‌های پیشنهادی و سندهای هر وضعیت.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine, draftTitles: const {
        'demand_money': 'دادخواست مطالبهٔ وجه',
        'defense_brief': 'لایحهٔ دفاعیه',
        'formal_notice': 'اظهارنامهٔ رسمی',
        'eviction': 'دادخواست تخلیهٔ ملک اجاره‌ای',
      });

  String say(Advocate a, String t) {
    final sb = StringBuffer(a.respond(t).text);
    var guard = 0;
    while (a.hasMore && guard < 8) {
      guard++;
      sb.write('\n${a.respond(ChipTexts.moreChip).text}');
    }
    return sb.toString();
  }

  /// پرسش‌های پرونده را با «نمی‌دانم» رد می‌کند تا نوبت به پرسشِ «طرف
  /// مقابل چه می‌گوید؟» برسد.
  AdvocateReply untilReply(Advocate a, String opening) {
    var r = a.respond(opening);
    var guard = 0;
    while (a.file.pending != 'q:reply' && guard < 30) {
      guard++;
      r = a.respond(
          r.chips.contains('نه، لازم نیست') ? 'نه، لازم نیست' : 'نمیدونم');
    }
    return r;
  }

  const depositChip = 'تنظیم دادخواست مطالبهٔ ودیعه';
  const depositBrief = 'تنظیم لایحهٔ مطالبهٔ ودیعه';

  group('سه زبان، یک پرونده', () {
    test('مستأجر و ودیعه: زبان کوچه و زبان رسمی', () {
      for (final t in [
        'صاحبخونه پول پیشمو نمیده',
        'موجر محترم از استرداد ودیعه اینجانب خودداری می نماید',
      ]) {
        final a = fresh();
        a.respond(t);
        expect(a.file.topic, 'rent', reason: t);
        expect(a.file.get('role'), 'tenant', reason: t);
        expect(a.file.get('matter'), 'deposit', reason: t);
        expect(a.unresolved, isEmpty, reason: t);
      }
    });

    test('موجر و تخلیه: زبان کوچه و اصطلاح حقوقی', () {
      for (final t in [
        'مستاجرم خونه رو خالی نمیکنه',
        'مستاجر از تخلیه عین مستاجره خودداری می نماید',
      ]) {
        final a = fresh();
        a.respond(t);
        expect(a.file.topic, 'rent', reason: t);
        expect(a.file.get('role'), 'landlord', reason: t);
        expect(a.file.get('aim'), 'evict', reason: t);
        expect(a.unresolved, isEmpty, reason: t);
      }
    });

    test('موجر و اجارهٔ عقب‌افتاده: «کرایه نداده» و «اجور معوقه»', () {
      for (final t in [
        'مستاجرم سه ماهه کرایه نداده',
        'مستاجر اجور معوقه را پرداخت نمی نماید',
      ]) {
        final a = fresh();
        a.respond(t);
        expect(a.file.topic, 'rent', reason: t);
        expect(a.file.get('role'), 'landlord', reason: t);
        expect(a.file.get('aim'), 'unpaid', reason: t);
        expect(a.unresolved, isEmpty, reason: t);
      }
    });
  });

  group('محور پرونده', () {
    test('اشارهٔ گذرا به بحثی دیگر جواب می‌گیرد ولی پرونده را عوض نمی‌کند', () {
      final a = fresh();
      a.respond('صاحبخونه پول پیشمو نمیده');
      final r = say(a, 'تازه میخواد کرایه رو هم ببره بالا');
      expect(a.file.get('matter'), 'deposit');
      expect(r, contains('یک‌طرفه'));
      expect(a.unresolved, isEmpty);
    });

    test('خواستهٔ مهم‌تر جای خواستهٔ قبلی را می‌گیرد', () {
      final a = fresh();
      a.respond('مستاجرم سه ماهه کرایه نداده');
      expect(a.file.get('aim'), 'unpaid');
      a.respond('خونه رو هم خالی نمیکنه');
      expect(a.file.get('aim'), 'evict');

      final b = fresh();
      b.respond('صاحبخونه میگه باید بلند شی');
      expect(b.file.get('matter'), 'evict');
      b.respond('برام دستور تخلیه اومده');
      expect(b.file.get('matter'), 'order');
    });
  });

  group('پاسخ به وضعیت‌های تازه', () {
    test('مستأجر: عوض‌کردن قفل و دستور تخلیه', () {
      final a = fresh();
      final lock = say(a, 'مستاجرم و صاحبخونه قفل در رو عوض کرده');
      expect(a.file.get('role'), 'tenant');
      expect(lock, contains('تصرف عدوانی'));

      final b = fresh();
      final order = say(b, 'صاحبخونه برام دستور تخلیه گرفته');
      expect(b.file.get('matter'), 'order');
      expect(order, contains('ودیعه'));
      expect(a.unresolved, isEmpty);
      expect(b.unresolved, isEmpty);
    });

    test('موجر: اقدام خودسرانه و واگذاری به غیر', () {
      final a = fresh();
      final lock = say(a, 'مستاجرم بلند نمیشه میتونم قفل رو عوض کنم؟');
      expect(a.file.get('role'), 'landlord');
      expect(lock, contains('دستور تخلیه'));

      final b = fresh();
      final sub = say(b, 'مستاجرم خونه رو به یکی دیگه اجاره داده');
      expect(b.file.get('role'), 'landlord');
      expect(b.file.get('aim'), 'breach');
      expect(sub, contains('حق انتقال به غیر'));
      expect(a.unresolved, isEmpty);
      expect(b.unresolved, isEmpty);
    });
  });

  group('دکمه‌های پیشنهادی', () {
    test('چینش ثابت: پرسشِ همین گفتگو، بعد دادخواست، بعد لایحه', () {
      final a = fresh();
      a.respond('صاحبخونه پول پیشمو نمیده');
      final chips = a.idleChips;
      expect(chips.length, greaterThanOrEqualTo(3));
      expect(chips[0], isNot(startsWith('تنظیم')));
      expect(chips[1], depositChip);
      expect(chips[2], depositBrief);
    });

    test('دادخواست و لایحه کنار جواب‌های پرسش هم دمِ دست می‌ماند', () {
      final a = fresh();
      final r = a.respond('صاحبخونه پول پیشمو نمیده');
      final i = r.chips.indexOf(depositChip);
      expect(i, greaterThanOrEqualTo(0));
      expect(r.chips.indexOf(depositBrief), i + 1);
    });

    test('سند هر وضعیت فرق دارد', () {
      final a = fresh();
      a.respond('مستاجرم خونه رو خالی نمیکنه');
      expect([for (final g in a.filings) g.template],
          ['eviction', 'defense_brief']);
      expect(a.filings.first.chip, 'تنظیم دادخواست تخلیه');

      final b = fresh();
      b.respond('مستاجرم سه ماهه کرایه نداده');
      expect(b.filings.first.template, 'demand_money');
      expect(b.filings.first.chip, 'تنظیم دادخواست مطالبهٔ اجاره‌بها');

      // تا معلوم نشده دعوا سرِ چیست، سندی پیشنهاد نمی‌شود.
      final c = fresh();
      c.respond('با صاحبخونه سر اجاره به مشکل خوردم');
      expect(c.filings, isEmpty);
    });

    test('لمس دکمهٔ سند: متن پیشنهادی از واقعیت‌های همین پرونده می‌آید', () {
      final a = fresh();
      a.respond('صاحبخونه پول پیشمو نمیده');
      a.respond('آره قرارداد تموم شده، یه ماهه خونه رو خالی کردم');
      final r = a.respond(depositChip);
      expect(a.offeredDraft, 'demand_money');
      expect(r.chips, contains('بله، بنویس'));
      expect(a.offeredDraft, 'demand_money');
      final fill = a.fillFor('demand_money');
      expect(fill['basis_detail'], contains('ودیعه'));
      expect(fill['basis_detail'], contains('تخلیه کرده'));
      expect(a.file.topic, 'rent');
      expect(a.unresolved, isEmpty);
    });

    test('تخلیه‌ای که پایه ندارد پیشنهاد نمی‌شود؛ طلب اجاره جایش می‌آید', () {
      final a = fresh();
      a.respond('مستاجرم سه ماهه کرایه نداده');
      a.respond('خونه رو هم خالی نمیکنه');
      expect(a.file.get('aim'), 'evict');
      expect(a.filings.first.template, 'eviction');
      a.respond('نه هنوز مونده');
      a.respond('نه، چنین شرطی نیست');
      expect(a.file.no('ended'), isTrue);
      expect(a.file.no('clause'), isTrue);
      expect([for (final g in a.filings) g.chip], [
        'تنظیم دادخواست مطالبهٔ اجاره‌بها',
        'تنظیم لایحهٔ مطالبهٔ اجاره‌بها',
      ]);
      expect(a.fillFor('defense_brief')['subject'], contains('اجاره‌بها'));
    });
  });

  group('حرفی که به محور پرونده می‌خورد بی‌جواب نمی‌ماند', () {
    test('دستور تخلیه آمده و ودیعه پس داده نشده', () {
      final a = fresh();
      say(a, 'صاحبخونه برام دستور تخلیه گرفته');
      final r = say(a, 'هنوز پول پیشمو نداده');
      expect(a.file.get('matter'), 'order');
      expect(r, contains('دایرهٔ اجرا'));
      expect(r, contains('ماده ۴ قانون روابط موجر و مستأجر'));
      expect(r, isNot(contains('همین را در نظر گرفته‌ام')));
      expect(a.unresolved, isEmpty);
    });

    test('خسارت به ملک با بحثِ وسایلِ جامانده قاطی نمی‌شود', () {
      final a = fresh();
      final r = a.respond('مستاجرم خونه رو داغون کرده و گذاشته رفته');
      expect(a.file.get('aim'), 'damage');
      expect(a.file.get('aim'), 'damage');
      expect(r.chips, isNot(contains('به ملک خسارت زده')));
      final b = fresh();
      final g = say(b, 'مستاجرم رفته و وسایلش مونده تو خونه');
      expect(g, contains('وسایل'));
    });

    test('وقتی گفته «قبول نمی‌کند»، دوباره نمی‌پرسم او چه گفت', () {
      final a = fresh();
      final r = a.respond(
          'میخوام قبل از پایان قرارداد بلند شم صاحبخونه قبول نمیکنه');
          expect(a.file.get('matter'), 'leave');
      expect(a.file.get('matter'), 'leave');
    });
  });

  group('طرف مقابل چه می‌گوید', () {
    test('پرسش به زبانِ همان دعواست و بهانه‌های همان وضعیت را پیش می‌گذارد', () {
      final a = fresh();
      final r = untilReply(a, 'صاحبخونه پول پیشمو نمیده');
      expect(a.file.pending, 'q:reply');
      expect(r.chips, isNotEmpty);
      expect(
          r.chips,
          containsAll(
              ['می‌گوید پول ندارم', 'می‌گوید صبر کن مستأجر جدید بیاید']));
      final s = say(a, 'می‌گوید پول ندارم');
      expect(s, contains('ماده ۲۷۷ قانون مدنی'));
      expect(a.unresolved, isEmpty);
    });

    test('هیچ گزینه‌ای بی‌جوابِ حقوقی نمی‌ماند', () {
      for (final open in [
        'صاحبخونه پول پیشمو نمیده',
        'صاحبخونه میخواد بیرونم کنه',
        'صاحبخونه آبگرمکن خراب رو تعمیر نمیکنه',
        'مستاجرم خونه رو خالی نمیکنه',
        'مستاجرم سه ماهه کرایه نداده',
        'مستاجرم خونه رو داغون کرده و گذاشته رفته',
      ]) {
        final probe = fresh();
        final r = untilReply(probe, open);
        expect(probe.file.pending, 'q:reply', reason: open);
        final options = [
          for (final c in r.chips)
            if (c.startsWith('می‌گوید') ||
                c == 'جواب نمی‌دهد' ||
                c == 'دلیلی نمی‌گوید')
              c,
        ];
        expect(options.length, greaterThanOrEqualTo(3), reason: open);
        for (final c in options) {
          final a = fresh();
          untilReply(a, open);
          final s = say(a, c);
          expect(s, contains(RegExp('(?:ماده|مواد) [۰-۹]')),
              reason: '$open / $c');
          expect(s, isNot(contains('کنار بقیهٔ ماجرا یادداشت کردم')),
              reason: '$open / $c');
          expect(a.unresolved, isEmpty, reason: '$open / $c');
        }
      }
    });

    test('وقتی دستور تخلیه آمده، نمی‌پرسم موجر چه می‌گوید', () {
      final a = fresh();
      var r = a.respond('صاحبخونه برام دستور تخلیه گرفته');
      expect(a.file.get('matter'), 'order');
      for (var i = 0; i < 20; i++) {
        expect(a.file.pending, isNot('q:reply'), reason: 'نوبت $i');
        expect(a.file.pending, isNot('q:reply'), reason: 'نوبت $i');
        expect(r.chips, isNot(contains('انکار می‌کند')), reason: 'نوبت $i');
        if (a.file.covered.contains('q:goal')) break;
        r = a.respond(
            r.chips.contains('نه، لازم نیست') ? 'نه، لازم نیست' : 'نمیدونم');
      }
      expect(a.file.covered, contains('q:reply'));
    });

    test('«نمی‌دانم» در جوابِ پرسشِ باز، حرفِ تازه حساب نمی‌شود', () {
      final a = fresh();
      untilReply(a, 'صاحبخونه پول پیشمو نمیده');
      final r = a.respond('نمیدونم');
      expect(r.chips, isNotEmpty);
      expect(a.file.pending, 'q:goal');
      expect(a.file.pending, 'q:goal');
      final g = a.respond('نمیدونم');
      expect(r.chips, isNotEmpty);
      expect(a.file.pending, 'q:goal');
    });

    test('خرابیِ خانهٔ اجاره‌ای با زبان کوچه هم پروندهٔ اجاره باز می‌کند', () {
      for (final open in [
        'صاحبخونه آبگرمکن خراب رو تعمیر نمیکنه',
        'صاحبخونه کولر رو درست نمیکنه',
        'خونه اجاره ای سقفش چکه میکنه',
      ]) {
        final a = fresh();
        a.respond(open);
        expect(a.file.topic, 'rent', reason: open);
      }
    });

    test('نقلِ حرفِ مستأجر، موجر را مستأجر نمی‌کند', () {
      final a = fresh();
      a.respond('مستاجرم خونه رو خالی نمیکنه');
      final r = say(a, 'میگه اول پول پیشمو بده');
      expect(a.file.get('role'), 'landlord');
      expect(r, contains('هم‌زمان'));
      say(a, 'میگه از پول پیش کم کن');
      expect(a.file.get('role'), 'landlord');
      // ولی حرفِ صریحِ خودش نقش را عوض می‌کند.
      a.respond('نه، من مستاجر هستم');
      expect(a.file.get('role'), 'tenant');
    });
  });

  group('پرسش‌های تازهٔ اجاره', () {
    test('مستأجر: خرجِ ملک، جریمهٔ قرارداد و قراردادِ بی‌مدت', () {
      final a = fresh();
      a.respond('صاحبخونه پول پیشمو نمیده');
      expect(say(a, 'کابینت زدم پولش رو میده؟'),
          contains('ماده ۵۰۲ قانون مدنی'));
      expect(say(a, 'تو قرارداد جریمه دیرکرد روزانه نوشتیم'),
          contains('ماده ۲۳۰ قانون مدنی'));
      expect(
          say(a, 'مدت قرارداد رو ننوشتیم'), contains('ماده ۵۰۱ قانون مدنی'));
      expect(a.file.get('matter'), 'deposit');
      expect(a.unresolved, isEmpty);
    });

    test('مستأجر: بهانهٔ «خودم می‌خواهم بنشینم» و ملکی که تحویل نمی‌شود', () {
      final a = fresh();
      a.respond('صاحبخونه میخواد بیرونم کنه');
      final own = say(a, 'میگه پسرم میخواد ازدواج کنه خونه رو لازم داره');
      expect(own, contains('نیاز شخصی'));
      expect(a.file.get('matter'), 'evict');

      final b = fresh();
      final d = say(b, 'مستاجرم و صاحبخونه خونه رو تحویل نمیده');
      expect(b.file.get('role'), 'tenant');
      // تحویل‌ندادن خودش یک محور است؛ دیگر نمی‌پرسم «اختلاف سرِ چیست؟».
      expect(b.file.get('matter'), 'deliver');
      expect(d, contains('ماده ۴۷۶ قانون مدنی'));
      expect(d, isNot(contains('اختلافتان با موجر سرِ چیست')));
      expect(say(b, 'قدم بعدی چیست؟'), contains('تحویل‌گرفتن ملک'));
      expect(a.unresolved, isEmpty);
      expect(b.unresolved, isEmpty);
    });

    test('موجر: ضامن، ادعای پرداخت و تغییرِ بی‌اجازه', () {
      final a = fresh();
      a.respond('مستاجرم سه ماهه کرایه نداده');
      expect(say(a, 'ضامنش رو میتونم طرف دعوا کنم؟'),
          contains('مواد ۴۹۴ و ۴۹۵ قانون مدنی'));
      expect(say(a, 'میگه نقدی دادم ولی رسید نداره'),
          contains('ماده ۱۹۸ قانون آیین دادرسی'));
      expect(say(a, 'بدون اجازه تو حیاط دیوار کشیده'),
          contains('ماده ۵۰۳ قانون مدنی'));
      expect(a.file.get('role'), 'landlord');
      expect(a.file.get('aim'), 'unpaid');
      expect(a.unresolved, isEmpty);
    });
  });
}
