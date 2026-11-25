import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/reasoner.dart';

/// نقشهٔ پرسش‌های یک پرونده: «حالا چه بپرسم؟» — بی‌نیاز از وکیل.
///
/// این تابع پیش‌تر `Advocate._nextSlot` بود. هیچ‌چیز از گفتگو را نمی‌خواست:
/// نه صدایی که پاسخ می‌سازد، نه حالتِ روی میز، نه موتور. تنها چیزی که
/// می‌دانست این بود که کدام پرسش‌ها پرسیدنی‌اند و کدام‌شان مهم‌تر است.
/// جداکردنش دو فایده دارد: یک واحدِ آزمون‌شدنی می‌شود
/// (`test/advocate/isolation_test.dart` بدون ساختنِ `Advocate` صدایش
/// می‌زند)، و `Advocate` دیگر هم صاحبِ پرونده باشد هم صاحبِ نقشهٔ پرسش.
class CasePlan {
  const CasePlan._();

  /// پرسشِ بعدی، یا `null` اگر پرسیدنی نمانده باشد.
  ///
  /// سه چیز یک پرسش را از میز برمی‌دارد: متنِ خالی، جوابِ گرفته
  /// ([CaseFile.touched])، و شرطی که هنوز برقرار نیست ([Slot.when]). پرسشی
  /// که دو بار بی‌جواب مانده هم دوباره پرسیده نمی‌شود؛ اصرارِ سوم فقط
  /// گفتگو را می‌بندد.
  static Slot? nextSlot(Topic t, CaseFile f) {
    final askable = <Slot>[];
    for (final s in t.slots) {
      if (s.ask.isEmpty || f.touched(s.id)) continue;
      final w = s.when;
      if (w != null && !w(f)) continue;
      if ((f.askCount[s.id] ?? 0) >= 2) continue;
      askable.add(s);
    }
    return Reasoner.nextQuestion(t, f, askable);
  }
}
