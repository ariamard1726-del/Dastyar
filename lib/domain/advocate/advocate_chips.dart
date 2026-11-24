part of 'advocate.dart';

// دکمه‌های پیشنهادی زیر هر پاسخ.

extension _Chips on Advocate {
  ChipPlan get _chipPlan => ChipPlan(
        file: file,
        dialog: dialog,
        filings: filings,
        draftTitles: _draftTitles,
      );

  /// پیشنهادهای متناسب با همین گفتگو.
  List<String> _suggest(Topic t) => _chipPlan.suggest(t);

  /// بیرون از پرونده، نمونه‌های آماده فقط پیش از آن‌که کاربر ماجرایی گفته
  /// باشد نشان داده می‌شود؛ بعد از آن ربطی به حرف او ندارد.
  List<String> _idleChips() => _chipPlan.idle(_current());

  /// نمونه‌های آغاز گفتگو.
  List<String> _starters() => _chipPlan.starters();
}
