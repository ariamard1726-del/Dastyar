part of 'advocate.dart';

// پاسخ از بانک پرسش‌وپاسخ و از متن قوانین — نخستین چیزی که وکیل برای پرسشِ
// حقوقی می‌آزماید و واپسین چیزی که پیش از «نمی‌فهمم» جواب می‌دهد.
//
// این تکه تا امروز متدهای `Advocate` بود (`_lookup` و `_qaReply`): برای آزمودنِ
// اینکه «پرسشِ سندِ عادی به پاسخِ اجاره می‌خورد یا نه» باید یک وکیلِ کامل با
// پرونده و صدا ساخته می‌شد. حالا `LawAnswer` فقط موتور، صدا و شناساییِ طرفِ
// گفتگو را می‌گیرد و وقتی جوابی ندارد `null` می‌دهد تا خودِ وکیل تصمیم بگیرد
// چه چیزی جایش بنشیند.

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

/// پاسخ از بانک پرسش‌وپاسخ یا از متن قوانین.
///
/// `null` یعنی «اینجا جوابی ندارم» — تصمیمِ بعدی (نمی‌فهمم، موضوعِ درِ
/// دروازه، پرسشِ کنجکاو) کارِ وکیل است.
class LawAnswer {
  LawAnswer({
    required this.engine,
    required this.voice,
    required this.party,
    this.prepared,
  });

  final KnowledgeEngine engine;
  final ReplyVoice voice;

  /// پاسخی که worker موتور برای همان متن از پیش ساخته است؛ نبودش یعنی مسیر
  /// همگام قدیمی (مثلاً در آزمونها یا وقتی isolate در دسترس نبود).
  final EngineReply? Function(String raw)? prepared;

  /// شناساییِ طرفِ گفتگو («موجر»، «کارگر») از متن.
  final String Function(String n) party;

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

  AdvocateReply? lookup(String raw, String n,
      {required bool hasCase, required int loose}) {
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
        advocateText('lawRuleUnavailable'),
        ask: advocateText('lawRuleUnavailableAsk'),
      );
    }
    if (legalish &&
        Sense.words(n) >= 2 &&
        (direct || Sense.isQuestion(n) || loose >= 3)) {
      final r = prepared?.call(raw) ?? engine.query(raw);
      // نزدیک‌ترینِ موتور گاهی فقط به‌خاطر یک شماره (مثلاً «۱۷») آمده است.
      // اگر هیچ واژهٔ معنادار پرسش در متنش نیست، آن را جواب ندانیم.
      if (_isLawHit(r) &&
          !direct &&
          !_sharesContent(n, r.contextHits.first.chunk.body)) {
        return _out(
          advocateText('lawNoDirectMatch'),
          ask: advocateText('lawNoDirectMatchAsk'),
        );
      }
      if (_isLawHit(r)) {
        final laws = [
          for (final h in r.contextHits.where(_isLaw).take(2))
            LawText(h.chunk.title, h.chunk.source, h.chunk.body, '',
                status: engine.meta[h.chunk.lawId]?['status']?.toString() ?? ''),
        ];
        final lead = direct
            ? advocateText('lawDirectLead')
            : advocateText('lawFallbackLead');
        voice.rest = '';
        voice.offeredMore = false;
        return AdvocateReply(
          '$lead\n\n${r.text}\n\n'
          // اگر ماجرای کاربر را از پیش می‌دانیم، پرسیدنِ «چه شده؟» یعنی
          // فراموش‌کردنِ حرف‌هایش؛ پس همان را به پروندهٔ باز وصل می‌کنیم.
          '${hasCase ? advocateText('lawInCaseTail') : advocateText('lawOutCaseTail')}',
          laws: laws,
          source: AnswerSource.engine,
        );
      }
    }
    if (!legalish && Sense.isQuestion(n) && _party(n).isEmpty) {
      return _out(
        advocateText('lawOutOfScope'),
        ask: advocateText('lawOutOfScopeAsk'),
      );
    }
    return null;
  }

  /// پاسخ آمادهٔ بانک پرسش‌وپاسخ اجاره، همراه با استنادهای ماده‌ای.
  AdvocateReply _qaReply(QaItem qa) {
    final cites = [for (final r in qa.refs) engine.qa.citeLabel(r)]
        .where((c) => c.isNotEmpty)
        .join('، ');
    final src = cites.isEmpty ? '' : advocateFormat('lawQaCite', {'cites': cites});
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
      laws.add(LawText('$kind ${Sense.fa(art)} ${c.source}', c.source, c.body, '',
          status: engine.meta[c.lawId]?['status']?.toString() ?? ''));
    }
    if (laws.isNotEmpty) voice.lastLaws = laws;
    // پرسش‌های هم‌موضوع، تا گفتگو از همان جا ادامه پیدا کند.
    final next = [for (final q in engine.qa.related(qa)) q.question];
    voice.rest = '';
    voice.offeredMore = false;
    return AdvocateReply(
      '${qa.answer}$src\n\n${advocateText('lawQaDisclaimer')}',
      chips: [
        ...next,
        if (laws.isNotEmpty) ChipTexts.lawChip,
      ],
      laws: laws,
      source: AnswerSource.qaBank,
    );
  }
}
