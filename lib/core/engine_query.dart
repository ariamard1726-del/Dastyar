part of 'engine.dart';

// پاسخ‌سازی: یافتنِ ماده با ارجاعِ صریح، رتبه‌بندیِ پرسش، پیشنهادهای نزدیک،
// و هشدارِ «این حوزه در دانشِ فعلی نیست».
//
// این‌جا هیچ دارایی‌ای خوانده نمی‌شود و هیچ حالتی نوشته نمی‌شود؛ فقط از
// ایندکسِ ساخته‌شده پاسخ ساخته می‌شود.

extension _EngineQuery on KnowledgeEngine {
/// شمارهٔ chunk یک ماده از روی (شناسهٔ قانون، عنوان ماده)؛ یا `null`.
///
/// همتای O(1) پیمایش خطیِ `for (final c in engine.chunks)` که در تطبیق
/// واژه‌ها و برگ‌های مسیر موضوعی استفاده می‌شد. فهرست با اولین فراخوانی
/// ساخته و با هر بار `load()` دور انداخته می‌شود.
/// متن رسمی یک ماده را با نام قانون و شمارهٔ ماده پیدا می‌کند.
/// اگر در بستهٔ قوانین نباشد null برمی‌گرداند و هرگز متنی نمی‌سازد.
Chunk? findArticle(String law, String article) {
  final lawN = KnowledgeEngine._collapse(KnowledgeEngine.normalize(law));
  final want = ArticleQuery.canonical(article);
  if (want.isEmpty || lawN.isEmpty) return null;
  var indices = _index.byTitle[want];
  if (indices == null && want.startsWith('ماده ')) {
    indices = _index.byTitle['اصل ${want.substring(5)}'];
  }
  if (indices == null) return null;
  final mentionedIds = _mentionedLaws(law).map((l) => l.id).toSet();
  for (final idx in indices) {
    final c = _index.chunks[idx];
    if (c.lawId == lawN || mentionedIds.contains(c.lawId)) return c;
    final s = c.normSource;
    if (s.isEmpty) continue;
    if (s == lawN || s.contains(lawN) || lawN.contains(s)) return c;
  }
  return null;
}

/// شمارهٔ بخشِ یک ماده از روی (شناسهٔ قانون، عنوان ماده)؛ یا `null`.
///
/// همتای O(1)ِ پیمایشِ خطیِ `for (final c in engine.chunks)` که در تطبیقِ
/// واژه‌ها و برگ‌های مسیرِ موضوعی استفاده می‌شد.
int? chunkOf(String lawId, String title) => _index.chunkOf(lawId, title);

/// نام‌های قانون در متن: کارش به [LawMention] سپرده شده است.
List<CatalogLaw> _mentionedLaws(String q) => _mention.mentioned(q);

List<CatalogLaw> _loadedLaws() => _mention.loaded();

bool _asksLawList(String n) => _mention.asksLawList(n);

/// چه کسری از وزن واژه‌های پرسش در این ماده (یا با کمک مترادف‌ها) پیدا می‌شود.
/// عددی بین ۰ و ۱؛ هرچه کمتر، احتمال بی‌ربط‌بودن ماده بیشتر است.
/// گسترش پیشوند در زمان O(log V + |t| + matches) به‌جای پیمایش خطی کل واژگان.
  /// پردازش یکپارچهٔ پرسش با یک‌بار اجرای رتبه‌بندی (پاسخ نهایی + زمینهٔ LLM + پیشنهادهای نزدیک).
  EngineReply query(String question, {int maxAlternatives = 3}) {
    final n = KnowledgeEngine.normalize(question);
    if (QueryRouter.asksCapabilities(n)) {
      return EngineReply(text: replies.get('capabilities'));
    }
    if (QueryRouter.asksOutcomePrediction(n)) {
      return EngineReply(text: replies.get('outcome_prediction'));
    }
    final art = ArticleQuery.re.firstMatch(n);
    final qTokens = KnowledgeEngine.tokenize(question);
    if (qTokens.every((t) => t.replaceAll(KnowledgeEngine._punctOnlyRe, '').isEmpty) &&
        art == null) {
      final txt =
          n.contains('سلام') ? replies.get('greeting') : replies.get('ask_more');
      return EngineReply(text: txt);
    }
    if (_index.chunks.isEmpty) {
      return EngineReply(text: replies.get('no_knowledge'));
    }

    if (_asksLawList(n)) {
      return EngineReply(text: _text.lawList());
    }

    final mentioned = _mentionedLaws(question);
    final missing = mentioned.where((l) => !isLoaded(l.id)).toList();
    final loaded = mentioned.where((l) => isLoaded(l.id)).toList();
    final missingNote = missing.isEmpty
        ? ''
        : replies.get('missing_law', {'law': missing.first.title});

    if (loaded.isEmpty && missing.isNotEmpty) {
      return EngineReply(
        text:
            '$missingNote برای همین نمی‌توانم از روی آن جواب بدهم. می‌توانید از منبع رسمی قوانین، دفتر خدمات قضایی یا یک کارشناس حقوقی بپرسید.',
      );
    }

    // شمارهٔ ماده با «قانون» ولی نام قانونی که نمی‌شناسیم
    if (art != null && mentioned.isEmpty && n.contains('قانون')) {
      final names = _loadedLaws().map((l) => l.title).join('، ');
      return EngineReply(
        text:
            'نام این قانون را در فهرست خودم پیدا نکردم یا متنش در برنامه نیست.${names.isEmpty ? '' : ' قوانین موجود: $names.'} نام کامل قانون را بنویسید، مثلاً «ماده ۱۰ قانون مدنی».',
      );
    }

    final rankK = maxAlternatives > 0 ? math.max(12, maxAlternatives * 4) : 4;
    final r = _ranker.rankInternal(question, mentioned: mentioned, k: rankK);
    final top4 = r.hits.take(4).toList();
    final ctx = top4.where((h) => h.score >= EngineRules.minHitScore).toList();
    final alts = maxAlternatives > 0
        ? _alternativesFromRank(n, mentioned, r, max: maxAlternatives)
        : const <String>[];

    if (art != null &&
        loaded.isNotEmpty &&
        (top4.isEmpty || top4.first.score < EngineRules.explicitScore)) {
      final kind = art.group(1) == 'اصل' ? 'اصل' : 'ماده';
      final num = ArticleQuery.label(art);
      return EngineReply(
        text:
            '$kind $num در متن «${loaded.first.title}» که در برنامه است پیدا نشد. ممکن است چنین مادهٔ معتبری نباشد یا متن برنامه ناقص باشد. شمارهٔ ماده را دوباره بررسی کنید.${missingNote.isEmpty ? '' : '\n\n$missingNote'}',
        alternatives: alts,
      );
    }

    if (top4.isEmpty || top4.first.score < EngineRules.minHitScore) {
      return EngineReply(text: _text.notFound(), alternatives: alts);
    }

    // صریح‌بودنِ پرسش (درخواست مستقیم ماده) از مسیرِ انتخابِ زیر عبور می‌کند:
    final explicit = art != null && top4.first.score >= EngineRules.explicitScore;

    // انتخاب مادهٔ پاسخ: رتبهٔ نخستِ BM25F مبناست؛ اما گاهی مادهٔ هم‌جنسِ
    // نادرست (مثلاً نفقهٔ عقد موقت در برابر دائم) رتبهٔ نخست می‌گیرد. اگر
    // مادهٔ دیگری از برترین‌ها پوششِ پرسش را به‌مراتب (حاشیهٔ ۰٫۲۵) بهتر
    // بدهد، همان پاسخ می‌دهد. اگر هیچ ماده‌ای به آستانهٔ پوشش نرسد، صادقانه
    // «پیدا نکردم» گفته می‌شود.
    final topCov = explicit ? 1.0 : _ranker.coverage(question, top4.first.chunk);
    var bestCov = topCov;
    Hit bestHit = top4.first;
    if (!explicit) {
      for (final h in top4.skip(1)) {
        final c = _ranker.coverage(question, h.chunk);
        if (c > bestCov) {
          bestCov = c;
          bestHit = h;
        }
      }
      // بدون برتریِ محسوس، رتبهٔ نخست پاسخ می‌دهد و کفِ پوشش روی همان مادهٔ انتخاب‌شده سنجیده می‌شود.
      final keepFirst = bestCov < topCov + EngineRules.coverageMargin;
      if (keepFirst) bestHit = top4.first;
      final chosenCov = keepFirst ? topCov : bestCov;
      if (chosenCov < KnowledgeEngine._lowCover) {
        return EngineReply(
          text: _text.notFound(),
          contextHits: ctx,
          alternatives: alts,
        );
      }
    }

    if (art == null && _hitsUnloadedDomain(n, mentioned, bestHit.chunk)) {
      return EngineReply(text: _text.notFound(), alternatives: alts);
    }

    final topChunk = bestHit.chunk;
    var res = format(topChunk);
    if (r.note.isNotEmpty) res += '\n\n${r.note}';
    if (top4.length > 1) {
      final b = top4[0].score;
      if (b < EngineRules.explicitScore) {
        final others = top4
            .skip(1)
            .where((h) =>
                h.score >= EngineRules.minHitScore &&
                h.score >= b * EngineRules.nearAlternativeFactor &&
                h != bestHit)
            .take(EngineRules.maxNearAlternatives)
            .toList();
        if (others.isNotEmpty) {
          res += '\n\nمواد نزدیک دیگر:';
          for (final h in others) {
            res +=
                '\n• ${PersianText.toFaDigits(h.chunk.title)} — ${h.chunk.source}';
          }
        }
      }
    }
    if (missingNote.isNotEmpty) res += '\n\n$missingNote';

    return EngineReply(
      text: res,
      answered: true,
      contextHits: ctx,
      alternatives: alts,
      conflictChains: conflictChainsFor(topChunk),
    );
  }

  /// تشخیص عمومی پرسش‌هایی که موضوع اصلی آن‌ها متعلق به قوانین واردنشده است
  /// یا با مادهٔ بازیابی‌شده صرفاً اشتراک واژه‌های عمومی دارند.
  bool _hitsUnloadedDomain(
    String normQuestion,
    List<CatalogLaw> mentioned,
    Chunk top,
  ) {
    if (mentioned.isNotEmpty) return false;
    final cn = KnowledgeEngine._collapse(normQuestion);

    if (!isLoaded('penal')) {
      final hasMarker = EngineRules.penalContextMarkers.any(cn.contains);
      final hasCrime = EngineRules.unloadedPenalTerms.any(cn.contains);
      final hasLoadedExc = EngineRules.loadedCriminalExceptions.any(cn.contains);
      if (hasMarker && hasCrime && !hasLoadedExc) return true;
    }

    if (!isLoaded('direct_taxes') && cn.contains('مالیات')) {
      if (EngineRules.taxTriggers.any(cn.contains) ||
          (!LawIndex.chunkHasTerm(top, 'مالیات') &&
              !top.normSource.contains('مالیات'))) {
        return true;
      }
    }

    if (!isLoaded('social_security') && cn.contains('تامین اجتماعی')) {
      if (EngineRules.socialSecurityTriggers.any(cn.contains)) {
        return true;
      }
    }

    final qWords = ' ${KnowledgeEngine._phrase(normQuestion)} ';
    for (final (trigger, requiredAny) in EngineRules.anchorGroups) {
      if (qWords.contains(' $trigger ')) {
        if (!requiredAny.any((r) => LawIndex.chunkHasTerm(top, r))) {
          return true;
        }
      }
    }

    return false;
  }

  /// استخراج زنجیره‌های تعارض یا ارجاع متقابل ثبت‌شده برای یک ماده در relationships.json.
  List<String> conflictChainsFor(Chunk c) {
    final articles = _relationships['articles'];
    if (articles is! Map<String, dynamic> || articles.isEmpty) return const [];
    final m = ArticleQuery.re.firstMatch(c.normTitle);
    if (m == null) return const [];
    final key = KnowledgeEngine._collapse(m.group(2) ??
        '${m.group(3) ?? ''}${m.group(4) != null ? (m.group(5) != null ? ' مکرر ${m.group(5)}' : ' مکرر') : ''}');
    if (key.isEmpty) return const [];

    final scopedKey = '${c.lawId}:$key';
    String? lookupKey;
    if (articles.containsKey(scopedKey)) {
      lookupKey = scopedKey;
    } else if (articles.containsKey(key)) {
      final node = articles[key];
      final nodeLaw = node is Map<String, dynamic> ? node['law'] : null;
      if (nodeLaw == null || nodeLaw.toString() == c.lawId) {
        lookupKey = key;
      }
    }
    if (lookupKey == null) return const [];

    return _conflictsService
        .getConflictsChain(lookupKey, _relationships)
        .where((chain) => chain.contains('->'))
        .map(PersianText.toFaDigits)
        .toList();
  }

  String answer(String question) => query(question, maxAlternatives: 0).text;

  List<String> _alternativesFromRank(
    String normQuestion,
    List<CatalogLaw> mentioned,
    RankResult r, {
    int max = 3,
  }) {
    if (ArticleQuery.re.hasMatch(normQuestion)) return [];
    if (_asksLawList(normQuestion)) return [];
    if (mentioned.any((l) => !isLoaded(l.id))) return [];
    if (r.hits.length < 2) return [];
    final top = r.hits.first.score;
    if (top >= EngineRules.explicitScore) return [];
    final out = <String>[];
    for (final h in r.hits.skip(1)) {
      if (h.score < EngineRules.minHitScore ||
          h.score < top * EngineRules.altMinScoreRatio) {
        continue;
      }
      final c = h.chunk;
      if (c.source.isEmpty) continue;
      if (!KnowledgeEngine._articleTitleRe.hasMatch(c.normTitle)) continue;
      if (!_mentionedLaws(c.source).any((l) => l.id == c.lawId)) continue;
      out.add(PersianText.toFaDigits('${c.title} ${c.source}'));
      if (out.length >= max) break;
    }
    return out;
  }

  /// پیشنهاد مواد نزدیک برای دکمه‌های گفتگو.
  /// هر پیشنهاد به شکل «ماده ۲۰۲ قانون مدنی» است و اگر کاربر آن را بزند،
  /// همان ماده دقیقاً پیدا می‌شود. در موارد نامطمئن فهرست خالی است.
  List<String> alternatives(String question, {int max = 3}) {
    final n = KnowledgeEngine.normalize(question);
    if (ArticleQuery.re.hasMatch(n)) return [];
    if (_asksLawList(n)) return [];
    final mentioned = _mentionedLaws(question);
    if (mentioned.any((l) => !isLoaded(l.id))) return [];
    final r = _ranker.rankInternal(question, mentioned: mentioned, k: 12);
    return _alternativesFromRank(n, mentioned, r, max: max);
  }

}
