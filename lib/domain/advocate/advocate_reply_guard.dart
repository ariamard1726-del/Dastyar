part of 'advocate.dart';

// نگهبان‌های پیش از ترتیب: تصمیم‌هایی که به یک قاعده در فهرستِ کاندیدها
// نمی‌سپارند، چون یا پیش از همه باید اجرا شوند (ایمنی، انصراف) یا ورودی‌شان
// خواندنِ پرونده است، نه ساختنِ پاسخ (خواندنِ موضوع، اصلاحِ کاربر، مهلت، سند).
//
// این‌ها متدهای `Advocate` بودند؛ رفتار و تنهٔ کد دست‌نخورده است، فقط از
// فایلِ ۴۱۰خطیِ خطِ تولید جدا شدند.

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
  /// سرکوب میشود تا گفتگو در حلقه نیفتد؛ ولی گزارش تازهٔ خطر، هر بار جوابِ
  /// فوری میگیرد.
  AdvocateReply? _safetyReply(String n) {
    final safe = _safetyBot.reply(n);
    if (safe == null) return null;
    // تنها تکرارِ دقیق همان متن سرکوب میشود. یک گزارش تازهٔ خشونت در همان
    // پرونده نباید بیپاسخ بماند.
    if (dialog.safetyShown && dialog.lastSafetyText == n) return null;
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
      if (pick != null && score >= 3) {
        _open(pick, n);
        // دکمه‌های داخلی با دکمه‌های ایمنیِ نمایش‌داده‌شده هم‌خوان بماند.
        dialog.askChips = safe.chips;
      } else {
        dialog.safetyCarry = n;
      }
    }
    // `_open` وضعیت پرونده را پاک میکند؛ متنِ آخرین هشدار را همیشه **پس** از
    // آن می نویسیم تا تکرارِ همان پیام سرکوب شود.
    dialog.lastSafetyText = n;
    dialog.safetyShown = true;
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
    if (nb != null && ns >= 3) return _open(nb, fixed);
    return _out(
      advocateText('guardCorrectionBody'),
      ask: advocateText('guardCorrectionAsk'),
      chips: _branchStart(),
    );

  }
}
