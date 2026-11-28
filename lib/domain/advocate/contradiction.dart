import 'package:dastyar/domain/advocate/text_sense.dart';

/// تناقض‌یابی محتوایی (فاز ۴): تشخیصِ صریحِ «ردِ شرط» توسط کاربر.
///
/// وقتی متن کاربر شرطِ «بودنِ چیزی» را (مثل «قرارداد کتبی») صریحاً نفی کند
/// («قرارداد کتبی ندارم»)، قاعدهٔ سه‌ارزشی نباید آن شرط را «برقرار» بگیرد؛
/// باید به‌جای پاسخ قطعی، همان شرط را با سؤال نشان دهد. این کلاس فقط «آیا
/// نفی صریح رخ داده» را می‌سنجد؛ تصمیم «پاسخ / سؤال» با Reasoner است.
///
/// محدودیت صادقانه: این تحلیل اسکوپِ نفی («چه چیزی» نفی شده) را فقط تا سطح
/// واژه انجام می‌دهد؛ نفی‌های مرکب («نه اینکه قرارداد کتبی داشته باشیم»)
/// ممکن است اشتباه بگیرد. به همین خاطر خروجی آن «هشدار» است نه «حکم».
class Contradiction {
  Contradiction._();

  static final RegExp _sentenceSplit = RegExp(r'[.؟!؟،\n]');

  /// آیا در همان جمله‌ای که [cue] هست، نفی صریح هم هست؟
  ///
  /// - «قرارداد کتبی ندارم» × «قرارداد کتبی» → true
  /// - «قرارداد کتبی دارم» × «قرارداد کتبی» → false
  /// - «قرارداد کتبی امضا شد اما گم شد» × «قرارداد کتبی» → false
  /// - «بیمه ام را نمی کنند» × «بیمه» → true
  static bool negates(String text, String cue) {
    final needle = Sense.norm(cue);
    if (needle.isEmpty) return false;
    final normalized = Sense.norm(text);
    for (final part in normalized.split(_sentenceSplit)) {
      if (!part.contains(needle)) continue;
      if (Sense.containsNegation(part)) return true;
    }
    return false;
  }

  /// کدام‌یک از [cues] صریحاً نفی شده‌اند (برای پرسشِ پیگیری).
  static List<String> negatedCues(String text, Iterable<String> cues) =>
      [for (final c in cues) if (negates(text, c)) c];
}
