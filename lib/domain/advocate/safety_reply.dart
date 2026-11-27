part of 'advocate.dart';

// پاسخِ ایمنی، پیش از هر پاسخِ دیگر.
//
// این بخش «حقوقی» نیست: اگر کسی همین حالا در خطر است، هیچ فرایند حقوقی‌ای
// نباید جلوی تماس با اورژانس را بگیرد. جداکردنش دو فایده دارد: قاعده‌اش یک جا
// خوانده می‌شود، و می‌شود آزمونش کرد بدونِ ساختنِ کلِ وکیل — چیزی که پیش‌تر
// ممکن نبود، چون `_safety` متدِ خصوصیِ `Advocate` بود.

/// خشونت خانگی، تهدید، یا گزارشِ تماس با اورژانس.
///
/// خودش تصمیم نمی‌گیرد پرونده باز شود یا نه؛ آن کارِ `Advocate` است.
class SafetyReply {
  SafetyReply({required this.voice});

  final ReplyVoice voice;

  AdvocateReply _out(
    String text, {
    List<String> chips = const [],
    String ask = '',
    bool full = false,
    int budget = _budget,
    AnswerSource source = AnswerSource.safety,
  }) =>
      voice.out(text,
          chips: chips, ask: ask, full: full, budget: budget, source: source);

  /// «الان در خطر هستم» جوابِ پرسش خودِ ماست، نه توصیفِ ماجرا.
  bool asksDanger(String n) => Sense.has(n,
      'الان در خطر(?: هستم|یم)?(?! نیست)|همین حالا در خطر|در خطر فوری|هنوز در خطر|کسی در خطر');

  /// حرف از آسیب رساندن به خود. وکیل قاعدمحور نباید در چنین لحظهای وارد
  /// بحث حقوقی شود؛ نخست کمک فوری، سپس در صورت امنیت، بحث حقوقی.
  bool asksSelfHarm(String n) => Sense.has(n,
      'خودکش|خودمو میکشم|خودم را میکشم|دیگه تحمل ندارم|دیگر تحمل ندارم|'
      'نمیخوام زنده بمونم|نمیخواهم زنده بمانم|قصد دارم بمیرم');

  bool acknowledgesSafe(String n) => Sense.has(
      n,
      r'^\s*(?:الان )?(?:امن (?:است|هست|هستم)|در خطر نیستم|جای امنی هستم|خطر رفع شد(?:ه)?)\s*$');

  bool _isCalled(String n) =>
      Sense.has(n, 'اورژانس|۱۱۰|۱۱۵|پلیس|کلانتری|بهزیستی') &&
      Sense.has(n, 'زنگ زدم|زنگ زدیم|تماس گرفتم|خبر دادم|زنگ زده');

  bool _isViolent(String n) =>
      Sense.has(n,
          'کتک|کفش پرت|پرت (?:می|کرد|کنه|میکنه)|چاقو|تهدید|(?:را|رو|منو|مرا|ما را|او را|بچه رو|بچه را) (?:زد|زده|زدن|میزن|می زن|میزنه|میزنن|میزند)') &&
      Sense.has(n,
          'خاله|عمه|عمو|دایی|مادر|پدر|برادر|خواهر|شوهر|زنم|همسرم|بچه|پسرم|دخترم|مادرم|پدرم|خانواده|نامادری|ناپدری');

  SafetySeverity severityOf(String n) {
    if (asksSelfHarm(n) || asksDanger(n)) return SafetySeverity.critical;
    if (_isCalled(n) || _isViolent(n)) return SafetySeverity.elevated;
    return SafetySeverity.none;
  }

  AdvocateReply? reply(String n) {
    // «الان در خطر هستم» جوابِ پرسش خودِ ماست و باید سریع‌ترین راه را بدهد.
    if (asksSelfHarm(n)) {
      return _out(
        advocateText('safetySelfHarmText'),
        ask: advocateText('safetySelfHarmAsk'),
        chips: [
          advocateText('safetyChipSafeNow'),
          advocateText('safetyChipDangerNow'),
        ],
        source: AnswerSource.safety,
      );
    }
    if (asksDanger(n)) {
      return _out(
        advocateText('safetyDangerText'),
        ask: advocateText('safetyDangerAsk'),
        chips: [
          advocateText('safetyChipSafeNow'),
          advocateText('safetyChipDangerNow'),
        ],
        source: AnswerSource.safety,
      );
    }
    final called = _isCalled(n);
    final violent = _isViolent(n);
    if (called) {
      return _out(
        advocateText('safetyCalledText'),
        ask: advocateText('safetyCalledAsk'),
        chips: [
          advocateText('safetyChipInDanger'),
          advocateText('safetyChipSafe'),
        ],
        source: AnswerSource.safety,
      );
    }
    if (violent) {
      return _out(
        advocateText('safetyViolentText'),
        ask: advocateText('safetyViolentAsk'),
        chips: [
          advocateText('safetyChipInDanger'),
          advocateText('safetyChipSafe'),
        ],
        source: AnswerSource.safety,
      );
    }
    return null;
  }
}
