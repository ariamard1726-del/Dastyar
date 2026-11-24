part of 'advocate.dart';

// راهنمای آماده، واژه‌نامه و آخرین راه (بانک پرسش‌وپاسخ و متن قوانین).
//
// این‌ها آخرین چیزی بودند که از «راهنمای آماده» روی خودِ `Advocate` مانده
// بود. `GuideReply` همکارهایش را در سازنده می‌گیرد؛ تنها چیزی که به‌صورتِ
// تابع گرفته می‌شود، `closeCase` است، چون `CaseFlow` خودش برای دکمه‌های
// راهنما به همین کلاس نیاز دارد و اگر شیء را می‌گرفتیم، ساختِ هر دو به هم
// گره می‌خورد.

/// راهنما، واژه‌نامه و پاسخِ پرسش‌های پیرامونِ یک راهنما.
class GuideReply {
  GuideReply({
    required this.file,
    required this.dialog,
    required this.voice,
    required this.engine,
    required this.talk,
    required this.lawAnswer,
    required this.metaReplies,
    required this.draftTitles,
    required this.closeCase,
  });

  final CaseFile file;
  final DialogueState dialog;
  final ReplyVoice voice;
  final KnowledgeEngine engine;

  /// گفت‌وگوی انسانی: «منظورتان چیست؟»، پرسشِ کنجکاو، پاسخِ SOCIAL.
  final TalkReply talk;

  /// بانک پرسش‌وپاسخ و متن قوانین.
  final LawAnswer lawAnswer;

  /// پاسخ‌های «دربارهٔ برنامه» (موضوعِ درِ دروازه).
  final MetaReply metaReplies;

  /// عنوانِ سندهای آماده، برای دکمهٔ راهنما.
  final Map<String, String> draftTitles;

  /// بستنِ پرونده پیش از بازکردنِ راهنما؛ تابع، نه شیء (نگاه کنید به بالای فایل).
  final void Function() closeCase;

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

  String _pick(List<String> options) => voice.pick(options);

  /// واپسین راه: بانک پرسش‌وپاسخ و متن قوانین (در `LawAnswer`)؛ اگر آنجا
  /// جوابی نبود، تصمیمِ وکیل: «نمی‌فهمم»، موضوعِ درِ دروازه، یا پرسشِ کنجکاو.
  AdvocateReply lookup(String raw, String n) {
    final hit = lawAnswer.lookup(raw, n,
        hasCase: hasCase, loose: dialog.loose.length);
    if (hit != null) return hit;
    if (Sense.words(n) < 2 || !Sense.has(n, '[\u0600-\u06FF]{2}')) {
      return talk.unclearReply(raw);
    }
    // واژهٔ یک موضوع بدون شرطِ بازشدنش: پرسش، نه حکم.
    final gated = metaReplies.gatedTopic(n);
    if (gated != null) return metaReplies.gatedReply(gated);
    return talk.curious(raw, n);
  }

  String? glossary(String n) {
    final cmp = Glossary.compare(n);
    if (cmp != null) return cmp;
    if (!Glossary.asksMeaning(n)) return null;
    final ts = Glossary.find(n);
    if (ts.isEmpty) return null;
    return ts.first.text;
  }

  AdvocateReply openGuide(LegalGuide g, String raw, String n,
      {bool switched = false}) {
    closeCase();
    dialog.guide = g;
    final sb = StringBuffer();
    if (switched) {
      sb.write('این موضوعِ جداگانه‌ای است؛ پس آن را جدا بررسی می‌کنم.\n\n');
    } else if (g.empathy.isNotEmpty && LawyerVoice.expressesDistress(raw)) {
      sb.write('${g.empathy}\n\n');
    }
    sb.write(g.answer);
    sb.write(_guideSteps(g));
    if (g.cautions.isNotEmpty) {
      sb.write('\n\nحواستان باشد:');
      for (final c in g.cautions) {
        sb.write('\n• $c');
      }
    }
    final refs = [for (final r in g.refs) '[[${r.lawId}:${r.article}]]'];
    if (refs.isNotEmpty) sb.write('\n\nمستند این حرف‌ها ${refs.join(' ')} است.');
    voice.lastBody = g.answer;
    dialog.guideAsked = g.followUp.isNotEmpty;
    dialog.guideStepped = false;
    return _out(sb.toString(),
        chips: _guideChips(g),
        ask: g.followUp,
        source: AnswerSource.guide);
  }

  String _guideSteps(LegalGuide g) {
    if (g.steps.isEmpty) return '';
    final sb = StringBuffer('\n\nقدم‌هایی که پیشنهاد می‌کنم:');
    var i = 1;
    for (final s in g.steps) {
      sb.write('\n${Sense.fa(i)}) $s');
      i++;
    }
    return sb.toString();
  }

  List<String> _guideChips(LegalGuide g) {
    final out = <String>[if (g.steps.isNotEmpty) 'قدم بعدی چیست؟'];
    for (final id in g.templateIds) {
      final title = draftTitles[id];
      if (title != null) {
        out.add(title);
        break;
      }
    }
    return out;
  }

  AdvocateReply? follow(LegalGuide g, String n) {
    final gl = glossary(n);
    if (gl != null) {
      return _out(gl, chips: _guideChips(g), source: AnswerSource.glossary);
    }
    final kind = Sense.followKind(n);
    if (kind == 'next' && g.steps.isNotEmpty) {
      dialog.guideAsked = false;
      if (dialog.guideStepped) {
        dialog.guideStepped = false;
        return _out(
          'قدم‌ها همان‌هاست که گفتم. از اولی شروع کنید: ${g.steps.first}',
          ask: 'کجای کار گیر کرده‌اید یا نگران کدام قدم هستید؟',
          chips: _guideChips(g),
          source: AnswerSource.guide,
        );
      }
      dialog.guideStepped = true;
      return _out('برای «${g.title}»${_guideSteps(g).replaceFirst('\n\n', ' ')}',
          ask: 'کدام‌یک از این قدم‌ها را تا حالا برداشته‌اید؟',
          chips: _guideChips(g),
          budget: _roomyBudget,
          source: AnswerSource.guide);
    }
    if (kind == 'lawyer') {
      return _out(anyLawyer, chips: _guideChips(g), source: AnswerSource.guide);
    }
    final soc = talk.social(n, null);
    if (soc != null) return soc;
    if (kind.isNotEmpty || Sense.isQuestion(n)) {
      final r = engine.query('${g.title} $n');
      if (_isLawHit(r)) {
        return AdvocateReply(
          'دربارهٔ این بخش از «${g.title}» تحلیل آماده‌ای ندارم؛ نزدیک‌ترین متن قانونی که پیدا کردم این است:\n\n${r.text}',
          chips: _guideChips(g),
          laws: [
            for (final h in r.contextHits.where(_isLaw).take(2))
              LawText(h.chunk.title, h.chunk.source, h.chunk.body, '',
                  status: engine.meta[h.chunk.lawId]?['status']?.toString() ?? ''),
          ],
          source: AnswerSource.engine,
        );
      }
    }
    // جوابِ پرسشی که خودم آخرِ راهنما پرسیده بودم: حالا نوبت قدم‌هاست.
    if (dialog.guideAsked && g.steps.isNotEmpty && !Sense.isQuestion(n)) {
      dialog.guideAsked = false;
      dialog.guideStepped = true;
      return _out('${_pick(Say.fine)} با این حساب${_guideSteps(g).replaceFirst('\n\n', ' ')}',
          ask: 'کدام‌یک از این قدم‌ها را تا حالا برداشته‌اید؟',
          chips: _guideChips(g),
          source: AnswerSource.guide);
    }
    return null;
  }
}
