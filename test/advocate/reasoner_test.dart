import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/reasoner.dart';
import 'package:dastyar/domain/advocate/topics_life.dart';

/// آزمون استدلال: کدام ادعا روی میز است، هر شرط چه وضعی دارد، و پرسش بعدی
/// کدام است. بخش اول فقط منطق را می‌سنجد (بدون متن)؛ بخش دوم گفتگو را.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  CaseFile file(Map<String, String> facts) {
    final f = CaseFile()..topic = 'labor';
    f.facts.addAll(facts);
    return f;
  }

  List<String> labels(CaseFile f) =>
      [for (final v in Reasoner.assess(laborTopic, f)) v.claim.label];

  ClaimView view(CaseFile f, String label) => Reasoner.assess(laborTopic, f)
      .firstWhere((v) => v.claim.label == label);

  List<Slot> askable(CaseFile f) => [
        for (final s in laborTopic.slots)
          if (s.ask.isNotEmpty &&
              !f.touched(s.id) &&
              (s.when == null || s.when!(f)))
            s,
      ];

  String? next(CaseFile f) =>
      Reasoner.nextQuestion(laborTopic, f, askable(f))?.id;

  group('ادعاهای روی میز', () {
    test('اخراج: اخراج، سنوات و بیمه مطرح است؛ حقوق معوق نه', () {
      expect(labels(file({'event': 'fired'})),
          ['اخراج', 'سنوات', 'بیمهٔ ردنشده']);
    });

    test('اخراج با حقوقِ نگرفته: هر چهار ادعا', () {
      expect(labels(file({'event': 'fired', 'owed': 'yes'})),
          ['اخراج', 'حقوق معوق', 'سنوات', 'بیمهٔ ردنشده']);
    });

    test('کسی که بیمه بوده ادعای بیمه ندارد', () {
      expect(labels(file({'event': 'unpaid', 'insured': 'yes'})),
          ['حقوق معوق', 'سنوات']);
    });
  });

  group('سنجش شرط‌ها', () {
    test('اخراج بدون اخطار، بدون امضا، وسط قرارداد: محکم', () {
      final v = view(
        file({
          'event': 'fired',
          'contract': 'yes',
          'signed': 'no',
          'expired': 'no',
          'warned': 'no',
        }),
        'اخراج',
      );
      expect(v.standing, Standing.strong);
      expect(v.met, 4);
    });

    test('تمام‌شدن مدت قرارداد اخراج نیست', () {
      final v = view(
        file({'event': 'fired', 'contract': 'yes', 'expired': 'yes'}),
        'اخراج',
      );
      expect(v.standing, Standing.weak);
      expect(v.failed, [3]);
    });

    test('امضای استعفا ادعای اخراج را سست می‌کند ولی سنوات را نه', () {
      final f = file({
        'event': 'fired',
        'contract': 'yes',
        'signed': 'yes',
        'months': '36',
      });
      expect(view(f, 'اخراج').standing, Standing.weak);
      expect(view(f, 'سنوات').standing, Standing.strong);
    });

    test('تا وقتی سر کار است سنوات قابل‌مطالبه نیست', () {
      final f = file({
        'event': 'unpaid',
        'contract': 'yes',
        'working': 'yes',
        'months': '60',
      });
      expect(view(f, 'سنوات').standing, Standing.weak);
      expect(view(f, 'سنوات').failed, [2]);
    });

    test('بدون قرارداد و بیمه، شاهد رابطهٔ کاری را ثابت می‌کند', () {
      final f = file({'event': 'unpaid', 'contract': 'no', 'insured': 'no'});
      expect(view(f, 'حقوق معوق').elements.first.holds, isNull);
      f.facts['proof'] = 'yes';
      expect(view(f, 'حقوق معوق').elements.first.holds, isTrue);
      f.facts['proof'] = 'no';
      expect(view(f, 'حقوق معوق').standing, Standing.weak);
    });

    test('«نمی‌دانم» شرط را نامعلوم نگه می‌دارد، نه برقرار و نه رد', () {
      final f = file({'event': 'fired', 'contract': 'yes', 'warned': '?'});
      final v = view(f, 'اخراج');
      expect(v.elements[3].holds, isNull);
      expect(v.standing, Standing.open);
    });

    test('هر شرط دست‌کم یک مادهٔ قانون را نشان می‌دهد یا دلیلش را می‌گوید', () {
      for (final c in laborTopic.claims) {
        expect(c.label, isNotEmpty);
        for (final e in c.elements) {
          expect(e.needs, isNotEmpty, reason: e.text);
        }
        final cited = c.elements.any((e) => e.text.contains('[[')) ||
            c.win(file({'months': '24'})).contains('[[');
        expect(cited, isTrue, reason: c.label);
      }
    });
  });

  group('پرسش بعدی', () {
    test('پیش از هر چیز می‌پرسد چه اتفاقی افتاده', () {
      expect(next(file({})), 'event');
    });

    test('در اخراج، اول اثبات رابطهٔ کاری و بعد شرط‌های خودِ اخراج', () {
      final f = file({'event': 'fired'});
      expect(next(f), 'contract');
      f.facts['contract'] = 'yes';
      expect(next(f), 'signed');
      f.facts['signed'] = 'no';
      expect(next(f), 'expired');
      f.facts['expired'] = 'no';
      expect(next(f), 'warned');
      f.facts['warned'] = 'no';
      // ادعای اصلی روشن شد؛ نوبت سنوات است.
      expect(next(f), 'months');
    });

    test('وقتی قرارداد نیست سراغ بیمه و بعد شاهد می‌رود', () {
      final f = file({'event': 'unpaid', 'contract': 'no'});
      expect(next(f), 'insured');
      f.facts['insured'] = 'no';
      expect(next(f), 'proof');
    });

    test('ادعایی که رد شده دیگر پرسشی نمی‌خواهد', () {
      final f = file({'event': 'fired', 'contract': 'yes', 'expired': 'yes'});
      // اخراج سست شده؛ «اخطار» و «امضا» دیگر برای آن وزنی ندارند.
      final w = Reasoner.weights(laborTopic, f);
      expect(w.containsKey('warned'), isFalse);
      expect(next(f), 'months');
    });

    test('موضوعی که شرط‌هایش به پرسش گره نخورده همان ترتیب قبلی را دارد', () {
      for (final t in Advocate.topics) {
        if (t.id == 'labor') continue;
        final f = CaseFile()..topic = t.id;
        final a = [
          for (final s in t.slots)
            if (s.ask.isNotEmpty && (s.when == null || s.when!(f))) s,
        ];
        if (a.isEmpty) continue;
        expect(Reasoner.nextQuestion(t, f, a)?.id, a.first.id, reason: t.id);
      }
    });
  });

  group('گفتگو', () {
    late KnowledgeEngine engine;

    setUpAll(() async {
      engine = KnowledgeEngine();
      await engine.load();
    });

    Advocate fresh() => Advocate(engine, draftTitles: const {});

    String say(Advocate a, String t) {
      final sb = StringBuffer(a.respond(t).text);
      var guard = 0;
      while (a.hasMore && guard < 8) {
        guard++;
        sb.write('\n${a.respond(Advocate.moreChip).text}');
      }
      return sb.toString();
    }

    test('اخراج: پرسش‌ها به ترتیبِ اثر، و پیشنهاد تحلیل پیش از پرسش‌های فرعی',
        () {
      final a = fresh();
      expect(say(a, 'کارفرما اخراجم کرده'), contains('قرارداد کتبی دارید؟'));
      expect(say(a, 'بله'), contains('امضا کرده‌اید؟'));
      expect(say(a, 'نه، چیزی امضا نکرده‌ام'), contains('وسط قرارداد'));
      expect(say(a, 'وسط قرارداد بود'), contains('اخطار کتبی'));
      final r = say(a, 'نه، هیچ اخطاری ندادند');
      expect(a.file.no('warned'), isTrue);
      expect(r, contains('دست شما چقدر پر است'));
      final arg = say(a, 'بله، بگو');
      expect(arg, contains('اخراج: دستتان پر است'));
      expect(arg, contains('ماده ۱۶۵'));
      expect(arg, contains('سنوات: به یک نکته بسته است'));
      expect(arg, contains('روی اخراج محکم بایستید'));
      // بعد از تحلیل، پرسش‌های مانده را ادامه می‌دهد.
      expect(arg, contains('چند وقت است آنجا کار می‌کنید؟'));
      expect(a.unresolved, isEmpty);
    });

    test('استدلال با عوض‌شدن واقعیت عوض می‌شود', () {
      final a = fresh();
      say(a, 'کارفرما اخراجم کرده');
      say(a, 'قرارداد دارم ولی مدتش تموم شده بود و تمدید نکرد');
      expect(a.file.yes('expired'), isTrue);
      final arg = say(a, 'استدلالت چیه؟');
      expect(arg, contains('اخراج: فعلاً گیر دارد'));
      expect(arg, contains('پایان قرارداد است نه اخراج'));
      expect(arg, isNot(contains('روی اخراج محکم')));
    });

    test('اخراج همراه با حقوق نگرفته: هر دو خواسته دیده می‌شود', () {
      final a = fresh();
      say(a, 'کارفرما اخراجم کرده و سه ماهه حقوقمو نداده');
      expect(a.file.get('event'), 'fired');
      expect(a.file.yes('owed'), isTrue);
      final arg = say(a, 'استدلالت چیه؟');
      expect(arg, contains('اخراج:'));
      expect(arg, contains('حقوق معوق:'));
      expect(arg, contains('سنوات:'));
    });

    test('کسی که هنوز سر کار است: سنوات در برنامه و تحلیل نمی‌آید', () {
      final a = fresh();
      say(a, 'کارفرما سه ماهه حقوقمو نداده');
      say(a, 'قرارداد دارم');
      say(a, 'هنوز کار می‌کنم');
      expect(a.file.yes('working'), isTrue);
      final arg = say(a, 'استدلالت چیه؟');
      expect(arg, contains('سنوات: فعلاً گیر دارد'));
      final plan = say(a, 'قدم بعدی چیست؟');
      expect(plan, contains('حقوق معوق'));
      expect(plan, isNot(contains('حقوق معوق، سنوات')));
    });
  });
}
