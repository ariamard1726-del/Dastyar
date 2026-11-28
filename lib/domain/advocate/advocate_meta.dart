part of 'advocate.dart';

// پیام‌هایی که دربارهٔ *خودِ برنامه* هستند یا ماجرای حقوقی نیستند.
//
// در آزمون گفتگوی واقعی، کاربر وسط پروندهٔ ودیعه نوشت «از برنامه خارج شدم و
// دوباره برگشتم» و پاسخ «منظورتان از … چیست؟» گرفت؛ بعد از «سگم مرده» همان
// پرسش تکرار شد. هیچ‌کدام ماجرای حقوقی نبود، ولی هر دو یک پرسش واقعی داشتند:
// «حرف‌های قبلی چه شد؟» و «برای این غم چه می‌گویی؟». این دو، پاسخ صریح دارند.

/// واژه‌های خودِ برنامه (واژهٔ کامل، تا «برنامه‌ریزی» و «اپل» گرفته نشود).
const String _appWords = 'برنامه|اپ|اپلیکیشن|نرم افزار|نرم‌افزار';

/// کاری که کاربر با برنامه کرده است.
const String _appActs =
    'خارج شدم|بیرون آمدم|بیرون زدم|بستم|بسته شد|باز کردم|بازش کردم|دوباره (?:وارد|باز|آمد|اومدم)|برگشتم|از اول|کرش|قطع شد|ریست شد|پاک شد';

/// نشانهٔ اینکه پیام دربارهٔ تاریخچهٔ گفتگوست، نه ماجرای حقوقی.
const String _historyWords =
    'پیام(?:های| ها)? قبلی|پیام‌های قبلی|تاریخچه|گفتگو(?:ی|یِ)? (?:قبلی|قبلی‌ام)|حافظهٔ برنامه|چت قبلی';

/// نشانهٔ حقوقی؛ اگر در پیام باشد، آن پیام ماجرای حقوقی است و نباید اینجا
/// گرفته شود.
const String _legalCues =
    'اجاره|ودیعه|پول پیش|مستأجر|مالک|صاحبخانه|صاحب خونه|چک|سفته|قرض|طلب|بدهی|'
    'طلاق|مهریه|نفقه|حضانت|ارث|وصیت|دیه|بیمه|سند|قرارداد|دادگاه|دادسرا|شکایت|'
    'کارفرما|حقوق|سنوات|اخراج|همسایه|خرید|فروش|ضمانت|کیفرخواست|احضاریه|پرونده|وکیل';

/// واژه‌های سوگ و از دست دادن — فقط برای پیام‌های کوتاهِ بی‌نشانهٔ حقوقی.
///
/// «مرد» تنها گرفته نمی‌شود: در فارسی «مرد» یعنی جنس مذکر («یک مرد به من
/// حمله کرد») و گرفتنش پاسخ تسلیت به یک ماجرای کیفری می‌دهد. پس فقط صورت
/// مالکیت‌دار («سگم مرده»، «پدرش مرد») و واژه‌های بی‌ابهام می‌آید.
///
/// ضمیرِ چسبیده با `Sense.word` گرفته نمی‌شود (مرزِ واژه پیش از «م» در
/// «سگم» شکسته است)، پس الگو خودِ «م + فاصله + فعل» را می‌آورد. این آزمون در
/// `tests/python/test_advocate_patterns.py` روی همین رشته از سورس اجرا می‌شود؛
/// نسخهٔ اولِ الگو یک فاصلهٔ اضافه داشت و «سگم مرده» را نمی‌گرفت.
const String _lossWords =
    'م (?:مرده|مرد|مُرد)(?![ا-ی])|ت (?:مرده|مرد|مُرد)(?![ا-ی])'
    '|ش (?:مرده|مرد|مُرد)(?![ا-ی])'
    '|(?:مان|تان|شان) (?:مرده|مرد|مُرد)(?![ا-ی])'
    '|فوت (?:کرد|شد|کرده)|تلف شد|از دست (?:دادم|دادیم|رفت)|خاکش کردیم|خاک کردند';

/// پاسخ‌های «دربارهٔ خودِ برنامه» و «ماجرای حقوقی نیست» — بی‌نیاز از وکیل.
///
/// این پاسخ‌ها پیش‌تر متدهای `Advocate` بودند: برای گفتنِ «فهمیدم برنامه را بستید
/// و باز کردید» لازم نبود وکیلِ کامل در دست باشد، فقط پرونده، وضعیتِ روی میز و
/// صدا. حالا کلاسِ خودش را دارند و `current` و `anyTopicCue` را از بیرون
/// می‌گیرند.
class MetaReply {
  MetaReply({
    required this.file,
    required this.dialog,
    required this.voice,
    required this.current,
    required this.anyTopicCue,
  });

  final CaseFile file;
  final DialogueState dialog;
  final ReplyVoice voice;

  /// موضوعِ بازِ فعلی (برای نام‌بردن در پاسخ).
  final Topic? Function() current;

  /// آیا پیام به موضوعی نشانهٔ روشن دارد؟
  final bool Function(String n) anyTopicCue;

  /// آیا پرونده یا راهنمایی روی میز است؟ همان تعریفِ وکیل، اینجا از دو
  /// همکارش ساخته می‌شود.
  bool get hasCase => file.topic.isNotEmpty || dialog.guide != null;

  AdvocateReply _out(
    String text, {
    List<String> chips = const [],
    String ask = '',
    bool full = false,
    int budget = _budget,
    AnswerSource source = AnswerSource.topic,
  }) =>
      voice.out(text,
          chips: chips, ask: ask, full: full, budget: budget, source: source);

  /// پاسخ به پیام‌های «دربارهٔ برنامه» و پیام‌های شخصیِ غیرحقوقی؛ `null` یعنی
  /// این پیام از این دسته نیست و مسیر عادی ادامه پیدا می‌کند.
  AdvocateReply? metaReply(String raw, String n) {
    final legal = Sense.has(n, _legalCues);

    // جملهٔ کوتاهِ سوگ پیش از هر حدسِ موضوعی بررسی می‌شود: «سگم مرده» به یک
    // نشانهٔ ضعیف در موضوع‌های دیگر می‌خورد و همان نشانه کافی بود که این پیام
    // به «منظورتان چیست؟» برسد. تنها نگهبانِ لازم، نشانهٔ حقوقی است.
    if (!legal && Sense.words(n) <= 8 && Sense.has(n, _lossWords)) {
      return lossReply();
    }

    // نشانهٔ حقوقی، یا موضوعِ شناخته‌شده، یعنی ماجرای واقعی: کاری به آن نداریم.
    if (legal) return null;
    if (Advocate.topicOf(raw) != null) return null;
    if (anyTopicCue(n)) return null;

    final aboutApp =
        (Sense.word(n, _appWords) && Sense.has(n, _appActs)) ||
            Sense.has(n, _historyWords);
    if (aboutApp) return appMetaReply();

    return null;
  }

  /// «برنامه را بستم و برگشتم» یک پرسش واقعی دارد: حرف‌های پیشین چه شد؟
  /// پاسخش کوتاه و راست است، چون وضعیت ذخیره‌سازی واقعاً همین است:
  /// تاریخچه در همین دستگاه و رمزنگاری‌شده می‌ماند (`HistoryStore`).
  AdvocateReply appMetaReply() {
    final caseOpen = hasCase;
    if (caseOpen) {
      final title = current()?.title ?? advocateText('metaFallbackTitle');
      return _out(
        advocateFormat('metaAppCaseBody', {'title': title}),
        ask: dialog.askText.isEmpty
            ? advocateText('metaAppCaseAsk')
            : dialog.askText,
        chips: dialog.askChips,
      );
    }
    return _out(
      advocateText('metaAppIdleBody'),
      ask: advocateText('metaAppIdleAsk'),
      chips: ChipTexts.branchChips,
    );
  }

  /// موضوعی که پیام به آن نزدیک است ولی شرطِ بازشدنش را ندارد
  /// ([Topic.gate]). به‌جای حکم و ماده، یک سؤال کوتاه می‌پرسیم.
  Topic? gatedTopic(String n) {
    Topic? best;
    var bestScore = 0;
    for (final t in Advocate.topics) {
      if (t.gate == null) continue;
      if (t.gate!(n)) continue;
      final s = TopicScore.ignoringGate(t, n);
      if (s > bestScore) {
        best = t;
        bestScore = s;
      }
    }
    return bestScore >= 4 ? best : null;
  }

  /// پاسخ به پیامی که فقط واژهٔ موضوع را دارد، نه ماجرا را.
  AdvocateReply gatedReply(Topic t) => _out(
        advocateFormat('metaGatedBody', {'title': t.title}),
        ask: advocateText('metaGatedAsk'),
        chips: advocateTextSeq('metaGatedChip', 3),
      );

  /// جملهٔ کوتاهِ سوگ: نه تحلیل حقوقی می‌سازیم، نه نقش همراه عاطفی بازی
  /// می‌کنیم؛ فقط صادقانه می‌گوییم چه کاری از ما برمی‌آید.
  AdvocateReply lossReply() {
    if (hasCase) {
      return _out(
        advocateText('metaLossCaseBody'),
        ask: dialog.askText.isEmpty
            ? advocateText('metaLossCaseAsk')
            : dialog.askText,
        chips: dialog.askChips,
      );
    }
    return _out(
      advocateText('metaLossIdleBody'),
      ask: advocateText('metaLossIdleAsk'),
      chips: ChipTexts.branchChips,
    );
  }
}

extension _MetaReplyHelpers on Advocate {
  AdvocateReply? _termOrLinkReply(
      String raw, String n, TopicRead read, TopicGuess? guess) {
    if (hasCase || read.bestScore >= _topicOpenMin) return null;
    final confidentGuess = guess != null && guess.confident;
    final lt =
        Sense.has(n, 'قهر') || confidentGuess ? null : _termReply.lawTerms(raw, n);
    if (lt != null) return lt;
    final refs = Understanding.linkedArticles(n);
    if (refs.isEmpty) return null;
    return _out(
      advocateFormat('replyLinkedArticles', {'refs': refs.join(' ')}),
      ask: advocateText('replyLinkedAsk'),
      full: true,
    );
  }

  AdvocateReply? _sulkingReply(String n) {
    if (!Sense.has(n, 'قهر') ||
        !Sense.has(n, 'زندان|حبس|بازداشت|جریمه|پلیس|دادگاه')) {
      return null;
    }
    return _out(
      advocateText('replySulkingWarning'),
      ask: advocateText('replySulkingAsk'),
    );
  }

  AdvocateReply? _appChatReply(String n) {
    if (!Sense.has(n, 'گفتگوی من با برنامه|گفتگو با برنامه|با برنامه (?:هست|است)')) {
      return null;
    }
    return _out(
      advocateText('replyAppChatBody'),
      ask: advocateText('replyAppChatAsk'),
    );
  }
}
