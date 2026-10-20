import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/drafting.dart';
import 'package:dastyar/engine.dart';
import 'package:dastyar/templates.dart';

List<LegalTemplate> loadTemplates() {
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

LegalTemplate byId(List<LegalTemplate> ts, String id) =>
    ts.firstWhere((t) => t.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ts = loadTemplates();

  group('قالب‌ها', () {
    test('حداقل یک قالب هست', () {
      expect(ts, isNotEmpty);
    });

    test('جای‌نگهدار تعریف‌نشده ندارند', () {
      for (final t in ts) {
        expect(t.undefinedPlaceholders(), isEmpty, reason: t.id);
      }
    });

    test('با مقدار خالی هم کامل ساخته می‌شوند', () {
      for (final t in ts) {
        final text = TemplateRenderer.render(t, {});
        expect(text.contains('{{'), isFalse, reason: t.id);
        expect(text.trim(), isNotEmpty, reason: t.id);
      }
    });

    test('قالب مبلغ با ویرگول فارسی', () {
      expect(TemplateRenderer.money('50000000'), '۵۰،۰۰۰،۰۰۰');
      final t = byId(ts, 'demand_money');
      final text = TemplateRenderer.render(t, {'amount': '50000000'});
      expect(text, contains('۵۰،۰۰۰،۰۰۰ ریال'));
    });
  });

  group('تشخیص منظور', () {
    test('عنوان دقیق قالب', () {
      final r = Drafting.detect('دادخواست مطالبهٔ وجه', ts);
      expect(r.template?.id, 'demand_money');
    });

    test('درخواست صریح با دو قالب مشابه سؤال می‌پرسد', () {
      final r = Drafting.detect('می‌خواهم دادخواست بنویسم', ts);
      expect(r.template, isNull);
      expect(r.choices.length, greaterThanOrEqualTo(2));
    });

    test('دادخواست اعسار', () {
      final r = Drafting.detect('دادخواست اعسار بنویس', ts);
      expect(r.template?.id, 'insolvency');
    });

    test('پیشنهاد برای شرح وضعیت: قرض', () {
      final r = Drafting.suggest('دوستم پول قرض گرفته و پس نمی‌دهد', ts);
      expect(r.template?.id, 'demand_money');
    });

    test('پیشنهاد برای شرح وضعیت: تهدید', () {
      final r = Drafting.suggest('یکی مرا تهدید کرد', ts);
      expect(r.template?.id, 'complaint');
    });

    test('پیشنهاد برای شرح وضعیت: وکیل', () {
      final r = Drafting.suggest('پول وکیل ندارم', ts);
      expect(r.template?.id, 'legal_aid');
    });

    test('سؤال تعریفی پیشنهاد نمی‌آورد', () {
      final r = Drafting.suggest('قرض چیست؟', ts);
      expect(r.none, isTrue);
    });

    test('جملهٔ بی‌ربط پیشنهاد نمی‌آورد', () {
      final r = Drafting.suggest('امروز هوا چطور است', ts);
      expect(r.none, isTrue);
    });
  });

  group('گفتگوی تهیهٔ متن', () {
    test('مبلغ همراه کلمه رد می‌شود و عدد کامل پذیرفته', () {
      final t = byId(ts, 'demand_money');
      final s = DraftSession(t);
      s.index = t.fields.indexWhere((f) => f.id == 'amount');
      final bad = Drafting.answer(s, '۵ میلیون تومان');
      expect(bad.text, contains('فقط عدد'));
      expect(s.values.containsKey('amount'), isFalse);
      Drafting.answer(s, '۵۰۰۰۰۰۰۰');
      expect(s.values['amount'], '50000000');
    });

    test('انصراف گفتگو را می‌بندد', () {
      final s = DraftSession(byId(ts, 'demand_money'));
      expect(Drafting.answer(s, DraftCmd.cancel).ended, isTrue);
    });

    test('هر قالب تا آخر به متن کامل می‌رسد', () {
      for (final t in ts) {
        final s = DraftSession(t);
        DraftReply? r;
        var guard = 0;
        while (!s.done && guard++ < 80) {
          final f = s.current!;
          String v;
          switch (f.type) {
            case 'choice':
              v = f.options.first;
              break;
            case 'check':
              v = DraftCmd.yes;
              break;
            case 'number':
              v = '1000';
              break;
            default:
              v = 'نمونه';
          }
          r = Drafting.answer(s, v);
        }
        expect(s.done, isTrue, reason: t.id);
        expect(r!.isDocument, isTrue, reason: t.id);
        expect(r.text.contains('{{'), isFalse, reason: t.id);
      }
    });
  });

  group('موتور دانش', () {
    test('نرمال‌سازی ارقام و حروف', () {
      expect(KnowledgeEngine.normalize('۱۲۳ك'), '123ک');
    });

    test('بارگذاری و پاسخ به شمارهٔ اضطراری', () async {
      final e = KnowledgeEngine();
      await e.load();
      expect(e.size, greaterThan(0));
      expect(e.answer('شماره اضطراری ایران'), contains('۱۱۵'));
    });
  });
}
