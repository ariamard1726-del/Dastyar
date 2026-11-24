part of 'advocate.dart';

// پوستهٔ نازکِ روندِ پرونده. خودِ روند در `case_flow.dart` (`class CaseFlow`)
// است؛ این متدها فقط نام‌های پیشین را نگه می‌دارند تا بقیهٔ بخش‌ها بی‌تغییر
// بمانند و اگر روزی کسی خواست مستقیم `CaseFlow` را صدا بزند، راهش باز باشد.

/// نشانه‌های اینکه کاربر دارد حرف قبلی‌اش را صریحاً اصلاح می‌کند.
const String _amend =
    ' منظورم | اشتباه (?:گفتم|نوشتم|شد|فهمیدی|گرفتی) | در اصل | درستش | نه (?:اصلا )?(?:مشکل|موضوع|دعوا|حرف|مسئله)(?:م|مون| من| ما)? ';

extension _CaseFlow on Advocate {
  void _closeCase() => _case.closeCase();

  AdvocateReply _filing(Filing g) => _case.filing(g);

  AdvocateReply _open(Topic t, String n,
          {bool switched = false, bool guessed = false}) =>
      _case.open(t, n, switched: switched, guessed: guessed);

  AdvocateReply _inCase(Topic t, String raw, String n, Issue? issue) =>
      _case.inCase(t, raw, n, issue);
}
