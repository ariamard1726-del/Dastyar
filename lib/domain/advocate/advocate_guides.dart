part of 'advocate.dart';

// واژه‌نامه، جست‌وجوی متن قانون و راهنماهای آماده.

extension _Guides on Advocate {
  String? _glossary(String n) {
    final cmp = Glossary.compare(n);
    if (cmp != null) return cmp;
    if (!Glossary.asksMeaning(n)) return null;
    final ts = Glossary.find(n);
    if (ts.isEmpty) return null;
    return ts.first.text;
  }

  /// واپسین راه: جست‌وجوی واژگانی (BM25) در متن قوانین؛ بدون مدل.
  /// پاسخ آمادهٔ بانک پرسش‌وپاسخ اجاره، همراه با استنادهای ماده‌ای.
  AdvocateReply _qaReply(QaItem qa) {
    final cites = [for (final r in qa.refs) engine.qa.citeLabel(r)]
        .where((c) => c.isNotEmpty)
        .join('، ');
    final src = cites.isEmpty ? '' : '\n\nمستند: $cites.';
    // متن همان موادی که پاسخ به آن‌ها استناد می‌کند، تا دکمهٔ «متن قانون» کار کند.
    final laws = <LawText>[];
    for (final r in qa.refs) {
      final cut = r.indexOf(':');
      if (cut <= 0 || cut == r.length - 1) continue;
      final law = r.substring(0, cut);
      final art = r.substring(cut + 1);
      final kind = law == 'constitution' ? 'اصل' : 'ماده';
      final c = engine.findArticle(law, '$kind $art');
      if (c == null) continue;
      laws.add(LawText('$kind ${Sense.fa(art)} ${c.source}', c.source, c.body, ''));
    }
    if (laws.isNotEmpty) _lastLaws = laws;
    // پرسش‌های هم‌موضوع، تا گفتگو از همان جا ادامه پیدا کند.
    final next = [for (final q in engine.qa.related(qa)) q.question];
    _rest = '';
    _offeredMore = false;
    return AdvocateReply(
      '${qa.answer}$src\n\n'
      'این پاسخ عمومی است. اگر بگویید ماجرای شما دقیقاً چیست، آن را با وضعیت خودتان تطبیق می‌دهم.',
      chips: [
        ...next,
        if (laws.isNotEmpty) Advocate.lawChip,
      ],
      laws: laws,
    );
  }

  AdvocateReply _lookup(String raw, String n) {
    // پرسش‌های آمادهٔ بانک (مثلاً اجاره) پیش از جست‌وجوی واژگانی پاسخ داده می‌شوند.
    final qa = engine.qa.match(raw);
    if (qa != null) return _qaReply(qa);
    final direct = Sense.has(n, '(?:ماده|اصل) [0-9]+');
    final legalish = direct ||
        Sense.has(n,
            'قانون|حق |حقوق|جرم|مجازات|دادگاه|دادسرا|شکایت|قرارداد|(?:^| )سند|ارث|دیه|مهریه|جریمه|وکالت|وصیت|ملک|معامله|خسارت|بدهی|(?:^| )طلب|محکوم|حکم |(?:^| )رای |تعهد|ضامن|ضمانت|فسخ|مالکیت|توقیف|زندان|حبس|قاضی|وکیل');
    if (legalish &&
        Sense.words(n) >= 2 &&
        (direct || Sense.isQuestion(n) || _loose.length >= 3)) {
      final r = engine.query(raw);
      if (_isLawHit(r)) {
        final laws = [
          for (final h in r.contextHits.where(_isLaw).take(2))
            LawText(h.chunk.title, h.chunk.source, h.chunk.body, ''),
        ];
        final lead = direct
            ? 'این متنِ همان ماده در بانک قوانین من است:'
            : 'تحلیل آماده‌ای برای این پرسش ندارم؛ نزدیک‌ترین متن قانونی که پیدا کردم این است:';
        _rest = '';
        _offeredMore = false;
        return AdvocateReply(
          '$lead\n\n${r.text}\n\n'
          'این به ماجرای خودتان مربوط است؟ اگر بگویید چه شده، متناسب با وضعیت شما می‌گویم.',
          laws: laws,
        );
      }
    }
    if (!legalish && Sense.isQuestion(n) && _party(n).isEmpty) {
      return _out(
        'این یکی از حوزهٔ کار من بیرون است؛ من فقط در مسائل حقوقی (اجاره، کار، چک و طلب، خانواده، شکایت و دفاع) می‌توانم کمک کنم.',
        ask: 'گرفتاری حقوقی‌ای هست که بخواهید درباره‌اش حرف بزنیم؟',
      );
    }
    if (Sense.words(n) < 2 || !Sense.has(n, '[\u0600-\u06FF]{2}')) {
      return _out(_unclearText(raw));
    }
    return _curious(raw, n);
  }

  AdvocateReply _openGuide(LegalGuide g, String raw, String n,
      {bool switched = false}) {
    _closeCase();
    _guide = g;
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
    _lastBody = g.answer;
    _guideAsked = g.followUp.isNotEmpty;
    _guideStepped = false;
    return _out(sb.toString(), chips: _guideChips(g), ask: g.followUp);
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
    if (gl != null) return _out(gl, chips: _guideChips(g));
    final kind = Sense.followKind(n);
    if (kind == 'next' && g.steps.isNotEmpty) {
      _guideAsked = false;
      if (_guideStepped) {
        _guideStepped = false;
        return _out(
          'قدم‌ها همان‌هاست که گفتم. از اولی شروع کنید: ${g.steps.first}',
          ask: 'کجای کار گیر کرده‌اید یا نگران کدام قدم هستید؟',
          chips: _guideChips(g),
        );
      }
      _guideStepped = true;
      return _out('برای «${g.title}»${_guideSteps(g).replaceFirst('\n\n', ' ')}',
          ask: 'کدام‌یک از این قدم‌ها را تا حالا برداشته‌اید؟',
          chips: _guideChips(g),
          budget: _roomyBudget);
    }
    if (kind == 'lawyer') return _out(anyLawyer, chips: _guideChips(g));
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
              LawText(h.chunk.title, h.chunk.source, h.chunk.body, ''),
          ],
        );
      }
    }
    // جوابِ پرسشی که خودم آخرِ راهنما پرسیده بودم: حالا نوبت قدم‌هاست.
    if (_guideAsked && g.steps.isNotEmpty && !Sense.isQuestion(n)) {
      _guideAsked = false;
      _guideStepped = true;
      return _out('${_pick(Say.fine)} با این حساب${_guideSteps(g).replaceFirst('\n\n', ' ')}',
          ask: 'کدام‌یک از این قدم‌ها را تا حالا برداشته‌اید؟',
          chips: _guideChips(g));
    }
    return null;
  }
}

/// منبع «دانش عمومی» دربارهٔ خودِ برنامه است، نه متن قانون؛ هرگز به‌عنوان
/// «نزدیک‌ترین متن قانونی» نشان داده نمی‌شود.
const String _generalSource = 'دانش عمومی';

bool _isLaw(Hit h) => h.chunk.source != _generalSource;

/// پاسخ موتور فقط وقتی متن قانونی دارد که بهترین نتیجه‌اش قانون باشد.
bool _isLawHit(EngineReply r) =>
    r.contextHits.isNotEmpty && _isLaw(r.contextHits.first);

