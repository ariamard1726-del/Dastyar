import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/dialogue/conversation_memory.dart';

void main() {
  group('استخراج مبلغ', () {
    SlotValue? a(String t) => DialogueStateManager.extractAmount(t);

    test('عدد + واحد + ارز', () {
      final v = a('50 میلیون تومان قرض دادم')!;
      expect(v.value, 50000000);
      expect(v.display, '۵۰ میلیون تومان');
    });

    test('ارقام فارسی و عربی', () {
      expect(a('۵۰ میلیون تومان')!.value, 50000000);
      expect(a('٥٠ ميليون تومان')!.value, 50000000);
    });

    test('عدد با حروف', () {
      expect(a('پنجاه میلیون تومان')!.value, 50000000);
      expect(a('دویست و پنجاه هزار تومان')!.value, 250000);
      expect(a('یک میلیارد و سیصد میلیون')!.value, 1300000000);
      expect(a('سه صد هزار تومان')!.value, 300000);
    });

    test('نیم و اعشار', () {
      expect(a('یک و نیم میلیون تومان')!.value, 1500000);
      expect(a('2.5 میلیون')!.value, 2500000);
      expect(a('۲٫۵ میلیون')!.value, 2500000);
      expect(a('دو میلیون و نیم')!.value, 2500000);
    });

    test('جداکنندهٔ هزارگان و چسبیدن واحد به عدد', () {
      expect(a('50,000,000 تومان')!.value, 50000000);
      expect(a('۵۰٬۰۰۰٬۰۰۰ تومان')!.value, 50000000);
      expect(a('50میلیون')!.value, 50000000);
      expect(a('۵۰۰ هزار‌تومان')!.value, 500000);
    });

    test('ریال به تومان تبدیل می‌شود', () {
      final v = a('۵۰۰ هزار ریال')!;
      expect(v.value, 50000);
      expect(v.display, contains('ریال'));
      expect(v.display, contains('۵۰ هزار تومان'));
    });

    test('نمایش مرکب', () {
      expect(a('1500000 تومان')!.display, '۱ میلیون و ۵۰۰ هزار تومان');
    });

    test('عدد بی‌واحد، تاریخ یا مدت مبلغ نیست', () {
      expect(a('سه ماه پیش'), isNull);
      expect(a('۱۵ آبان'), isNull);
      expect(a('نه، مدرکی ندارم'), isNull);
      expect(a('ماده 10 قانون'), isNull);
    });
  });

  group('استخراج تاریخ', () {
    SlotValue? d(String t) => DialogueStateManager.extractDate(t);

    test('جلالی عددی', () {
      final v = d('در تاریخ 1403/08/15 پول را دادم')!;
      expect(v.value, 14030815);
      expect(v.display, '۱۵ آبان ۱۴۰۳');
      expect(d('۱۴۰۲-۱۲-۰۱')!.value, 14021201);
    });

    test('تاریخ نامعتبر رد می‌شود', () {
      expect(d('1403/13/01'), isNull);
      expect(d('1403/08/31'), isNull);
    });

    test('با نام ماه', () {
      expect(d('۱۵ آبان ۱۴۰۳')!.value, 14030815);
      expect(d('سوم: 3 دی ماه')!.display, '۳ دی');
      expect(d('اسفند ۱۴۰۲')!.value, 14021200);
    });

    test('نسبی', () {
      expect(d('دیروز کتکم زد')!.value, 1);
      expect(d('ماه پیش')!.display, 'ماه پیش');
      expect(d('سه ماه پیش')!.value, 90);
      expect(d('2 هفته قبل')!.value, 14);
      expect(d('بیست و پنج روز پیش')!.value, 25);
      expect(d('چند ماه پیش')!.display, 'چند ماه پیش');
      expect(d('پارسال')!.value, 365);
    });
  });

  group('واژه‌نامه‌ها', () {
    test('مدرک', () {
      expect(DialogueStateManager.extractProof('فیش دارم')!.raw, 'bank_slip');
      expect(DialogueStateManager.extractProof('فقط پیام واتساپ دارم')!.raw,
          'messages');
      final multi =
          DialogueStateManager.extractProof('هم چک دارم هم شاهد')!;
      expect(multi.raw, 'cheque,witness');
      expect(DialogueStateManager.extractProof('مدرکی ندارم')!.raw, 'none');
    });

    test('نوع اتفاق', () {
      final v = DialogueStateManager.extractIncident('دیروز کتکم زد')!;
      expect(v.raw, 'assault');
      expect(v.display, 'ضرب و شتم');
      expect(DialogueStateManager.extractIncident('تهديدم كرد')!.raw, 'threat');
    });

    test('وضعیت درآمد', () {
      expect(DialogueStateManager.extractIncomeStatus('الان بیکارم')!.raw,
          'unemployed');
      expect(DialogueStateManager.extractIncomeStatus('هیچ درآمدی ندارم')!.raw,
          'no_income');
    });
  });

  group('DialogueStateManager', () {
    test('جریان کامل مطالبهٔ پول با تأیید اسلات قبلی', () {
      final m = DialogueStateManager(intent: 'demand_money');
      final f = m.extractAndUpdate('دوستم 50 میلیون تومان قرض گرفته');
      expect(f.keys, [DialogueStateManager.amount]);
      final q1 = m.getNextQuestion()!;
      expect(q1, startsWith('متوجه شدم، مبلغ ۵۰ میلیون تومان ثبت شد. حالا '));
      expect(q1, contains('مدرک'));
      expect(m.pendingSlot, DialogueStateManager.proof);

      m.extractAndUpdate('فیش واریز دارم');
      final q2 = m.getNextQuestion()!;
      expect(q2, contains('مدرک فیش واریز بانکی ثبت شد'));
      expect(m.pendingSlot, DialogueStateManager.date);

      m.extractAndUpdate('یادم نیست');
      expect(m.slot(DialogueStateManager.date)!.raw, 'unknown');
      expect(m.isComplete, isTrue);
      expect(m.getNextQuestion(), contains('اطلاعات اصلی پرونده کامل شد'));
      expect(m.getNextQuestion(), isNull);
    });

    test('ترتیب اسلات‌های شکایت: نوع اتفاق، تاریخ، مدرک', () {
      final m = DialogueStateManager(intent: 'complaint');
      expect(m.getNextQuestion(), contains('چه اتفاقی'));
      m.extractAndUpdate('دیروز کتکم زد');
      final q = m.getNextQuestion()!;
      expect(q, contains('نوع اتفاق ضرب و شتم'));
      expect(q, contains('تاریخ دیروز'));
      expect(q, contains('ثبت شدند'));
      expect(m.pendingSlot, DialogueStateManager.proof);
      m.extractAndUpdate('نه');
      expect(m.slot(DialogueStateManager.proof)!.raw, 'none');
    });

    test('اعسار: مبلغ و وضعیت درآمد', () {
      final m = DialogueStateManager(intent: 'insolvency');
      m.extractAndUpdate('محکوم به پرداخت دویست میلیون تومان شده‌ام و بیکارم');
      expect(m.isComplete, isTrue);
      expect(m.slot(DialogueStateManager.amount)!.value, 200000000);
      expect(m.slot(DialogueStateManager.incomeStatus)!.raw, 'unemployed');
    });

    test('پاسخ عددی کوتاه به پرسش مبلغ', () {
      final m = DialogueStateManager(intent: 'insolvency');
      m.getNextQuestion();
      m.extractAndUpdate('۸۰۰۰۰۰۰۰');
      expect(m.slot(DialogueStateManager.amount)!.value, 80000000);
    });

    test('تکرار پرسش، جملهٔ دیگری می‌گوید و چرخه قطعی است', () {
      final m = DialogueStateManager(intent: 'demand_money');
      final a = m.getNextQuestion();
      final b = m.getNextQuestion();
      final c = m.getNextQuestion();
      final d = m.getNextQuestion();
      expect({a, b, c}.length, 3);
      expect(d, a);
      final m2 = DialogueStateManager(intent: 'demand_money');
      expect(m2.getNextQuestion(), a);
    });

    test('تأییدها چرخشی‌اند', () {
      final m = DialogueStateManager(intent: 'demand_money');
      m.extractAndUpdate('50 میلیون تومان');
      expect(m.getNextQuestion(), startsWith('متوجه شدم،'));
      m.extractAndUpdate('چک دارم');
      expect(m.getNextQuestion(), startsWith('بسیار خب،'));
    });

    test('بدون قصد پرسشی نیست و اسلات‌ها با reset پاک می‌شوند', () {
      final m = DialogueStateManager();
      m.extractAndUpdate('50 میلیون تومان');
      expect(m.getNextQuestion(), isNull);
      m.setIntent('demand_money');
      expect(m.slot(DialogueStateManager.amount), isNotNull);
      m.reset();
      expect(m.slots, isEmpty);
    });

    test('اصلاح مقدار توسط کاربر', () {
      final m = DialogueStateManager(intent: 'demand_money');
      m.extractAndUpdate('50 میلیون تومان');
      final f = m.extractAndUpdate('ببخشید، 60 میلیون تومان بود');
      expect(f[DialogueStateManager.amount]!.value, 60000000);
      expect(m.extractAndUpdate('60 میلیون تومان'), isEmpty);
    });
  });
}
