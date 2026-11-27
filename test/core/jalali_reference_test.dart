import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/jalali.dart';

/// درستی تقویم شمسیِ برنامه با الگوریتم مرجعِ رایج (jalaali-js/Borkowski)
/// سنجیده می‌شود، نه با خودش.
///
/// برنامه قاعدهٔ ۳۳ساله را به کار می‌برد که برای سال‌های ۱۳۰۰ تا ۱۵۰۰ همان
/// نتیجهٔ الگوریتم مرجع را می‌دهد؛ این آزمون همان هم‌خوانی را قفل می‌کند تا
/// اگر روزی قاعده عوض شد، تفاوت پنهان نماند.
bool referenceLeap(int jy) {
  const breaks = <int>[
    -61, 9, 38, 199, 426, 686, 756, 818, 1111, 1181, 1210, //
    1635, 2060, 2097, 2192, 2262, 2324, 2394, 2456, 3178,
  ];
  var jp = breaks[0];
  var jump = 0;
  for (var i = 1; i < breaks.length; i++) {
    final jm = breaks[i];
    jump = jm - jp;
    if (jy < jm) break;
    jp = jm;
  }
  var n = jy - jp;
  if (jump - n < 6) n = n - jump + ((jump + 4) ~/ 33) * 33;
  // برای تصمیم کبیسه فقط n و jump لازم‌اند (jalaali-js، تابع jalCal).
  return (((n + 1) % 33) - 1) % 4 == 0;
}

void main() {
  test('کبیسه‌بودن ۱۳۰۰ تا ۱۵۰۰ با الگوریتم مرجع یکی است', () {
    final diffs = <int>[];
    for (var y = 1300; y <= 1500; y++) {
      if (JalaliDate.isLeapYear(y) != referenceLeap(y)) diffs.add(y);
    }
    expect(diffs, isEmpty, reason: 'سال‌های واگرا: $diffs');
  });

  test('درازای ماه‌ها درست است', () {
    for (var y = 1395; y <= 1405; y++) {
      for (var m = 1; m <= 6; m++) {
        expect(JalaliDate.monthLength(y, m), 31, reason: '$y/$m');
      }
      for (var m = 7; m <= 11; m++) {
        expect(JalaliDate.monthLength(y, m), 30, reason: '$y/$m');
      }
      expect(JalaliDate.monthLength(y, 12),
          JalaliDate.isLeapYear(y) ? 30 : 29,
          reason: '$y/12');
    }
  });

  test('رفت‌وبرگشت سریال برای هر روز ۱۳۹۵ تا ۱۴۰۵ بی‌خطاست', () {
    final start = const JalaliDate(1395, 1, 1).serial;
    final end = const JalaliDate(1405, 12, 29).serial;
    expect(end, greaterThan(start));
    for (var s = start; s <= end; s++) {
      final d = JalaliDate.fromSerial(s);
      expect(d, isNotNull, reason: 'serial $s');
      expect(d!.serial, s, reason: 'serial $s → ${d.year}/${d.month}/${d.day}');
      expect(d.isValid, isTrue);
    }
  });

  test('جمع روز و ماه با هم جمع می‌شوند', () {
    // ۱۴۰۳ کبیسه است: ۳۰ روز اسفند.
    expect(const JalaliDate(1403, 12, 1).addDays(29).fa, '۱۴۰۳/۱۲/۳۰');
    expect(const JalaliDate(1403, 12, 1).addDays(30).fa, '۱۴۰۴/۰۱/۰۱');
    // ۱۴۰۴ کبیسه نیست: ۲۹ روز اسفند.
    expect(const JalaliDate(1404, 12, 1).addDays(28).fa, '۱۴۰۴/۱۲/۲۹');
    expect(const JalaliDate(1404, 12, 1).addDays(29).fa, '۱۴۰۵/۰۱/۰۱');
    expect(const JalaliDate(1403, 6, 31).addMonths(6).addDays(1).fa,
        '۱۴۰۴/۰۱/۰۱');
  });
}
