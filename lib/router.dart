/// تشخیص قصدهای ثابت پرسش و متن پاسخ آن‌ها.
/// (فعلاً فقط دو قصد؛ قصدهای دیگر در قدم‌های بعد به اینجا می‌آیند.)
class QueryRouter {
  QueryRouter._();

  static bool asksCapabilities(String n) {
    final compact = n.replaceAll(RegExp(r'[\s‌‍‎‏،؛؟,.!?:]+'), '');
    final asksWhat =
        compact.contains('چهکاری') || compact.contains('چهکارهایی');
    final capabilityVerb =
        compact.contains('انجاممیدهی') ||
        compact.contains('انجاممیدی') ||
        compact.contains('میتوانی') ||
        compact.contains('میتونی') ||
        compact.contains('میکنی') ||
        compact.contains('ازدستتبرمیاد');
    final asksAboutCapabilities =
        (compact.contains('قابلیتهای') ||
         compact.contains('تواناییهای')) &&
        (compact.contains('دستیار') ||
         compact.contains('برنامه') ||
         compact.contains('تو'));
    return (asksWhat && capabilityVerb) || asksAboutCapabilities;
  }

  static bool asksOutcomePrediction(String n) {
    final compact = n.replaceAll(RegExp(r'[\s‌‍‎‏،؛؟,.!?:]+'), '');
    final asksCase = compact.contains('پرونده') ||
        compact.contains('حکمقاضی') ||
        compact.contains('نتیجهدادگاه');
    final asksPrediction =
        compact.contains('چهحکمی') ||
        compact.contains('صادرخواهدکرد') ||
        compact.contains('پیشبینینتیجه') ||
        compact.contains('نتیجهقطعی') ||
        compact.contains('حکمدقیق');
    return asksCase && asksPrediction;
  }

  static String capabilitiesText() {
    return replies.get('capabilities');
  }

  static String outcomeText() {
    return replies.get('outcome_prediction');
  }
}
