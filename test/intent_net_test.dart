import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/intent_net.dart';

/// این تست آینهٔ Dartِ `tools/check.py intent` است: همان مدل، همان مجموعهٔ
/// آزمون و همان نگهبان‌ها. اگر پیاده‌سازی Dart از ریاضی پایتون (هش FNV-1a،
/// n-gramها، L1-normalize، relu، softmax، کوانتیزاسیون int8) مو به مو پیروی
/// نکند، دقت به زمین می‌خورد و تست رد می‌شود.
IntentNet _loadNet() {
  final m = jsonDecode(
    File('assets/brain/intent_model.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  return IntentNet.fromJson(m);
}

List<(String, String)> _loadRows(String path) {
  final out = <(String, String)>[];
  for (final l in File(path).readAsLinesSync()) {
    final t = l.trim();
    if (t.isEmpty || t.startsWith('#') || !t.contains('|')) continue;
    final i = t.indexOf('|');
    out.add((t.substring(0, i).trim(), t.substring(i + 1).trim()));
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late IntentNet net;

  setUpAll(() {
    net = _loadNet();
  });

  group('شبکهٔ عصبی نیت: ساختار و برابری با آینهٔ پایتون', () {
    test('اسکیمای مدل معتبر است (۱۶ برچسب، آستانه‌ها، relu/l1)', () {
      expect(net.labels.length, 16);
      expect(net.labels, containsAll(<String>[
        'cheque', 'labor', 'lease', 'family', 'fraud_cyber',
        'criminal_harm', 'litigation_defense', 'debt', 'general_intake',
        'legal_question', 'article_lookup', 'draft_request', 'cancel',
        'chitchat', 'out_of_scope', 'counsel_answer',
      ]));
      expect(net.topicMin, 0.45);
      expect(net.ragMin, 0.50);
      expect(net.cancelMin, 0.60);
      expect(net.metrics, isNotEmpty);
    });

    test('دقت روی brain/eval/intent_eval.txt دست‌کم ۰٫۹۰ است (هم‌تراز CI پایتون)', () {
      final rows = _loadRows('brain/eval/intent_eval.txt');
      expect(rows.length, greaterThanOrEqualTo(140));
      var ok = 0;
      final wrong = <String>[];
      for (final r in rows) {
        final s = net.classify(r.$2);
        if (s.label == r.$1) {
          ok++;
        } else {
          wrong.add('[${r.$1}->${s.label} ${s.score.toStringAsFixed(2)}] ${r.$2}');
        }
      }
      final acc = ok / rows.length;
      expect(
        acc,
        greaterThanOrEqualTo(0.90),
        reason: 'raw_acc=$acc\n${wrong.join('\n')}',
      );
    });

    test('هر ۲۲ نگهبان حیاتیِ جریان‌های اپ درست طبقه‌بندی می‌شوند', () {
      const critical = <(String, String)>[
        ('lease', 'مستأجرم مدت قراردادش تمام شده ولی خانه را تخلیه نمی‌کند'),
        ('counsel_answer', 'قرارداد کتبی با امضای دو شاهد داریم'),
        ('litigation_defense', 'حکم غیابی علیه من صادر شده چه کار کنم؟'),
        ('counsel_answer', 'کمتر از ۲۰ روز گذشته است'),
        ('cheque', 'چک دادم بابت ضمانت الان برگشت زده و می‌خواهم بدانم چه کار کنم'),
        ('counsel_answer', 'بله، گواهی دارم و زیر ۶ ماه است'),
        ('debt', 'دوستم پول قرض گرفته و پس نمی‌دهد'),
        ('general_intake', 'مشاورهٔ حقوقی گام‌به‌گام'),
        ('general_intake', 'مشاوره'),
        ('legal_question', 'قانون چک چه می‌گوید؟'),
        ('legal_question', 'مجازات کلاهبرداری چیست'),
        ('article_lookup', 'ماده ۱۰ قانون مدنی چه می‌گوید'),
        ('article_lookup', 'اصل ۳۵ قانون اساسی'),
        ('cancel', 'انصراف'),
        ('cancel', 'پایان مشاوره'),
        ('chitchat', 'سلام'),
        ('out_of_scope', 'امروز هوا چطور است'),
        ('draft_request', 'برایم شکوائیه بنویس'),
        ('draft_request', 'لایحه دفاعیه آماده کن'),
        ('cheque', 'چک برگشتی دارم'),
        ('labor', 'کارفرما اخراجم کرده'),
        ('family', 'مهریه‌ام را نمی‌دهد'),
      ];
      for (final c in critical) {
        final s = net.classify(c.$2);
        expect(s.label, c.$1, reason: '${c.$2} → ${s.label} (${s.score})');
      }
    });

    test('پرسش‌های حقوقی بالای rag_min و لغو بالای cancel_min امتیاز دارند', () {
      final q = net.classify('قانون چک چه می‌گوید؟');
      expect(IntentNet.ragLabels.contains(q.label), isTrue);
      expect(q.score, greaterThanOrEqualTo(net.ragMin));

      final c = net.classify('انصراف');
      expect(c.label, 'cancel');
      expect(c.score, greaterThanOrEqualTo(net.cancelMin));

      final t = net.classify('چک برگشتی دارم');
      expect(IntentNet.topicLabels.contains(t.label), isTrue);
      expect(t.score, greaterThanOrEqualTo(net.topicMin));
    });

    test('احتمال‌ها جمعاً یک است و نرمال‌سازی فارسی/عربی/ارقام یکسان می‌دهد', () {
      final p = net.probabilities('چک برگشتی دارم');
      final sum = p.fold<double>(0, (a, b) => a + b);
      expect(sum, closeTo(1.0, 1e-9));

      expect(
        net.classify('چک برگشتی دارم').label,
        net.classify('چك برگشتي دارم').label,
      );
      expect(
        net.classify('کمتر از ۲۰ روز گذشته است').label,
        net.classify('کمتر از 20 روز گذشته است').label,
      );
      expect(
        net.featureBuckets('مهریه‌ام را نمی‌دهد'),
        net.featureBuckets('مهریه ام را نمی دهد'),
      );
    });

    test('متن تهی هیچ آستانه‌ای را رد نمی‌کند', () {
      final s = net.classify('...');
      expect(s.score, lessThan(net.topicMin));
      expect(net.probabilities(''), everyElement(0.0));
    });

    test('بارگذاری از asset با rootBundle هم کار می‌کند', () async {
      final n = await IntentNet.load();
      expect(n, isNotNull);
      expect(n!.classify('سلام').label, 'chitchat');
    });

    test('مدل خراب به‌جای پرتاب خطا، null بارگذاری می‌شود', () async {
      final n = await IntentNet.load(asset: 'assets/brain/does_not_exist.json');
      expect(n, isNull);
    });
  });
}
