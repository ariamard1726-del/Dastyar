part of 'advocate.dart';

// گفت‌وگوی انسانی: خلاصه، احوال‌پرسی، سوگ، و «منظورتان چیست؟».
//
// این هفت متد پیش‌تر روی `Advocate` بودند و برای آزمودنِ «بعد از دو پیامِ
// نامفهوم، دکمه‌های شروع می‌آید یا نه؟» باید یک وکیلِ کامل ساخته می‌شد. حالا
// `TalkReply` فقط پرونده، وضعیتِ روی میز، صدا، طبقه‌بندِ نیت و دکمه‌های
// پیشنهادی را می‌گیرد؛ تصمیمِ «این پیام مالِ کدام مسیر است» همچنان کارِ وکیل است.

/// گفت‌وگوی انسانی، بی‌نیاز از خودِ وکیل.
class TalkReply {
  TalkReply({
    required this.file,
    required this.dialog,
    required this.voice,
    required this.intentNet,
    required this.chipPlan,
    int Function()? openMin,
  }) : _openMin = openMin ?? (() => topicOpenMin);

  final CaseFile file;
  final DialogueState dialog;
  final ReplyVoice voice;

  /// طبقه‌بندِ نیت (می‌تواند نباشد؛ اپ بدونِ مدل هم کار می‌کند).
  final IntentNet? intentNet;

  /// دکمه‌های پیشنهادی؛ سازنده‌اش هر بار از پروندهٔ جاری ساخته می‌شود.
  final ChipPlan Function() chipPlan;
  final int Function() _openMin;

  /// موضوعی که همین حالا باز است.
  Topic? get _currentTopic {
    for (final t in Advocate.topics) {
      if (t.id == file.topic) return t;
    }
    return null;
  }

  List<String> get _idleChips => chipPlan().idle(_currentTopic);

  List<String> get _starters => chipPlan().starters();

  List<String> _suggest(Topic t) => chipPlan().suggest(t);

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

  /// همدلی برای ناامیدی وقتی هیچ موضوعی باز نیست.
  AdvocateReply? hopeless(String n) {
    if (Sense.words(n) > 10 || !Sense.has(n, _hopelessPattern)) return null;
    return _out(
      advocateText('tpHopelessBody'),
      ask: advocateText('tpHopelessAsk'),
      chips: _idleChips,
    );
  }

  AdvocateReply summary(Topic? topic) {
    final g = dialog.guide;
    if (topic == null && g != null) {
      return _out(g.brief.isNotEmpty ? g.brief : _sentences(g.answer).take(2).join(' '),
          chips: const [ChipTexts.newCaseChip]);
    }
    if (topic == null) {
      return _out(
        advocateText('tpSummaryEmptyBody'),
        ask: advocateText('tpSummaryEmptyAsk'),
        chips: _idleChips,
      );
    }
    final sb = StringBuffer(advocateText('tpSummaryHeader'));
    final got = recapOf(topic, file);
    if (got.isNotEmpty) {
      sb.write(advocateFormat('tpSummaryStory', {'got': _join(got)}));
    }
    final open = _sentences(_strip(topic.opening(file)));
    if (open.isNotEmpty) {
      sb.write(advocateFormat('tpSummaryLaw', {'law': open.first}));
    }
    final plan = topic.follow['next'];
    if (plan != null) {
      final steps = [
        for (final l in _strip(plan(file)).split('\n'))
          if (RegExp('^[۰-۹]+[)]').hasMatch(l.trim())) _brief(l.trim()),
      ];
      if (steps.isNotEmpty) {
        sb.write(advocateText('tpSummaryTodo'));
        for (final s in steps.take(4)) {
          sb.write('   $s\n');
        }
      }
    }
    final q = CasePlan.nextSlot(topic, file);
    if (q != null) {
      sb.write(advocateFormat('tpSummaryMissing', {'ask': q.ask}));
    }
    return _out(sb.toString().trimRight(),
        chips: _suggest(topic), budget: _roomyBudget);
  }

  AdvocateReply? social(String n, Topic? topic) {
    final w = Sense.words(n);
    if (w > 7) return null;
    if (Sense.has(n, 'ممنون|مرسی|متشکر|سپاس|دستت درد نکنه|دمت گرم|لطف کردی|تشکر')) {
      return _out(
        topic == null
            ? advocateText('tpThanksIdle')
            : dialog.askText.isNotEmpty
                ? advocateText('tpThanksAsked')
                : advocateText('tpThanksCase'),
        chips: _idleChips,
      );
    }
    if (Sense.has(n, 'خداحافظ|خدانگهدار|خدا نگهدار|فعلا |بای ')) {
      return _out(advocateText('tpBye'));
    }
    if (Sense.has(n, '^ (?:سلام|درود|وقت بخیر|صبح بخیر|عصر بخیر|شب بخیر|خسته نباشی)')) {
      if (topic != null) {
        return _out(advocateText('tpGreetCase'),
            ask: dialog.askText, chips: dialog.askChips);
      }
      // پیش‌تر سلام چهار ماجرای آمادهٔ دیگران را پیشنهاد می‌داد؛ کاربر تازه
      // نمی‌دانست از کجا شروع کند. حالا اول شاخهٔ کار روشن می‌شود
      // (حقوقی/کیفری/اداری/نمی‌دانم) و راهِ انصراف هم روی دکمه‌ها هست.
      dialog.branchAsked = true;
      return _out(
        advocateText('tpGreetIdleBody'),
        ask: advocateText('tpGreetIdleAsk'),
        chips: ChipTexts.branchChips,
      );
    }
    if (Sense.has(n,
        'خوبی|خوبید|چطوری|چطورید|حالت چطوره|حالتون چطوره|حال ?و ?احوال|چه خبر|خوب هستی|خوبین')) {
      // چرخش: هر نوبت جملهٔ دیگری، تا گفتگو تکراری به نظر نرسد.
      final replies = advocateTextSeq('tpHowReply', 3);
      final asks = advocateTextSeq('tpHowAsk', 3);
      final i = file.turns > 0 ? file.turns - 1 : 0;
      if (topic == null) {
        // همان جهت‌دهیِ سلام: اول شاخهٔ کار، بعد ماجرا.
        dialog.branchAsked = true;
        return _out(replies[i % replies.length],
            ask: asks[i % asks.length], chips: ChipTexts.branchChips);
      }
      return _out(replies[i % replies.length],
          ask: dialog.askText, chips: dialog.askChips);
    }
    return null;
  }

  /// وقتی موضوع را نمی‌شناسم: به‌جای «متوجه نشدم»، نشان می‌دهم چه شنیده‌ام
  /// و مثل هر وکیلی دربارهٔ ماجرا می‌پرسم تا تصویر روشن شود.
  AdvocateReply curious(String raw, String n) {
    final all = dialog.loose.join(' ');
    final who = _party(all);
    var area = '';
    final net = intentNet;
    if (net != null && Sense.words(n) >= 3) {
      final top = net.classify(raw);
      if (top.score >= 0.5) area = _areas[top.label] ?? '';
    }
    final allN = Sense.norm(all);
    final known = who.isNotEmpty ||
        area.isNotEmpty ||
        Sense.has(allN, 'پول|خسارت|پس بد|برگرد|غرامت|هزینه|شکایت|مجازات|زندان|جرم');
    // نه طرفی شناخته شد، نه موضوعی، نه نکته‌ای: به‌جای حدس یا جملهٔ ثابت،
    // کلمه‌های خودِ کاربر را نقل می‌کنم و توضیح می‌خواهم.
    if (!known) return unclearReply(raw);
    final heard = who.isNotEmpty
        ? advocateFormat('tpCuriousParty', {'who': who})
        : advocateFormat('tpCuriousQuote', {'quote': _clip(raw)});
    final k = dialog.loose.length;
    if (k <= 1) {
      return _out(area.isEmpty ? heard : '$heard $area',
          ask: who.isNotEmpty
              ? advocateText('tpCuriousAskWho')
              : Sense.words(n) >= 4
                  ? advocateText('tpCuriousAskLong')
                  : advocateText('tpCuriousAskShort'));
    }
    if (k == 2) {
      return _out(area.isEmpty ? advocateText('tpCuriousStep2Body') : area,
          ask: advocateText('tpCuriousStep2Ask'));
    }
    // برای ماجرایی که تحلیل آماده ندارم، دست‌کم راهِ کلی را روراست می‌گویم.
    if (Sense.has(allN, 'پول|خسارت|پس بد|برگرد|غرامت|هزینه')) {
      return _out(
        advocateText('tpCuriousMoneyBody'),
        ask: advocateText('tpCuriousMoneyAsk'),
      );
    }
    if (Sense.has(allN, 'شکایت|مجازات|زندان|جرم')) {
      return _out(
        advocateText('tpCuriousCrimBody'),
        ask: advocateText('tpCuriousCrimAsk'),
      );
    }
    return unclearReply(raw);
  }

  /// آیا پیام به موضوعی نشانهٔ روشن (امتیاز ۳ به بالا) دارد؟ برای اینکه
  /// قاعده‌های عمومی (مثل «دعوای لفظی») ماجرای موضوع‌دار را ندزدند.
  bool anyTopicCue(String n) {
    final openMin = _openMin();
    for (final t in allTopics) {
      if (_score(t, n) >= openMin) return true;
    }
    return false;
  }

  /// پاسخ به پیامی که به هیچ نکته‌ای وصل نشد. نخست با نقل همان کلمه‌های
  /// کاربر می‌پرسد منظورش چیست؛ اگر بار دوم هم نامفهوم ماند، به‌جای بن‌بست
  /// («در پایگاه نیست») حوزهٔ کارش را می‌گوید و راه ادامه را نشان می‌دهد.
  ///
  /// پیش‌تر بار دوم، حرفِ *پیام قبلی* را نقل می‌کرد و می‌گفت جوابی ندارد؛
  /// هم به پیام تازه ربطی نداشت، هم دست کاربر را خالی می‌گذاشت.
  String unclearText(String raw) {
    if (dialog.unclearPhrase.isNotEmpty && dialog.unclearTurn == file.turns - 1) {
      dialog.unclearPhrase = '';
      dialog.unclearTurn = -10;
      return advocateText('tpUnclearRepeat');
    }
    dialog.unclearPhrase = _quoteWords(raw);
    dialog.unclearTurn = file.turns;
    return advocateFormat('tpUnclearFirst', {'phrase': dialog.unclearPhrase});
  }

  /// همان پاسخِ نامفهوم، ولی این بار با دکمه‌های شروع تا کاربر در بن‌بست
  /// نماند.
  AdvocateReply unclearReply(String raw, {List<String> chips = const []}) {
    final stuck = dialog.unclearPhrase.isNotEmpty && dialog.unclearTurn == file.turns - 1;
    final text = unclearText(raw);
    // پیامِ نامفهومِ کوتاه («سگم مرده»، «هوم») کاربر را همان‌جا گیر می‌اندازد؛
    // پس از بار اول هم راهِ خروج نشان داده می‌شود. برای جملهٔ بلندِ نامفهوم،
    // دکمه‌ها فقط بار دوم (وقتی «stuck» است) می‌آیند تا گفتگو شلوغ نشود.
    if (!stuck && Sense.words(Sense.norm(raw)) > 3) return _out(text);
    final out = <String>[...chips, ..._starters];
    if (out.isEmpty) out.addAll(_idleChips);
    if (out.isEmpty) return _out(text);
    return _out(
      text,
      ask: stuck
          ? advocateText('tpUnclearStuckAsk')
          : advocateText('tpUnclearChipsAsk'),
      chips: out,
    );
  }
}
