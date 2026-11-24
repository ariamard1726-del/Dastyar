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
    if (raw.trim() == Advocate.newCaseChip) {
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
        chips: const [Advocate.newCaseChip],
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
          raw.trim() == Advocate.sideChip ||
          (Sense.words(n) <= 6 &&
              Sense.has(n,
                  'موضوع (?:تازه|جدید|دیگه|دیگر)|جدا(?:ست| است|گانه)|ماجرای دیگه|ماجرای تازه'))) {
        return _open(pend, Sense.norm(pendText), switched: true);
      }
      final curTopic = _current();
      if (curTopic != null &&
          (raw.trim() == Advocate.newTopicNoChip ||
              raw.trim() == Advocate.relatedChip ||
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
      if (raw.trim() == Advocate.noneChip ||
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
        (raw.trim() == Advocate.wrongChip ||
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

  /// «ادامه بده» یا «بیشتر بگو»: متنی که در پاسخ قبلی جا نشد.
  AdvocateReply? _routeMore(String raw, String n, bool short) {
    final rest = voice.rest;
    if (rest.isNotEmpty &&
        (raw.trim() == Advocate.moreChip ||
            (short &&
                Sense.has(n,
                    'ادامه|بقیه|بیشتر (?:بگو|توضیح|باز)|کامل(?:ش|ترش)? (?:بگو|کن)')) ||
            (voice.offeredMore && short && Sense.saysYes(n)))) {
      var ask = _askText;
      var chips = _askChips;
      final t0 = _current();
      if (ask.isEmpty && t0 != null && cutText(rest, _budget)[1].isEmpty) {
        final a = _nextAsk(t0);
        _askText = ask = a.text;
        _askChips = chips = a.chips;
      }
      return _out(rest, ask: ask, chips: chips);
    }
    if (voice.offeredMore && rest.isNotEmpty && short && Sense.saysNo(n)) {
      final t0 = _current();
      if (t0 != null) return _finish(t0, [_pick(Say.fine)]);
      return _out(_pick(Say.fine), ask: 'چیز دیگری هست که بخواهید بدانید؟');
    }
    return null;
  }

  /// پاسخ به پیشنهادی که خودم به شکل پرسش داده بودم («بگویم؟»).
  AdvocateReply? _routeOffer(String raw, String n, bool short) {
    // جواب به پیشنهادی که به شکل پرسش داده بودم.
    if (_offer.isNotEmpty && short) {
      final t0 = _current();
      final offer = _offer;
      // «نمی‌دانم» در جوابِ «بگویم؟» یعنی تصمیم با خودت: می‌گویم. ولی
      // برای نوشتنِ سند، بی‌خواستِ روشنِ کاربر دست به کار نمی‌شوم.
      final unsure = Sense.saysDontKnow(n);
      if (t0 != null &&
          (Sense.saysYes(n) ||
              (unsure && offer != 'draft') ||
              raw.trim() == Advocate.moreChip ||
              Sense.has(n, '^ (?:بگو|بگید|بگویید|حتما|لطفا|ادامه) '))) {
        clearOffer();
        if (offer == 'draft') {
          return _out(
              'برای نوشتنش کافی است بگویید «بنویس»؛ چند سؤال کوتاه می‌پرسم و متن را آماده می‌کنم.');
        }
        file.turns--;
        return _reply(offer == 'argue' ? 'استدلالت چیه؟' : 'قدم بعدی چیست؟');
      }
      if (t0 != null && (Sense.saysNo(n) || unsure)) {
        clearOffer();
        return _finish(t0, [_pick(Say.fine)]);
      }
    }
    return null;
  }

  /// «باشه»/«نه» وقتی پرسشی روی میز نیست: پرسش بعدی می‌آید، نه
  /// «متوجه نشدم».
  AdvocateReply? _routeBareAck(String raw, String n) {
    // «باشه»، «نه» یا «ادامه بده» وقتی پرسشی روی میز نیست: گفتگو را با
    // پرسش بعدی جلو می‌برم، نه با «متوجه نشدم».
    final t1 = _current();
    if (t1 != null &&
        voice.rest.isEmpty &&
        _offer.isEmpty &&
        file.pending.isEmpty &&
        _side == null &&
        Sense.words(n) <= 3 &&
        (raw.trim() == Advocate.moreChip ||
            Sense.has(n, '^ ادامه ') ||
            Sense.saysYes(n) ||
            Sense.saysNo(n))) {
      return _finish(t1, [_pick(Say.fine)]);
    }
    return null;
  }

  /// اشارهٔ کناری به موضوعی دیگر («قولنامه داریم») و پرسش «موضوع
  /// جداست؟». پروندهٔ فعلی تا پاسخ کاربر دست‌نخورده می‌ماند.
  AdvocateReply? _routeSide(String raw, String n) {
    // پیشنهادِ «موضوع جداست؟» فقط برای همان پیامِ بعدی معتبر است.
    final side = _side;
    final sideText = _sideText;
    _side = null;
    _sideText = '';
    if (side != null &&
        (raw.trim() == Advocate.sideChip ||
            raw.trim() == Advocate.newTopicChip ||
            (Sense.words(n) <= 4 &&
                Sense.has(n, 'جدا(?:ست| است|گانه)|موضوع دیگه|ماجرای دیگه')))) {
      return _open(side, Sense.norm(sideText), switched: true);
    }
    if (side != null && raw.trim() == Advocate.sameCaseChip) {
      // کاربر می‌گوید همان پرونده است؛ اشارهٔ کناری را رها می‌کنیم.
      final cur = _current();
      if (cur != null) {
        return _out('باشد، همین پرونده را ادامه می‌دهیم.',
            ask: _askText.isEmpty ? 'ادامه بدهید.' : _askText, chips: _askChips);
      }
    }
    return null;
  }

  /// حساب تاریخ پایان مهلت، وقتی کاربر هم تاریخ ابلاغ را داده و هم
  /// مدت را. این حساب است، نه فتوا؛ هشدارش هم با آن می‌آید.
  AdvocateReply? _routeDeadline(String raw, String n, bool hasCase) {
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
  AdvocateReply? _routeRepeat(String prevN, String n, bool hasCase) {
    // کاربر همان حرف قبلی‌اش را دوباره فرستاده: دوباره از اول نمی‌پرسیم.
    if (hasCase && Understanding.isRepeat(prevN, n)) {
      return _out(
        'این را پیش‌تر گفته‌اید و چیز تازه‌ای در آن نیست؛ همان ماجرا را در نظر دارم و از همان‌جا ادامه می‌دهم.',
        ask: _askText.isEmpty
            ? 'چه تغییری کرده، یا دقیقاً چه می‌خواهید بدانید؟'
            : _askText,
        chips: _askChips,
      );
    }
    return null;
  }

  /// قاعده‌های مستندِ بی‌نیاز از پرونده: ثبت طلاق و تعارض قوانین.
  AdvocateReply? _routeFixedRules(String n) {
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
