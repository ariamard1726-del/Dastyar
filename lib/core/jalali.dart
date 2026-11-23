import 'package:dastyar/core/persian_text.dart';

/// تاریخ هجری شمسی، فقط برای حساب‌کردن تاریخ پایان مهلت‌ها.
///
/// این فایل هیچ حکم حقوقی‌ای نمی‌دهد؛ فقط تقویم است. این‌که کدام مهلت به
/// ماجرای کاربر می‌خورد و چند روز است، کار قانون است و جای دیگری گفته
/// می‌شود. قاعدهٔ کبیسه همان قاعدهٔ مشهور ۳۳ساله است که برای سال‌های
/// ۱۳۰۰ تا ۱۵۰۰ درست است.
class JalaliDate {
  final int year;
  final int month;
  final int day;

  const JalaliDate(this.year, this.month, this.day);

  /// سال مبنای شمارش سریال؛ فقط برای جمع و تفریق روز.
  static const int baseYear = 1300;

  static const Set<int> _leapMod = {1, 5, 9, 13, 17, 22, 26, 30};

  static bool isLeapYear(int y) => _leapMod.contains(y % 33);

  static int monthLength(int year, int month) {
    if (month <= 6) return 31;
    if (month <= 11) return 30;
    return isLeapYear(year) ? 30 : 29;
  }

  /// تاریخ معتبر است؟ (ماه ۱ تا ۱۲ و روز در محدودهٔ همان ماه)
  bool get isValid =>
      month >= 1 &&
      month <= 12 &&
      day >= 1 &&
      day <= monthLength(year, month);

  /// شمارهٔ روز از مبدأ [baseYear]/۰۱/۰۱.
  int get serial {
    var s = 0;
    for (var y = baseYear; y < year; y++) {
      s += isLeapYear(y) ? 366 : 365;
    }
    for (var m = 1; m < month; m++) {
      s += monthLength(year, m);
    }
    return s + day;
  }

  static JalaliDate? fromSerial(int serial) {
    if (serial < 1) return null;
    var y = baseYear;
    var s = serial;
    for (var guard = 0; guard < 800; guard++) {
      final len = isLeapYear(y) ? 366 : 365;
      if (s <= len) break;
      s -= len;
      y++;
    }
    var m = 1;
    while (m < 12 && s > monthLength(y, m)) {
      s -= monthLength(y, m);
      m++;
    }
    return JalaliDate(y, m, s);
  }

  JalaliDate addMonths(int n) {
    var y = year;
    var m = month + n;
    while (m > 12) {
      m -= 12;
      y++;
    }
    while (m < 1) {
      m += 12;
      y--;
    }
    final last = monthLength(y, m);
    return JalaliDate(y, m, day > last ? last : day);
  }

  JalaliDate addDays(int n) => fromSerial(serial + n) ?? this;

  /// «۱۴۰۳/۰۳/۱۵» با ارقام فارسی و صفرِ پیش از ماه و روز.
  String get fa {
    final mm = month < 10 ? '0$month' : '$month';
    final dd = day < 10 ? '0$day' : '$day';
    return PersianText.toFaDigits('$year/$mm/$dd');
  }

  /// نخستین تاریخی که در متن آمده و معتبر است.
  static JalaliDate? parse(String text) {
    final t = asciiKeepText(text);
    final m = RegExp(
      r'(?<![0-9])(1[2-6][0-9]{2})\s*[/\-.]\s*([0-9]{1,2})\s*[/\-.]\s*([0-9]{1,2})(?![0-9])',
    ).firstMatch(t);
    if (m == null) return null;
    final d = JalaliDate(
      int.parse(m[1]!),
      int.parse(m[2]!),
      int.parse(m[3]!),
    );
    return d.isValid ? d : null;
  }

  @override
  String toString() => '$year/$month/$day';
}

/// ارقام فارسی/عربی را به لاتین برمی‌گرداند و بقیهٔ متن را دست نمی‌زند.
String asciiKeepText(String s) {
  final sb = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x06F0 && r <= 0x06F9) {
      sb.writeCharCode(0x30 + (r - 0x06F0));
    } else if (r >= 0x0660 && r <= 0x0669) {
      sb.writeCharCode(0x30 + (r - 0x0660));
    } else {
      sb.writeCharCode(r);
    }
  }
  return sb.toString();
}

/// یک مدت: «۲ ماه»، «دو هفته»، «۲۰ روز»، «یک سال».
class DeadlineSpan {
  final int months;
  final int days;

  const DeadlineSpan({this.months = 0, this.days = 0});

  bool get isEmpty => months == 0 && days == 0;

  /// برچسب فارسی برای نمایش در پاسخ.
  String get label {
    final parts = <String>[];
    if (months > 0) {
      final years = months ~/ 12;
      final rest = months % 12;
      if (years > 0) parts.add('${_faNum(years)} سال');
      if (rest > 0) parts.add('${_faNum(rest)} ماه');
    }
    if (days > 0) {
      final weeks = days ~/ 7;
      final rest = days % 7;
      if (weeks > 0) parts.add('${_faNum(weeks)} هفته');
      if (rest > 0) parts.add('${_faNum(rest)} روز');
    }
    return parts.join(' و ');
  }

  static String _faNum(int n) => PersianText.toFaDigits('$n');
}

const Map<String, int> _numberWords = {
  'یک': 1,
  'دو': 2,
  'سه': 3,
  'چهار': 4,
  'پنج': 5,
  'شش': 6,
  'هفت': 7,
  'هشت': 8,
  'نه': 9,
  'ده': 10,
  'یازده': 11,
  'دوازده': 12,
  'پانزده': 15,
  'بیست': 20,
  'سی': 30,
  'چهل': 40,
  'پنجاه': 50,
  'شصت': 60,
  'هفتاد': 70,
  'هشتاد': 80,
  'نود': 90,
  'صد': 100,
};

/// مدتِ نوشته‌شده در متن را می‌خواند؛ اگر نبود `null`.
DeadlineSpan? parseDuration(String text) {
  final t = asciiKeepText(text);
  final wordAlt = _numberWords.keys.join('|');
  final re = RegExp(
    '(?<![\\u0600-\\u06FF])([0-9]{1,3}|$wordAlt)\\s*(ماهه|ماه|روز|هفته|سال)(?![\\u0600-\\u06FF])',
  );
  final m = re.firstMatch(t);
  if (m == null) return null;
  final raw = m[1]!;
  final n = int.tryParse(raw) ?? _numberWords[raw];
  if (n == null || n <= 0 || n > 600) return null;
  final unit = m[2]!;
  if (unit == 'روز') return DeadlineSpan(days: n);
  if (unit == 'هفته') return DeadlineSpan(days: n * 7);
  if (unit == 'سال') return DeadlineSpan(months: n * 12);
  return DeadlineSpan(months: n);
}

/// نتیجهٔ حساب یک مهلت: تاریخ مبدأ، مدت، و تاریخ پایان.
class DeadlineCalc {
  final JalaliDate start;
  final DeadlineSpan span;

  const DeadlineCalc(this.start, this.span);

  /// آخرین روز مهلت، همان مدت از تاریخ مبدأ.
  JalaliDate get end =>
      span.months == 0 ? start.addDays(span.days) : start.addMonths(span.months).addDays(span.days);

  /// روزی که مهلت از آن شروع می‌شود (روز بعد از ابلاغ).
  JalaliDate get startNext => start.addDays(1);
}

/// اگر متن هم تاریخ داشته باشد هم مدت، حساب مهلت را برمی‌گرداند.
DeadlineCalc? computeDeadline(String text) {
  final date = JalaliDate.parse(text);
  if (date == null) return null;
  final span = parseDuration(text);
  if (span == null || span.isEmpty) return null;
  return DeadlineCalc(date, span);
}
