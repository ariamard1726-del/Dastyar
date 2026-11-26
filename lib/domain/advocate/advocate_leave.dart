part of 'advocate.dart';

  /// «انصراف» آخرین دکمهٔ **هر** پاسخ است، در هر مرحله‌ای از گفتگو؛ وگرنه
  /// کاربر از وسط ماجرا راه خروج ندارد (بعضی مسیرها مثل جست‌وجوی متن قانون،
  /// پاسخ را مستقیم می‌سازند و از [_out] نمی‌گذرند).
extension _LeaveChip on Advocate {
  AdvocateReply _withLeave(AdvocateReply r) {
    if (r.chips.isNotEmpty && r.chips.last == ChipTexts.leaveChip) return r;
    return AdvocateReply(
      r.text,
      chips: [...r.chips.where((c) => c != ChipTexts.leaveChip), ChipTexts.leaveChip],
      laws: r.laws,
      source: r.source,
      ask: r.ask,
    );
  }
}
