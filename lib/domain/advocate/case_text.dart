part of 'advocate.dart';

// متنِ پاسخ: پیشنهادِ تنظیمِ سند، اثرِ حقوقیِ واقعیت‌های تازه، پرسشِ بعدی،
// واکنش به پاسخ‌های کوتاه، و جملهٔ مقدمه.
//
// همهٔ این‌ها «چطور گفته شود» است، نه «چه تصمیمی گرفته شود»؛ جدا شدنشان
// یعنی عوض کردنِ یک جمله لازم نباشد کلِ روندِ پرونده را جابه‌جا کند.

extension _CaseText on CaseFlow {
  /// پاسخ به دکمهٔ یک سند: می‌گویم با همین پرونده چه چیزی در آن می‌نویسم و
  /// نوشتنش را پیشنهاد می‌کنم (در برنامه، لایهٔ بالاتر همین‌جا مستقیم
  /// پرسش‌های سند را شروع می‌کند).
  AdvocateReply filing(Filing g) {
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
    dialog.askText = ask;
    dialog.askChips = chips;
    final r = _out(sb.toString(), ask: ask, chips: chips, budget: _roomyBudget);
    dialog.offer = 'draft';
    dialog.offerDraft = g.template;
    return r;
  }

  /// اثر حقوقیِ واقعیت‌های تازه را اضافه می‌کند؛ حرفی که قبلاً زده شده
  /// تکرار نمی‌شود.
  void addEffects(List<String> parts, List<Slot> news, int max,
      {Set<String> skip = const {}}) {
    var added = 0;
    for (final s in news) {
      if (skip.contains(s.id)) continue;
      final fx = s.effect;
      if (fx == null) continue;
      final e = fx(file);
      if (e.isEmpty || parts.contains(e) || voice.said.contains(e)) continue;
      parts.add(e);
      voice.said.add(e);
      added++;
      if (added >= max) break;
    }
  }

  /// اگر مبلغ بدون واحد گفته شده («۳۰ تومن»)، برداشت خودم را شفاف می‌گویم.
  void noteAmount(List<String> parts, List<Slot> news, String n) {
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

  Body? generic(String kind) {
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
  /// پرسش بعدی؛ منطقش در `case_plan.dart` است تا بی‌نیاز از وکیل آزمون شود.
  /// اگر تکلیفِ همهٔ شرط‌های ادعای اصلی روشن شده باشد، وضع آن را می‌دهد؛
  /// هرچند هنوز پرسش‌های فرعی (مبلغ، خواسته‌های دیگر) مانده باشد. تا وقتی
  /// شرطی از آن نامعلوم است null می‌دهد، چون همان شرط می‌تواند توصیه را
  /// عوض کند.
  Standing? leadSettled(Topic t) {
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
  _Ask nextAsk(Topic t) {
    clearOffer();
    final q = CasePlan.nextSlot(t, file);
    final settled = q == null ? null : leadSettled(t);
    if (settled != null &&
        !file.covered.contains('f:argue') &&
        file.covered.add('o:argue')) {
      // وکیل منتظر تمام‌شدن همهٔ پرسش‌ها نمی‌ماند: همین که تکلیف ادعای اصلی
      // روشن شد، پیشنهاد می‌دهد نظرش را بگوید.
      file.pending = '';
      dialog.offer = 'argue';
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
        if (c == 0 && dialog.lastServed.isNotEmpty && served != dialog.lastServed) {
          lead = 'حالا دربارهٔ «$served»: ';
        }
        dialog.lastServed = served;
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
    final claim = argument._claim(t);
    if (claim != null &&
        claim.elements.isNotEmpty &&
        !file.covered.contains('f:argue') &&
        file.covered.add('o:argue')) {
      dialog.offer = 'argue';
      return const _Ask(
          'می‌خواهید بگویم از نظر قانون دست شما چقدر پر است؟', _yesNo);
    }
    if (t.follow['next'] != null &&
        !file.covered.contains('f:next') &&
        file.covered.add('o:next')) {
      dialog.offer = 'next';
      return const _Ask('قدم‌های عملی را به ترتیب بگویم؟', _yesNo);
    }
    if (!file.covered.contains('o:draft')) {
      for (final id in draftIds) {
        final title = draftTitles[id];
        if (title == null) continue;
        file.covered.add('o:draft');
        dialog.offer = 'draft';
        dialog.offerDraft = id;
        return _Ask('می‌خواهید «$title» را با همین اطلاعات برایتان بنویسم؟',
            const ['بله، بنویس', 'نه، لازم نیست']);
      }
    }
    return const _Ask('', []);
  }

  /// واکنش به جوابِ پرسش‌های باز.
  String react(String id, String n) {
    final unsure = Sense.words(n) <= 5 && Sense.saysDontKnow(n);
    if (id == 'q:reply') {
      if (unsure) {
        return 'اشکالی ندارد. اگر بعداً حرفی زد یا پیامی داد، نگهش دارید؛ به کار می‌آید.';
      }
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
      return 'خوب شد که گفته‌اید؛ این را کنار بقیهٔ ماجرا یادداشت کردم.';
    }
    if (unsure) {
      return 'اشکالی ندارد؛ لازم نیست همین حالا تصمیم بگیرید. هر دو راه را جلوی شما می‌گذارم: اول توافق، و اگر جواب نداد مسیر قانونی.';
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

}
