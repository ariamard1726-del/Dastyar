import 'package:dastyar/core/persian_text.dart';

/// نیتهای غیرحقوقی که لایهٔ گفتگوی کوتاه تشخیص میدهد.
enum SmallTalkIntent {
  greeting,
  howAreYou,
  thanks,
  distress,
  profanity,
  metaNextStep,
  offTopic,
  farewell,
}

/// پاسخ کاملاً ازپیشنوشتهٔ لایهٔ گفتگوی کوتاه.
///
/// هیچ بخشی از آن از موتور دانش، شبکهٔ نیت، برنامهٔ گفتگو یا مدل زبانی
/// نمیآید؛ بنابراین نه استناد قانونی دارد، نه پرسش RAG و نه حدس حقوقی.
class SmallTalkReply {
  final SmallTalkIntent intent;
  final String text;
  final List<String> chips;

  const SmallTalkReply({
    required this.intent,
    required this.text,
    this.chips = const <String>[],
  });
}

/// مسیریاب ورودیهای غیرحقوقی: احوالپرسی، احوالپرسی دوباره، تشکر،
/// تخلیهٔ هیجانی (دلدرد/خستگی)، ناسزا و موضوعات کاملاً نامرتبط.
///
/// **جداسازی کامل**: تنها وابستگی این فایل [PersianText] است. هیچ `import`
/// یا فراخوانی به `KnowledgeEngine`، `IntentNet`، `DialoguePlanner`،
/// `CounselorTurn` یا مدل زبانی وجود ندارد. این لایه یک تابع خالص است:
/// «متن + زمینهٔ حقوقی فعال» → یک پاسخ ثابت یا `null`. نتیجه:
///  * برای پیامهای غیرحقوقی هیچ توکن LLM مصرف نمیشود؛
///  * چون پاسخها ازپیش نوشته شدهاند، توهم حقوقی (hallucination) ممکن نیست؛
///  * جریان حقوقی فقط زمانی فراخوانی میشود که واقعاً لازم باشد.
///
/// **نگهبان سخت حقوقی**: اگر پیام کوچکترین نشانهٔ حقوقی داشته باشد
/// (مثلاً «سلام، چک من برگشت خورده»)، لایه `null` برمیگرداند تا همان
/// پیام به جریان حقوقی برسد. احوالپرسی خالص («سلام») پاسخ میگیرد.
class SmallTalkLayer {
  const SmallTalkLayer();

  static const List<String> defaultIntakeChips = <String>[
    'چک برگشتی',
    'اختلاف کاری',
    'اجاره و ملک',
    'خانواده و مهریه',
    'کلاهبرداری',
    'نزاع و ضرب و جرح',
    'دعوای حقوقی',
    'بدهی و مطالبه',
  ];

  static const List<String> activeSessionChips = <String>[
    'ادامه بررسی پرونده',
    'سؤال جدید دارم',
  ];

  // ── نگهبان حقوقی ─────────────────────────────────────────────────────
  // هر واژه/عبارت زیر یعنی «این پیام حقوقی است، دست نگه دار». فهرست
  // عمداً محافظهکارانه است: در شک، پیام به جریان حقوقی سپرده میشود.
  static final RegExp _legalSignalRe = PersianText.wordRe(<String>[
    // اسناد، چک و مطالبات
    'چک', 'سفته', 'برات', 'صیادی', 'گواهی عدم پرداخت', 'برگشت خورده',
    'برگشتی', 'ضامن', 'ضمانت', 'طلب', 'طلبکار', 'بدهی', 'بدهکار',
    'اعسار', 'تقسیط', 'اظهارنامه', 'سند رسمی', 'لایحه',
    // ملک و اجاره
    'اجاره', 'موجر', 'مستاجر', 'مستأجر', 'تخلیه', 'پول پیش', 'ودیعه',
    'صاحبخانه', 'ملک',
    // خانواده
    'مهریه', 'نفقه', 'حضانت', 'طلاق', 'تمکین', 'ارث', 'وصیت',
    // کار و بیمه
    'کارفرما', 'کارگر', 'اخراج', 'حقوق', 'بیمه', 'سنوات', 'عیدی',
    'قرارداد کار', 'قرارداد', 'بازگشت به کار',
    // جرایم
    'کلاهبرداری', 'فیشینگ', 'هک', 'خیانت در امانت', 'فروش مال غیر',
    'امانت', 'توهین', 'افترا', 'فحاشی', 'ضرب و جرح', 'تهدید', 'مزاحمت',
    'دیه', 'قصاص', 'تعزیر', 'مجازات', 'جرم', 'پزشکی قانونی',
    // آیین دادرسی و نهادها
    'شکایت', 'شکوائیه', 'دادخواست', 'دادگاه', 'دادسرا', 'کلانتری',
    'ابلاغیه', 'احضاریه', 'حکم غیابی', 'رای غیابی', 'واخواهی',
    'تجدیدنظر', 'اعتراض به رای', 'اعتراض به رأی', 'وکیل', 'پرونده',
    'مدرک', 'صلاحیت', 'مهلت',
    // نشانههای کلی پرسش حقوقی
    'قانون', 'ماده', 'مشاوره', 'مشکل حقوقی', 'سوال حقوقی', 'سؤال حقوقی',
    'مسئله حقوقی', 'کمک حقوقی', 'حقوقی',
  ]);

  /// ارجاع صریح به ماده/اصل قانون («ماده ۱۳»، «اصل ۲۲»).
  static final RegExp _articleRefRe =
      RegExp(r'(?:ماده|اصل)\s*(?:واحده|\d+)');

  /// آیا پیام نشانهٔ حقوقی دارد؟ (قابل آزمون جداگانه و عمومی)
  static bool hasLegalSignal(String rawText) =>
      _hasLegalSignalIn(PersianText.phrase(rawText));

  static bool _hasLegalSignalIn(String phrase) =>
      phrase.isNotEmpty &&
      (_legalSignalRe.hasMatch(phrase) || _articleRefRe.hasMatch(phrase));

  // ── الگوهای نیتهای غیرحقوقی ─────────────────────────────────────────
  static final RegExp _greetingRe = PersianText.wordRe(<String>[
    'سلام', 'درود', 'وقت بخیر', 'صبح بخیر', 'عصر بخیر', 'شب بخیر',
    'سلام علیکم', 'سلام عرض کردم', 'عرض سلام', 'hello',
  ]);

  static final RegExp _howAreYouRe = PersianText.wordRe(<String>[
    'چطوری', 'چطورید', 'چطورین', 'خوبی', 'خوبید', 'خوب هستی',
    'خوب هستید', 'حالت چطوره', 'حالتون چطوره', 'حال شما چطوره',
    'چه خبر', 'چیکار میکنی', 'چکار میکنی', 'چه کار میکنی', 'اخبارت چیه',
  ]);

  static final RegExp _thanksRe = PersianText.wordRe(<String>[
    'ممنون', 'مرسی', 'متشکرم', 'مچکرم', 'تشکر', 'سپاس',
    'دستت درد نکنه', 'دست شما درد نکنه', 'خدا خیرت بده',
    'لطف کردی', 'لطف کردید', 'محبت کردی',
  ]);

  static final RegExp _distressRe = PersianText.wordRe(<String>[
    'حالم خوب نیست', 'حالم بده', 'حالم بد است', 'خسته ام', 'خستهام',
    'خسته شدم', 'اعصابم خرده', 'اعصابم خورد شد', 'ناراحتم',
    'کلافه ام', 'کلافهام', 'داغونم', 'استرس دارم', 'نگرانم',
    'طاقتم تموم شده', 'دیگه تحمل ندارم', 'نمیدونم چی بگم',
    'بغضم گرفته', 'عصبانی ام', 'عصبانیم', 'دلم گرفته',
    'حوصله ندارم', 'خیلی ناراحتم',
  ]);

  static final RegExp _profanityRe = PersianText.wordRe(<String>[
    'لعنت', 'لعنتی', 'کثافت', 'کثیف', 'احمق', 'خنگ', 'ابله',
    'گوساله', 'خر', 'بی شرف', 'بیشرف', 'حرامزاده', 'پدرسوخته',
    'عوضی', 'نفهم', 'بی ادب', 'مرض داری', 'خفه شو', 'گم شو',
    'گمشو', 'دیوانه', 'گه',
  ]);

  static final RegExp _metaNextStepRe = PersianText.wordRe(<String>[
    'الان چکار کنم', 'الان چیکار کنم', 'باید چه کار کنم',
    'باید چیکار کنم', 'باید چکار کنم', 'قدم بعدی چیه', 'حالا چی',
    'از کجا شروع کنم', 'چی کار کنم دیگه', 'خب الان چی',
    'مرحله بعد چیه',
  ]);

  static final RegExp _offTopicRe = PersianText.wordRe(<String>[
    'هوا چطوره', 'هوا چطور است', 'آب و هوا', 'هوا گرمه', 'هوا سرده',
    'بارون میاد', 'باران می بارد', 'برف میاد', 'دمای هوا',
    'پیش بینی هوا', 'ساعت چنده', 'ساعت چند است', 'تاریخ امروز',
    'امروز چندمه', 'جوک بگو', 'جک بگو', 'شعر بگو', 'چه فیلمی',
    'چه کتابی', 'فیلم خوب', 'کتاب خوب', 'آهنگ', 'موسیقی', 'سریال',
    'فوتبال', 'نتیجه بازی', 'بازی امروز', 'ورزش', 'مسابقه',
    'دستور پخت', 'چی بپزم', 'غذای خوب', 'قیمت دلار', 'قیمت طلا',
    'بورس', 'بیت کوین', 'پایتخت', 'جغرافیا',
    'what is the weather', 'how is the weather', 'weather',
    'tell me a joke',
  ]);

  static final RegExp _farewellRe = PersianText.wordRe(<String>[
    'خداحافظ', 'خدانگهدار', 'بدرود', 'فعلا', 'فعلاً', 'شب خوش',
    'به امید دیدار',
  ]);

  /// پاسخهای کوتاه تأییدی در میانهٔ جلسهٔ حقوقی نباید بلعیده شوند؛
  /// آنجا «بله ممنون» یعنی پاسخ به اسلات قبلی، نه گفتگوی کوتاه.
  static const List<String> _confirmationWords = <String>[
    'بله', 'بلی', 'آره', 'اره', 'خیر', 'نه', 'باشه', 'اوکی', 'حتما',
  ];

  static bool _startsWithConfirmation(String phrase) =>
      _confirmationWords.any((w) => phrase == w || phrase.startsWith('$w '));

  /// مسیریابی پیام. `null` یعنی «این پیام به جریان حقوقی واگذار شود».
  SmallTalkReply? tryHandle(
    String rawText, {
    bool hasActiveLegalContext = false,
  }) {
    final phrase = PersianText.phrase(rawText);
    if (phrase.isEmpty) return null;

    // ۱) هیچ پیام حقوقی (حتی با سلام شروع شده) وارد این لایه نمیشود.
    if (_hasLegalSignalIn(phrase)) return null;

    // ۲) در جریان حقوقی فعال، پاسخهای تأییدی به اسلاتها حفظ میشوند.
    if (hasActiveLegalContext && _startsWithConfirmation(phrase)) return null;

    final intent = _classify(phrase);
    if (intent == null) return null;

    return SmallTalkReply(
      intent: intent,
      text: _replyFor(intent, hasActiveLegalContext),
      chips: hasActiveLegalContext ? activeSessionChips : defaultIntakeChips,
    );
  }

  static SmallTalkIntent? _classify(String phrase) {
    // ترتیب اهمیت: ناسزا و ناراحتی زودتر از احوالپرسی پاسخ میگیرند تا
    // «لعنتی سلام» یا «سلام حالم بده» به پیام خشک سلام تقلیل نیابد.
    if (_profanityRe.hasMatch(phrase)) return SmallTalkIntent.profanity;
    if (_distressRe.hasMatch(phrase)) return SmallTalkIntent.distress;
    if (_farewellRe.hasMatch(phrase)) return SmallTalkIntent.farewell;
    if (_greetingRe.hasMatch(phrase)) return SmallTalkIntent.greeting;
    if (_howAreYouRe.hasMatch(phrase)) return SmallTalkIntent.howAreYou;
    if (_thanksRe.hasMatch(phrase)) return SmallTalkIntent.thanks;
    if (_metaNextStepRe.hasMatch(phrase)) return SmallTalkIntent.metaNextStep;
    if (_offTopicRe.hasMatch(phrase)) return SmallTalkIntent.offTopic;
    return null;
  }

  /// پاسخهای ثابت و کوتاه، بدون هیچ تحلیل، استناد یا حدس حقوقی.
  static String _replyFor(SmallTalkIntent intent, bool active) {
    switch (intent) {
      case SmallTalkIntent.greeting:
        return active
            ? 'سلام، خوش برگشتید. گفتگوی قبلیتان همچنان باز است؛ هر وقت آماده بودید از همانجا ادامه میدهیم.'
            : 'سلام و وقت بخیر. من دستیار حقوقی شما هستم؛ بفرمایید چه موضوعی پیش آمده تا با هم قدمبهقدم بررسیاش کنیم.';
      case SmallTalkIntent.howAreYou:
        return active
            ? 'خوبم، ممنون. شما چطورید؟ هر وقت آماده بودید، همان پرسش قبل را پاسخ دهید تا ادامه دهیم.'
            : 'خوبم، ممنون که پرسیدید. شما چطورید؟ هرگاه خواستید، ماجرایی که ذهنتان را مشغول کرده همینجا بنویسید.';
      case SmallTalkIntent.thanks:
        return active
            ? 'خواهش میکنم. اگر نکتهای در همان گفتگو مانده، بفرمایید تا ادامه دهیم.'
            : 'خواهش میکنم، وظیفهای نبود. هر وقت خواستید، همینجا در خدمتم.';
      case SmallTalkIntent.distress:
        return active
            ? 'حق دارید خسته و نگران باشید؛ عجلههای نیست. هر وقت خواستید، پاسخ همان پرسش قبل را بدهید تا با هم ادامه دهیم.'
            : 'متأسفم که اینقدر فشار رویتان است؛ کاملاً درکتان میکنم و عجلههای نیست. هر وقت آماده بودید، آرام و قدمبهقدم کنارتان هستم.';
      case SmallTalkIntent.profanity:
        return active
            ? 'باشه، متوجه ناراحتیتان هستم. بیایید آرام همان گفتگو را ادامه دهیم؛ هر وقت آماده بودید پاسخ پرسش قبل را بدهید.'
            : 'متوجهام که ناراحت یا عصبانی هستید. لحن تند را کنار میگذارم؛ اینجا بدون قضاوت کنارتان هستم. هر وقت خواستید، اصل ماجرا را بنویسید.';
      case SmallTalkIntent.metaNextStep:
        return active
            ? 'درک میکنم که میخواهید زودتر به نتیجه برسید. کافی است پاسخ همان پرسش قبل را بدهید تا بلافاصله قدم بعدی را مشخص کنم.'
            : 'حتماً کمکتان میکنم. برای شروع کافی است در یک جمله بنویسید چه اتفاقی افتاده، یا یکی از گزینهها را انتخاب کنید.';
      case SmallTalkIntent.offTopic:
        return active
            ? 'این موضوع از تخصص من خارج است و دربارهاش چیزی حدس نمیزنم. خوشحالم که راحت صحبت میکنید؛ اجازه بدهید همان گفتگوی حقوقی را به نتیجه برسانیم.'
            : 'این موضوع خارج از حوزهٔ کاری من است و دربارهاش حدس نمیزنم؛ من فقط برای مسائل حقوقی اینجا هستم. اگر ماجرای حقوقی دارید، یکی از گزینهها را بزنید یا آن را بنویسید.';
      case SmallTalkIntent.farewell:
        return active
            ? 'به امید دیدار. هر وقت برگشتید، گفتگویتان از همانجا ادامه پیدا میکند.'
            : 'خداحافظ. هر وقت خواستید، همینجا در خدمتم.';
    }
  }
}
