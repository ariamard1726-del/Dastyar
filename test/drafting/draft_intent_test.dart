import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/templates.dart';

void main() {
  final ts = <LegalTemplate>[
    for (final f in Directory('assets/templates').listSync())
      if (f is File && f.path.endsWith('.json'))
        LegalTemplate.fromJson(
            jsonDecode(f.readAsStringSync()) as Map<String, dynamic>),
  ];

  test('سؤال دربارهٔ تنظیم، متن نمی‌خواهد', () {
    expect(DraftIntent.detect('تنظیم سند چه شرایطی دارد؟', ts).none, isTrue);
    expect(DraftIntent.detect('دادخواست چیست', ts).none, isTrue);
  });

  test('درخواست صریح تشخیص داده می‌شود', () {
    expect(DraftIntent.detect('می‌خواهم شکوائیه بنویسم', ts).none, isFalse);
    expect(DraftIntent.detect('دادخواست تنظیم کن', ts).none, isFalse);
  });
}
