import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'package:dastyar/core/law_topic_prior.dart';
import 'package:dastyar/core/article_query.dart';
import 'package:dastyar/core/law_index.dart';
import 'package:dastyar/core/law_ranker.dart';
import 'package:dastyar/core/law_text.dart';
import 'package:dastyar/core/law_mention.dart';
import 'package:dastyar/core/models.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/qa_bank.dart';
import 'package:dastyar/core/replies.dart';
import 'package:dastyar/core/router.dart';
import 'package:dastyar/core/conflicts_service.dart';

export 'models.dart';

class KnowledgeEngine {
  /// پاسخ‌های ثابت؛ از assets/replies.json خوانده می‌شوند.
  final Replies replies = Replies();
  /// متنِ قوانین، نمایهٔ واژه‌ها، ایندکسِ مواد و شمارشِ هر قانون؛
  /// صاحبش `LawIndex` است تا موتور فقط بارگذاری و پاسخ‌سازی کند.
  final LawIndex _index = LawIndex();

  // زیر این پوشش، پاسخ با هشدار «مطمئن نیستم» نشان داده می‌شود.
  static const double _lowCover = 0.4;

  // پرسش‌های «X چیست / کیست / یعنی چه»: مادهٔ تعریف‌کننده باید جلو بیاید.

  // الگوهای ازپیش‌کامپایل‌شده برای جلوگیری از ساخت مکرر RegExp
  static final RegExp _punctOnlyRe = RegExp(r'[\p{P}]', unicode: true);
  static final RegExp _articleTitleRe = RegExp(
    r'^(?:ماده|اصل)\s*(?:واحده|\d+(?:\s*مکرر(?:\s*\d{1,2})?)?)$',
  );

  // پارامترهای BM25F: اشباع بسامد، نرمال‌سازی طول، و وزن عنوان / متن / زمینه.

  final List<CatalogLaw> catalog = [];
  final Map<String, String> categoryNames = {};
  final Map<String, Map<String, dynamic>> meta = {};
  /// شناسایی نام قانون در متن؛ جدا از ایندکس و رتبه‌بندی.
  late final LawMention _mention =
      LawMention(catalog: catalog, isLoaded: isLoaded);

  /// امتیازدهیِ BM25F و گسترشِ پیشوند؛ منطقش در `law_ranker.dart` است.
  late final LawRanker _ranker = LawRanker(
    index: _index,
    mention: _mention,
    isLoaded: isLoaded,
    topicFactors: (q) => _lawPrior.factors(q),
    expand: _expand,
    synonyms: _syn,
  );

  final ConflictsService _conflictsService = ConflictsService();
  Map<String, dynamic> _relationships = const {};

  static const List<String> _unloadedPenalTerms = [
    'سرقت', 'دزدی', 'کلاهبرداری', 'قتل', 'ضرب و جرح', 'خیانت در امانت',
    'توهین', 'افترا', 'جعل', 'رشوه', 'اختلاس', 'جرایم رایانه', 'هک',
  ];
  static const List<String> _penalContextMarkers = [
    'مجازات', 'دیه', 'قصاص', 'حدود', 'تعزیر', 'جرم',
  ];
  static const List<String> _loadedCriminalExceptions = [
    'چک', 'ورشکست', 'شرکت', 'سهام', 'برات', 'سفته', 'کارگر', 'کارفرما',
  ];
  static const List<(String, List<String>)> _anchorGroups = [
    ('طلاق', ['طلاق', 'خلع', 'مبارات', 'عده']),
    ('حضانت', ['حضانت', 'طفل']),
    ('مهریه', ['مهر', 'صداق', 'مهریه']),
    ('دیه', ['دیه']),
    ('سربازی', ['سربازی', 'وظیفه عمومی']),
    ('گمرک', ['گمرک', 'گمرکی', 'ترخیص']),
    ('گواهینامه', ['گواهینامه', 'رانندگی']),
    ('خلافی', ['خلافی', 'رانندگی']),
    ('ویزا', ['ویزا', 'روادید']),
    ('شنگن', ['شنگن', 'روادید']),
    ('پناهندگی', ['پناهندگی', 'پناهنده']),
  ];

  /// خطاهای بارگذاری فایل‌های کمکی؛ دیگر بی‌صدا نادیده گرفته نمی‌شوند.
  final List<String> warnings = [];

  int get size => _index.chunks.length;

  /// بخش‌های قوانین و فهرست وارونهٔ آن‌ها؛ برای تطبیق واژه‌ها (law_terms.dart).
  List<Chunk> get chunks => _index.chunks;
  Map<String, List<int>> get postings => _index.postings;
  Map<String, double> get idf => _index.idf;
  /// بانک پرسش‌وپاسخ حقوقی (اجاره)؛ پس از [load] پر می‌شود.
  QaBank get qa => _qaBank;
  /// فهرست واژه‌های حقوقی با ماده؛ پس از [load] پر می‌شود.
  Map<String, dynamic> get legalTerms => _legalTerms;
  /// مسیرهای تصمیم موضوعی (assets/brain/topics/index.json)؛ پس از [load] پر می‌شود.
  List<Map<String, dynamic>> get topicFlows => _topicFlows;
  Map<String, int> get lawCounts => _index.lawCounts;
  bool isLoaded(String id) => (_index.lawCounts[id] ?? 0) > 0;

  /// نوشتنِ متنِ ماده و فهرستِ قوانین؛ صاحبش [LawText] است.
  late final LawText _text = LawText(
    meta: meta,
    replies: replies,
    catalog: catalog,
    lawCountOf: (id) => _index.lawCounts[id] ?? 0,
  );

  /// متنِ آمادهٔ یک ماده، با منبع و تاریخ. پاس‌دهنده به [LawText].
  String format(Chunk c) => _text.format(c);

  /// رتبه‌بندیِ پرسش؛ پاس‌دهنده به [LawRanker].
  RankResult rank(String question, {int k = 3}) => _ranker.rank(question, k: k);

  /// چه کسری از وزن واژه‌های پرسش در این ماده پیدا می‌شود (۰ تا ۱).
  double coverage(String question, Chunk c) => _ranker.coverage(question, c);

  // لایهٔ متن به persian_text.dart رفته؛ اینجا فقط نام‌های قدیمی نگه داشته شده‌اند.
  static String normalize(String s) => PersianText.normalize(s);

  static String _collapse(String s) => PersianText.collapse(s);

  static List<String> tokenizeIndex(String s) => PersianText.tokenizeIndex(s);

  static List<String> tokenize(String s) => PersianText.tokenize(s);

Future<void> _loadCatalog() async {
  try {
    final t = await rootBundle.loadString('assets/laws_catalog.json');
    final m = jsonDecode(t) as Map<String, dynamic>;
    final cats = (m['categories'] ?? {}) as Map<String, dynamic>;
    cats.forEach((k, v) => categoryNames[k] = v.toString());
    for (final e in (m['laws'] ?? []) as List) {
      final l = e as Map<String, dynamic>;
      catalog.add(CatalogLaw(
        l['id'].toString(),
        l['title'].toString(),
        (l['category'] ?? '').toString(),
        (l['priority'] ?? 3) as int,
        ((l['aliases'] ?? []) as List).map((x) => x.toString()).toList(),
      ));
    }
  } catch (e) {
    warnings.add('laws_catalog.json: $e');
  }
}

Future<void> _loadMeta() async {
  try {
    final t = await rootBundle.loadString('assets/laws/_meta.json');
    final m = jsonDecode(t) as Map<String, dynamic>;
    m.forEach((k, v) {
      if (v is Map<String, dynamic>) meta[k] = v;
    });
  } catch (e) {
    warnings.add('_meta.json: $e');
  }
}

Future<void> _loadReplies() async {
  try {
    final t = await rootBundle.loadString('assets/replies.json');
    final m = jsonDecode(t) as Map<String, dynamic>;
    replies.setOverridesRaw(m);
  } catch (e) {
    warnings.add('replies.json: $e');
  }
}

LawTopicPrior _lawPrior = LawTopicPrior.empty;

QaBank _qaBank = QaBank.empty;

/// واژه‌ها و عبارت‌های حقوقی با ماده‌ای مشخص (assets/brain/legal_terms.json).
Map<String, dynamic> _legalTerms = const {};

/// مسیرهای تصمیم موضوعی، با ترتیب فهرست index.json.
List<Map<String, dynamic>> _topicFlows = const [];

Future<void> _loadTopicFlows() async {
  _topicFlows = const [];
  try {
    final idx = jsonDecode(await rootBundle.loadString('assets/brain/topics/index.json'))
        as Map<String, dynamic>;
    final out = <Map<String, dynamic>>[];
    for (final name in (idx['topics'] as List).cast<String>()) {
      final t = await rootBundle.loadString('assets/brain/topics/$name');
      out.add(jsonDecode(t) as Map<String, dynamic>);
    }
    _topicFlows = out;
  } catch (e) {
    warnings.add('brain/topics: $e');
  }
}

Future<void> _loadLegalTerms() async {
  _legalTerms = const {};
  try {
    final t = await rootBundle.loadString('assets/brain/legal_terms.json');
    _legalTerms = jsonDecode(t) as Map<String, dynamic>;
  } catch (e) {
    warnings.add('brain/legal_terms.json: $e');
  }
}

Future<void> _loadQa() async {
  _qaBank = QaBank.empty;
  try {
    final t = await rootBundle.loadString('assets/qa/lease_qa.json');
    _qaBank = QaBank.fromJson(jsonDecode(t));
  } catch (e) {
    warnings.add('qa/lease_qa.json: $e');
  }
}

Future<void> _loadLawTopics() async {
  _lawPrior = LawTopicPrior.empty;
  try {
    final t = await rootBundle.loadString('assets/brain/law_topics.json');
    _lawPrior = LawTopicPrior.fromJson(jsonDecode(t));
  } catch (e) {
    warnings.add('law_topics.json: $e');
  }
}

Future<void> _loadRelationships() async {
  try {
    final t = await rootBundle.loadString('assets/relationships.json');
    final m = jsonDecode(t);
    if (m is Map<String, dynamic>) {
      _relationships = m;
    }
  } catch (e) {
    warnings.add('relationships.json: $e');
  }
}

Future<List<String>?> _loadKnowledgeChunk() async {
  try {
    final text = await rootBundle.loadString('assets/knowledge.txt');
    return ['knowledge', 'دانش عمومی', text];
  } catch (e) {
    warnings.add('assets/knowledge.txt: $e');
    return null;
  }
}

Future<void> load() async {
  _index.clear();
  catalog.clear();
  categoryNames.clear();
  meta.clear();
  _relationships = const {};
  warnings.clear();

  final knowledgeFuture = _loadKnowledgeChunk();
  await Future.wait<void>([
    _loadCatalog(),
    _loadMeta(),
    _loadReplies(),
    _loadSynonyms(),
    _loadRelationships(),
    _loadLawTopics(),
    _loadQa(),
    _loadLegalTerms(),
    _loadTopicFlows(),
    knowledgeFuture,
  ]);

  final raw = <List<String>>[];
  final knowledgeRaw = await knowledgeFuture;
  if (knowledgeRaw != null) {
    raw.add(knowledgeRaw);
  }

  final entries = meta.entries.toList();
  final loadedLaws = await Future.wait<List<String>?>(
    entries.map((entry) async {
      final lawId = entry.key;
      final path = entry.value['path'];
      if (path is! String || path.isEmpty) return null;
      final fullPath = 'assets/laws/$path';
      try {
        final text = await rootBundle.loadString(fullPath);
        final fallbackTitle = (entry.value['title'] ?? '').toString().trim();
        return [lawId, fallbackTitle, text];
      } catch (e) {
        warnings.add('$fullPath: $e');
        return null;
      }
    }),
  );

  for (final item in loadedLaws) {
    if (item != null) raw.add(item);
  }

  IndexBuild built;
  try {
    built = await LawIndex.buildAsync(raw);
  } catch (_) {
    built = LawIndex.build(raw); // اگر Isolate شکست خورد، روی همین رشته
  }
  _index.adopt(built);
}

final List<List<String>> _syn = [];

static String _phrase(String s) => PersianText.phrase(s);

Future<void> _loadSynonyms() async {
  _syn.clear();
  try {
    final t = await rootBundle.loadString('assets/synonyms.txt');
    for (final line in t.split('\n')) {
      final l = line.trim();
      if (l.isEmpty || l.startsWith('#')) continue;
      final i = l.indexOf('|');
      if (i < 0) continue;
      final k = _phrase(l.substring(0, i));
      final v = l.substring(i + 1).trim();
      if (k.isNotEmpty && v.isNotEmpty) _syn.add([k, v]);
    }
  } catch (e) {
    warnings.add('synonyms.txt: $e');
  }
}

/// واژه‌های قانونیِ معادلِ عبارت‌های عامیانهٔ پرسش.
List<String> _expand(String question) {
  final n = ' ${_phrase(question)} ';
  final out = <String>[];
  for (final r in _syn) {
    if (n.contains(' ${r[0]} ')) out.addAll(tokenizeIndex(r[1]));
  }
  return out;
}

/// شمارهٔ chunk یک ماده از روی (شناسهٔ قانون، عنوان ماده)؛ یا `null`.
///
/// همتای O(1) پیمایش خطیِ `for (final c in engine.chunks)` که در تطبیق
/// واژه‌ها و برگ‌های مسیر موضوعی استفاده می‌شد. فهرست با اولین فراخوانی
/// ساخته و با هر بار `load()` دور انداخته می‌شود.
/// متن رسمی یک ماده را با نام قانون و شمارهٔ ماده پیدا می‌کند.
/// اگر در بستهٔ قوانین نباشد null برمی‌گرداند و هرگز متنی نمی‌سازد.
Chunk? findArticle(String law, String article) {
  final lawN = _collapse(normalize(law));
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
    final n = normalize(question);
    if (QueryRouter.asksCapabilities(n)) {
      return EngineReply(text: replies.get('capabilities'));
    }
    if (QueryRouter.asksOutcomePrediction(n)) {
      return EngineReply(text: replies.get('outcome_prediction'));
    }
    final art = ArticleQuery.re.firstMatch(n);
    final qTokens = tokenize(question);
    if (qTokens.every((t) => t.replaceAll(_punctOnlyRe, '').isEmpty) &&
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
    final ctx = top4.where((h) => h.score >= 0.3).toList();
    final alts = maxAlternatives > 0
        ? _alternativesFromRank(n, mentioned, r, max: maxAlternatives)
        : const <String>[];

    if (art != null &&
        loaded.isNotEmpty &&
        (top4.isEmpty || top4.first.score < 99)) {
      final kind = art.group(1) == 'اصل' ? 'اصل' : 'ماده';
      final num = ArticleQuery.label(art);
      return EngineReply(
        text:
            '$kind $num در متن «${loaded.first.title}» که در برنامه است پیدا نشد. ممکن است چنین مادهٔ معتبری نباشد یا متن برنامه ناقص باشد. شمارهٔ ماده را دوباره بررسی کنید.${missingNote.isEmpty ? '' : '\n\n$missingNote'}',
        alternatives: alts,
      );
    }

    if (top4.isEmpty || top4.first.score < 0.3) {
      return EngineReply(text: _text.notFound(), alternatives: alts);
    }

    // صریح‌بودنِ پرسش (درخواست مستقیم ماده) از مسیرِ انتخابِ زیر عبور می‌کند:
    final explicit = art != null && top4.first.score >= 99;

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
      if (bestCov < _lowCover) {
        return EngineReply(
          text: _text.notFound(),
          contextHits: ctx,
          alternatives: alts,
        );
      }
      // بدون برتریِ محسوس، رتبهٔ نخست پاسخ می‌دهد.
      if (bestCov < topCov + 0.25) bestHit = top4.first;
    }

    if (art == null && _hitsUnloadedDomain(n, mentioned, bestHit.chunk)) {
      return EngineReply(text: _text.notFound(), alternatives: alts);
    }

    final topChunk = bestHit.chunk;
    var res = format(topChunk);
    if (r.note.isNotEmpty) res += '\n\n${r.note}';
    if (top4.length > 1) {
      final b = top4[0].score;
      if (b < 99) {
        final others = top4
            .skip(1)
            .where((h) => h.score >= 0.3 && h.score >= b * 0.5 && h != bestHit)
            .take(2)
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
    final cn = _collapse(normQuestion);

    if (!isLoaded('penal')) {
      final hasMarker = _penalContextMarkers.any(cn.contains);
      final hasCrime = _unloadedPenalTerms.any(cn.contains);
      final hasLoadedExc = _loadedCriminalExceptions.any(cn.contains);
      if (hasMarker && hasCrime && !hasLoadedExc) return true;
    }

    if (!isLoaded('direct_taxes') && cn.contains('مالیات')) {
      if (cn.contains('مالیات بر درآمد') ||
          cn.contains('محاسبه مالیات') ||
          cn.contains('نرخ مالیات') ||
          cn.contains('معافیت مالیاتی') ||
          (!LawIndex.chunkHasTerm(top, 'مالیات') &&
              !top.normSource.contains('مالیات'))) {
        return true;
      }
    }

    if (!isLoaded('social_security') && cn.contains('تامین اجتماعی')) {
      if (cn.contains('حق بیمه') ||
          cn.contains('مستمری') ||
          cn.contains('بازنشستگی')) {
        return true;
      }
    }

    final qWords = ' ${_phrase(normQuestion)} ';
    for (final (trigger, requiredAny) in _anchorGroups) {
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
    final key = _collapse(m.group(2) ??
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
    if (top >= 99) return [];
    final out = <String>[];
    for (final h in r.hits.skip(1)) {
      if (h.score < 0.3 || h.score < top * 0.4) continue;
      final c = h.chunk;
      if (c.source.isEmpty) continue;
      if (!_articleTitleRe.hasMatch(c.normTitle)) continue;
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
    final n = normalize(question);
    if (ArticleQuery.re.hasMatch(n)) return [];
    if (_asksLawList(n)) return [];
    final mentioned = _mentionedLaws(question);
    if (mentioned.any((l) => !isLoaded(l.id))) return [];
    final r = _ranker.rankInternal(question, mentioned: mentioned, k: 12);
    return _alternativesFromRank(n, mentioned, r, max: max);
  }

}
