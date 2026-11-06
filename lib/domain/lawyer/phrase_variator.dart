/// انتخاب قطعیِ عبارت از میان گونه‌ها، بدون تکرار پشت‌سرهم.
///
/// برای هر «کلید» (مثلاً `opener.neutral`) یک شمارندهٔ جدا نگه می‌دارد و
/// گونه‌ها را به‌نوبت می‌چرخاند؛ پس تا همهٔ گونه‌های یک فهرست یک‌بار نیامده‌اند،
/// هیچ‌کدام تکرار نمی‌شود و دو پاسخ پیاپی هرگز با یک جمله شروع نمی‌شوند.
/// از Random استفاده نمی‌کند تا خروجی در تست قابل پیش‌بینی باشد؛ [seed]
/// فقط نقطهٔ شروع چرخش را جابه‌جا می‌کند.
class PhraseVariator {
  final int seed;
  final Map<String, int> _counters = {};

  PhraseVariator({this.seed = 0});

  /// شمارندهٔ فعلی یک کلید (برای تست).
  int counterOf(String key) => _counters[key] ?? 0;

  String pick(String key, List<String> variants) {
    if (variants.isEmpty) return '';
    if (variants.length == 1) return variants.first;
    final c = _counters[key] ?? 0;
    _counters[key] = c + 1;
    // بذر صفر (پیش‌فرض آزمون‌ها) همیشه از گزینهٔ نخست شروع می‌کند.
    final offset =
        seed == 0 ? 0 : (seed + _stableHash(key)) % variants.length;
    return variants[(offset + c) % variants.length];
  }

  void reset() => _counters.clear();

  /// درهم‌سازی پایدار (مستقل از پلتفرم) برای پخش نقطهٔ شروع کلیدها.
  static int _stableHash(String s) {
    var h = 0;
    for (final u in s.codeUnits) {
      h = (h * 31 + u) & 0x3fffffff;
    }
    return h;
  }
}
