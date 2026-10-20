import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/drafting.dart';
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

void main() {
  final ts = loadTemplates();

  String? sug(String text) => Drafting.suggest(text, ts).template?.id;

  group('جهت وضعیت', () {
    test('بدهکار پیشنهاد مطالبه نمی‌گیرد', () {
      expect(sug('من از دوستم قرض گرفتم و بدهکارم'), isNull);
    });
    test('کسی که از او شکایت شده شکوائیه نمی‌گیرد', () {
      expect(sug('از من شکایت کرده‌اند'), isNull);
    });
    test('احضاریه گرفته', () {
      expect(sug('برایم احضاریه آمده و شکایت شده'), isNull);
    });
  });

  group('محاوره و املا', () {
    test('پولمو نمیده', () {
      expect(sug('دوستم پولمو پس نمیده'), 'demand_money');
    });
    test('نمی دهد با فاصله', () {
      expect(sug('پول من را پس نمی دهد'), 'demand_money');
    });
    test('پولم را نداد', () {
      expect(sug('همکارم پولم را نداد'), 'demand_money');
    });
    test('تهدیدم می‌کند', () {
      expect(sug('همسایه‌ام مدام تهدیدم می‌کند'), 'complaint');
    });
    test('وکیل بگیرم', () {
      expect(sug('نمی‌توانم وکیل بگیرم'), 'legal_aid');
    });
    test('پول وکیل ندارم', () {
      expect(sug('پول وکیل ندارم'), 'legal_aid');
    });
  });

  group('سؤال اطلاعاتی', () {
    test('آیا تهدید جرم است', () {
      expect(sug('آیا تهدید جرم است؟'), isNull);
    });
    test('مجازات کلاهبرداری', () {
      expect(sug('مجازات کلاهبرداری چیست'), isNull);
    });
    test('تعریف قرض', () {
      expect(sug('قرض چیست؟'), isNull);
    });
  });

  group('بله و نه', () {
    test('تشخیص', () {
      expect(Drafting.isYes('بله'), isTrue);
      expect(Drafting.isYes('آره'), isTrue);
      expect(Drafting.isNo('نه'), isTrue);
      expect(Drafting.isNo('خیر'), isTrue);
      expect(Drafting.isYes('نه'), isFalse);
    });
  });
}
