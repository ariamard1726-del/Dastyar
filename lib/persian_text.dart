class PersianText {
  /// عادی‌سازی پیشرفته متن برای جستجو و مقایسه
  static String normalize(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll(RegExp(r'[\u064A]'), '\u06CC')
        .replaceAll(RegExp(r'[\u0643]'), '\u06A9')
        .replaceAllMapped(RegExp(r'[\u0660-\u0669]'), (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0x0660 + 0x06F0))
        .replaceAll(RegExp(r'\u200C+'), '\u200C')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
  }

  /// تبدیل متن به عبارت تمیز (حذف علائم نگارشی و فاصله‌های اضافی)
  static String phrase(String text) {
    return normalize(text)
        .replaceAll(RegExp(r'[\p{P}]', unicode: true), '')
        .replaceAll(RegExp(r' +'), ' ')
        .trim();
  }

  /// حذف کامل فاصله‌ها و نیم‌فاصله‌ها برای تطابق واژگانی سخت‌گیرانه
  static String collapse(String text) {
    return normalize(text).replaceAll(RegExp(r'[\s\u200C]'), '');
  }

  /// توکنایز کردن متن برای ایندکس
  static List<String> tokenizeIndex(String text) {
    final normalized = normalize(text);
    final tokens = normalized.split(RegExp(r'[\s\u200C\p{P}]+', unicode: true));
    return tokens.where((t) => t.length >= 2).toList();
  }

  /// توکنایز کردن برای نمایش یا پردازش‌های خاص
  static List<String> tokenize(String text) {
    return normalize(text).split(RegExp(r'[\s\u200C]+'));
  }
}
