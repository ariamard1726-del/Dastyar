part of 'advocate.dart';

extension _Routes on Advocate {
  // مسیرهای یک‌نوبتیِ پاسخ: هر کدام یا جواب می‌دهد یا `null`.
  //
  // پیش‌تر این‌ها پشتِ سرِ هم داخل `_reply` بودند و یک تابعِ چندصدخطی
  // می‌ساختند؛ حالا هر مسیر نام دارد و تنها خوانده می‌شود. ترتیبِ فراخوانی
  // همان ترتیبِ پیشین است و عوض نشده.

  /// «موضوع تازه‌ای دارم»: پروندهٔ جاری بسته می‌شود، بی‌آنکه چیزی از آن
  /// در پاسخ‌های بعدی بمانَد.
  AdvocateReply? _routeNewCase(String raw) {
    if (raw.trim() == newCaseChip) {
      _closeCase();
      _loose.clear();
      return _out(
        'باشد، آن موضوع را کنار می‌گذارم.',
        ask: 'ماجرای تازه چیست؟ از هر جا که راحت‌ترید شروع کنید.',
      );
    }
    return null;
  }

  /// اعتراضِ «گزینه‌ای برای بیرون آمدن نیست»: راه خروج نشان داده می‌شود.
  AdvocateReply? _routeNoOption(String raw) {
    // «گزینه‌ای وجود ندارد»: اعتراض به نبودن راه خروج. راه خروج را نشان می‌دهیم.
    if (Drafting.isComplaintNoOption(raw)) {
      return _out(
        'درست می‌گویید؛ راه خروج را روشن نگفته بودم. برای بیرون آمدن از این موضوع، «انصراف» یا «موضوع تازه‌ای دارم» را بزنید یا همان را بنویسید.',
        ask: 'می‌خواهید این موضوع را کنار بگذاریم یا ادامه دهیم؟',
        chips: const [newCaseChip],
      );
    }
    return null;
  }

  /// پاسخ به «این موضوع تازه است یا مربوط به قبلی؟».
  ///
  /// این پرسش پیش از هر قاعدهٔ دیگری بررسی می‌شود؛ وگرنه «بله»/«خیر» ادامهٔ
  /// پروندهٔ قبلی خوانده می‌شود و پرونده عوض نمی‌شود.
  AdvocateReply? _routePending(String raw, String n) {
    final pend = _pendingTopic;
    final pendText = _pendingText;
    _pendingTopic = null;
    _pendingText = '';
    if (pend != null) {
      if (raw.trim() == Advocate.newTopicYesChip ||
          raw.trim() == sideChip ||
          (Sense.words(n) <= 6 &&
              Sense.has(n,
                  'موضوع (?:تازه|جدید|دیگه|دیگر)|جدا(?:ست| است|گانه)|ماجرای دیگه|ماجرای تازه'))) {
        return _open(pend, Sense.norm(pendText), switched: true);
      }
      final curTopic = _current();
      if (curTopic != null &&
          (raw.trim() == Advocate.newTopicNoChip ||
              raw.trim() == relatedChip ||
              (Sense.words(n) <= 6 &&
                  Sense.has(n,
                      'مربوط|همین (?:موضوع|ماجرا|پرونده)|همان (?:موضوع|ماجرا)|ماجرای قبلی|موضوع قبلی|به قبلی')))) {
        final pn = Sense.norm(pendText);
        final r = _inCase(curTopic, pendText, pn, _matchIssue(curTopic, pn));
        // «خیر» یعنی همان پرونده؛ این را صریح می‌گوییم تا کاربر نداند که
        // برنامه سرگردان شده است.
        return AdvocateReply(
          'باشد، همین پرونده را ادامه می‌دهیم.\n\n${r.text}',
          chips: r.chips,
          laws: r.laws,
          source: r.source,
        );
      }
    }
    return null;
  }

  /// دعوای لفظی: تا وقتی تهدید یا برخورد فیزیکی نبوده، خودِ «جر و بحث»
  /// جرم نیست؛ ولی باید بدانیم کدامش پیش آمده.
  AdvocateReply? _routeFight(String n, bool hasCase) {
    // دعوای لفظی: تا وقتی تهدید یا برخورد فیزیکی نبوده، خودِ «جر و بحث»
    // جرم نیست؛ ولی باید بدانیم کدامش پیش آمده. پیش‌تر این جمله به حدسِ
    // «دفاع در برابر شکایت» یا پاسخ «در پایگاه نیست» می‌رسید.
    if (!hasCase &&
        !Sense.has(n,
            'کتک|مشت|لگد|چاقو|زخم|ضرب|جرح|هل داد|هلم داد|بیمارستان|پزشکی قانونی') &&
        // «دعوا سر کرایه خانه» یا «با مستاجر درگیر شدم» ماجرای موضوع‌دار است و
        // باید به موضوع خودش برسد، نه به پاسخ عمومیِ دعوای لفظی.
        !_anyTopicCue(n) &&
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
  AdvocateReply? _routeChoice(
      String raw, String n, List<Topic> choices, String choiceText) {
    // جواب به «ماجرای شما به کدام نزدیک‌تر است؟».
    if (choices.isNotEmpty) {
      for (final t in choices) {
        if (n == Sense.norm(t.title)) {
          return _open(t, Sense.norm(choiceText));
        }
      }
      if (choices.length == 1 && Sense.words(n) <= 3 && Sense.saysYes(n)) {
        return _open(choices.first, Sense.norm(choiceText));
      }
      if (raw.trim() == noneChip ||
          (Sense.words(n) <= 3 && Sense.saysNo(n))) {
        _branchAsked = true;
        return _out(
          'باشد.',
          ask:
              'پس خودتان بگویید: چه اتفاقی افتاده و طرف مقابل کیست؟ هرچه بیشتر تعریف کنید بهتر می‌فهمم.',
          chips: Advocate.branchChips,
        );
      }
    }
    return null;
  }

  /// پرونده با حدس باز شده بود و کاربر می‌گوید حدس غلط است.
  AdvocateReply? _routeWrongGuess(String raw, String n, bool guessed) {
    // پرونده با حدس باز شده بود و کاربر می‌گوید حدس غلط است.
    if (guessed &&
        (raw.trim() == wrongChip ||
            (Sense.words(n) <= 7 &&
                Sense.has(n,
                    'موضوع(?:م)? (?:این|اون|آن|ان) نیست|اشتباه (?:گرفتی|فهمیدی|متوجه شدی)|منظورم این نبود|ربطی نداره|ربطی ندارد')))) {
      _closeCase();
      _loose.clear();
      return _out(
        'ببخشید، اشتباه برداشت کردم.',
        ask:
            'موضوع شما چیست؟ با یکی دو جمله بگویید چه شده و طرف مقابل کیست.',
        chips: _branchStart(),
      );
    }
    return null;
  }
}
