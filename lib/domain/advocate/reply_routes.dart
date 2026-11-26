part of 'advocate.dart';

// مسیرهای یک‌نوبتیِ پاسخ: هر کدام یا جواب می‌دهد یا `null`.
//
// پیش‌تر این سیزده متد، متدهای خصوصیِ `Advocate` بودند؛ یعنی برای سنجیدنِ
// «کاربر گفت "نمی‌دانم" سرِ پیشنهادِ سند» باید یک وکیلِ کامل ساخته می‌شد.
// حالا `ReplyRoutes` همکارهایش را در سازنده می‌گیرد و هر مسیر یک متدِ نام‌دار
// است. **ترتیبِ** صدا زدن‌شان همچنان در `Advocate._reply` نوشته شده، چون آن
// ترتیب خودِ تصمیمِ معماری است و باید در یک نگاه دیده شود.

/// پرسش فرضی است، نه ماجرای کاربر: طرفها با حروف الف/ب/ج/د نامیده شدهاند
/// و خودِ پیام دارای «پرسشها» است. چنین پیامی نباید پروندهٔ شخصی باز کند یا
/// بپرسد «شما خریدار هستید یا فروشنده؟»؛ متن قانون را نشان میدهد.
bool _isHypotheticalQuestion(String raw, String n) {
  if (!Sense.has(n, 'پرسش') || Sense.words(n) < 12) return false;
  final parties = RegExp(
          r'(?:^|[^\u0600-\u06FF])(?<p>الف|ب|ج|د)(?:$|[^\u0600-\u06FF])')
      .allMatches(raw)
      .map((m) => m.namedGroup('p') ?? '')
      .toSet();
  return parties.length >= 2;
}

/// مسیرهای یک‌نوبتیِ پاسخ، بی‌نیاز از خودِ وکیل.
class ReplyRoutes {
  ReplyRoutes({
    required this.file,
    required this.dialog,
    required this.voice,
    required this.flow,
    required this.picker,
    required this.talk,
    required this.talkRoute,
    required this.reply,
  });

  final CaseFile file;
  final DialogueState dialog;
  final ReplyVoice voice;

  /// روندِ پرونده: بازکردن، بستن، پاسخِ داخلِ پرونده، جمع‌بندی.
  final CaseFlow flow;

  /// موضوعِ باز و تطبیقِ بحث.
  final TopicPicker picker;

  /// پاسخِ «آیا این پیام نشانهٔ روشنِ موضوعی دارد؟».
  final TalkReply talk;

  /// دکمه‌های دستهٔ مشکل.
  final TalkRoute talkRoute;

  /// بازگشت به `_reply` برای پیامی که خودِ وکیل ساخته («قدم بعدی چیست؟»).
  final AdvocateReply Function(String raw, {bool again}) reply;

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

  String _pick(List<String> options) => voice.pick(options);

  // مسیرهای یک‌نوبتیِ پاسخ: هر کدام یا جواب می‌دهد یا `null`.
  //
  // پیش‌تر این‌ها پشتِ سرِ هم داخل `_reply` بودند و یک تابعِ چندصدخطی
  // می‌ساختند؛ حالا هر مسیر نام دارد و تنها خوانده می‌شود. ترتیبِ فراخوانی
  // همان ترتیبِ پیشین است و عوض نشده.

  /// «موضوع تازه‌ای دارم»: پروندهٔ جاری بسته می‌شود، بی‌آنکه چیزی از آن
  /// در پاسخ‌های بعدی بمانَد.
  AdvocateReply? newCase(String raw) {
    final x = raw.trim();
    final y = Sense.norm(raw);
    // «تازه هست» / «موضوع جدیدی هست» همان معنای دکمهٔ «موضوع تازه‌ای دارم»
    // را دارد. وقتی پرسشِ «تازه یا مربوط؟» روی میز است، این مسیر عقب میماند
    // تا مسیرِ pending آن را بگیرید و پروندهٔ معلق را باز کند.
    // دکمهٔ «بله، موضوع تازه است» از مسیرِ pending عبور میکند و پروندهٔ
    // معلق را باز میکند؛ پس در جدیدِ موضوعِ تازه فقط جملههای آزاد کاربر را
    // میگیریم، نه خودِ دکمهٔ همان پرسش را.
    final asksNew = x == ChipTexts.newCaseChip ||
        (x != ChipTexts.newTopicChip &&
            Sense.words(y) <= 6 &&
            Sense.has(y,
                'تازه (?:هست|است)|جدید (?:هست|است)|موضوع (?:تازه|جدید)(?:ی)?(?: (?:هست|است))?|ماجرای (?:تازه|جدید)(?:ی)?(?: (?:هست|است))?'));
    if (dialog.pendingTopic == null && asksNew) {
      // وقتی پروندهٔ بازی هست، «تازه هست» یعنی «موضوع دیگری هم دارم»؛
      // نباید محتوا و چسبندگی پروندهٔ جاری را پاک کند. فقط دکمهٔ صریحِ
      // «موضوع تازه» پرونده را میبندد.
      if (x != ChipTexts.newCaseChip && file.topic.isNotEmpty) {
        dialog.pendingTopic = null;
        return _out(
          'باشد، ماجرای تازهای هم هست.',
          ask: 'اول ماجرای جاری را تمام میکنیم یا میخواهید آنرا کنار بگذارید؟',
          chips: [ChipTexts.newTopicChip, ChipTexts.leaveChip],
        );
      }
      flow.closeCase();
      dialog.loose.clear();
      return _out(
        'باشد، آن موضوع را کنار می‌گذارم.',
        ask: 'ماجرای تازه چیست؟ از هر جا که راحت‌ترید شروع کنید.',
      );
    }
    return null;
  }

  /// اعتراضِ «گزینه‌ای برای بیرون آمدن نیست»: راه خروج نشان داده می‌شود.
  AdvocateReply? noOption(String raw) {
    // «گزینه‌ای وجود ندارد»: اعتراض به نبودن راه خروج. راه خروج را نشان می‌دهیم.
    if (DraftWords.isComplaintNoOption(raw)) {
      return _out(
        'درست می‌گویید؛ راه خروج را روشن نگفته بودم. برای بیرون آمدن از این موضوع، «انصراف» یا «موضوع تازه‌ای دارم» را بزنید یا همان را بنویسید.',
        ask: 'می‌خواهید این موضوع را کنار بگذاریم یا ادامه دهیم؟',
        chips: const [ChipTexts.newCaseChip],
      );
    }
    return null;
  }

  /// پاسخ به «این موضوع تازه است یا مربوط به قبلی؟».
  ///
  /// این پرسش پیش از هر قاعدهٔ دیگری بررسی می‌شود؛ وگرنه «بله»/«خیر» ادامهٔ
  /// پروندهٔ قبلی خوانده می‌شود و پرونده عوض نمی‌شود.
  AdvocateReply? pending(String raw, String n) {
    final pend = dialog.pendingTopic;
    final pendText = dialog.pendingText;
    if (pend != null) {
      void handled() {
        dialog.pendingTopic = null;
        dialog.pendingText = '';
      }
      if (raw.trim() == ChipTexts.newTopicYesChip ||
          raw.trim() == ChipTexts.sideChip ||
          (Sense.words(n) <= 6 &&
              Sense.has(n,
                  'موضوع (?:تازه|جدید|دیگه|دیگر)|جدا(?:ست| است|گانه)|ماجرای دیگه|ماجرای تازه'))) {
        handled();
        return flow.open(pend, Sense.norm(pendText), switched: true);
      }
      final curTopic = picker.current();
      if (curTopic != null &&
          (raw.trim() == ChipTexts.newTopicNoChip ||
              raw.trim() == ChipTexts.relatedChip ||
              (Sense.words(n) <= 6 &&
                  Sense.has(n,
                      'مربوط|همین (?:موضوع|ماجرا|پرونده)|همان (?:موضوع|ماجرا)|ماجرای قبلی|موضوع قبلی|به قبلی')))) {
        handled();
        final pn = Sense.norm(pendText);
        final r = flow.inCase(curTopic, pendText, pn, picker.matchIssue(curTopic, pn));
        // «خیر» یعنی همان پرونده؛ این را صریح می‌گوییم تا کاربر نداند که
        // برنامه سرگردان شده است.
        return AdvocateReply(
          'باشد، همین پرونده را ادامه می‌دهیم.\n\n${r.text}',
          chips: r.chips,
          laws: r.laws,
          source: r.source,
          ask: r.ask,
        );
      }
    }
    return null;
  }

  /// دعوای لفظی: تا وقتی تهدید یا برخورد فیزیکی نبوده، خودِ «جر و بحث»
  /// جرم نیست؛ ولی باید بدانیم کدامش پیش آمده.
  AdvocateReply? fight(String n, bool hasCase) {
    // دعوای لفظی: تا وقتی تهدید یا برخورد فیزیکی نبوده، خودِ «جر و بحث»
    // جرم نیست؛ ولی باید بدانیم کدامش پیش آمده. پیش‌تر این جمله به حدسِ
    // «دفاع در برابر شکایت» یا پاسخ «در پایگاه نیست» می‌رسید.
    if (!hasCase &&
        !Sense.has(n,
            'کتک|مشت|لگد|چاقو|زخم|ضرب|جرح|هل داد|هلم داد|بیمارستان|پزشکی قانونی') &&
        // «دعوا سر کرایه خانه» یا «با مستاجر درگیر شدم» ماجرای موضوع‌دار است و
        // باید به موضوع خودش برسد، نه به پاسخ عمومیِ دعوای لفظی.
        !talk.anyTopicCue(n) &&
        Sense.has(n,
            'جر ?و ?بحث|بگو ?مگو|دعوای لفظی|دعوا(?:م|مون)? (?:شد|کردم)|بحث(?:م|مون)? (?:شد|کردیم|کردم)')) {
      return _out(
        'دعوای لفظی به‌تنهایی جرم نیست؛ دادگاه برای «حرف زدن» پرونده باز نمی‌کند. '
        'اگر در همان دعوا تهدید، توهین یا برخورد فیزیکی هم بوده، هر کدام مسیر '
        'جداگانه‌ای دارد و باید بگویید کدام پیش آمده.',
        ask: 'در آن دعوا چه چیزی اتفاق افتاد؛ فقط حرف بود، تهدید شد، یا برخورد فیزیکی هم شد؟',
        chips: const ['فقط حرف بود', 'تهدید شد', 'برخورد فیزیکی شد'],
      );
    }
    return null;
  }

  /// جواب به «ماجرای شما به کدام نزدیک‌تر است؟».
  AdvocateReply? choice(
      String raw, String n, List<Topic> choices, String choiceText) {
    // جواب به «ماجرای شما به کدام نزدیک‌تر است؟».
    if (choices.isNotEmpty) {
      for (final t in choices) {
        if (n == Sense.norm(t.title)) {
          return flow.open(t, Sense.norm(choiceText));
        }
      }
      if (choices.length == 1 && Sense.words(n) <= 3 && Sense.saysYes(n)) {
        return flow.open(choices.first, Sense.norm(choiceText));
      }
      if (raw.trim() == ChipTexts.noneChip ||
          (Sense.words(n) <= 3 && Sense.saysNo(n))) {
        dialog.branchAsked = true;
        return _out(
          'باشد.',
          ask:
              'پس خودتان بگویید: چه اتفاقی افتاده و طرف مقابل کیست؟ هرچه بیشتر تعریف کنید بهتر می‌فهمم.',
          chips: ChipTexts.branchChips,
        );
      }
    }
    return null;
  }

  /// پرونده با حدس باز شده بود و کاربر می‌گوید حدس غلط است.
  AdvocateReply? wrongGuess(String raw, String n, bool guessed) {
    // پرونده با حدس باز شده بود و کاربر می‌گوید حدس غلط است.
    if (guessed &&
        (raw.trim() == ChipTexts.wrongChip ||
            (Sense.words(n) <= 7 &&
                Sense.has(n,
                    'موضوع(?:م)? (?:این|اون|آن|ان) نیست|اشتباه (?:گرفتی|فهمیدی|متوجه شدی)|منظورم این نبود|ربطی نداره|ربطی ندارد')))) {
      flow.closeCase();
      dialog.loose.clear();
      return _out(
        'ببخشید، اشتباه برداشت کردم.',
        ask:
            'موضوع شما چیست؟ با یکی دو جمله بگویید چه شده و طرف مقابل کیست.',
        chips: talkRoute.branchStart(),
      );
    }
    return null;
  }

  /// «ادامه بده» یا «بیشتر بگو»: متنی که در پاسخ قبلی جا نشد.
  AdvocateReply? more(String raw, String n, bool short) {
    final rest = voice.rest;
    if (rest.isNotEmpty &&
        (raw.trim() == ChipTexts.moreChip ||
            (short &&
                Sense.has(n,
                    'ادامه|بقیه|بیشتر (?:بگو|توضیح|باز)|کامل(?:ش|ترش)? (?:بگو|کن)')) ||
            (voice.offeredMore && short && Sense.saysYes(n)))) {
      var ask = dialog.askText;
      var chips = dialog.askChips;
      final t0 = picker.current();
      if (ask.isEmpty && t0 != null && cutText(rest, _budget)[1].isEmpty) {
        final a = flow.nextAsk(t0);
        dialog.askText = ask = a.text;
        dialog.askChips = chips = a.chips;
      }
      return _out(rest, ask: ask, chips: chips);
    }
    if (voice.offeredMore && rest.isNotEmpty && short && Sense.saysNo(n)) {
      final t0 = picker.current();
      if (t0 != null) return flow.finish(t0, [_pick(Say.fine)]);
      return _out(_pick(Say.fine), ask: 'چیز دیگری هست که بخواهید بدانید؟');
    }
    return null;
  }

  /// پاسخ به پیشنهادی که خودم به شکل پرسش داده بودم («بگویم؟»).
  AdvocateReply? offer(String raw, String n, bool short) {
    // جواب به پیشنهادی که به شکل پرسش داده بودم.
    if (dialog.offer.isNotEmpty && short) {
      final t0 = picker.current();
      final offer = dialog.offer;
      // «نمی‌دانم» در جوابِ «بگویم؟» یعنی تصمیم با خودت: می‌گویم. ولی
      // برای نوشتنِ سند، بی‌خواستِ روشنِ کاربر دست به کار نمی‌شوم.
      final unsure = Sense.saysDontKnow(n);
      if (t0 != null &&
          (Sense.saysYes(n) ||
              (unsure && offer != 'draft') ||
              raw.trim() == ChipTexts.moreChip ||
              Sense.has(n, '^ (?:بگو|بگید|بگویید|حتما|لطفا|ادامه) '))) {
        flow.clearOffer();
        if (offer == 'draft') {
          return _out(
              'برای نوشتنش کافی است بگویید «بنویس»؛ چند سؤال کوتاه می‌پرسم و متن را آماده می‌کنم.');
        }
        return reply(offer == 'argue' ? 'استدلالت چیه؟' : 'قدم بعدی چیست؟',
            again: true);
      }
      if (t0 != null && (Sense.saysNo(n) || unsure)) {
        flow.clearOffer();
        return flow.finish(t0, [_pick(Say.fine)]);
      }
    }
    return null;
  }

  /// «باشه»/«نه» وقتی پرسشی روی میز نیست: پرسش بعدی می‌آید، نه
  /// «متوجه نشدم».
  AdvocateReply? bareAck(String raw, String n) {
    // «باشه»، «نه» یا «ادامه بده» وقتی پرسشی روی میز نیست: گفتگو را با
    // پرسش بعدی جلو می‌برم، نه با «متوجه نشدم».
    final t1 = picker.current();
    if (t1 != null &&
        voice.rest.isEmpty &&
        dialog.offer.isEmpty &&
        file.pending.isEmpty &&
        dialog.side == null &&
        Sense.words(n) <= 3 &&
        (raw.trim() == ChipTexts.moreChip ||
            Sense.has(n, '^ ادامه ') ||
            Sense.saysYes(n) ||
            Sense.saysNo(n))) {
      return flow.finish(t1, [_pick(Say.fine)]);
    }
    return null;
  }

  /// اشارهٔ کناری به موضوعی دیگر («قولنامه داریم») و پرسش «موضوع
  /// جداست؟». پروندهٔ فعلی تا پاسخ کاربر دست‌نخورده می‌ماند.
  AdvocateReply? side(String raw, String n) {
    // پیشنهادِ «موضوع جداست؟» فقط برای همان پیامِ بعدی معتبر است.
    final side = dialog.side;
    final sideText = dialog.sideText;
    dialog.side = null;
    dialog.sideText = '';
    if (side != null &&
        (raw.trim() == ChipTexts.sideChip ||
            raw.trim() == ChipTexts.newTopicChip ||
            (Sense.words(n) <= 4 &&
                Sense.has(n, 'جدا(?:ست| است|گانه)|موضوع دیگه|ماجرای دیگه')))) {
      return flow.open(side, Sense.norm(sideText), switched: true);
    }
    if (side != null && raw.trim() == ChipTexts.sameCaseChip) {
      // کاربر می‌گوید همان پرونده است؛ اشارهٔ کناری را رها می‌کنیم.
      final cur = picker.current();
      if (cur != null) {
        return _out('باشد، همین پرونده را ادامه می‌دهیم.',
            ask: dialog.askText.isEmpty ? 'ادامه بدهید.' : dialog.askText, chips: dialog.askChips);
      }
    }
    return null;
  }

  /// حساب تاریخ پایان مهلت، وقتی کاربر هم تاریخ ابلاغ را داده و هم
  /// مدت را. این حساب است، نه فتوا؛ هشدارش هم با آن می‌آید.
  AdvocateReply? deadline(String raw, String n, bool hasCase) {
    // حساب تاریخ پایان مهلت: کاربر هم تاریخ ابلاغ را داده هم مدت را و
    // فقط حساب تقویمی می‌خواهد. پیش‌تر در همین حالت جواب کلی می‌داد و همان
    // تاریخ را دوباره می‌پرسید. این حساب است، نه فتوا؛ ولی چون مدت را قانون
    // تعیین می‌کند، همان هشدار را هم می‌دهیم.
    if (!hasCase &&
        Sense.has(n, 'مهلت|آخرین روز|چه تاریخی|چه تاریخ|تا کی|تاریخ پایان|پایان مهلت') &&
        Sense.has(n, 'ابلاغ|رأی|رای|دادنامه|اعتراض|تجدیدنظر|واخواهی|فرجام')) {
      final due = computeDeadline(raw);
      if (due != null) {
        final span = due.span.label;
        final end = due.end.fa;
        return _out(
          'حساب تقویمی‌اش این می‌شود: ${due.start.fa} به‌اضافهٔ $span می‌شود $end. '
          'در مهلت‌های قانونی معمولاً روز ابلاغ حساب نمی‌شود؛ با آن قاعده مهلت از ${due.startNext.fa} شروع می‌شود و آخرین روزش $end است. '
          'ولی اینکه این مهلت در قانون $span است یا نه، به نوع رأی و مرجع ابلاغ‌کننده بستگی دارد و متن آن را در بانک ندارم؛ '
          'پس همین عدد را با متن قانون یا دفتر خدمات قضایی تطبیق دهید.',
          ask: 'این مهلت مربوط به اعتراض، تجدیدنظر یا فرجام است؟',
          chips: const ['اعتراض', 'تجدیدنظر', 'فرجام'],
        );
      }
    }
    return null;
  }

  /// کاربر همان حرف قبلی‌اش را دوباره فرستاده: از اول نمی‌پرسیم.
  AdvocateReply? repeat(String prevN, String n, bool hasCase) {
    // کاربر همان حرف قبلی‌اش را دوباره فرستاده: دوباره از اول نمی‌پرسیم.
    if (hasCase && Understanding.isRepeat(prevN, n)) {
      return _out(
        'این را پیش‌تر گفته‌اید و چیز تازه‌ای در آن نیست؛ همان ماجرا را در نظر دارم و از همان‌جا ادامه می‌دهم.',
        ask: dialog.askText.isEmpty
            ? 'چه تغییری کرده، یا دقیقاً چه می‌خواهید بدانید؟'
            : dialog.askText,
        chips: dialog.askChips,
      );
    }
    return null;
  }

  /// قاعده‌های مستندِ بی‌نیاز از پرونده: ثبت طلاق و تعارض قوانین.
  AdvocateReply? fixedRules(String n) {
    // ثبت طلاق و تعارض قوانین: پاسخ مستند به متن قانون.
    final divorce = Understanding.divorceRegistration(n);
    if (divorce != null) {
      return _out(divorce,
          ask: 'گواهی عدم امکان سازش را گرفته‌اید، و آیا به دفترخانه تسلیم کرده‌اید؟',
          full: true);
    }
    // قاعدهٔ تعارض پیش از فهرست مواد: پرسشی که شرط قرارداد و حق قانونی را
    // با هم دارد، باید با همان قاعده جواب بگیرد، نه با یک ارجاع ساده.
    final rule = Understanding.conflictRule(n);
    if (rule != null) {
      return _out(rule,
          ask: 'این حکم برای همین پرونده است؟ اگر بگویید چه شده، همان را روی متن قانون می‌سنجم.',
          full: true);
    }
    return null;
  }
}
