part of 'advocate.dart';

// متنِ دکمه‌ها: همان چیزی که کاربر روی صفحه می‌بیند.
//
// این برچسب‌ها داده‌اند، نه رفتار؛ عضوِ کلاسِ ۵۰۰ خطی بودنشان فقط باعث
// می‌شد برای عوض کردنِ یک کلمه، فایلِ سیم‌کشی باز شود. حالا یک صفحه‌اند و
// آزمون هم حرف‌به‌حرف همان‌ها را قفل کرده است.

abstract final class ChipTexts {
  static const String moreChip = 'ادامه بده';
  static const String lawChip = 'متن قانون را ببینم';
  static const String newCaseChip = 'موضوع تازه‌ای دارم';
  /// پاسخ کاربر به «این ماجرای جدایی است؟».
  static const String sideChip = 'این یک موضوع جداست';
  /// پاسخ کاربر به «به همین ماجرای قبلی مربوط است؟».
  static const String relatedChip = 'به همین ماجرای قبلی مربوط است';
  /// پاسخ‌های پرسشِ «موضوع تازه است یا به قبلی مربوط؟» وقتی فقط همین پرسش
  /// روی میز است.
  static const String newTopicYesChip = 'بله';
  static const String newTopicNoChip = 'خیر';
  /// همان پاسخ‌ها وقتی پرسش همراهِ پرسشِ خودِ پرونده می‌آید؛ «بله/خیر» تنها
  /// با جوابِ پرسش‌های پرونده اشتباه می‌شود.
  static const String newTopicChip = 'بله، موضوع تازه است';
  static const String sameCaseChip = 'خیر، به همان ماجرا مربوط است';
  /// خروج از موضوع فقط با این دکمه (یا «انصراف» نوشته‌شده) انجام می‌شود.
  static const String leaveChip = 'انصراف';
  /// پاسخ کاربر به «ماجرای شما به کدام نزدیک‌تر است؟».
  static const String noneChip = 'هیچ‌کدام';
  /// پاسخ کاربر وقتی پرونده با حدسِ مدل باز شده و حدس غلط بوده.
  static const String wrongChip = 'موضوعم این نیست';
  static const List<String> starterChips = [
    'صاحبخانه پول پیشم را نمی‌دهد',
    'کارفرما اخراجم کرده',
    'چکم برگشت خورده',
    'می‌خواهم طلاق بگیرم',
  ];
  /// دکمه‌های «دستهٔ مشکل» که بعد از سلام نشان داده می‌شوند.
  ///
  /// پیش‌تر پاسخِ سلام چهار ماجرای آمادهٔ دیگران را پیشنهاد می‌داد؛ برای
  /// کاربری که تازه سلام کرده، این نمی‌گفت از کجا شروع کند. حالا اول شاخهٔ
  /// کار روشن می‌شود و بعد ماجرا پرسیده می‌شود.
  static const String civilChip = 'حقوقی';
  static const String criminalChip = 'کیفری';
  static const String adminChip = 'اداری';
  static const String unsureChip = 'نمی‌دانم';
  /// دکمهٔ خروج، همان [leaveChip] است: هم موضوعِ باز را می‌بندد، هم در آغاز
  /// گفتگو راهِ انصراف است.
  static const List<String> branchChips = [
    civilChip,
    criminalChip,
    adminChip,
    unsureChip,
    leaveChip,
  ];
}
