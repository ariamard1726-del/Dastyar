import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/drafting.dart';
import 'package:dastyar/templates.dart';

void main() {
  final ts = <LegalTemplate>[
    for (final f in Directory('assets/templates').listSync())
      if (f is File && f.path.endsWith('.json'))
        LegalTemplate.fromJson(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>),
  ];

  test('سؤال دربارهٔ تنظیم، متن نمی‌خواهد', () {
    expect(Drafting.detect('تنظیم سند چه شرایطی دارد؟', ts).none, isTrue);
    expect(Drafting.detect('دادخواست چیست', ts).none, isTrue);
  });

  test('درخواست صریح تشخیص داده می‌شود', () {
    expect(Drafting.detect('می‌خواهم شکوائیه بنویسم', ts).none, isFalse);
    expect(Drafting.detect('دادخواست تنظیم کن', ts).none, isFalse);
  });
}
