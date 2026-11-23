import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/jalali.dart';

/// حساب تقویم شمسی برای مهلت‌ها؛ هیچ حکم حقوقی این‌جا نیست.
void main() {
  test('تاریخ معتبر و نامعتبر', () {
    expect(const JalaliDate(1403, 1, 1).isValid, isTrue);
    expect(const JalaliDate(1403, 12, 30).isValid, isTrue); // ۱۴۰۳ کبیسه است
    expect(const JalaliDate(1404, 12, 30).isValid, isFalse);
    expect(const JalaliDate(1403, 13, 1).isValid, isFalse);
    expect(const JalaliDate(1403, 7, 31).isValid, isFalse);
  });

  test('کبیسه‌بودن سال', () {
    expect(JalaliDate.isLeapYear(1403), isTrue);
    expect(JalaliDate.isLeapYear(1404), isFalse);
    expect(JalaliDate.isLeapYear(1399), isTrue);
  });

  test('جمع ماه، با اصلاح روز در ماه کوتاه', () {
    expect(const JalaliDate(1403, 1, 15).addMonths(2).fa, '۱۴۰۳/۰۳/۱۵');
    expect(const JalaliDate(1403, 6, 31).addMonths(1).fa, '۱۴۰۳/۰۷/۳۰');
    expect(const JalaliDate(1403, 11, 30).addMonths(1).fa, '۱۴۰۳/۱۲/۳۰');
    expect(const JalaliDate(1404, 11, 30).addMonths(1).fa, '۱۴۰۴/۱۲/۲۹');
    expect(const JalaliDate(1403, 12, 30).addMonths(1).fa, '۱۴۰۴/۰۱/۳۰');
    expect(const JalaliDate(1403, 1, 15).addMonths(12).fa, '۱۴۰۴/۰۱/۱۵');
  });

  test('جمع روز، از جمله گذر از پایان سال', () {
    expect(const JalaliDate(1403, 1, 15).addDays(20).fa, '۱۴۰۳/۰۲/۰۴');
    expect(const JalaliDate(1403, 12, 20).addDays(10).fa, '۱۴۰۳/۱۲/۳۰');
    expect(const JalaliDate(1403, 12, 20).addDays(11).fa, '۱۴۰۴/۰۱/۰۱');
    expect(const JalaliDate(1404, 12, 20).addDays(11).fa, '۱۴۰۵/۰۱/۰۲');
  });

  test('خواندن تاریخ از متن، با ارقام فارسی یا لاتین', () {
    expect(JalaliDate.parse('ابلاغ ۱۴۰۳/۰۱/۱۵ بود')!.fa, '۱۴۰۳/۰۱/۱۵');
    expect(JalaliDate.parse('1403-1-5')!.fa, '۱۴۰۳/۰۱/۰۵');
    expect(JalaliDate.parse('۱۴۰۳.۰۱.۱۵')!.fa, '۱۴۰۳/۰۱/۱۵');
    expect(JalaliDate.parse('هیچ تاریخی نیست'), isNull);
    expect(JalaliDate.parse('۱۴۰۴/۱۲/۳۰'), isNull); // ۱۴۰۴ کبیسه نیست
  });

  test('خواندن مدت از متن', () {
    expect(parseDuration('مهلت ۲ ماهه')!.months, 2);
    expect(parseDuration('دو ماه')!.months, 2);
    expect(parseDuration('۲۰ روز')!.days, 20);
    expect(parseDuration('دو هفته')!.days, 14);
    expect(parseDuration('یک سال')!.months, 12);
    expect(parseDuration('۲ ماه و ۱۰ روز')!.months, 2);
    expect(parseDuration('ماده ۲۵ قانون کار'), isNull);
    expect(parseDuration('هیچ مدتی نیست'), isNull);
  });

  test('برچسب مدت به فارسی', () {
    expect(const DeadlineSpan(months: 2).label, '۲ ماه');
    expect(const DeadlineSpan(months: 24).label, '۲ سال');
    expect(const DeadlineSpan(days: 20).label, '۲ هفته و ۶ روز');
  });

  test('حساب کامل مهلت از متن', () {
    final d = computeDeadline('اگر ابلاغ ۱۴۰۳/۰۱/۱۵ باشد، مهلت ۲ ماهه تا کی است؟')!;
    expect(d.start.fa, '۱۴۰۳/۰۱/۱۵');
    expect(d.end.fa, '۱۴۰۳/۰۳/۱۵');
    expect(d.startNext.fa, '۱۴۰۳/۰۱/۱۶');
    expect(computeDeadline('مهلت ۲ ماهه چقدر است؟'), isNull);
    expect(computeDeadline('ابلاغ ۱۴۰۳/۰۱/۱۵ بود'), isNull);
  });
}
