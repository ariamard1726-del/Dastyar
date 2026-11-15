/// حدسِ مدل دربارهٔ موضوع یک جمله: بهترین دسته، دستهٔ دوم و اطمینان هرکدام.
///
/// فقط یک حدس است؛ این‌که با آن چه شود (باز کردن پرونده، پرسیدن از کاربر یا
/// نادیده‌گرفتن) تصمیمِ وکیل است.
class TopicGuess {
  const TopicGuess(
    this.label,
    this.score,
    this.second,
    this.secondScore, {
    this.confident = false,
    this.plausible = false,
    this.millis = 0,
    this.tokens = 0,
  });

  final String label;
  final double score;
  final String second;
  final double secondScore;

  /// اطمینان به اندازه‌ای هست که پرونده مستقیم باز شود.
  final bool confident;

  /// اطمینان به اندازه‌ای هست که از کاربر پرسیده شود.
  final bool plausible;

  /// زمان محاسبه روی همین دستگاه و شمار توکن‌های جمله.
  final int millis;
  final int tokens;

  @override
  String toString() =>
      '$label=${score.toStringAsFixed(2)} ($second=${secondScore.toStringAsFixed(2)})';
}
