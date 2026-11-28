part of 'advocate.dart';

// دو شاخهٔ پرونده: «پرونده‌ای باز نیست» (از بازکردنِ موضوع تا پاسخِ
// واژه‌محور) و «پرونده باز است» (عوض‌کردنِ موضوع یا ادامهٔ همان پرونده).
//
// پرسشِ «این موضوع تازه است یا مربوط به قبلی؟» هم این‌جاست، چون بخشی از
// خارج‌شدن از پروندهٔ جاریست و پاسخِ خودش را می‌سازد.

extension _ReplyCaseFlow on Advocate {
  /// پرونده‌ای باز نیست: از بازکردنِ موضوعِ روشن تا پاسخِ واژه‌محور و پرسشِ
  /// کنجکاو. تنها ورودیِ محاسبه‌شده‌اش [read] است، پس دیگر با امتیاززدن و
  /// تصمیم‌گیریِ `_reply` قاطی نمی‌شود.
  AdvocateReply _noCaseReply(String raw, String n, TopicRead read, TopicGuess? guess) {
    final best = read.best;
    final bestScore = read.bestScore;
    final scores = read.scores;
    if (best != null && bestScore >= _topicOpenMin) {
      final others = <Topic>[
        for (final t in Advocate.topics)
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
          advocateFormat('caseMultiTopicPrompt', {'lines': lines.join('\n')}),
          chips: [for (final t in dialog.choices) t.title, ChipTexts.noneChip],
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
      for (final t in Advocate.topics) {
        final sc = _score(t, joined);
        if (sc > js) {
          jb = t;
          js = sc;
        }
      }
      if (jb != null && js >= _topicOpenMin && (scores[jb.id] ?? 0) >= 1) {
        dialog.loose.removeLast();
        return _open(jb, n);
      }
    }
    final g = _guides.glossary(n);
    if (g != null) {
      return _out(g,
          ask: dialog.guide == null ? advocateText('caseGlossaryAsk') : '',
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
            chips: r.chips,
            laws: r.laws,
            source: AnswerSource.intentNet,
            ask: r.ask);
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
    final dominant = bestScore >= _topicDominantMin && cur * 2 < bestScore;
    if (best != null && best.id != topic.id && (cur == 0 || dominant)) {
      // وسط یک پرونده، هر اشاره‌ای به موضوع دیگر به معنی ماجرای تازه
      // نیست (مثلاً «قولنامه داریم» در پروندهٔ اجاره). فقط وقتی می‌پرم که
      // خودِ کاربر موضوع را عوض کند یا نشانه قوی باشد؛ در حالت میانه می‌پرسم.
      final marker = Sense.has(n, _newMatter);
      final answers = _answers(topic, n);
      final long = Sense.words(n) >= 5;
      final need = marker ? _topicOpenMin : (topic.id == 'accused' ? 9 : _topicStrongMin);
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
    final curTitle = _current()?.title ?? advocateText('caseSwitchFallbackTitle');
    // پرسشِ خودِ پرونده کنار می‌رود تا در این نوبت فقط یک پرسش باشد و
    // «بله/خیر» دو معنا نداشته باشد.
    file.pending = '';
    dialog.askText = '';
    dialog.askChips = const [];
    return _out(
      advocateFormat('caseSwitchBody', {
        'curTitle': curTitle,
        'newTitle': t.title,
      }),
      ask: advocateText('caseSwitchAsk'),
      chips: const [ChipTexts.newTopicYesChip, ChipTexts.newTopicNoChip],
    );
  }
}
