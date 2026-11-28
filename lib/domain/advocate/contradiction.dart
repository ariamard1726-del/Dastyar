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

  /// مرز جمله در متنِ *خام* (پیش از یکسان‌سازی): نقطه، علامت‌های سؤال و
  /// تعجبِ فارسی و لاتین، ویرگول و سمیکالن و دو نقطه و خط نو.
  ///
  /// نکتهٔ پیاده‌سازی: یکسان‌ساز `Sense.norm` نقطه‌ها را حذف می‌کند، پس
  /// تقسیم جمله باید روی متن خام انجام شود و بعد هر جمله جداگانه
  /// یکسان‌سازی شود؛ وگرنه نفیِ جملهٔ همسایه به جملهٔ فعلی می‌چسبد.
  static final RegExp _sentenceSplit = RegExp(r'[.؟!?؟؛;:،\n]');

  /// حروف فارسی/عربی (و اشکل) برای مرزِ واژهٔ فارسی.
  static const String _fa = '[\\u0600-\\u06FF\\uFB50-\\uFDFF\\uFE70-\\uFEFF]';

  /// پیوست‌های چسبیدهٔ متداول فارسی پشتِ واژه (ضمیر، نشانهٔ جمع و …):
  /// «شاهدم»، «شاهدی»، «شاهدان»، «شاهدها»، «شاهدمان» همان واژهٔ «شاهد»
  /// هستند؛ «شهادتنامه» نه. بلندترین‌ها اول می‌آیند تا تطبیق اشتباهی نگیرد.
  static const String _enclitics =
      '(?:مان|تان|شان|های|ها|یّ|ّ|ام|ای|ات|اش|ان|ین|م|ت|ش|ی)?';

  /// آیا در همان جمله‌ای که [cue] هست، نفی صریح هم هست؟
  ///
  /// - «قرارداد کتبی ندارم» × «قرارداد کتبی» → true
  /// - «قرارداد کتبی دارم» × «قرارداد کتبی» → false
  /// - «شاهدی ندارم» × «شاهد» → true (پیوستِ «ی» همان واژه است)
  /// - «شاهدی ندارم. قرارداد کتبی دارم» × «قرارداد کتبی» → false
  static bool negates(String text, String cue) {
    final needle = Sense.norm(cue).trim();
    if (needle.isEmpty) return false;
    final pattern = _cuePattern(needle);
    for (final rawPart in text.split(_sentenceSplit)) {
      final part = Sense.norm(rawPart);
      if (!pattern.hasMatch(part)) continue;
      if (Sense.containsNegation(part)) return true;
    }
    return false;
  }

  /// کدام‌یک از [cues] صریحاً نفی شده‌اند (برای پرسشِ پیگیری).
  static List<String> negatedCues(String text, Iterable<String> cues) =>
      [for (final c in cues) if (negates(text, c)) c];

  static RegExp _cuePattern(String cue) =>
      RegExp('(?<!$_fa)${RegExp.escape(cue)}$_enclitics(?!$_fa)');
}
