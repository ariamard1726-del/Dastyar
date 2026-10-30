class PersianText {
  /// عادی‌سازی پیشرفته متن برای جستجو و مقایسه
  static String normalize(String text) {
    if (text.isEmpty) return text;
    return text
        // ۱. یکسان‌سازی ی و ک عربی/فارسی و اعداد
        .replaceAll(RegExp(r'[\u064A]'), '\u06CC') // ی عربی به فارسی
        .replaceAll(RegExp(r'[\u0643]'), '\u06A9') // ک عربی به فارسی
        .replaceAll(RegExp(r'[\u0660-\u0669]'), (m) => String.fromCharCode(m.group(0)!.codeUnitAt(0) - 0x0660 + 0x06F0)) // اعداد عربی به فارسی
        // ۲. مدیریت فاصله‌ها و نیم‌فاصله‌ها
        .replaceAll(RegExp(r'\u200C+'), '\u200C') // تجمیع نیم‌فاصله‌های پشت سر هم
        .replaceAll(RegExp(r' +'), ' ') // تجمیع فاصله‌های متعدد
        .trim();
  }

  /// حذف کامل فاصله‌ها و نیم‌فاصله‌ها برای تطابق واژگانی سخت‌گیرانه
  static String collapse(String text) {
    return normalize(text).replaceAll(RegExp(r'[\s\u200C]'), '');
  }

  /// توکنایز کردن متن برای ایندکس (جدا کردن کلمات معنادار)
  static List<String> tokenizeIndex(String text) {
    final normalized = normalize(text);
    // حذف علائم نگارشی و جدا کردن کلمات
    final tokens = normalized.split(RegExp(r'[\s\u200C\p{P}]+', unicode: true));
    return tokens.where((t) => t.length >= 2).toList(); // حذف کلمات تک‌حرفی بی‌اثر
  }

  /// توکنایز کردن برای نمایش یا پردازش‌های خاص
  static List<String> tokenize(String text) {
    return normalize(text).split(RegExp(r'[\s\u200C]+'));
  }
}
