import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';

/// آنچه در این نوبت «روی میز» است: پرسشی که پرسیده‌ام، پیشنهادی که داده‌ام،
/// موضوعی که منتظر تأییدش هستم و پروندهٔ کمکی که باز کرده‌ام.
///
/// پیش‌تر این ۲۵ فیلد روی خودِ `Advocate` بودند، کنارِ موتور، پرونده و
/// موضوع‌ها؛ هر متدی در هر بخش می‌توانست هر کدام را عوض کند و همین باعث
/// می‌شد «چه چیزی روی میز است» را نتوان جدا آزمود. حالا یک صاحب دارد و
/// `Advocate` فقط از آن می‌خواند.
///
/// این وضعیت **رفتاری** است: با `reset()` به حالت آغاز گفتگو برمی‌گردد و با
/// `clearCase()` با بسته‌شدن پرونده پاک می‌شود (به‌جز آنچه به گفتگو مربوط است،
/// نه به پرونده).
class DialogueState {
  /// آخرین پرسشی که از کاربر کرده‌ام و دکمه‌های جوابش.
  String askText = '';
  List<String> askChips = const [];

  /// پیشنهادی که در پاسخ قبلی به شکل پرسش داده‌ام: `argue`، `next` یا
  /// `draft` (خالی = هیچ)، و شناسهٔ قالبی که برای نوشتن پیشنهاد شده است.
  String offer = '';
  String offerDraft = '';

  /// موضوع‌هایی که با حدسِ نامطمئن از کاربر پرسیده‌ام «کدام؟»، و پیامی که
  /// این پرسش را پیش آورد. فقط برای پیام بعدی معتبر است.
  List<Topic> choices = const [];
  String choiceText = '';

  /// پروندهٔ جاری با حدسِ مدل باز شده و کاربر هنوز تأییدش نکرده است.
  bool guessed = false;

  /// موضوعی که پیام کاربر به آن اشاره کرده، ولی هنوز تأیید نشده است.
  Topic? pendingTopic;
  String pendingText = '';

  /// موضوع دیگری که وسط پرونده به آن اشاره شد ولی مطمئن نیستم ماجرای
  /// جدایی باشد؛ به‌جای پریدنِ خودسرانه از کاربر می‌پرسم.
  Topic? side;
  String sideText = '';

  /// دکمه‌های دستهٔ مشکل در همین نوبتِ بعد معنا دارند.
  bool branchAsked = false;

  /// راهنمای آماده‌ای که باز شده، و اینکه پرسشِ پایانش بی‌جواب مانده است.
  LegalGuide? guide;
  bool guideAsked = false;
  bool guideStepped = false;

  /// بحثی که به نقشِ طرفِ دیگر موکول شده است.
  String deferred = '';

  /// نام ادعایی که آخرین پرسشِ من برای روشن‌شدنِ آن بود.
  String lastServed = '';

  /// واقعیت‌هایی که آخرین استدلال روی آن‌ها بنا شده بود.
  String arguedOn = '';

  /// همهٔ حرف‌های کاربر در پروندهٔ جاری (برای پیشنهادهای متناسب).
  String heard = '';

  /// پاسخ بعدی توضیحی است که خودِ کاربر خواسته (استدلال، نقشهٔ راه) و جای
  /// بیشتری می‌گیرد.
  bool roomy = false;

  /// پیام نامفهومِ قبلی (نقل کوتاه) و نوبتش: اگر پیام بعدی هم نامفهوم بود،
  /// دیگر نمی‌پرسد، می‌گوید جوابی ندارد.
  String unclearPhrase = '';
  int unclearTurn = -10;

  /// پیامی که پاسخ ایمنی جایش را گرفت، و اینکه پیام ایمنی در این پرونده
  /// گفته شده است یا نه (یک بار کافی است تا گفتگو در حلقه نیفتد).
  String safetyCarry = '';
  bool safetyShown = false;

  /// پیام‌های کاربر پیش از بازشدن پرونده (حداکثر سه تای آخر).
  final List<String> loose = [];

  /// پیشنهادِ معلق را کنار می‌گذارد (وقتی لایهٔ بالاتر خودش به آن رسید).
  void clearOffer() {
    offer = '';
    offerDraft = '';
  }

  /// با بسته‌شدن پرونده: هرچه به همان پرونده مربوط بود پاک می‌شود.
  void clearCase() {
    pendingTopic = null;
    pendingText = '';
    lastServed = '';
    safetyShown = false;
    safetyCarry = '';
    guide = null;
    deferred = '';
    arguedOn = '';
    heard = '';
    askText = '';
    askChips = const [];
    guideAsked = false;
    clearOffer();
  }

  /// آغاز گفتگوی تازه.
  void reset() {
    clearCase();
    choices = const [];
    choiceText = '';
    guessed = false;
    side = null;
    sideText = '';
    branchAsked = false;
    unclearPhrase = '';
    unclearTurn = -10;
    roomy = false;
    loose.clear();
  }
}
