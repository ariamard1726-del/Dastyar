part of 'advocate.dart';

// واژه‌نامه، جست‌وجوی متن قانون و راهنماهای آماده.

extension _Guides on Advocate {
  /// واپسین راه: بانک پرسش‌وپاسخ و متن قوانین (در `LawAnswer`)؛ اگر آنجا
  /// جوابی نبود، تصمیمِ وکیل: «نمی‌فهمم»، موضوعِ درِ دروازه، یا پرسشِ کنجکاو.
  AdvocateReply _lookup(String raw, String n) {
    final hit = _lawAnswer.lookup(raw, n,
        hasCase: hasCase, loose: dialog.loose.length);
    if (hit != null) return hit;
    if (Sense.words(n) < 2 || !Sense.has(n, '[\u0600-\u06FF]{2}')) {
      return _unclearReply(raw);
    }
    // واژهٔ یک موضوع بدون شرطِ بازشدنش: پرسش، نه حکم.
    final gated = _metaReplyBot.gatedTopic(n);
    if (gated != null) return _metaReplyBot.gatedReply(gated);
    return _curious(raw, n);
  }

  String? _glossary(String n) {
    final cmp = Glossary.compare(n);
    if (cmp != null) return cmp;
    if (!Glossary.asksMeaning(n)) return null;
    final ts = Glossary.find(n);
    if (ts.isEmpty) return null;
    return ts.first.text;
  }

  AdvocateReply _openGuide(LegalGuide g, String raw, String n,
      {bool switched = false}) {
    _closeCase();
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
      final title = _draftTitles[id];
      if (title != null) {
        out.add(title);
        break;
      }
    }
    return out;
  }

  AdvocateReply? _guideFollow(LegalGuide g, String n) {
    final gl = _glossary(n);
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
    final soc = _social(n, null);
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

extension _LawTermsReply on Advocate {
  /// پاسخ بر پایهٔ تطبیق واژه‌ها با متن قوانین (نگاه کنید به [LawTerms]).
  AdvocateReply? _lawTermsReply(String raw, String n) {
    if (Sense.words(n) < 2 || _vague(n)) return null;
    // شماره‌ها، ماده‌های مشخص و آیین‌نامه‌ها پیش‌تر و با قاعدهٔ خودشان جواب
    // می‌گیرند؛ بانک پرسش‌وپاسخ هم اولویت دارد.
    if (Sense.has(n, '[0-9]|(?:ماده|اصل) ?(?:[0-9]|واحده)|آیین ?نامه|دستورالعمل|بخشنامه')) return null;
    if (engine.qa.match(raw) != null) return null;
    // جمله‌ای که هیچ نشانهٔ حقوقی ندارد (سلام، خوراک، جغرافیا) با متن قانون
    // سنجیده نمی‌شود، حتی اگر دو واژه‌اش در قانون باشد.
    if (!Sense.has(n, _legalHint)) return null;
    final tm = _terms.match(raw);
    final c = tm.chunk;
    if (tm.accepted && c != null) {
      final lawName = engine.meta[c.lawId]?['title']?.toString() ?? c.source;
      final words = tm.matched.map((w) => '«$w»').join('، ');
      final gap = tm.missing.isEmpty
          ? ''
          : ' واژهٔ ${tm.missing.map((w) => '«$w»').join('، ')} در این ماده نیست.';
      voice.rest = '';
      voice.offeredMore = false;
      return AdvocateReply(
        'در «$lawName» ${PersianText.toFaDigits(c.title)} واژه‌های $words با هم آمده‌اند.$gap\n\n${c.body}\n\n'
        'این ماده لزوماً حکم اصلی ماجرای شما نیست؛ اگر بگویید چه شده، می‌سنجم که به همین ماده مربوط است یا نه.',
        laws: [
          LawText(c.title, c.source, c.body, '',
              status: engine.meta[c.lawId]?['status']?.toString() ?? ''),
        ],
        source: AnswerSource.lawTerms,
      );
    }
    final unknown = tm.unknown;
    final known = [for (final w in tm.missing) if (!unknown.contains(w)) w, ...tm.matched];
    if (known.length < 2) return null;
    // لحن: این پاسخ یک گزارش داخلی نیست؛ کاربر باید بفهمد «چرا ماده‌ای
    // نگفتم» و چه چیزی کمکش می‌کند — نه اینکه فهرست واژه‌های ناشناس ببیند.
    final unknownText = unknown.isEmpty
        ? ''
        : 'واژه‌های ${unknown.map((w) => '«$w»').join('، ')} با همین ریخت در '
            'هیچ‌یک از قوانین من نیست (شاید با تعبیر دیگری آمده باشد). ';
    return _out(
      '$unknownText'
      'واژه‌های ${known.map((w) => '«$w»').join('، ')} در متن قوانین من هست، ولی '
      'ماده‌ای که همهٔ این‌ها را با هم داشته باشد پیدا نکردم؛ حدس نمی‌زنم و '
      'مادهٔ بی‌ربط هم نمی‌آورم.',
      ask: 'ماجرای شما دقیقاً چیست؟ چه کسی و چه کاری کرده است؟',
    );
  }
}

/// نشانه‌های حقوقیِ کلی؛ فقط برای تصمیم «این جمله حقوقی است؟» به کار می‌رود.
const String _legalHint =
    'بیع|رهن|شرط|خیار|عقد|غبن|فاحش|کارشناس|قولنامه|طرفین|مبلغ|مالک|مستاجر|موجر|دعوا|اتهام|قصاص|تخلف|جعل|توهین|افترا|تهدید|قانون|حق |حقوق|جرم|مجازات|دادگاه|دادسرا|شکایت|قرارداد|(?:^| )سند|ارث|دیه|مهریه|جریمه|وکالت|وکیل|وصیت|ملک|معامله|خسارت|بدهی|(?:^| )طلب|محکوم|حکم |(?:^| )رای |تعهد|ضامن|ضمانت|فسخ|مالکیت|توقیف|زندان|حبس|قاضی|کارفرما|کارگر|اخراج|اجاره|موجر|مستاجر|چک|طلاق|نفقه|حضانت|بیمه|ورشکست|شرکت|سهام|ثبت|طلبکار|بدهکار|سرقت|دزد|کلاهبردار|تصرف|همسایه|دیوار|ودیعه|بانک|اجرای|دادخواست|لایحه|اجرائیه|کیفری|مدنی';

extension _TopicFlowReply on Advocate {
  /// پاسخ مسیرهای تصمیم موضوعی زنده، فقط وقتی پرونده‌ای باز نیست. هر موضوع با
  /// دروازهٔ واژه‌هایش فعال می‌شود؛ اگر هیچ برگی جز `ask` نباشد، `null`.
  AdvocateReply? _topicReply(String raw, String n) {
    if (hasCase) return null;
    for (final flow in engine.topicFlows) {
      // فقط موضوع‌های «live» در گفتگو جواب می‌دهند؛ بقیه هنوز با پاسخ‌های قدیمی
      // (که آزمون‌های موجود روی آن‌ها قفل‌اند) تداخل پیدا می‌کنند.
      if (flow['live'] != true) continue;
      final leafId = TopicFlow.route(flow, raw);
      if (leafId == 'ask') continue;
      final r = _topicLeafReply(flow, leafId);
      if (r != null) return r;
    }
    return null;
  }

  AdvocateReply? _topicLeafReply(Map<String, dynamic> flow, String leafId) {
    final leaves = flow['leaves'];
    if (leaves is! Map) return null;
    final leaf = leaves[leafId];
    if (leaf is! Map) return null;
    final laws = <LawText>[];
    for (final a in (leaf['articles'] as List? ?? const []).cast<Map>()) {
      final lawId = a['law'].toString();
      final title = a['title'].toString();
      final at = engine.chunkOf(lawId, title);
      if (at == null) continue;
      final c = engine.chunks[at];
      laws.add(LawText(c.title, c.source, c.body, '',
          status: engine.meta[c.lawId]?['status']?.toString() ?? ''));
    }
    final refs = laws.map((l) => '«${l.title}»').join('، ');
    final text = '${leaf['title']}\n\n${leaf['text']}'
        '${refs.isEmpty ? '' : '\n\nمواد مستند: ${PersianText.toFaDigits(refs)}'}\n\n'
        '${flow['disclaimer'] ?? ''}';
    voice.rest = '';
    voice.offeredMore = false;
    return AdvocateReply(text, laws: laws, source: AnswerSource.topicFlow);
  }
}
