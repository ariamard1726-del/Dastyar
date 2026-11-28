part of 'advocate.dart';

// پاسخِ یک نوبتِ داخلِ پرونده: بازکردن، پاسخ با واقعیت‌های تازه، جمع‌بندی.
//
// این سه متد تصمیم می‌گیرند *چه* گفته شود؛ ساختنِ جمله‌ها کارِ
// `case_text.dart` است و نوشتنِ واقعیت‌ها کارِ `case_facts.dart`.

extension _CaseAnswers on CaseFlow {
  AdvocateReply open(Topic t, String n,
      {bool switched = false, bool guessed = false}) {
    final earlier = switched ? const <String>[] : List<String>.of(dialog.loose);
    dialog.loose.clear();
    closeCase();
    file.topic = t.id;
    // حرف‌هایی که پیش از بازشدن پرونده زده شده هم جزو ماجراست.
    for (final old in earlier) {
      absorb(t, old, live: false);
    }
    final news = absorb(t, n);
    dialog.heard = '${earlier.join(' ')} $n';
    if (Sense.has(dialog.heard, _replySaid)) file.covered.add('q:reply');
    if (Sense.has(dialog.heard, _goalSaid)) file.covered.add('q:goal');
    final parts = <String>[];
    // اول نشان می‌دهم حرف کاربر را چطور فهمیده‌ام؛ اگر اشتباه گرفته باشم
    // همان‌جا می‌تواند اصلاحم کند.
    final got = recapOf(t, file);
    if (got.isNotEmpty) {
      parts.add('${_pick(Say.understood)} ${_join(got)}.');
    }
    final open = t.opening(file);
    final issue = picker.matchIssue(t, n);
    var answered = false;
    if (issue != null) {
      if (roleUnknown(t)) {
        dialog.deferred = issue.id;
      } else {
        // کاربر پرسش مشخصی دارد: اول جواب همان را می‌دهم، نه مقدمهٔ کلی.
        final b = issue.body(file);
        parts.add(b);
        file.covered.add(issue.id);
        voice.said.add(b);
        voice.lastBody = b;
        answered = true;
      }
    }
    if (!answered && open.isNotEmpty) parts.add(open);
    addEffects(parts, news, 1,
        skip: dialog.deferred.isEmpty && issue != null ? issue.covers : const {});
    noteAmount(parts, news, n);
    if (voice.lastBody.isEmpty) {
      // «ساده‌تر بگو» باید سراغ حرف قانون برود، نه بازگویی ماجرا.
      if (open.isNotEmpty) {
        voice.lastBody = open;
      } else if (parts.isNotEmpty) {
        voice.lastBody = parts.first;
      }
    }
    var lead = '';
    if (guessed) {
      // پرونده با حدس باز شده؛ این را پنهان نمی‌کنم تا اگر غلط است بگوید.
      lead = advocateFormat('caseGuessedLead', {'title': t.title});
    } else if (switched) {
      lead = _pick(Say.switched);
    } else if (LawyerVoice.expressesDistress(n) ||
        Sense.has(n, 'کتک|میزنه| زد|اخراج|تهدید|بیچاره|بدبخت|نگران|میترسم|استرس')) {
      lead = _pick(Say.empathy);
    }
    final also = dialog.also;
    dialog.also = null;
    if (also != null && also.id != t.id) {
      parts.add(advocateFormat('caseAlsoNotice', {'title': also.title}));
    }
    return finish(t, parts, lead: lead);
  }

  AdvocateReply inCase(Topic t, String raw, String n, Issue? issue) {
    final wasPending = file.pending;
    final before = argument._standings(t);
    final news = absorb(t, n);
    // جملهٔ بلندِ بی‌ربط در وسط یک پرونده: به‌جای تکرار قدم‌های همان پرونده،
    // کلمه‌های خودِ کاربر نقل و توضیح خواسته می‌شود.
    if (news.isEmpty &&
        !wasPending.startsWith('q:') &&
        Sense.words(n) >= 4 &&
        !Sense.isQuestion(n) &&
        Sense.followKind(n).isEmpty &&
        Advocate.topicOf(raw) == null &&
        !Sense.has(n, _goalSaid) &&
        !Sense.has(n, _replySaid) &&
        picker.matchIssue(t, n) == null &&
        glossary(n) == null) {
      return talk.unclearReply(raw, chips: const [ChipTexts.newCaseChip]);
    }
    dialog.heard = '${dialog.heard} $n';
    // آنچه کاربر خودش گفته، دوباره پرسیده نمی‌شود.
    final heardGoal = wasPending != 'q:goal' &&
        !file.covered.contains('q:goal') &&
        Sense.has(n, _goalSaid);
    if (heardGoal) file.covered.add('q:goal');
    if (wasPending != 'q:reply' &&
        (Sense.has(n, _replySaid) ||
            news.any((s) =>
                file.has(s.id) && s.options.any((o) => o.contains('انکار'))))) {
      file.covered.add('q:reply');
    }
    final parts = <String>[];
    var understood = news.isNotEmpty || file.touched(file.pending);
    var reasoned = false;
    var asked = issue;
    if (asked == null && dialog.deferred.isNotEmpty && !roleUnknown(t)) {
      for (final i in t.issues) {
        if (i.id != dialog.deferred) continue;
        // حالا که نقش معلوم شده، بحثی که مالِ طرفِ دیگر است جواب داده
        // نمی‌شود.
        final w = i.when;
        if (w == null || w(file)) asked = i;
      }
      dialog.deferred = '';
    }
    // اگر همین بحث قبلاً باز شده و کاربر حالا فقط یک واقعیت تازه می‌دهد
    // (نه پرسش)، کل توضیح تکرار نمی‌شود؛ فقط اثرِ همان واقعیت گفته می‌شود.
    final onlyFact = asked != null &&
        file.covered.contains(asked.id) &&
        !Sense.isQuestion(n) &&
        news.any((s) => s.effect != null && s.effect!(file).isNotEmpty);
    // «می‌توانم … بگیرم؟»: جوابِ پرسشِ بله/نه دربارهٔ یک خواسته، حکمِ همان
    // خواسته روی واقعیت‌های همین پرونده است، نه توضیح کلی.
    final focus = argument._askedClaim(t, n, asked);
    if (focus != null) {
      final b = argument._verdict(focus);
      parts.add(b);
      dialog.roomy = true;
      voice.said.add(b);
      voice.lastBody = b;
      understood = true;
      reasoned = true;
    } else if (asked != null && !onlyFact) {
      final b = asked.body(file);
      parts.add(b);
      file.covered.add(asked.id);
      voice.said.add(b);
      voice.lastBody = b;
      understood = true;
    } else if (onlyFact) {
      understood = true;
    } else {
      final g = glossary(n);
      if (g != null) {
        parts.add(g);
        understood = true;
      } else {
        final kind = Sense.followKind(n);
        // استدلالی که با همین واقعیت‌ها گفته شده برای «شانسم چقدر است؟»
        // تکرار نمی‌شود؛ با «استدلالت چیه؟» یا واقعیت تازه دوباره می‌آید.
        final stale = kind == 'chance' && dialog.arguedOn == _factsKey();
        final arg =
            (kind == 'argue' || kind == 'chance') && !stale ? argument._argue(t) : null;
        final fb = kind.isEmpty
            ? null
            : (t.follow[kind == 'argue' ? 'chance' : kind] ?? generic(kind));
        if (arg != null) {
          reasoned = true;
          parts.add(arg);
          dialog.roomy = true;
          dialog.arguedOn = _factsKey();
          file.covered.add('f:argue');
          file.covered.add('f:chance');
          voice.said.add(arg);
          voice.lastBody = arg;
          understood = true;
        } else if (fb != null) {
          final b = fb(file);
          parts.add(b);
          dialog.roomy = kind == 'next';
          file.covered.add('f:$kind');
          voice.said.add(b);
          voice.lastBody = b;
          understood = true;
        }
      }
    }
    // جوابِ پرسشِ بازِ خودم (طرف چه گفته؟ دنبال چه هستید؟) را بی‌واکنش
    // نمی‌گذارم.
    // «ادامه بده» جواب پرسش نیست؛ نباید به‌عنوان جواب، «خوب شد گفتید» بگیرد.
    final isMore = Sense.has(n, ' (?:ادامه|بقیه)(?: |\$)');
    if (wasPending.startsWith('q:') && parts.isEmpty && !isMore) {
      if (news.isEmpty) {
        final soc = talk.social(n, t);
        if (soc != null) return soc;
      }
      // واقعیتِ تازه‌ای که به‌جای جواب آمده («اجاره‌نامه دارم»)، واکنشِ
      // خودش را دارد؛ رویش «همین را هدف می‌گیرم» نمی‌گذارم.
      final fact =
          news.any((s) => s.effect != null && s.effect!(file).isNotEmpty);
      if (!fact || heardGoal) {
        parts.add(react(heardGoal ? 'q:goal' : wasPending, n));
      }
      understood = true;
    } else if (heardGoal && parts.isEmpty) {
      parts.add(react('q:goal', n));
      understood = true;
    }
    addEffects(parts, news, 2,
        skip: asked == null || onlyFact ? const {} : asked.covers);
    if (onlyFact && parts.isEmpty) {
      final b = asked.body(file);
      parts.add(b);
      voice.lastBody = b;
    }
    // حرف تازه اگر نتیجه را جابه‌جا کرده، همان‌جا می‌گویم؛ و اگر حرف قبلی
    // را برعکس کرده، می‌گویم که برداشتم را عوض کرده‌ام.
    if (!reasoned && news.isNotEmpty) {
      final shift = argument._shift(t, before);
      if (shift.isNotEmpty) parts.insert(0, shift);
    }
    final fix = argument._correction(t);
    if (fix.isNotEmpty) parts.insert(0, fix);
    noteAmount(parts, news, n);
    if (!understood && echo.isNotEmpty) {
      parts.add(_pick(Say.known));
      understood = true;
    }
    if (!understood) {
      final soc = talk.social(n, t);
      if (soc != null) return soc;
      final ask = picker.sideNote();
      // حرفی که موضوعش چیز دیگری است، وسط این پرونده به راهنمای همان موضوع
      // دیگر پرت نمی‌شود؛ جای آن، از کاربر توضیح می‌خواهیم و رشتهٔ پرونده
      // می‌مانَد (کاربر گفته «مربوط به همان ماجرا نیست/هست» را هم همین‌جا
      // جواب می‌دهیم).
      final foreign = Advocate.topicOf(raw);
      if (ask.isEmpty &&
          Sense.words(n) >= 3 &&
          (foreign == null || foreign == t.id)) {
        final lg = picker.matchGuide(raw, n);
        if (lg != null) {
          if (dialog.askText.isEmpty) return openGuide(lg, raw, n, switched: true);
          // وسطِ پرونده، حرفِ تازه را کوتاه جواب می‌دهم و رشتهٔ گفتگو را
          // نگه می‌دارم.
          return _out(
            advocateFormat('caseGuideSideNote', {
              'answer': _relevant(lg.answer, n),
            }),
            ask: advocateFormat('caseGuideReturnAsk', {'ask': dialog.askText}),
            chips: dialog.askChips,
            full: true,
          );
        }
      }
      if (ask.isEmpty && Sense.has(n, 'ماده [0-9]+|قانون ')) {
        final hit = _lookup(raw, n);
        if (hit != null) return hit;
      }
      file.pending = '';
      clearOffer();
      dialog.askText = '';
      dialog.askChips = const [];
      return _out(
        parts.join('\n\n'),
        ask: ask.isEmpty ? talk.unclearText(raw) : ask,
        chips: [
          if (ask.isNotEmpty) ...const [
            ChipTexts.newTopicChip,
            ChipTexts.sameCaseChip,
          ],
          ...chipPlan().suggest(t),
        ],
      );
    }
    if (parts.isEmpty) parts.add(_pick(Say.fine));
    // اگر حرف کاربر را در همین پرونده فهمیده‌ام، فقط برای پیام‌های بلند
    // می‌پرسم که آیا ماجرای جدایی هم هست؛ وگرنه مزاحم گفتگو می‌شود.
    final note = picker.sideNote();
    if (note.isNotEmpty && Sense.words(n) >= 5) {
      parts.add(note);
    } else {
      dialog.side = null;
      dialog.sideText = '';
    }
    return finish(t, parts);
  }

  AdvocateReply finish(Topic t, List<String> parts, {String lead = ''}) {
    var body = parts.join('\n\n');
    if (lead.isNotEmpty) body = body.isEmpty ? lead : '$lead\n\n$body';
    voice.said.addAll(parts);
    final a = nextAsk(t);
    dialog.askText = a.text;
    dialog.askChips = a.chips;
    final chips = <String>[...a.chips];
    if (a.text.isEmpty) {
      // دیگر پرسشی ندارم؛ در را باز می‌گذارم.
      if (parts.length <= 1 && body.length < 40) {
        body = advocateFormat('caseOpenQuestionTail', {'body': body});
      }
      chips.addAll(chipPlan().suggest(t));
    } else if (chips.isEmpty) {
      // با دادخواست و لایحه سه دکمه می‌شود: پرسش، دادخواست، لایحه.
      chips.addAll(chipPlan().suggest(t).take(filings().isEmpty ? 2 : 3));
    } else {
      // جوابِ پرسش جلوتر است؛ ولی دادخواست و لایحهٔ همین پرونده هم دمِ
      // دست می‌ماند.
      for (final g in filings()) {
        if (!chips.contains(g.chip)) chips.add(g.chip);
      }
    }
    if (dialog.side != null) {
      chips.insertAll(0, const [ChipTexts.newTopicChip, ChipTexts.sameCaseChip]);
    }
    final roomy = dialog.roomy;
    dialog.roomy = false;
    return _out(body,
        chips: chips, ask: a.text, budget: roomy ? _roomyBudget : _budget);
  }
}
