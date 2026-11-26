part of 'advocate.dart';

// یک پاسخِ ممکن برای همین پیام، و داوری که میانشان انتخاب میکند.
//
// پیشتر ترتیبِ پاسخها فقط از ترتیبِ `if`های داخلِ `_reply` پیدا میشد: برای
// فهمیدنِ اینکه «ایمنی پیش از موضوع است یا بعدش» باید دویست خط کد خوانده
// میشد. حالا هر پاسخ یک ورودیِ نامدار در یک فهرست است و داور، **اولین**
// ورودیای که جواب بدهد را برمیگرداند.
//
// این «امتیازدهی» نیست: داور هیچ ورودیای را دوباره وزن نمیکند، چون ترتیبِ
// فعلی در چند جا خودش تصمیم است (ایمنی پیش از موضوع، اصلاحِ کاربر پیش از
// بازکردنِ پرونده). ترتیب = اولویت، و عوضکردنش باید آگاهانه باشد، نه
// نتیجهٔ یک عدد. [AnswerCandidate.confidence] فقط توصیفِ کاندید است و در
// انتخاب دخیل نیست.

/// یک پاسخِ ممکن، با نامی که در گفتگو و در آزمون قابلِ ارجاع باشد.
class AnswerCandidate {
  const AnswerCandidate(
    this.name,
    this.build, {
    this.source = AnswerSource.unknown,
    this.confidence = 1.0,
    this.why = '',
  });

  /// نامِ کوتاهِ مسیر؛ در مستندات و آزمونها همین نام بهکار میرود.
  final String name;

  /// پاسخ را میسازد؛ `null` یعنی «این پیام مالِ من نیست».
  final AdvocateReply? Function() build;

  /// دستهٔ دانشی که این مسیر به آن تعلق دارد. برچسبِ توصیفی است؛ منبعِ
  /// نهاییِ پاسخ همان [AdvocateReply.source] است که سازندهٔ پاسخ مینویسد.
  final AnswerSource source;

  /// میزان اطمینانِ اعلامشدهٔ مسیر، صرفاً برای بازرسی و آزمون. داور از آن
  /// برای جابهجایی ترتیب استفاده نمیکند.
  final double confidence;

  /// دلیلِ کوتاهِ حضور مسیر در این جای فهرست (برای اشکالزدایی).
  final String why;
}

/// تصمیمِ داور: کاندیدِ برنده و پاسخی که ساخت.
///
/// پیشتر فقط متن پاسخ برمیگشت و نمیشد فهمید کدام مسیر برنده شده است. حالا
/// نام، منبع و دلیلِ مسیر همراهِ پاسخ نگهداری میشود.
class AnswerDecision {
  const AnswerDecision(this.candidate, this.reply);

  final AnswerCandidate candidate;
  final AdvocateReply reply;
}

/// داورِ فهرست: اولین کاندیدی که پاسخ بدهد برنده است.
class AnswerArbiter {
  const AnswerArbiter();

  AnswerDecision? decide(Iterable<AnswerCandidate> candidates) {
    for (final c in candidates) {
      final r = c.build();
      if (r != null) return AnswerDecision(c, r);
    }
    return null;
  }

  /// سازگاری با صدا زنندههایی که تنها به متن پاسخ نیاز دارند.
  AdvocateReply? pick(Iterable<AnswerCandidate> candidates) =>
      decide(candidates)?.reply;
}
