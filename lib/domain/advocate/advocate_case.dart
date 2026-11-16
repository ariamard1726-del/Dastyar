part of 'advocate.dart';

// روند پرونده: بازکردن، خواندن واقعیت‌ها، پرسش بعدی و جمع‌بندی.

/// نشانه‌های اینکه کاربر دارد حرف قبلی‌اش را صریحاً اصلاح می‌کند.
const String _amend =
    ' منظورم | اشتباه (?:گفتم|نوشتم|شد|فهمیدی|گرفتی) | در اصل | درستش | نه (?:اصلا )?(?:مشکل|موضوع|دعوا|حرف|مسئله)(?:م|مون| من| ما)? ';

/// آیا مقدارِ تازهٔ یک واقعیتِ محوری از مقدارِ فعلی مهم‌تر است؟
bool _outranks(Slot s, String now, String old) {
  final a = s.priority.indexOf(now);
  final b = s.priority.indexOf(old);
  return a >= 0 && (b < 0 || a < b);
}

/// آیا کاربر همین مقدار را صریح و از زبان خودش گفته است؟
bool _saidSure(Slot s, String n, String v) {
  final r = s.readSure;
  return r != null && r(n) == v;
}

String _join(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.first;
  return '${items.sublist(0, items.length - 1).join('، ')} و ${items.last}';
}

extension _CaseFlow on Advocate {
  void _closeCase() {
    file.clearCase();
    _lastServed = '';
    _flips.clear();
    _guide = null;
    _lastBody = '';
    _deferred = '';
    _arguedOn = '';
    _heard = '';
    _askText = '';
    _askChips = const [];
    _guideAsked = false;
    clearOffer();
  }

  /// واقعیت‌های تازهٔ پیام را در پرونده می‌نشاند و فهرست تغییرها را می‌دهد.
  ///
  /// [live] یعنی این همان پیامی است که کاربر الان فرستاده (نه مرور پیام‌های
  /// قبلی)؛ فقط در این حالت جوابِ کوتاه به پرسشِ معلق تفسیر می‌شود.
  List<Slot> _absorb(Topic t, String n, {bool live = true}) {
    final out = <Slot>[];
    if (live) {
      _echo.clear();
      _flips.clear();
    }
    final unsure = Sense.saysDontKnow(n);
    final hedged = unsure && Sense.has(n, ' یا نه |شاید|مطمئن نیستم');
    final reads = <String, String?>{for (final s in t.slots) s.id: s.read(n)};
    // «آره مدتش تموم شده»: بله‌ای که پشتش واقعیتِ بله/نه‌ایِ دیگری آمده،
    // جوابِ همان واقعیت است نه پرسشِ معلق.
    var otherBool = false;
    var otherAny = false;
    for (final e in reads.entries) {
      if (e.key == file.pending || e.value == null) continue;
      otherAny = true;
      if (e.value == 'yes' || e.value == 'no') otherBool = true;
    }
    for (final s in t.slots) {
      var v = reads[s.id];
      if (v != null && hedged && (v == 'yes' || v == 'no')) v = '?';
      if (live && v == null && s.id == file.pending) {
        final rp = s.readPending;
        final r = rp == null ? null : rp(n);
        if (r != null && !(otherBool && (r == 'yes' || r == 'no'))) v = r;
        if (v == null) {
          if (unsure) {
            if (!otherAny) v = '?';
          } else if (!otherBool) {
            if (Sense.saysYes(n) && s.yesValue.isNotEmpty) {
              v = s.yesValue;
            } else if (Sense.saysNo(n) && s.noValue.isNotEmpty) {
              v = s.noValue;
            }
          }
        }
      }
      if (v == null) continue;
      if (v == file.facts[s.id]) {
        if (live && v != '?') _echo.add(s);
        continue;
      }
      if (v == '?' && file.has(s.id)) continue;
      // محورِ پرونده با اشارهٔ گذرا به موضوعی دیگر عوض نمی‌شود.
      if (s.sticky &&
          v != '?' &&
          file.has(s.id) &&
          s.id != file.pending &&
          !_outranks(s, v, file.get(s.id)) &&
          !_saidSure(s, n, v) &&
          !(live && Sense.has(n, _amend))) {
        continue;
      }
      final old = file.facts[s.id];
      if (live &&
          old != null &&
          (old == 'yes' || old == 'no') &&
          (v == 'yes' || v == 'no')) {
        _flips[s.id] = old;
      }
      file.facts[s.id] = v;
      if (v != '?') out.add(s);
    }
    return out;
  }

  /// پاسخ به دکمهٔ یک سند: می‌گویم با همین پرونده چه چیزی در آن می‌نویسم و
  /// نوشتنش را پیشنهاد می‌کنم (در برنامه، لایهٔ بالاتر همین‌جا مستقیم
  /// پرسش‌های سند را شروع می‌کند).
  AdvocateReply _filing(Filing g) {
    final fill = fillFor(g.template);
    final sb = StringBuffer(
        '«${g.name}» را می‌شود با همین اطلاعاتی که داده‌اید نوشت؛ نام و نشانی دو طرف را هم موقع نوشتن می‌پرسم.');
    for (final k in const [
      'subject',
      'basis_detail',
      'ground_detail',
      'merits_defense',
      'statement_body',
    ]) {
      final v = fill[k];
      if (v != null && v.isNotEmpty) {
        sb.write('\nمتنی که برای شرح آن پیشنهاد می‌کنم: «$v»');
        break;
      }
    }
    final papers = fill['evidence'] ?? fill['attachments'] ?? '';
    if (papers.isNotEmpty) sb.write('\nپیوست‌ها: $papers.');
    const ask = 'همین حالا بنویسمش؟';
    const chips = ['بله، بنویس', 'نه، لازم نیست'];
    file.covered.add('o:draft');
    _askText = ask;
    _askChips = chips;
    final r = _out(sb.toString(), ask: ask, chips: chips, budget: _roomyBudget);
    _offer = 'draft';
    _offerDraft = g.template;
    return r;
  }

  bool _roleUnknown(Topic t) {
    for (final s in t.slots) {
      if (s.id == 'role') return !file.has('role');
    }
    return false;
  }

  AdvocateReply _open(Topic t, String n,
      {bool switched = false, bool guessed = false}) {
    final earlier = switched ? const <String>[] : List<String>.of(_loose);
    _loose.clear();
    _closeCase();
    file.topic = t.id;
    // حرف‌هایی که پیش از بازشدن پرونده زده شده هم جزو ماجراست.
    for (final old in earlier) {
      _absorb(t, old, live: false);
    }
    final news = _absorb(t, n);
    _heard = '${earlier.join(' ')} $n';
    if (Sense.has(_heard, _replySaid)) file.covered.add('q:reply');
    if (Sense.has(_heard, _goalSaid)) file.covered.add('q:goal');
    final parts = <String>[];
    // اول نشان می‌دهم حرف کاربر را چطور فهمیده‌ام؛ اگر اشتباه گرفته باشم
    // همان‌جا می‌تواند اصلاحم کند.
    final got = _recap(t);
    if (got.isNotEmpty) {
      parts.add('${_pick(Say.understood)} ${_join(got)}.');
    }
    final open = t.opening(file);
    final issue = _matchIssue(t, n);
    var answered = false;
    if (issue != null) {
      if (_roleUnknown(t)) {
        _deferred = issue.id;
      } else {
        // کاربر پرسش مشخصی دارد: اول جواب همان را می‌دهم، نه مقدمهٔ کلی.
        final b = issue.body(file);
        parts.add(b);
        file.covered.add(issue.id);
        _said.add(b);
        _lastBody = b;
        answered = true;
      }
    }
    if (!answered && open.isNotEmpty) parts.add(open);
    _addEffects(parts, news, 1,
        skip: _deferred.isEmpty && issue != null ? issue.covers : const {});
    _noteAmount(parts, news, n);
    if (_lastBody.isEmpty) {
      // «ساده‌تر بگو» باید سراغ حرف قانون برود، نه بازگویی ماجرا.
      if (open.isNotEmpty) {
        _lastBody = open;
      } else if (parts.isNotEmpty) {
        _lastBody = parts.first;
      }
    }
    var lead = '';
    if (guessed) {
      // پرونده با حدس باز شده؛ این را پنهان نمی‌کنم تا اگر غلط است بگوید.
      lead =
          'برداشتم این است که موضوع شما «${t.title}» است؛ اگر اشتباه گرفته‌ام بگویید.';
    } else if (switched) {
      lead = _pick(Say.switched);
    } else if (LawyerVoice.expressesDistress(n) ||
        Sense.has(n, 'کتک|میزنه| زد|اخراج|تهدید|بیچاره|بدبخت|نگران|میترسم|استرس')) {
      lead = _pick(Say.empathy);
    }
    final also = _also;
    _also = null;
    if (also != null && also.id != t.id) {
      parts.add(
          'به موضوع «${also.title}» هم اشاره کردید. آن پروندهٔ جدایی است؛ اول همین را روشن می‌کنیم و بعد، هر وقت گفتید، سراغ آن می‌رویم.');
    }
    return _finish(t, parts, lead: lead);
  }

  /// اثر حقوقیِ واقعیت‌های تازه را اضافه می‌کند؛ حرفی که قبلاً زده شده
  /// تکرار نمی‌شود.
  void _addEffects(List<String> parts, List<Slot> news, int max,
      {Set<String> skip = const {}}) {
    var added = 0;
    for (final s in news) {
      if (skip.contains(s.id)) continue;
      final fx = s.effect;
      if (fx == null) continue;
      final e = fx(file);
      if (e.isEmpty || parts.contains(e) || _said.contains(e)) continue;
      parts.add(e);
      _said.add(e);
      added++;
      if (added >= max) break;
    }
  }

  /// اگر مبلغ بدون واحد گفته شده («۳۰ تومن»)، برداشت خودم را شفاف می‌گویم.
  void _noteAmount(List<String> parts, List<Slot> news, String n) {
    if (Sense.amountIsExplicit(n)) return;
    for (final s in news) {
      if (s.id != 'amount' && s.id != 'salary') continue;
      final v = file.n(s.id);
      if (v == null) continue;
      parts.add(
          'رقم را «${Sense.toman(v)}» فهمیدم؛ اگر منظورتان چیز دیگری بود، با واحدش بنویسید (مثلاً «۳۰ میلیون» یا «۵۰۰ هزار»).');
      return;
    }
  }

  AdvocateReply _inCase(Topic t, String raw, String n, Issue? issue) {
    final wasPending = file.pending;
    final before = _standings(t);
    final news = _absorb(t, n);
    _heard = '$_heard $n';
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
    if (asked == null && _deferred.isNotEmpty && !_roleUnknown(t)) {
      for (final i in t.issues) {
        if (i.id != _deferred) continue;
        // حالا که نقش معلوم شده، بحثی که مالِ طرفِ دیگر است جواب داده
        // نمی‌شود.
        final w = i.when;
        if (w == null || w(file)) asked = i;
      }
      _deferred = '';
    }
    // اگر همین بحث قبلاً باز شده و کاربر حالا فقط یک واقعیت تازه می‌دهد
    // (نه پرسش)، کل توضیح تکرار نمی‌شود؛ فقط اثرِ همان واقعیت گفته می‌شود.
    final onlyFact = asked != null &&
        file.covered.contains(asked.id) &&
        !Sense.isQuestion(n) &&
        news.any((s) => s.effect != null && s.effect!(file).isNotEmpty);
    // «می‌توانم … بگیرم؟»: جوابِ پرسشِ بله/نه دربارهٔ یک خواسته، حکمِ همان
    // خواسته روی واقعیت‌های همین پرونده است، نه توضیح کلی.
    final focus = _askedClaim(t, n, asked);
    if (focus != null) {
      final b = _verdict(focus);
      parts.add(b);
      _roomy = true;
      _said.add(b);
      _lastBody = b;
      understood = true;
      reasoned = true;
    } else if (asked != null && !onlyFact) {
      final b = asked.body(file);
      parts.add(b);
      file.covered.add(asked.id);
      _said.add(b);
      _lastBody = b;
      understood = true;
    } else if (onlyFact) {
      understood = true;
    } else {
      final g = _glossary(n);
      if (g != null) {
        parts.add(g);
        understood = true;
      } else {
        final kind = Sense.followKind(n);
        // استدلالی که با همین واقعیت‌ها گفته شده برای «شانسم چقدر است؟»
        // تکرار نمی‌شود؛ با «استدلالت چیه؟» یا واقعیت تازه دوباره می‌آید.
        final stale = kind == 'chance' && _arguedOn == _factsKey();
        final arg =
            (kind == 'argue' || kind == 'chance') && !stale ? _argue(t) : null;
        final fb = kind.isEmpty
            ? null
            : (t.follow[kind == 'argue' ? 'chance' : kind] ?? _generic(kind));
        if (arg != null) {
          reasoned = true;
          parts.add(arg);
          _roomy = true;
          _arguedOn = _factsKey();
          file.covered.add('f:argue');
          file.covered.add('f:chance');
          _said.add(arg);
          _lastBody = arg;
          understood = true;
        } else if (fb != null) {
          final b = fb(file);
          parts.add(b);
          _roomy = kind == 'next';
          file.covered.add('f:$kind');
          _said.add(b);
          _lastBody = b;
          understood = true;
        }
      }
    }
    // جوابِ پرسشِ بازِ خودم (طرف چه گفته؟ دنبال چه هستید؟) را بی‌واکنش
    // نمی‌گذارم.
    if (wasPending.startsWith('q:') && parts.isEmpty) {
      if (news.isEmpty) {
        final soc = _social(n, t);
        if (soc != null) return soc;
      }
      parts.add(_react(heardGoal ? 'q:goal' : wasPending, n));
      understood = true;
    } else if (heardGoal && parts.isEmpty) {
      parts.add(_react('q:goal', n));
      understood = true;
    }
    _addEffects(parts, news, 2,
        skip: asked == null || onlyFact ? const {} : asked.covers);
    if (onlyFact && parts.isEmpty) {
      final b = asked.body(file);
      parts.add(b);
      _lastBody = b;
    }
    // حرف تازه اگر نتیجه را جابه‌جا کرده، همان‌جا می‌گویم؛ و اگر حرف قبلی
    // را برعکس کرده، می‌گویم که برداشتم را عوض کرده‌ام.
    if (!reasoned && news.isNotEmpty) {
      final shift = _shift(t, before);
      if (shift.isNotEmpty) parts.insert(0, shift);
    }
    final fix = _correction(t);
    if (fix.isNotEmpty) parts.insert(0, fix);
    _noteAmount(parts, news, n);
    if (!understood && _echo.isNotEmpty) {
      parts.add(_pick(Say.known));
      understood = true;
    }
    if (!understood) {
      final soc = _social(n, t);
      if (soc != null) return soc;
      final ask = _sideNote();
      if (ask.isEmpty && Sense.words(n) >= 3) {
        final lg = _matchGuide(raw, n);
        if (lg != null) {
          if (_askText.isEmpty) return _openGuide(lg, raw, n, switched: true);
          // وسطِ پرونده، حرفِ تازه را کوتاه جواب می‌دهم و رشتهٔ گفتگو را
          // نگه می‌دارم.
          return _out(
            '${_relevant(lg.answer, n)}\n\nاین می‌تواند پیگیری جداگانه‌ای داشته باشد؛ هر وقت خواستید سراغش می‌رویم.',
            ask: 'برگردیم سر پروندهٔ خودمان: $_askText',
            chips: _askChips,
            full: true,
          );
        }
      }
      if (ask.isEmpty && Sense.has(n, 'ماده [0-9]+|قانون ')) {
        return _lookup(raw, n);
      }
      file.pending = '';
      clearOffer();
      _askText = '';
      _askChips = const [];
      return _out(
        parts.join('\n\n'),
        ask: ask.isEmpty ? _pick(Say.lost) : ask,
        chips: [if (ask.isNotEmpty) Advocate.sideChip, ..._suggest(t)],
      );
    }
    if (parts.isEmpty) parts.add(_pick(Say.fine));
    // اگر حرف کاربر را در همین پرونده فهمیده‌ام، فقط برای پیام‌های بلند
    // می‌پرسم که آیا ماجرای جدایی هم هست؛ وگرنه مزاحم گفتگو می‌شود.
    final note = _sideNote();
    if (note.isNotEmpty && Sense.words(n) >= 5) {
      parts.add(note);
    } else {
      _side = null;
      _sideText = '';
    }
    return _finish(t, parts);
  }

  Body? _generic(String kind) {
    switch (kind) {
      case 'lawyer':
        return (f) => anyLawyer;
      case 'cost':
        return (f) => moneyCost;
      default:
        return null;
    }
  }

  /// پرسش بعدی: از میان پرسش‌هایی که هنوز جا دارند، آن‌که نتیجهٔ ادعاهای
  /// روی میز را زودتر روشن می‌کند. در موضوع‌هایی که شرط‌هایشان به پرسش‌ها
  /// گره نخورده، همان ترتیب موضوع است.
  Slot? _nextSlot(Topic t) {
    final askable = <Slot>[];
    for (final s in t.slots) {
      if (s.ask.isEmpty || file.touched(s.id)) continue;
      final w = s.when;
      if (w != null && !w(file)) continue;
      if ((file.askCount[s.id] ?? 0) >= 2) continue;
      askable.add(s);
    }
    return Reasoner.nextQuestion(t, file, askable);
  }

  /// اگر تکلیفِ همهٔ شرط‌های ادعای اصلی روشن شده باشد، وضع آن را می‌دهد؛
  /// هرچند هنوز پرسش‌های فرعی (مبلغ، خواسته‌های دیگر) مانده باشد. تا وقتی
  /// شرطی از آن نامعلوم است null می‌دهد، چون همان شرط می‌تواند توصیه را
  /// عوض کند.
  Standing? _leadSettled(Topic t) {
    final views = Reasoner.assess(t, file);
    if (views.isEmpty) return null;
    final lead = views.first;
    if (!lead.claim.elements.any((e) => e.needs.isNotEmpty)) return null;
    return lead.open.isEmpty ? lead.standing : null;
  }

  /// پرسش بعدیِ من در این پرونده. اول واقعیت‌هایی که تحلیل به آن‌ها بسته
  /// است؛ بعد کنجکاوی دربارهٔ برخورد طرف مقابل و خواستهٔ خودِ کاربر؛ و در
  /// آخر پیشنهادِ تحلیل، نقشهٔ راه و نوشتن متن — هر کدام به شکل یک پرسش، تا
  /// تصمیمش با کاربر باشد.
  _Ask _nextAsk(Topic t) {
    clearOffer();
    final q = _nextSlot(t);
    final settled = q == null ? null : _leadSettled(t);
    if (settled != null &&
        !file.covered.contains('f:argue') &&
        file.covered.add('o:argue')) {
      // وکیل منتظر تمام‌شدن همهٔ پرسش‌ها نمی‌ماند: همین که تکلیف ادعای اصلی
      // روشن شد، پیشنهاد می‌دهد نظرش را بگوید.
      file.pending = '';
      _offer = 'argue';
      return _Ask(
          settled == Standing.strong
              ? 'تا اینجا آن‌قدر می‌دانم که بگویم دست شما چقدر پر است؛ بگویم؟'
              : 'با همین‌ها می‌توانم بگویم گرهِ کار کجاست و چطور باز می‌شود؛ بگویم؟',
          _yesNo);
    }
    if (q != null) {
      final c = file.askCount[q.id] ?? 0;
      file.askCount[q.id] = c + 1;
      file.pending = q.id;
      // وقتی پرسش‌هایم از یک خواسته به خواستهٔ دیگر می‌رود، می‌گویم؛ تا
      // کاربر بداند هر پرسش برای چیست.
      final served = Reasoner.serves(t, file, q.id)?.label ?? '';
      var lead = '';
      if (served.isNotEmpty) {
        if (c == 0 && _lastServed.isNotEmpty && served != _lastServed) {
          lead = 'حالا دربارهٔ «$served»: ';
        }
        _lastServed = served;
      }
      return _Ask(
          c == 0 ? '$lead${q.ask}' : '${_pick(Say.askAgain)} ${q.ask}',
          q.options);
    }
    file.pending = '';
    if (_adversarial.contains(t.id) && file.covered.add('q:reply')) {
      // موضوع می‌تواند این پرسش را به زبانِ همان وضعیت بپرسد، یا بگوید
      // این‌جا جای پرسیدنش نیست.
      final ask = t.askReply;
      final own = ask == null ? null : ask(file);
      if (own == null) {
        file.pending = 'q:reply';
        return _Ask(_pick(Say.askReply), _replyChips);
      }
      if (own.text.isNotEmpty) {
        file.pending = 'q:reply';
        return _Ask(own.text, own.chips);
      }
    }
    if (file.covered.add('q:goal')) {
      file.pending = 'q:goal';
      return _Ask(_pick(Say.askGoal), _goalChips);
    }
    final claim = _claim(t);
    if (claim != null &&
        claim.elements.isNotEmpty &&
        !file.covered.contains('f:argue') &&
        file.covered.add('o:argue')) {
      _offer = 'argue';
      return const _Ask(
          'می‌خواهید بگویم از نظر قانون دست شما چقدر پر است؟', _yesNo);
    }
    if (t.follow['next'] != null &&
        !file.covered.contains('f:next') &&
        file.covered.add('o:next')) {
      _offer = 'next';
      return const _Ask('قدم‌های عملی را به ترتیب بگویم؟', _yesNo);
    }
    if (!file.covered.contains('o:draft')) {
      for (final id in draftIds) {
        final title = _draftTitles[id];
        if (title == null) continue;
        file.covered.add('o:draft');
        _offer = 'draft';
        _offerDraft = id;
        return _Ask('می‌خواهید «$title» را با همین اطلاعات برایتان بنویسم؟',
            const ['بله، بنویس', 'نه، لازم نیست']);
      }
    }
    return const _Ask('', []);
  }

  /// واکنش به جوابِ پرسش‌های باز.
  String _react(String id, String n) {
    if (id == 'q:reply') {
      if (Sense.has(n,
          'جواب ن|تلفن|بلاک|غیب|گم و گور|در دسترس|پیداش|خاموش|فرار|رفته')) {
        return 'پس عملاً در دسترس نیست. نگران این نباشید؛ ابلاغ رسمی برای همین وقت‌هاست و غیبت او جلوی کار شما را نمی‌گیرد.';
      }
      if (Sense.has(n,
          'انکار|قبول ن|زیر بار|حاشا|گردن ن|نمیدم|نمیده |نمیدهد|دروغ|منکر')) {
        return 'پس زیر بار نمی‌رود؛ یعنی با حرف حل نمی‌شود و همه‌چیز به مدرک شما برمی‌گردد.';
      }
      if (Sense.has(n,
          'امروز و فردا|امروز فردا|قول|میدم|میده |میدهد|صبر|وقت بده|مهلت|ندارم|نداره|دستم خالی|وضعم')) {
        return 'پس اصل حرف شما را رد نمی‌کند و فقط عقب می‌اندازد. این به نفع شماست: هر پیام یا قولی که داده نگه دارید، چون نشان می‌دهد خودش هم حق شما را قبول دارد.';
      }
      if (Sense.has(n, 'تهدید|فحش|فحاشی|دعوا|داد و بیداد|کتک|توهین')) {
        return 'این برخورد را جدی بگیرید و هر پیام یا صدایی که دارید نگه دارید؛ خودش می‌تواند موضوع شکایت جداگانه باشد.';
      }
      if (Sense.has(n,
          'هیچی|چیزی نگفت|حرف نزد|نگفتم|نگفته ام|هنوز ن|خبر نداره|نپرسیدم')) {
        return 'پس هنوز رسماً از او نخواسته‌اید. معمولاً قدم اول همین است که خواسته‌تان را طوری به او برسانید که بعداً قابل اثبات باشد.';
      }
      return 'خوب شد گفتید؛ این را کنار بقیهٔ ماجرا یادداشت کردم.';
    }
    if (Sense.has(n,
        'توافق|سازش|صلح|دوستانه|مسالمت|کنار بیا|زود|بی دردسر|آبرو|کدخدامنشی')) {
      return 'پس اول راهِ توافق را امتحان می‌کنیم: خواسته‌تان را رسمی ولی محترمانه اعلام می‌کنید و مهلت می‌دهید. اگر جواب نداد، مسیر قانونی سر جایش است.';
    }
    if (Sense.has(n,
        'قانونی|شکایت|دادگاه|تا آخر|تا اخر|تا ته|حقمو|حقم|کوتاه نمیام|محکوم')) {
      return 'پس مسیر رسمی را می‌رویم؛ از همین حالا باید مدرک‌ها را مرتب کنیم.';
    }
    return 'متوجه شدم؛ همین را هدف می‌گیرم.';
  }

  AdvocateReply _finish(Topic t, List<String> parts, {String lead = ''}) {
    var body = parts.join('\n\n');
    if (lead.isNotEmpty) body = body.isEmpty ? lead : '$lead\n\n$body';
    _said.addAll(parts);
    final a = _nextAsk(t);
    _askText = a.text;
    _askChips = a.chips;
    final chips = <String>[...a.chips];
    if (a.text.isEmpty) {
      // دیگر پرسشی ندارم؛ در را باز می‌گذارم.
      if (parts.length <= 1 && body.length < 40) {
        body =
            '$body هر وقت سؤال دیگری داشتید یا اتفاق تازه‌ای افتاد، همین‌جا بگویید.';
      }
      chips.addAll(_suggest(t));
    } else if (chips.isEmpty) {
      // با دادخواست و لایحه سه دکمه می‌شود: پرسش، دادخواست، لایحه.
      chips.addAll(_suggest(t).take(filings.isEmpty ? 2 : 3));
    } else {
      // جوابِ پرسش جلوتر است؛ ولی دادخواست و لایحهٔ همین پرونده هم دمِ
      // دست می‌ماند.
      for (final g in filings) {
        if (!chips.contains(g.chip)) chips.add(g.chip);
      }
    }
    if (_side != null) chips.insert(0, Advocate.sideChip);
    final roomy = _roomy;
    _roomy = false;
    return _out(body,
        chips: chips, ask: a.text, budget: roomy ? _roomyBudget : _budget);
  }

  /// برداشت وکیل از واقعیت‌هایی که تا اینجا شنیده است.
  List<String> _recap(Topic t) {
    final r = t.recap;
    if (r == null) return const [];
    return [
      for (final x in r(file))
        if (x.trim().isNotEmpty) x.trim(),
    ];
  }
}
