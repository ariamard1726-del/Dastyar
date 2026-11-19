import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/qa_bank.dart';

/// آزمون بانک پرسش‌وپاسخ اجاره: بارگذاری، تطبیق پرسش، و برچسب استناد.
/// صحت استنادها به متن واقعی قانون در tests/python/test_lease_qa.py بررسی می‌شود.
void main() {
  late QaBank bank;

  setUpAll(() {
    final raw = File('assets/qa/lease_qa.json').readAsStringSync();
    bank = QaBank.fromJson(jsonDecode(raw));
  });

  group('بارگذاری', () {
    test('حداقل ۱۰۰ پرسش‌وپاسخ دارد و عنوان قوانین کامل است', () {
      expect(bank.items.length, greaterThanOrEqualTo(100));
      expect(bank.lawTitles.keys, containsAll(['civil', 'landlord_tenant']));
      expect(bank.disclaimer.trim(), isNotEmpty);
    });

    test('شناسه‌ها یکتا هستند و هر پاسخ استناد دارد', () {
      final ids = bank.items.map((i) => i.id).toSet();
      expect(ids.length, bank.items.length);
      for (final it in bank.items) {
        expect(it.refs, isNotEmpty, reason: it.id);
        expect(it.answer.length, greaterThan(40), reason: it.id);
      }
    });

    test('ورودی نامعتبر بانک خالی می‌دهد', () {
      expect(QaBank.fromJson(null).isEmpty, isTrue);
      expect(QaBank.fromJson({'items': 'x'}).isEmpty, isTrue);
      final partial = QaBank.fromJson({
        'items': [
          {'id': 'a', 'q': '', 'a': 'پاسخ'},
          {'id': 'b', 'q': 'پرسش؟', 'a': 'پاسخ کامل', 'refs': ['civil:4']},
        ],
      });
      expect(partial.items.map((i) => i.id), ['b']);
    });
  });

  group('تطبیق پرسش', () {
    test('هر پرسش بانک خودش را پیدا می‌کند (بیشتر موارد)', () {
      var hit = 0;
      for (final it in bank.items) {
        if (bank.match(it.question)?.id == it.id) hit++;
      }
      expect(hit / bank.items.length, greaterThanOrEqualTo(0.9));
    });

    test('پرسش بی‌ربط به اجاره پاسخ بانک نمی‌گیرد', () {
      expect(bank.match('امروز هوا چطور است؟'), isNull);
      expect(bank.match('سلام'), isNull);
    });

    test('یک واژهٔ کلیدی تنها برای تطبیق کافی نیست', () {
      expect(bank.match('ودیعه'), isNull);
    });
  });

  group('برچسب استناد', () {
    test('شماره و عنوان قانون فارسی می‌شود', () {
      expect(bank.citeLabel('landlord_tenant:4'),
          'ماده ۴ قانون روابط موجر و مستأجر');
      expect(bank.citeLabel('civil:494'), 'ماده ۴۹۴ قانون مدنی');
    });

    test('استناد ناقص یا ناشناس خالی یا با نام خام برمی‌گردد', () {
      expect(bank.citeLabel('bad'), isEmpty);
      expect(bank.citeLabel('unknown:3'), 'ماده ۳ unknown');
    });
  });
}
