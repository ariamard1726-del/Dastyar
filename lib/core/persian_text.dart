/// لایهٔ متن فارسی: یکدست‌سازی نویسه‌ها، تبدیل ارقام، ریشه‌یابی سبک و واژه‌بندی.
/// موتور جست‌وجو و بخش‌های دیگر فقط از اینجا استفاده می‌کنند،
/// تا هر بهبود زبانی (ریشه‌یاب بهتر، نیم‌فاصله، ...) در یک جا انجام شود.
class PersianText {
  PersianText._();

  static const String _faDigits = '۰۱۲۳۴۵۶۷۸۹';

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

  // ریشه‌یابی محافظه‌کار برای نمایهٔ جست‌وجو: فقط «ها/های/هایی/ترین».
  // «ی» و «ان» حذف نمی‌شوند تا «مالی» با «مال» و «زندان» با «زند» یکی نشود.
  static const List<String> _suffixesIndex = ['ترین', 'هایی', 'های', 'ها'];

  static final RegExp _nonWord = RegExp(
    r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+',
  );
  static final RegExp _spaces = RegExp(r'\s+');

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

  /// تبدیل ارقام لاتین و عربی به ارقام فارسی به صورت ایمن روی Runes.
  static String toFaDigits(String s) {
    final sb = StringBuffer();
    for (final r in s.runes) {
      if (r >= 48 && r <= 57) {
        sb.write(_faDigits[r - 48]);
      } else if (r >= 0x0660 && r <= 0x0669) {
        sb.write(_faDigits[r - 0x0660]);
      } else {
        sb.writeCharCode(r);
      }
    }
    return sb.toString();
  }

  /// استخراج فقط ارقام از متن به صورت لاتین (۰-۹ / ٠-٩ / 0-9 -> 0-9).
  static String asciiDigits(String s) {
    final sb = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x06F0 && r <= 0x06F9) {
        sb.write(r - 0x06F0);
      } else if (r >= 0x0660 && r <= 0x0669) {
        sb.write(r - 0x0660);
      } else if (r >= 48 && r <= 57) {
        sb.writeCharCode(r);
      }
    }
    return sb.toString();
  }

  static String collapse(String s) => s.replaceAll(_spaces, ' ').trim();

  /// برش ایمن بر پایهٔ نویسه‌های یونیکد (Runes) تا جفت‌های جایگزین (UTF-16 Surrogates)
  /// مانند ایموجی‌ها از وسط نصف نشوند.
  static String truncate(String s, int maxRunes, {String ellipsis = ''}) {
    if (maxRunes <= 0) return ellipsis;
    if (s.length <= maxRunes) return s;
    final it = s.runes.iterator;
    var count = 0;
    final taken = <int>[];
    while (it.moveNext()) {
      if (count >= maxRunes) {
        return '${String.fromCharCodes(taken)}$ellipsis';
      }
      taken.add(it.current);
      count++;
    }
    return s;
  }

  static String _stem(String w) {
    for (final suf in _suffixes) {
      if (w.length - suf.length >= 3 && w.endsWith(suf)) {
        return w.substring(0, w.length - suf.length);
      }
    }
    return w;
  }

  static String _stemIndex(String w) {
    for (final suf in _suffixesIndex) {
      if (w.length - suf.length >= 3 && w.endsWith(suf)) {
        return w.substring(0, w.length - suf.length);
      }
    }
    return w;
  }

  static String stemIndex(String w) => _stemIndex(w);

  static String stemQuery(String w) => _stem(w);

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

  static final RegExp _allSameTenDigitsRe = RegExp(r'^(\d)\1{9}$');
  static final RegExp _irPhoneCleanRe = RegExp(r'[\s\-().]+');
  static final RegExp _irMobileOrLandlineRe =
      RegExp(r'^0(?:9\d{9}|[1-8]\d{9})$');

  /// اعتبارسنجی کد ملی ۱۰ رقمی ایران بر پایهٔ رقم کنترل (Modulo-11).
  static bool isValidIranianNationalId(String raw) {
    final cleaned = normalize(raw).replaceAll(_irPhoneCleanRe, '');
    if (cleaned.length != 10) return false;
    final digits = asciiDigits(cleaned);
    if (digits.length != 10) return false;
    if (_allSameTenDigitsRe.hasMatch(digits)) return false;

    var sum = 0;
    for (var i = 0; i < 9; i++) {
      sum += (digits.codeUnitAt(i) - 48) * (10 - i);
    }
    final rem = sum % 11;
    final check = digits.codeUnitAt(9) - 48;
    return rem < 2 ? check == rem : check == (11 - rem);
  }

  /// یکدست‌سازی شماره تلفن ایران (تبدیل +98 / 0098 به پیشوند 0 با ارقام لاتین).
  static String? normalizeIranianPhone(String raw) {
    var cleaned = normalize(raw).replaceAll(_irPhoneCleanRe, '');
    if (cleaned.startsWith('+98')) {
      cleaned = '0${cleaned.substring(3)}';
    } else if (cleaned.startsWith('0098')) {
      cleaned = '0${cleaned.substring(4)}';
    } else if (cleaned.length == 10 && cleaned.startsWith('9')) {
      cleaned = '0$cleaned';
    }
    if (!_irMobileOrLandlineRe.hasMatch(cleaned)) return null;
    return cleaned;
  }

  /// بررسی صحت قالب شماره تلفن همراه یا ثابت ایران.
  static bool isValidIranianPhone(String raw) =>
      normalizeIranianPhone(raw) != null;

  static RegExp wordRe(Iterable<String> words) {
    const letters = r'\u0621-\u06CC';
    const suffixes = 'ها|های|ام|ات|اش|مان|تان|شان|ان|م|ت|ش|ی|ای';
    return RegExp(
      '(?<![$letters])(?:${words.join('|')})(?:$suffixes)?(?![$letters])',
    );
  }
}