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
    if (qa != null && _qaFits(qa, n)) return _qaReply(qa);
    final direct = Sense.has(n, '(?:ماده|اصل) [0-9]+');
    final legalish = direct ||
        Sense.has(n,
            'قانون|حق |حقوق|جرم|مجازات|دادگاه|دادسرا|شکایت|قرارداد|(?:^| )سند|ارث|دیه|مهریه|جریمه|وکالت|وصیت|ملک|معامله|خسارت|بدهی|(?:^| )طلب|محکوم|حکم |(?:^| )رای |تعهد|ضامن|ضمانت|فسخ|مالکیت|توقیف|زندان|حبس|قاضی|وکیل');
    // بانک من فقط متن قوانین را دارد. اگر پرسش به آیین‌نامه یا دستورالعمل
    // اشاره کند، ماده‌ای با همان شماره از قانونی دیگر را جای آن نمی‌گذارم.
    if (direct && Sense.has(n, 'آیین ?نامه|دستورالعمل|بخشنامه')) {
      return _out(
        'در بانک قوانین من فقط متن قوانین است؛ آیین‌نامه و دستورالعمل در آن نیست، پس متن این ماده را با اطمینان نمی‌توانم بگویم.',
        ask: 'اگر منظورتان ماده‌ای از یک قانون است، نام همان قانون یا موضوعش را بگویید.',
      );
    }
    if (legalish &&
        Sense.words(n) >= 2 &&
        (direct || Sense.isQuestion(n) || _loose.length >= 3)) {
      final r = engine.query(raw);
      // نزدیک‌ترینِ موتور گاهی فقط به‌خاطر یک شماره (مثلاً «۱۷») آمده است.
      // اگر هیچ واژهٔ معنادار پرسش در متنش نیست، آن را جواب ندانیم.
      if (_isLawHit(r) &&
          !direct &&
          !_sharesContent(n, r.contextHits.first.chunk.body)) {
        return _out(
          'در بانک قوانین من متنی که مستقیم به این پرسش جواب دهد پیدا نکردم، پس ماده‌ی نامربوط نمی‌دهم.',
          ask: 'نام دقیق قانون یا شماره‌ی ماده‌ای که دنبالش هستید را بگویید.',
        );
      }
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


const Set<String> _genericLegal = {
  'قانون', 'ماده', 'مواد', 'مجازات', 'اسلامی', 'آیا', 'یکی', 'هست', 'چیست',
  'چیه', 'باید', 'میشه', 'میتونم', 'میتوانم', 'یا', 'این', 'آن', 'با', 'که',
  'برای', 'درباره', 'دربارهٔ', 'تفاوت', 'فرق', 'یکسان', 'همان',
};

/// آیا پرسش و متنِ قانون دست‌کم یک واژهٔ معنادار مشترک دارند؟ واژه‌های
/// کوتاه، عددها و واژه‌های عمومیِ قانونی کنار گذاشته می‌شوند.
bool _sharesContent(String n, String body) {
  final bn = Sense.norm(body);
  for (final w in Sense.norm(n).split(' ')) {
    if (w.length < 3 || _genericLegal.contains(w)) continue;
    if (RegExp(r'^[0-9۰-۹]+$').hasMatch(w)) continue;
    if (bn.contains(w)) return true;
  }
  return false;
}

/// پاسخ‌های بانک اجاره فقط برای پرسشی که واژهٔ اجاره‌ای دارد. بدون این
/// قید، پرسش دربارهٔ فروش دوباره‌ی ملک («سند عادی»، «سند رسمی») به
/// پاسخ اجاره می‌خورد.
bool _qaFits(QaItem qa, String n) {
  final rent = qa.refs.any((r) => r.startsWith('landlord_tenant:'));
  if (!rent) return true;
  return Sense.has(n,
      'اجاره|مستاجر|مستأجر|موجر|کرایه|ودیعه|تخلیه|سرقفلی|مغازه|منزل|خانه|واحد|مالک');
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
      _rest = '';
      _offeredMore = false;
      return AdvocateReply(
        'در «$lawName» ${PersianText.toFaDigits(c.title)} واژه‌های $words با هم آمده‌اند.$gap\n\n${c.body}\n\n'
        'این ماده لزوماً حکم اصلی ماجرای شما نیست؛ اگر بگویید چه شده، می‌سنجم که به همین ماده مربوط است یا نه.',
        laws: [LawText(c.title, c.source, c.body, '')],
      );
    }
    final unknown = tm.unknown;
    final known = [for (final w in tm.missing) if (!unknown.contains(w)) w, ...tm.matched];
    if (known.length < 2) return null;
    final unknownText = unknown.isEmpty
        ? ''
        : 'واژه‌های ${unknown.map((w) => '«$w»').join('، ')} در هیچ‌یک از قوانین من نیست. ';
    return _out(
      '$unknownText'
      'واژه‌های ${known.map((w) => '«$w»').join('، ')} در متن قوانین من هست، '
      'اما هیچ ماده‌ای همهٔ آن‌ها را با هم ندارد، پس ماده‌ای را به‌عنوان جواب نمی‌گذارم.',
      ask: 'ماجرای شما دقیقاً چیست؟ چه کسی و چه کاری کرده است؟',
    );
  }
}

/// نشانه‌های حقوقیِ کلی؛ فقط برای تصمیم «این جمله حقوقی است؟» به کار می‌رود.
const String _legalHint =
    'بیع|رهن|شرط|خیار|عقد|غبن|فاحش|کارشناس|قولنامه|طرفین|مبلغ|مالک|مستاجر|موجر|دعوا|اتهام|قصاص|تخلف|جعل|توهین|افترا|تهدید|قانون|حق |حقوق|جرم|مجازات|دادگاه|دادسرا|شکایت|قرارداد|(?:^| )سند|ارث|دیه|مهریه|جریمه|وکالت|وکیل|وصیت|ملک|معامله|خسارت|بدهی|(?:^| )طلب|محکوم|حکم |(?:^| )رای |تعهد|ضامن|ضمانت|فسخ|مالکیت|توقیف|زندان|حبس|قاضی|کارفرما|کارگر|اخراج|اجاره|موجر|مستاجر|چک|طلاق|نفقه|حضانت|بیمه|ورشکست|شرکت|سهام|ثبت|طلبکار|بدهکار|سرقت|دزد|کلاهبردار|تصرف|همسایه|دیوار|ودیعه|بانک|اجرای|دادخواست|لایحه|اجرائیه|کیفری|مدنی';

extension _TopicFlowReply on Advocate {
  /// پاسخ مسیرهای تصمیم موضوعی، فقط وقتی پرونده‌ای باز نیست. هر موضوع با
  /// دروازهٔ واژه‌هایش فعال می‌شود؛ اگر هیچ برگی جز `ask` نباشد، `null`.
  AdvocateReply? _topicReply(String raw, String n) {
    if (hasCase) return null;
    for (final flow in engine.topicFlows) {
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
      for (final c in engine.chunks) {
        if (c.lawId == lawId && c.title == title) {
          laws.add(LawText(c.title, c.source, c.body, ''));
          break;
        }
      }
    }
    final refs = laws.map((l) => '«${l.title}»').join('، ');
    final text = '${leaf['title']}\n\n${leaf['text']}'
        '${refs.isEmpty ? '' : '\n\nمواد مستند: ${PersianText.toFaDigits(refs)}'}\n\n'
        '${flow['disclaimer'] ?? ''}';
    _rest = '';
    _offeredMore = false;
    return AdvocateReply(text, laws: laws);
  }
}
