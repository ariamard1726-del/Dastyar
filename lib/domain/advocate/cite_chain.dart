import 'package:dastyar/domain/advocate/reasoner.dart';

/// زنجیرهٔ استناد (Cite Chain): از فکتِ کاربر تا نتیجهٔ استنادی، با ردِپا.
///
/// قالبِ خروجی عمداً ساختاری است تا هم UI (به‌جای متن آزاد) و هم ابزارهای
/// سنجش بتوانند همان یک زنجیره را بخوانند؛ هیچ مدل آماری وارد این مسیر
/// نمی‌شود.
///
/// زنجیره: **مقدمات** (فکت‌های کاربر) ← **قاعده** (شرط‌های برقرار/نابرقرار)
/// ← **نتیجه** (`strong | open | weak`) ← **استناد** («مادهٔ N قانون Y»)
/// ← **استثنا** (شرط‌های ناکام؛ اگر نباشد «—»).
///
/// «وضعیت سه‌ارزشی» دقیقاً همان [Standing] ای است که `Reasoner` به کار
/// می‌برد؛ دو enum جداگانه نمی‌سازیم. سیم‌کشی آن در مسیر پرونده، فعلاً برای
/// سنجش سازگاری در حین صدا زدنِ استدلال است (پاسخ متنی عوض نمی‌شود)؛
/// نمایش مستقیمِ زنجیره در UI به‌زبان بصری بعد از تثبیت لایهٔ نمایشی است.
class CiteChain {
  CiteChain({
    required this.facts,
    required this.rule,
    required this.standing,
    required this.citation,
    this.failedConditions = const [],
  });

  /// فکت‌های کاربر که قاعده رویشان سنجیده شده (به ترتیب بیان کاربر).
  final List<String> facts;

  /// نام یا توصیف کوتاه قاعده (مثلاً «گواهی عدم پرداخت»).
  final String rule;

  /// وضعیت سه‌ارزشیِ همان دعوای روی میز.
  final Standing standing;

  /// «مادهٔ N قانون Y» — فقط استنادی که موتور واقعاً بازیابی کرده.
  final String citation;

  /// شرط‌هایی که رد/معلوم نشدند؛ خالی = «هیچ شرطی نامعلوم نمانده».
  final List<String> failedConditions;

  /// برچسب فارسیِ وضعیت (همان نگاشتِ سه‌تایی امروز، یک‌بار این‌جا).
  static String labelOf(Standing s) {
    switch (s) {
      case Standing.strong:
        return 'برقرار';
      case Standing.open:
        return 'نامعلوم';
      case Standing.weak:
        return 'نابرقرار';
    }
  }

  /// یک‌خطی ساختاریافته برای لاگ/گزارش.
  String build() {
    final pre = facts.isEmpty ? '—' : facts.join('، ');
    final exc = failedConditions.isEmpty ? '—' : failedConditions.join('، ');
    return 'مقدمات: $pre؛ '
        'قاعده: $rule (${labelOf(standing)})؛ '
        'نتیجه: ${standing.name}؛ '
        'استناد: $citation؛ '
        'استثنا: $exc';
  }

  /// زنجیره به‌صورت سطربه‌سطر (برای UIِ «چرا؟ / با چه شرطی؟ / منبع؟»).
  List<String> toLines() => [
        'مقدمات: ${facts.isEmpty ? '—' : facts.join('، ')}',
        'قاعده: $rule (${labelOf(standing)})',
        'نتیجه: ${standing.name}',
        'استناد: $citation',
        if (failedConditions.isEmpty)
          'استثنا: —'
        else
          'استثنا: ${failedConditions.join('، ')}',
      ];
}
