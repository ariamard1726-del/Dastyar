/// یکدست‌سازی متن فارسی برای تطبیق قطعیِ کلیدواژه‌ها.
///
/// همهٔ متدها خالص و قطعی‌اند (بدون حالت و بدون تصادف) تا در تست‌ها
/// خروجی ثابت بدهند.
///
/// تفاوت با [PersianText.normalize]: این کلاس نیم‌فاصله (ZWNJ) را **حذف**
/// می‌کند (نه تبدیل به فاصله)، تا «می‌خواهم»، «میخواهم» و «می خواهم» در
/// تطبیق عبارت‌ها یکی شوند؛ کلیدواژه‌ها هم با همین تابع یکدست می‌شوند.
class PersianNormalizer {
  PersianNormalizer._();

  /// نگاشت نویسه‌های عربی/گونه‌ای به معادل فارسی.
  static const Map<int, String> _charMap = {
    0x064A: 'ی', // ي  یای عربی
    0x0649: 'ی', // ى  الف مقصوره
    0x0643: 'ک', // ك  کاف عربی
    0x06C0: 'ه', // ۀ
    0x0629: 'ه', // ة
    0x0623: 'ا', // أ
    0x0625: 'ا', // إ
    0x0671: 'ا', // ٱ
    0x0624: 'و', // ؤ
    0x0626: 'ی', // ئ  (اجرائیه = اجراییه)
  };

  static final RegExp _spaces = RegExp(r'\s+');

  /// هر چیزی جز حرف، رقم و فاصله (نشانه‌گذاری، ایموجی، نماد) → فاصله.
  static final RegExp _nonWord =
      RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

  static bool _isDiacritic(int r) =>
      (r >= 0x064B && r <= 0x065F) || // فتحه، ضمه، کسره، تنوین، تشدید، سکون…
      r == 0x0670 || // الف خنجری
      r == 0x0640 || // کشیده (ـ)
      (r >= 0x06D6 && r <= 0x06ED); // نشانه‌های قرآنی

  static bool _isInvisible(int r) =>
      r == 0x200C || // ZWNJ نیم‌فاصله
      r == 0x200D || // ZWJ
      r == 0x200E || // LRM
      r == 0x200F || // RLM
      r == 0xFEFF; // BOM

  /// یکدست‌سازی پایه:
  /// - «ي»→«ی»، «ك»→«ک» (و چند گونهٔ دیگر)،
  /// - ارقام فارسی (۰-۹) و عربی (٠-٩) → ارقام انگلیسی،
  /// - حذف نیم‌فاصله و نویسه‌های نامرئی جهت‌دهی،
  /// - حذف اعراب و کشیده،
  /// - حروف لاتین کوچک و فاصله‌های تکراری یکی.
  static String normalize(String input) {
    if (input.isEmpty) return '';
    final sb = StringBuffer();
    for (final r in input.runes) {
      if (r >= 0x06F0 && r <= 0x06F9) {
        sb.writeCharCode(0x30 + r - 0x06F0);
        continue;
      }
      if (r >= 0x0660 && r <= 0x0669) {
        sb.writeCharCode(0x30 + r - 0x0660);
        continue;
      }
      if (_isInvisible(r) || _isDiacritic(r)) continue;
      final mapped = _charMap[r];
      if (mapped != null) {
        sb.write(mapped);
      } else {
        sb.writeCharCode(r);
      }
    }
    return sb.toString().toLowerCase().replaceAll(_spaces, ' ').trim();
  }

  /// یکدست‌سازی برای تطبیق واژه‌ای: علاوه بر [normalize]، هر نشانه‌گذاری
  /// (،؛؟!.«»()… و ایموجی) با فاصله جایگزین می‌شود تا «چک،» و «چک» یکی
  /// شوند و مرز واژه‌ها حفظ شود.
  static String normalizeForMatching(String input) {
    final n = normalize(input);
    if (n.isEmpty) return '';
    final spaced = n.replaceAll(_nonWord, ' ').replaceAll(_spaces, ' ').trim();
    // «می دهد»/«نمی دهد» (با فاصلهٔ کامل) = «می‌دهد» با نیم‌فاصلهٔ حذف‌شده.
    return spaced.replaceAllMapped(
      _verbPrefix,
      (m) => '${m.group(1)}${m.group(2)}',
    );
  }

  static final RegExp _verbPrefix = RegExp(r'(^| )(ن?می) (?=[^ ])');

  /// واژه‌های متنِ یکدست‌شده برای تطبیق.
  static List<String> tokens(String input) {
    final n = normalizeForMatching(input);
    if (n.isEmpty) return const [];
    return n.split(' ');
  }

  /// پسوندهای رایجی که بعد از واژهٔ کلیدی مجازند (ضمیر ملکی، جمع، نکره).
  /// چون نیم‌فاصله حذف می‌شود، «چک‌هایم» به «چکهایم» تبدیل می‌شود.
  static const Set<String> _suffixes = {
    'م', 'ت', 'ش', 'مان', 'تان', 'شان', 'ام', 'ات', 'اش',
    'ها', 'های', 'هایم', 'هایت', 'هایش', 'هامو', 'هاش',
    'ی', 'ای', 'یم', 'مو', 'تو', 'شو', 'رو',
  };

  static bool _tokenMatches(String textTok, String phraseTok, bool suffixes) {
    if (textTok == phraseTok) return true;
    if (!suffixes || phraseTok.length < 2) return false;
    if (!textTok.startsWith(phraseTok)) return false;
    return _suffixes.contains(textTok.substring(phraseTok.length));
  }

  /// آیا [phrase] به‌صورت واژه/عبارت کامل در [text] آمده است؟
  ///
  /// هر دو ورودی یکدست می‌شوند و تطبیق روی مرز واژه است؛ «چک» در «چکاد»
  /// پیدا نمی‌شود. ترتیب و پیوستگی واژه‌های عبارت چندواژه‌ای لازم است.
  /// با [allowSuffixes] پسوندهای رایج (چکم، چک‌ها، مهریه‌ام) پذیرفته
  /// می‌شوند؛ چون «چکش» هم «چک+ش» خوانده می‌شود، کلیدواژه‌های کوتاه
  /// باید وزن کم داشته باشند.
  static bool containsPhrase(
    String text,
    String phrase, {
    bool allowSuffixes = true,
  }) =>
      containsPhraseTokens(tokens(text), tokens(phrase),
          allowSuffixes: allowSuffixes);

  /// نسخهٔ واژه‌به‌واژهٔ [containsPhrase] برای وقتی که متن یک بار
  /// واژه‌بندی شده و چندین عبارت روی آن آزموده می‌شود.
  static bool containsPhraseTokens(
    List<String> textTokens,
    List<String> phraseTokens, {
    bool allowSuffixes = true,
  }) {
    if (textTokens.isEmpty || phraseTokens.isEmpty) return false;
    final n = phraseTokens.length;
    for (var i = 0; i + n <= textTokens.length; i++) {
      var ok = true;
      for (var j = 0; j < n; j++) {
        if (!_tokenMatches(textTokens[i + j], phraseTokens[j], allowSuffixes)) {
          ok = false;
          break;
        }
      }
      if (ok) return true;
    }
    return false;
  }
}
