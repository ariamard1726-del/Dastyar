import 'package:dastyar/domain/advocate/advocate_texts_loader.dart';

/// بانک عبارت‌های وکیل: برای هر «کار گفتاری» چند بیان متفاوت هست تا
/// گفتگو یکنواخت و ماشینی نشود. انتخاب چرخشی است (نه تصادفی) تا رفتار
/// برنامه قابل‌تکرار و قابل‌آزمون بماند و متنها در `assets/brain/advocate_texts.json`
/// نگهداری می‌شوند.
class Say {
  const Say._();

  /// وقتی همان سؤال را دوباره می‌پرسیم.
  static List<String> get askAgain => advocateTextSeq('say_askAgain', 5);

  /// وقتی فقط بخشی از حرفم را گفته‌ام و بقیه مانده است.
  static List<String> get more => advocateTextSeq('say_more', 5);

  static List<String> get fine => advocateTextSeq('say_fine', 6);

  /// کنجکاوی دربارهٔ برخورد طرف مقابل (پرسش باز).
  static List<String> get askReply => advocateTextSeq('say_askReply', 3);

  /// کنجکاوی دربارهٔ خواستهٔ خودِ کاربر (پرسش باز).
  static List<String> get askGoal => advocateTextSeq('say_askGoal', 2);

  static String get disclaimer => advocateText('say_disclaimer');

  /// همدلی در آغاز یک ماجرای سخت.
  static List<String> get empathy => advocateTextSeq('say_empathy', 8);

  /// آغازِ بازگوییِ برداشت وکیل از حرف کاربر.
  static List<String> get understood => advocateTextSeq('say_understood', 7);

  /// آغازِ استدلال.
  static List<String> get argue => advocateTextSeq('say_argue', 7);

  static List<String> get holds => advocateTextSeq('say_holds', 4);

  static List<String> get fails => advocateTextSeq('say_fails', 3);

  static List<String> get unknown => advocateTextSeq('say_unknown', 5);

  /// وقتی حرف کاربر به نکتهٔ مشخصی وصل نشد.
  static List<String> get lost => advocateTextSeq('say_lost', 5);

  /// وقتی کاربر چیزی را که می‌دانستیم دوباره می‌گوید.
  static List<String> get known => advocateTextSeq('say_known', 5);

  static List<String> get counter => advocateTextSeq('say_counter', 3);

  static List<String> get switched => advocateTextSeq('say_switched', 4);
}
