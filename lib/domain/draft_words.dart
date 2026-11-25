import 'package:dastyar/core/engine.dart';

/// واژه‌های آمادهٔ گفتگو: «بله»، «خیر»، «انصراف»، و یکسان‌سازیِ متن پیش از
/// مقایسه.
///
/// جدا شدنش از بقیهٔ روند به این دلیل است که هم `DraftStep` (پاسخِ کاربر در
/// فرم) و هم `DraftIntent` (انتخابِ قالب) به همین یکسان‌سازی نیاز دارند؛ اگر
/// دو نسخه شود، «بله» در یک مسیر بله باشد و در مسیر دیگر نه.
class DraftWords {
  static final RegExp _nonLetter = RegExp(
    r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+',
  );
  static final RegExp _miPrefix = RegExp(r'(^| )(نمی|می) ');
  static final RegExp _spacesRe = RegExp(r'\s+');
  // یکسان‌سازی نیم‌فاصله و فاصله در «می/نمی» (نمی دهد = نمیدهد)
  static String norm(String s) {
    var n = KnowledgeEngine.normalize(s).replaceAll(_nonLetter, ' ');
    n = n.replaceAll(_spacesRe, ' ').trim();
    return n.replaceAllMapped(_miPrefix, (m) => '${m.group(1)}${m.group(2)}');
  }

  static const Set<String> _yes = {
    'بله',
    'اره',
    'بلی',
    'بله اماده کن',
    'اره اماده کن',
  };
  static const Set<String> _no = {
    'خیر',
    'نه',
    'نخیر',
    'نه ممنون',
    'خیر ممنون',
    'نه فقط توضیح بده',
    'فقط توضیح بده',
  };

  static String fold(String raw) {
    return KnowledgeEngine.normalize(raw)
        .replaceAll('آ', 'ا')
        .replaceAll('ئ', 'ی')
        .replaceAll('ؤ', 'و')
        .replaceAll(_nonLetter, ' ')
        .replaceAll(_spacesRe, ' ')
        .trim();
  }

  static bool isYes(String raw) => _yes.contains(fold(raw));

  /// کاربر می‌خواهد از این موضوع یا این فرم بیرون بیاید («انصراف»، «خروج از
  /// موضوع»، «نمی‌خواهم این بحث را ادامه دهم»، «چرا از موضوع خارج نمی‌شوی»).
  static bool isLeave(String raw) {
    final n = fold(raw);
    if (isComplaintNoOption(raw)) return false;
    if (RegExp(r'خروج از|از (?:موضوع|بحث|این بحث|این موضوع|ماجرا)[^؟]{0,12}(?:خارج|بیرون|بری)|(?:خارج|بیرون) (?:نمی|نمیشی|نمیشه|نشو|نمیشی)|ادامه (?:ش )?(?:نمی|نمیخوام|نخواهم)|(?:نمی خواهم|نمیخوام|نمیخواهم|نمی خوام|نخوام|نمی خوام) (?:این بحث|ادامه|بحث)|بیرون (?:بیام|بیایم)')
        .hasMatch(n)) {
      return true;
    }
    // «انصراف» به‌تنهایی یا در جملهٔ کوتاه؛ «انصراف از ضمانت» یعنی موضوع دیگری.
    return n.contains('انصراف') && n.split(' ').where((w) => w.isNotEmpty).length <= 4;
  }

  /// کاربر می‌گوید گزینه‌ای برای خروج نشان داده نشده («گزینه‌ای وجود ندارد»).
  static bool isComplaintNoOption(String raw) {
    final n = fold(raw);
    return RegExp(r'گزینه(?: ای| ی)? (?:وجود )?ندار|گزینه(?: انصراف)? (?:نیست|نیس)|(?:انصراف|گزینه) (?:وجود )?ندار|انصراف (?:وجود )?ندار|گزینه انصراف')
        .hasMatch(n);
  }

  static bool isNo(String raw) => _no.contains(fold(raw));
}
