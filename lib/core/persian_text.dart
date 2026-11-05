/// لایهٔ متن فارسی: یکدست‌سازی نویسه‌ها، تبدیل ارقام، ریشه‌یابی سبک و واژه‌بندی.
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

  static const List<String> _suffixes = ['ترین', 'هایی', 'های', 'ها', 'تر', 'ان', 'ات', 'ی'];
  static const List<String> _suffixesIndex = ['ترین', 'هایی', 'های', 'ها'];

  static final RegExp _nonWord = RegExp(r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+');
  static final RegExp _spaces = RegExp(r'\s+');

  static String normalize(String s) {
    const map = {
      'ي': 'ی', 'ى': 'ی', 'ك': 'ک', 'ۀ': 'ه', 'ة': 'ه',
      'أ': 'ا', 'إ': 'ا', 'ٱ': 'ا',
    };
    final sb = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x06F0 && r <= 0x06F9) { sb.write(r - 0x06F0); continue; }
      if (r >= 0x0660 && r <= 0x0669) { sb.write(r - 0x0660); continue; }
      if (r == 0x200C || r == 0x200D || r == 0x200E || r == 0x200F) { sb.write(' '); continue; }
      if (r >= 0x064B && r <= 0x065F) continue;
      if (r == 0x0640) continue;
      final ch = String.fromCharCode(r);
      sb.write(map[ch] ?? ch);
    }
    return sb.toString().toLowerCase();
  }

  static String toFaDigits(String s) {
    final sb = StringBuffer();
    for (final r in s.runes) {
      if (r >= 48 && r <= 57) sb.write(_faDigits[r - 48]);
      else if (r >= 0x0660 && r <= 0x0669) sb.write(_faDigits[r - 0x0660]);
      else sb.writeCharCode(r);
    }
    return sb.toString();
  }

  static String asciiDigits(String s) {
    final sb = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x06F0 && r <= 0x06F9) sb.write(r - 0x06F0);
      else if (r >= 0x0660 && r <= 0x0669) sb.write(r - 0x0660);
      else if (r >= 48 && r <= 57) sb.writeCharCode(r);
    }
    return sb.toString();
  }

  static String collapse(String s) => s.replaceAll(_spaces, ' ').trim();

  static String truncate(String s, int maxRunes, {String ellipsis = ''}) {
    if (maxRunes <= 0) return ellipsis;
    if (s.length <= maxRunes) return s;
    final it = s.runes.iterator;
    var count = 0;
    final taken = <int>[];
    while (it.moveNext()) {
      if (count >= maxRunes) return '${String.fromCharCodes(taken)}$ellipsis';
      taken.add(it.current);
      count++;
    }
    return s;
  }

  static String _stem(String w) {
    for (final suf in _suffixes) {
      if (w.length - suf.length >= 3 && w.endsWith(suf)) return w.substring(0, w.length - suf.length);
    }
    return w;
  }

  static String _stemIndex(String w) {
    for (final suf in _suffixesIndex) {
      if (w.length - suf.length >= 3 && w.endsWith(suf)) return w.substring(0, w.length - suf.length);
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

  static String phrase(String s) => collapse(normalize(s).replaceAll(_nonWord, ' '));

  static final RegExp _allSameTenDigitsRe = RegExp(r'^(\d)\1{9}$');
  static final RegExp _irPhoneCleanRe = RegExp(r'[\s\-().]+');
  static final RegExp _irMobileOrLandlineRe = RegExp(r'^0(?:9\d{9}|[1-8]\d{9})$');

  static bool isValidIranianNationalId(String raw) {
    final cleaned = normalize(raw).replaceAll(_irPhoneCleanRe, '');
    if (cleaned.length != 10) return false;
    final digits = asciiDigits(cleaned);
    if (digits.length != 10) return false;
    if (_allSameTenDigitsRe.hasMatch(digits)) return false;
    var sum = 0;
    for (var i = 0; i < 9; i++) sum += (digits.codeUnitAt(i) - 48) * (10 - i);
    final rem = sum % 11;
    final check = digits.codeUnitAt(9) - 48;
    return rem < 2 ? check == rem : check == (11 - rem);
  }

  static String? normalizeIranianPhone(String raw) {
    var cleaned = normalize(raw).replaceAll(_irPhoneCleanRe, '');
    if (cleaned.startsWith('+98')) cleaned = '0${cleaned.substring(3)}';
    else if (cleaned.startsWith('0098')) cleaned = '0${cleaned.substring(4)}';
    else if (cleaned.length == 10 && cleaned.startsWith('9')) cleaned = '0$cleaned';
    if (!_irMobileOrLandlineRe.hasMatch(cleaned)) return null;
    return cleaned;
  }

  static bool isValidIranianPhone(String raw) => normalizeIranianPhone(raw) != null;

  // ── مرز واژهٔ فارسی ──────────────────────────────────────────────────
  /// حروفی که مرز واژه را میسازند؛ `\b` فقط لاتین را میشناسد.
  static const String _wordLetters = r'\u0621-\u06CC';

  /// فاصلهٔ منعطف میان تکواژها: فاصله، نیمفاصله، پیوند مجازی و کشیدگی.
  static const String _wordGap = r'[\s\u200C\u200D\u0640]+';

  /// پسوندهای رایج فارسی، بلند به کوتاه تا «های» توسط «ها» بلعیده نشود.
  static const List<String> _wordSuffixes = <String>[
    'ترین', 'هایی', 'های', 'شان', 'تان', 'مان', 'اش', 'ات', 'ام',
    'ها', 'تر', 'ان', 'ای', 'م', 'ت', 'ش', 'ی',
  ];

  /// نویسههای یکدستشده توسط [normalize] به همراه شکلهای عربیشان، تا الگو
  /// حتی روی متن خام (نرمتنشده) هم درست کار کند.
  static const Map<String, String> _wordCharVariants = <String, String>{
    'ی': r'[\u06CC\u064A\u0649]', // ی / ي / ى
    'ک': r'[\u06A9\u0643]', // ک / ك
    'ه': r'[\u0647\u0629\u06C0]', // ه / ة / ۀ
    'ا': r'[\u0627\u0623\u0625\u0671]', // ا / أ / إ / ٱ
  };

  static String _wordCharPattern(String ch) {
    final variants = _wordCharVariants[ch];
    if (variants != null) return variants;
    if (ch.length == 1) {
      final code = ch.codeUnitAt(0);
      if (code >= 48 && code <= 57) {
        final d = code - 48;
        // رقم لاتین، فارسی و عربی همارز یکدیگرند.
        return '[$d${String.fromCharCode(0x06F0 + d)}${String.fromCharCode(0x0660 + d)}]';
      }
    }
    // گریز نویسههای ویژهٔ RegExp تا ورودی همیشه متن ساده باشد.
    return RegExp.escape(ch);
  }

  /// تبدیل یک واژه/عبارت [normalize]شده به الگوی RegExp.
  static String _wordPattern(String normalized) => normalized
      .split(' ')
      .map((token) => token.runes
          .map((r) => _wordCharPattern(String.fromCharCode(r)))
          .join())
      .join(_wordGap);

  /// الگوی «مرز واژهٔ فارسی» برای تشخیص دقیق واژهها و عبارتها.
  ///
  /// * یکدستسازی نویسهها (ي/ى ← ی، ك ← ک، ة/ۀ ← ه، أ/إ/ٱ ← ا)، تبدیل
  ///   ارقام فارسی/عربی، حذف اعراب/کشیدگی و اصلاح فاصلهها و نیمفاصلهها.
  /// * ورودیها با [RegExp.escape] گریز میشوند تا نویسههای ویژهٔ RegExp
  ///   هرگز به عنوان الگو تفسیر نشوند.
  /// * مرزها به جای `\b` با حروف فارسی تعریف شدهاند: «چک» در «چکار»
  ///   تطبیق نمیکند، ولی «چک»، «چکها»، «چکام» و «چک برگشتی» آری.
  /// * برای [words] خالی، الگویی برمیگرداند که هیچگاه تطبیق نمیکند.
  static RegExp wordRe(Iterable<String> words) {
    final alternatives = <String>[];
    final seen = <String>{};
    for (final raw in words) {
      final normalized = collapse(normalize(raw));
      if (normalized.isEmpty || !seen.add(normalized)) continue;
      alternatives.add(_wordPattern(normalized));
    }
    if (alternatives.isEmpty) return RegExp(r'(?!)');

    final suffixes = _wordSuffixes
        .map((s) => _wordPattern(collapse(normalize(s))))
        .join('|');
    return RegExp(
      '(?<![${_wordLetters}])(?:${alternatives.join('|')})(?:$suffixes)?(?![${_wordLetters}])',
      // [normalize] متن لاتین را هم کوچک میکند؛ الگو باید بیاعتنا به حالت
      // حروف باشد تا «C++» و «c++» هر دو تطبیق کنند.
      caseSensitive: false,
    );
  }
}