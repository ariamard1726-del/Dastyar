/// لایهٔ متن فارسی: یکدست‌سازی نویسه‌ها، ریشه‌یابی سبک و واژه‌بندی.
/// موتور جست‌وجو و بخش‌های دیگر فقط از اینجا استفاده می‌کنند،
/// تا هر بهبود زبانی (ریشه‌یاب بهتر، نیم‌فاصله، ...) در یک جا انجام شود.
class PersianText {
  PersianText._();

  static const Set<String> _stop = {
    'و', 'در', 'به', 'از', 'که', 'را', 'با', 'این', 'آن', 'برای', 'یک',
    'است', 'هست', 'چه', 'چی', 'چیست', 'کی', 'کجا', 'چرا', 'چطور',
    'چگونه', 'آیا', 'من', 'تو', 'شما', 'می', 'هم', 'یا', 'تا', 'بر',
    'هر', 'بود', 'شد', 'باشد', 'کند', 'کنم', 'کن', 'بگو',
    'درباره', 'مورد', 'لطفا', 'ممنون', 'ماده', 'قانون',
  };

  static const List<String> _suffixes = [
    'ترین', 'هایی', 'های', 'ها', 'تر', 'ان', 'ات', 'ی',
  ];

  static String normalize(String s) {
    const map = {
      'ي': 'ی', 'ى': 'ی', 'ك': 'ک', 'ۀ': 'ه', 'ة': 'ه',
      'أ': 'ا', 'إ': 'ا', 'ٱ': 'ا',
    };
    final sb = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x06F0 && r <= 0x06F9) {
        sb.write(r - 0x06F0);
        continue;
      }
      if (r >= 0x0660 && r <= 0x0669) {
        sb.write(r - 0x0660);
        continue;
      }
      if (r == 0x200C || r == 0x200D || r == 0x200E || r == 0x200F) {
        sb.write(' ');
        continue;
      }
      if (r >= 0x064B && r <= 0x065F) continue;
      if (r == 0x0640) continue;
      final ch = String.fromCharCode(r);
      sb.write(map[ch] ?? ch);
    }
    return sb.toString().toLowerCase();
  }

  static String collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _stem(String w) {
    for (final suf in _suffixes) {
      if (w.length - suf.length >= 3 && w.endsWith(suf)) {
        return w.substring(0, w.length - suf.length);
      }
    }
    return w;
  }

  static final RegExp _nonWord = RegExp(
    r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+',
  );

  // ریشه‌یابی محافظه‌کار برای نمایهٔ جست‌وجو: فقط «ها/های/هایی/ترین».
  // «ی» و «ان» حذف نمی‌شوند تا «مالی» با «مال» و «زندان» با «زند» یکی نشود.
  static const List<String> _suffixesIndex = ['ترین', 'هایی', 'های', 'ها'];

  static String _stemIndex(String w) {
    for (final suf in _suffixesIndex) {
      if (w.length - suf.length >= 3 && w.endsWith(suf)) {
        return w.substring(0, w.length - suf.length);
      }
    }
    return w;
  }

  static List<String> tokenizeIndex(String s) {
    final cleaned = normalize(s).replaceAll(_nonWord, ' ');
    final out = <String>[];
    for (final w in cleaned.split(' ')) {
      if (w.isEmpty || _stop.contains(w)) continue;
      out.add(_stemIndex(w));
    }
    return out;
  }

  static List<String> tokenize(String s) {
    final cleaned = normalize(s).replaceAll(_nonWord, ' ');
    final out = <String>[];
    for (final w in cleaned.split(' ')) {
      if (w.isEmpty || _stop.contains(w)) continue;
      out.add(_stem(w));
    }
    return out;
  }

  /// عبارت یکدست‌شده: نرمال، بدون نشانه، با فاصلهٔ تک.
  static String phrase(String s) =>
      collapse(normalize(s).replaceAll(_nonWord, ' '));
}
