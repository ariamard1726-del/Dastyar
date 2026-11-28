part of 'advocate.dart';

// نگهبان‌های پیش از ترتیب: تصمیم‌هایی که به یک قاعده در فهرستِ کاندیدها
// نمی‌سپارند، چون یا پیش از همه باید اجرا شوند (ایمنی، انصراف) یا ورودی‌شان
// خواندنِ پرونده است، نه ساختنِ پاسخ (خواندنِ موضوع، اصلاحِ کاربر، مهلت، سند).
//
// این‌ها متدهای `Advocate` بودند؛ رفتار و تنهٔ کد دست‌نخورده است، فقط از
// فایلِ ۴۱۰خطیِ خطِ تولید جدا شدند.

class _PreparedTurn {
  const _PreparedTurn({
    required this.raw,
    this.engineReply,
    this.guideQuery = '',
    this.guideReply,
    this.termMatch,
  });

  final String raw;
  final EngineReply? engineReply;
  final String guideQuery;
  final EngineReply? guideReply;
  final TermMatch? termMatch;

  EngineReply? engineFor(String query) {
    if (query == raw) return engineReply;
    if (guideQuery.isNotEmpty && query == guideQuery) return guideReply;
    return null;
  }

  TermMatch? termFor(String query) => query == raw ? termMatch : null;
}

extension _ReplyGuards on Advocate {
  /// نگهبان بازگشتِ `_reply`: سقف عمق و قفلِ `again: true`.
  AdvocateReply _guardedReply(
    String raw, {
    TopicGuess? guess,
    bool again = false,
  }) =>
      _loopGuard.run(
        again: again,
        body: () => _reply(raw, guess: guess, again: again),
      );

  /// «انصراف»، «خروج از موضوع»، «نمی‌خواهم این بحث را ادامه دهم»: پرونده بسته
  /// می‌شود و از کاربر موضوعِ تازه خواسته می‌شود.
  AdvocateReply? _leaveReply(String raw) {
    if (!DraftWords.isLeave(raw)) return null;
    _closeCase();
    dialog.loose.clear();
    dialog.branchAsked = true;
    return _out(
      advocateText('guardLeaveBody'),
      ask: advocateText('guardLeaveAsk'),
      chips: ChipTexts.branchChips,
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
      advocateText('guardObjectionBody'),
      ask: advocateText('guardObjectionAsk'),
      full: true,
    );
  }
  /// ایمنی، پیش از هر چیز و مستقل از امتیازِ موضوع. تکرارِ دقیق همان متن
  /// سرکوب میشود تا گفتگو در حلقه نیفتد؛ ولی گزارش تازهٔ خطر، یا تشدید شدت
  /// هشدار و یا گذر از پنجرهٔ نوبتی، هر بار جوابِ فوری میگیرد.
  AdvocateReply? _safetyReply(String n) {
    if (dialog.safetyShown &&
        !dialog.acknowledgedSafe &&
        _safetyBot.acknowledgesSafe(n)) {
      dialog.safetySeverity = SafetySeverity.none;
      dialog.acknowledgedSafe = true;
      dialog.lastSafetyText = '';
      dialog.lastSafetyTurn = file.turns;
      final t = _current();
      if (hasCase && t != null) {
        final a = _case.nextAsk(t);
        dialog.askText = a.text;
        dialog.askChips = a.chips;
        return _out(
          advocateText('safetySafeNowCaseBody'),
          ask: a.text,
          chips: a.chips,
          source: AnswerSource.safety,
        );
      }
      return _out(
        advocateText('safetySafeNowIdleBody'),
        ask: advocateText('safetySafeNowIdleAsk'),
        chips: _branchStart(),
        source: AnswerSource.safety,
      );
    }
    final safe = _safetyBot.reply(n);
    if (safe == null) return null;
    final sev = _safetyBot.severityOf(n);
    final escalated =
        sev == SafetySeverity.critical && dialog.safetySeverity != sev;
    final staleWindow = (file.turns - dialog.lastSafetyTurn) > 3;
    // تنها تکرارِ دقیق همان متن در همان پنجرهٔ نوبتی و بدون تشدید سرکوب میشود.
    if (dialog.safetyShown &&
        dialog.lastSafetyText == n &&
        !escalated &&
        !(sev == SafetySeverity.critical && staleWindow)) {
      return null;
    }
    // بازکردن بی‌صدای پرونده فقط بار اول؛ تکرار «در خطر هستم» نباید پرونده را
    // دوباره باز کند.
    if (!hasCase && !dialog.safetyShown) {
      // پیامِ خشونت اغلب موضوع روشنی هم دارد («زد و می‌خوام طلاق بگیرم»).
      // پاسخِ این نوبت ایمنی است، ولی پرونده را بی‌صدا باز می‌کنیم تا نوبت بعد
      // از سرِ همان موضوع ادامه پیدا کند و کاربر مجبور نشود ماجرا را دوباره
      // بگوید.
      Topic? pick;
      var score = 0;
      for (final t in Advocate.topics) {
        final sc = _score(t, n);
        if (sc > score) {
          pick = t;
          score = sc;
        }
      }
      if (pick != null && score >= _topicOpenMin) {
        _open(pick, n);
        // دکمه‌های داخلی با دکمه‌های ایمنیِ نمایش‌داده‌شده هم‌خوان بماند.
        dialog.askChips = safe.chips;
      } else {
        dialog.safetyCarry = n;
      }
    }
    // `_open` وضعیت پرونده را پاک میکند؛ وضعیت ماشین ایمنی همیشه **پس** از
    // آن نوشته میشود تا شدت، نوبت و تکرار سرکوب حفظ شود.
    dialog.lastSafetyText = n;
    dialog.safetyShown = true;
    dialog.safetySeverity = sev;
    dialog.lastSafetyTurn = file.turns;
    dialog.acknowledgedSafe = false;
    return safe;
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
    for (final t in Advocate.topics) {
      final s = _score(t, n);
      scores[t.id] = s;
      if (s > bestScore) {
        best = t;
        bestScore = s;
      }
    }
    if (bestScore < 4 && carry.isNotEmpty) {
      for (final t in Advocate.topics) {
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
    if (!Sense.has(n, Advocate._correctionPattern)) return null;
    final fixed = Advocate._afterCorrection(n);
    Topic? nb;
    var ns = 0;
    for (final t in Advocate.topics) {
      final s = fixed.isEmpty ? 0 : _score(t, fixed);
      if (s > ns) {
        nb = t;
        ns = s;
      }
    }
    _closeCase();
    dialog.loose.clear();
    if (nb != null && ns >= _topicOpenMin) return _open(nb, fixed);
    return _out(
      advocateText('guardCorrectionBody'),
      ask: advocateText('guardCorrectionAsk'),
      chips: _branchStart(),
    );

  }
}
