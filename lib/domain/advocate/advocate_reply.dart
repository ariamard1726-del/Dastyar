part of 'advocate.dart';

// خطِ تولیدِ پاسخ: ترتیبِ کاندیدها، خواندنِ موضوع، و تصمیم‌هایی که فقط از
// رویِ پرونده و موضوع گرفته می‌شوند.
//
// این‌ها متدهای `Advocate` بودند؛ یک کلاسِ ۹۸۹خطی که در آن سیم‌کشیِ بیست
// همکار، API عمومی و همین تصمیم‌ها روی هم افتاده بودند. حالا آن‌ها یک بخشِ
// جدا دارند و `advocate.dart` فقط سیم‌کشی و API است. رفتار عوض نشده: همهٔ
// این‌ها همان متدهای خصوصی‌اند و کدِ تنه‌شان دست‌نخورده است.

extension _ReplyPipeline on Advocate {
  /// «انصراف»، «خروج از موضوع»، «نمی‌خواهم این بحث را ادامه دهم»: پرونده بسته
  /// می‌شود و از کاربر موضوعِ تازه خواسته می‌شود.
  AdvocateReply? _leaveReply(String raw) {
    if (!Drafting.isLeave(raw)) return null;
    _closeCase();
    dialog.loose.clear();
    dialog.branchAsked = true;
    return _out(
      'باشد، این موضوع را کنار گذاشتم.',
      ask: 'موضوع تازه‌تان چیست؟',
      chips: Advocate.branchChips,
    );
  }
  /// لمسِ دکمهٔ «تنظیم دادخواست …» یا «تنظیم لایحه …».
  AdvocateReply? _filingReply(String raw) {
    final wanted = filingFor(raw);
    return wanted == null ? null : _filing(wanted);
  }
  /// مهلتِ اعتراض یا ابلاغ، وقتی پرونده‌ای باز نیست: مدت دقیق به نوع رأی و
  /// مرجع بستگی دارد و متن آن در بانک نیست؛ ولی بی‌پاسخ هم رها نمی‌شود.
  AdvocateReply? _objectionDeadline(String n) {
    if (hasCase) return null;
    if (!Sense.has(n, 'مهلت') || !Sense.has(n, 'اعتراض|ابلاغ')) return null;
    return _out(
      'مهلت اعتراض معمولاً از تاریخ ابلاغ شمرده می‌شود، ولی مدت دقیق به نوع رأی و مرجع بستگی دارد و متن آن قانون در بانک من نیست. '
      'برای همین، ابلاغ‌نامه و تاریخ دقیق آن را نگه دارید و پیش از گذشتن مهلت، با وکیل یا دفتر خدمات قضایی تأیید کنید.',
      ask: 'رأی یا تصمیمی که ابلاغ شده از کدام مرجع است؟ تاریخ ابلاغ را هم بگویید.',
      full: true,
    );
  }
  /// ایمنی، پیش از هر چیز و مستقل از امتیازِ موضوع. یک بار در هر پرونده گفته
  /// می‌شود تا گفتگو در حلقه نیفتد؛ ولی اگر کاربر خودش بگوید «الان در خطر
  /// هستم»، هر بار جوابِ فوری می‌گیرد.
  AdvocateReply? _safetyReply(String n) {
    if (dialog.safetyShown && !_safetyBot.asksDanger(n)) return null;
    final safe = _safetyBot.reply(n);
    if (safe == null) return null;
    // بازکردن بی‌صدای پرونده فقط بار اول؛ تکرار «در خطر هستم» نباید پرونده را
    // دوباره باز کند.
    if (!hasCase && !dialog.safetyShown) {
      // پیامِ خشونت اغلب موضوع روشنی هم دارد («زد و می‌خوام طلاق بگیرم»).
      // پاسخِ این نوبت ایمنی است، ولی پرونده را بی‌صدا باز می‌کنیم تا نوبت بعد
      // از سرِ همان موضوع ادامه پیدا کند و کاربر مجبور نشود ماجرا را دوباره
      // بگوید.
      Topic? pick;
      var score = 0;
      for (final t in topics) {
        final sc = _score(t, n);
        if (sc > score) {
          pick = t;
          score = sc;
        }
      }
      if (pick != null && score >= 3) {
        _open(pick, n);
        // دکمه‌های داخلی با دکمه‌های ایمنیِ نمایش‌داده‌شده هم‌خوان بماند.
        dialog.askChips = safe.chips;
      } else {
        dialog.safetyCarry = n;
      }
    }
    // پس از `_open` تنظیم می‌شود، چون بازکردن پرونده پرچم‌ها را صفر می‌کند.
    dialog.safetyShown = true;
    return safe;
  }
  /// [again] یعنی «این پیام را من خودم ساختم»: وکیل برای «بگویم؟» جواب
  /// کاربر را به پرسشِ تازه ترجمه می‌کند («بگو» ← «استدلالت چیه؟»). آن پیام
  /// نوبتِ کاربر نیست، پس شمارهٔ نوبت را جلو نمی‌برد. پیش‌تر این کار با
  /// `file.turns--` بعد از فراخوانیِ بازگشتی انجام می‌شد؛ حالا صریح است.
  AdvocateReply _reply(String raw, {TopicGuess? guess, bool again = false}) {
    final n = Sense.norm(raw);
    final prevN = _prevN;
    _prevN = n;
    voice.relevantChip = Understanding.relevantChip(raw) ?? '';
    if (!again) file.turns++;
    final choices = dialog.choices;
    final choiceText = dialog.choiceText;
    final guessed = dialog.guessed;
    final branchAsked = dialog.branchAsked;
    dialog.choices = const [];
    dialog.choiceText = '';
    dialog.guessed = false;
    dialog.branchAsked = false;
    final short = Sense.words(n) <= 4;
    // از این‌جا تا «موضوعِ کنارِ هم»، ترتیب خودِ تصمیم است: هر ورودی نام دارد
    // و داور اولین پاسخ‌دهنده را برمی‌گرداند. جای زنجیرهٔ `if`ها، فهرست خوانده
    // می‌شود. ترتیب دقیقاً همان ترتیبِ پیشین است.
    final hit = _arbiter.pick(<AnswerCandidate>[
      AnswerCandidate('موضوعِ تازه', () => _routes.newCase(raw)),
      AnswerCandidate('«هیچ‌کدام»', () => _routes.noOption(raw)),
      // پاسخ به «این موضوع تازه است یا مربوط به قبلی؟» پیش از هر قاعدهٔ دیگر؛
      // وگرنه «بله»/«خیر» ادامهٔ پروندهٔ قبلی خوانده می‌شود.
      AnswerCandidate('تازه است یا مربوط؟', () => _routes.pending(raw, n)),
      AnswerCandidate('دکمهٔ دستهٔ مشکل',
          () => _branchReply(raw, n, asked: branchAsked)),
      AnswerCandidate('کنار گذاشتنِ موضوع', () => _leaveReply(raw)),
      // ایمنی پیش از هر چیز و مستقل از امتیازِ موضوع.
      AnswerCandidate('ایمنی', () => _safetyReply(n)),
      // «از برنامه خارج شدم» و جملهٔ کوتاهِ سوگ: پرسشِ واقعی، ولی نه ماجرای
      // حقوقی؛ پس از ایمنی می‌آید تا پیامِ خطر زیرش نماند.
      AnswerCandidate('دربارهٔ برنامه', () => _metaReplyBot.metaReply(raw, n)),
      AnswerCandidate('دعوا و شکایت', () => _routes.fight(n, hasCase)),
      AnswerCandidate('انتخابِ موضوع',
          () => _routes.choice(raw, n, choices, choiceText)),
      AnswerCandidate('حدسِ اشتباه', () => _routes.wrongGuess(raw, n, guessed)),
      AnswerCandidate('ادامهٔ حرفِ قبلی', () => _routes.more(raw, n, short)),
      AnswerCandidate('تنظیمِ سند', () => _filingReply(raw)),
      AnswerCandidate('پیشنهادِ پاسخ', () => _routes.offer(raw, n, short)),
      AnswerCandidate('«باشه»', () => _routes.bareAck(raw, n)),
      AnswerCandidate('موضوعِ کنارِ هم', () => _routes.side(raw, n)),
    ]);
    if (hit != null) return hit;
    final topic = _current();
    // محاسبهٔ موضوع از تصمیم جدا شد: این‌جا فقط خوانده می‌شود، بعد تصمیم
    // گرفته می‌شود.
    final read = _readTopics(n);

    // دُمِ مسیرها: پیش از امتیاززدنِ موضوع، «مهلت» و «موضوعِ صریح» جای خودشان
    // را دارند؛ پس داور یک بار تنها با «مهلت» صدا زده می‌شود، بعد پاسخِ
    // موضوعی می‌آید و بعد داورِ دوم.
    final due = _arbiter.pick(<AnswerCandidate>[
      AnswerCandidate('مهلت', () => _routes.deadline(raw, n, hasCase)),
    ]);
    if (due != null) return due;
    // موضوع صریح (امتیاز بالا، بدون پرونده) بر پاسخ‌های کلیِ مقدم برتری دارد.
    final meta = _meta(n, topic, explicit: topic == null && read.bestScore >= 5);
    if (meta != null) return meta;

    final tail = _arbiter.pick(<AnswerCandidate>[
      AnswerCandidate('تکرارِ حرفِ قبلی', () => _routes.repeat(prevN, n, hasCase)),
      AnswerCandidate('قاعدهٔ ثابت', () => _routes.fixedRules(n)),
      // مهلت اعتراض یا ابلاغ: مدت به نوع رأی و مرجع بستگی دارد و متن آن در
      // بانک من نیست؛ پس بی‌پاسخ رها نمی‌کنم، راه درست را می‌گویم.
      AnswerCandidate('مهلتِ اعتراض', () => _objectionDeadline(n)),
    ]);
    if (tail != null) return tail;
    // واژهٔ مشخصِ قانونی (مهریه، ودیعه، غبن…) وقتی هیچ پرونده‌ای باز نیست
    // و موضوعی هم تشخیص داده نشده: همان مادهٔ مستند را نشان می‌دهیم.
    if (!hasCase && read.bestScore < 3) {
      // «قهر» و حدس مطمئنِ خوانندهٔ موضوع پیش از متن قانون می‌آیند.
      final confidentGuess = guess != null && guess.confident;
      final lt = Sense.has(n, 'قهر') || confidentGuess ? null : _termReply.lawTerms(raw, n);
      if (lt != null) return lt;
      final refs = Understanding.linkedArticles(n);
      if (refs.isNotEmpty) {
        return _out(
          'این واژه به ${refs.join(' ')} مربوط است.',
          ask: 'ماجرای شما دقیقاً چیست؟ چه کسی و چه کاری کرده است؟',
          full: true,
        );
      }
    }

    // «قهر» جرم نیست و کسی را به‌خاطر قهر زندانی یا جریمه نمی‌کنند. این را
    // پیش از هر موضوع می‌گوییم تا برداشت اشتباه جا نماند.
    if (Sense.has(n, 'قهر') &&
        Sense.has(n, 'زندان|حبس|بازداشت|جریمه|پلیس|دادگاه')) {
      return _out(
        'قهر کردن جرم نیست و کسی را به‌خاطر قهر زندانی یا جریمه نمی‌کنند. اگر ماجرای دعوا یا رفتار طرف مقابل نگرانتان کرده، همان را تعریف کنید.',
        ask: 'چه اتفاقی افتاده است؟',
      );
    }

    if (Sense.has(n, 'گفتگوی من با برنامه|گفتگو با برنامه|با برنامه (?:هست|است)')) {
      return _out('درست است؛ این گفتگو با خود همین برنامه است. هر ماجرایی دارید، بگویید.',
          ask: 'چه چیزی را بررسی کنیم؟');
    }

    final corrected = _correctionReply(n, topic);
    if (corrected != null) return corrected;
    if (topic == null) return _noCaseReply(raw, n, read, guess);
    return _inCaseReply(raw, n, topic, read);
  }
  /// خواندنِ موضوع از پیام: امتیازِ هر موضوع، و امتیازِ «پیامِ پیشینی که پاسخِ
  /// ایمنی جایش را گرفته بود» (`safetyCarry`) فقط وقتی پیامِ تازه خودش ضعیف
  /// است. هیچ تصمیمی این‌جا گرفته نمی‌شود.
  TopicRead _readTopics(String n) {
    final carry = dialog.safetyCarry;
    dialog.safetyCarry = '';
    Topic? best;
    var bestScore = 0;
    final scores = <String, int>{};
    for (final t in topics) {
      final s = _score(t, n);
      scores[t.id] = s;
      if (s > bestScore) {
        best = t;
        bestScore = s;
      }
    }
    if (bestScore < 4 && carry.isNotEmpty) {
      for (final t in topics) {
        final s = _score(t, '$n $carry');
        if (s > bestScore) {
          best = t;
          bestScore = s;
        }
        scores[t.id] = s;
      }
    }
    return TopicRead(best: best, bestScore: bestScore, scores: scores);
  }
  /// اصلاحِ کاربر («من اصلا در مورد طلاق صحبت نکردم، در مورد دستبرد بود»):
  /// موضوعِ قبلی رها می‌شود و فقط بخشِ اصلاح‌شده سنجیده می‌شود.
  AdvocateReply? _correctionReply(String n, Topic? topic) {
    if (topic == null || Sense.words(n) > 40) return null;
    if (!Sense.has(n, _correctionPattern)) return null;
    final fixed = _afterCorrection(n);
    Topic? nb;
    var ns = 0;
    for (final t in topics) {
      final s = fixed.isEmpty ? 0 : _score(t, fixed);
      if (s > ns) {
        nb = t;
        ns = s;
      }
    }
    _closeCase();
    dialog.loose.clear();
    if (nb != null && ns >= 3) return _open(nb, fixed);
    return _out(
      'ببخشید، برداشتم اشتباه بود. موضوع را دوباره بفرمایید: چه اتفاقی افتاده است؟',
      ask: 'طرف مقابل کیست و دقیقاً چه کرده است؟',
      chips: _branchStart(),
    );

  }
  /// پرونده‌ای باز نیست: از بازکردنِ موضوعِ روشن تا پاسخِ واژه‌محور و پرسشِ
  /// کنجکاو. تنها ورودیِ محاسبه‌شده‌اش [read] است، پس دیگر با امتیاززدن و
  /// تصمیم‌گیریِ `_reply` قاطی نمی‌شود.
  AdvocateReply _noCaseReply(String raw, String n, TopicRead read, TopicGuess? guess) {
    final best = read.best;
    final bestScore = read.bestScore;
    final scores = read.scores;
    if (best != null && bestScore >= 3) {
      final others = <Topic>[
        for (final t in topics)
          if (t.id != best.id && (scores[t.id] ?? 0) >= 4) t,
      ];
      if (others.isNotEmpty) dialog.also = others.first;
      // پیامِ چندموضوعی: پیش‌تر فقط به یکی از موضوع‌ها جواب می‌داد و بقیه
      // بی‌صدا می‌ماند. حالا موضوع‌ها را نام می‌برد و می‌پرسد از کدام شروع
      // کنیم؛ هر کدام پرونده و مهلت جدا دارد.
      final asksOrder = Sense.has(n,
          'اول کدام|کدوم را اول|کدام را اول|از کجا شروع|اول (?:چی|کدام)|چی را اول');
      if (others.isNotEmpty &&
          (asksOrder || (others.length >= 2 && Sense.words(n) >= 14))) {
        dialog.choices = <Topic>[best, ...others].take(3).toList();
        dialog.choiceText = n;
        final lines = [
          for (final t in dialog.choices) '• ${t.title}',
        ];
        return _out(
          'در این پیام چند ماجرای جدا بود:\n${lines.join('\n')}\n\n'
          'هر کدام پرونده، مهلت و مسیر خودش را دارد و یک‌جا جواب‌دادن به همه '
          'سطحی می‌شود. از کدام شروع کنیم؟',
          chips: [for (final t in dialog.choices) t.title, noneChip],
        );
      }
      return _open(best, n);
    }
    dialog.loose.add(n);
    if (dialog.loose.length > 3) dialog.loose.removeAt(0);
    // دو سه پیامِ کوتاهِ پشت‌سرهم با هم یک ماجرا هستند: اگر روی‌هم موضوع
    // را روشن کنند، همان پرونده باز می‌شود.
    if (dialog.loose.length > 1 && bestScore >= 1) {
      final joined = dialog.loose.join(' ');
      Topic? jb;
      var js = 0;
      for (final t in topics) {
        final sc = _score(t, joined);
        if (sc > js) {
          jb = t;
          js = sc;
        }
      }
      if (jb != null && js >= 3 && (scores[jb.id] ?? 0) >= 1) {
        dialog.loose.removeLast();
        return _open(jb, n);
      }
    }
    final g = _guides.glossary(n);
    if (g != null) {
      return _out(g,
          ask: dialog.guide == null ? 'این واژه در ماجرای خودتان پیش آمده؟ چه شده است؟' : '',
          source: AnswerSource.glossary);
    }
    final guide = dialog.guide;
    if (guide != null) {
      final r = _guides.follow(guide, n);
      if (r != null) return r;
    }
    // واژه‌های پرسش را با متن قوانین می‌سنجیم: ماده‌ای که واژه‌ها را با هم
    // دارد نشان داده می‌شود، و اگر نداشت، گفته می‌شود کدام واژه‌ها در قوانین
    // هست؛ پیش از حدس‌های کلی و پرسش «کدام نزدیک‌تر است؟».
    if (guide == null && (guess == null || !guess.confident)) {
      final tf = _termReply.topicFlow(raw, n);
      if (tf != null) return tf;
      final lt = _termReply.lawTerms(raw, n);
      if (lt != null) return lt;
    }
    // حدسِ مطمئنِ مدل بر راهنماهای آماده مقدم است: آن‌ها با یک واژه
    // انتخاب می‌شوند («حقوقم» در «بانک از حقوقم کسر می‌کند») و مدل کل
    // جمله را می‌بیند. «یک سؤال حقوقی دارم» موضوعی ندارد که حدس زده شود.
    final usable = guess != null && !_vague(n) ? guess : null;
    if (usable != null && usable.confident) {
      final r = _fromGuess(usable, raw, n, scores);
      if (r != null) return r;
    }
    // نظر دوم IntentNet پیش از راهنماهای ثابت: راهنماها با جفت واژه‌ها
    // تطبیق می‌یابند (مثلاً «حقوق» و «نداده») و «کارگاه حقوقم را نداده»
    // را به قاعدهٔ حقوق معوق می‌برند، پیش از آنکه موضوع ماجرا روشن شود.
    if (guess == null) {
      final hint = _secondOpinion(raw, n);
      if (hint != null) {
        dialog.loose.removeLast();
        // پرونده از روی نظر طبقه‌بند باز شد، پس برچسب همان است.
        final r = _open(hint, n);
        return AdvocateReply(r.text,
            chips: r.chips, laws: r.laws, source: AnswerSource.intentNet);
      }
    }
    final hopeless = _hopeless(n);
    if (hopeless != null) return hopeless;
    final lg = _matchGuide(raw, n);
    if (lg != null) return _guides.openGuide(lg, raw, n);
    final soc = _social(n, null);
    if (soc != null) return soc;
    if (guess != null) {
      final r = usable == null || usable.confident
          ? null
          : _fromGuess(usable, raw, n, scores);
      if (r != null) return r;
    }
    if (_vague(n)) return _intake(raw);
    return _guides.lookup(raw, n);

  }
  /// پرونده باز است: عوض‌کردنِ موضوع (با پرسش یا با نشانهٔ روشن) یا ادامهٔ
  /// همان پرونده.
  AdvocateReply _inCaseReply(String raw, String n, Topic topic, TopicRead read) {
    final best = read.best;
    final bestScore = read.bestScore;
    final scores = read.scores;
    final cur = scores[topic.id] ?? 0;
    final issue = _matchIssue(topic, n);
    // پیامی که موضوع دیگری را با نشانهٔ روشن می‌آورد، پروندهٔ فعلی را که
    // نشانه‌اش کمتر از نصف است عوض می‌کند (به جای چسبیدن به پروندهٔ قبلی).
    final dominant = bestScore >= 5 && cur * 2 < bestScore;
    if (best != null && best.id != topic.id && (cur == 0 || dominant)) {
      // وسط یک پرونده، هر اشاره‌ای به موضوع دیگر به معنی ماجرای تازه
      // نیست (مثلاً «قولنامه داریم» در پروندهٔ اجاره). فقط وقتی می‌پرم که
      // خودِ کاربر موضوع را عوض کند یا نشانه قوی باشد؛ در حالت میانه می‌پرسم.
      final marker = Sense.has(n, _newMatter);
      final answers = _answers(topic, n);
      final long = Sense.words(n) >= 5;
      final need = marker ? 3 : (topic.id == 'accused' ? 9 : 5);
      final strong = bestScore >= need ||
          (topic.id != 'accused' && bestScore >= 4 && Sense.isQuestion(n));
      if (strong &&
          (marker || (long && !answers)) &&
          (bestScore >= 4 || issue == null)) {
        if (marker) return _open(best, n, switched: true);
        return _askSwitch(best, raw);
      }
      // متهم معمولاً ماجرای پشتِ شکایت را تعریف می‌کند (ملک، چک، …)؛ آن‌جا
      // فقط با نشانهٔ خیلی قوی می‌پرسم.
      final hint = topic.id == 'accused' ? 6 : 4;
      if (bestScore >= hint && issue == null && !answers) {
        // جملهٔ کامل دربارهٔ موضوع دیگری: به‌جای نگه‌داشتنِ بی‌صدا، اعلام
        // می‌کنیم و از خودِ کاربر می‌پرسیم؛ اشارهٔ کوتاه («قولنامه داریم»)
        // فقط کنار گذاشته می‌شود.
        if (Sense.words(n) >= 5) return _askSwitch(best, raw);
        dialog.side = best;
        dialog.sideText = raw;
      }
    }
    return _inCase(topic, raw, n, issue);
  }
  /// پیامی به موضوع دیگری اشاره دارد، بدون آنکه کاربر صریحاً بگوید موضوع تازه
  /// است. پیش از عوض‌کردن پرونده می‌پرسیم؛ تا وقتی کاربر «انصراف» نزده، از
  /// موضوع فعلی خارج نمی‌شویم.
  AdvocateReply _askSwitch(Topic t, String raw) {
    dialog.pendingTopic = t;
    dialog.pendingText = raw;
    final curTitle = _current()?.title ?? 'موضوع قبلی';
    // پرسشِ خودِ پرونده کنار می‌رود تا در این نوبت فقط یک پرسش باشد و
    // «بله/خیر» دو معنا نداشته باشد.
    file.pending = '';
    dialog.askText = '';
    dialog.askChips = const [];
    return _out(
      'به نظر می‌رسد این حرف با «$curTitle» فرق دارد و درباره‌ی «${t.title}» است. '
      'هنوز پروندهٔ قبلی باز است و چیزی را پاک نمی‌کنم.',
      ask: 'این موضوع تازه است یا به همان ماجرای قبلی مربوط است؟',
      chips: const [Advocate.newTopicYesChip, Advocate.newTopicNoChip],
    );
  }
}
