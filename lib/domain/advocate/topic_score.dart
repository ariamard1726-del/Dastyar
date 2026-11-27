import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';

/// «این پیام چقدر به این موضوع می‌خورد؟» — بی‌نیاز از وکیل و از موتور.
///
/// پیش‌تر این دو تابعِ ساده داخل کتابخانهٔ `Advocate` بودند و چون `_` داشتند
/// از بیرون آزمون‌شدنی نبودند: برای سنجیدنِ «تشخیص موضوع» باید یک `Advocate`
/// و بانک قوانین ساخته می‌شد. حالا خودشان یک واحدند و
/// `test/advocate/isolation_test.dart` مستقیم صدایشان می‌زند.
class TopicScore {
  const TopicScore._();

  /// امتیازِ یک موضوع برای متنِ نرمال‌شده: جمع وزن نشانه‌هایی که در متن هست.
  ///
  /// صفر یعنی «این موضوع مطرح نیست»، نه «مطمئن نیستم»؛ شرطِ بازشدن
  /// ([Topic.gate]) هم پیش از شمردنِ نشانه‌ها سنجیده می‌شود.
  static int of(Topic t, String n) {
    if (t.anti.isNotEmpty && Sense.has(n, t.anti)) return 0;
    if (t.gate != null && !t.gate!(n)) return 0;
    return ignoringGate(t, n);
  }

  /// همان امتیازِ واژه‌ها، بدون شرطِ بازشدن؛ برای تشخیصِ «به این موضوع نزدیک
  /// است ولی هنوز شرطش را ندارد» تا به‌جای حکم، سؤال کوتاه پرسیده شود.
  static int ignoringGate(Topic t, String n) {
    if (t.anti.isNotEmpty && Sense.has(n, t.anti)) return 0;
    var s = 0;
    for (final e in t.cues.entries) {
      if (Sense.has(n, e.key)) s += e.value;
    }
    return s;
  }
}
