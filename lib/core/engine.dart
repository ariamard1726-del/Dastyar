import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'package:dastyar/core/config.dart';
import 'package:dastyar/core/models.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/replies.dart';
import 'package:dastyar/core/router.dart';
import 'package:dastyar/core/conflicts_service.dart';
import 'package:dastyar/domain/dialogue/evidence.dart';

export 'models.dart';

class KnowledgeEngine {
  /// پاسخ‌های ثابت؛ از assets/replies.json خوانده می‌شوند.
  final Replies replies = Replies();
  final List<Chunk> _chunks = [];
  final Map<String, double> _idf = {};
  final Map<String, List<int>> _postings = {};
  final Map<String, List<int>> _byTitle = {};
  double _avgLen = 1.0;
  double _maxIdf = 1.0;

  // زیر این پوشش، پاسخ با هشدار «مطمئن نیستم» نشان داده می‌شود.
  static const double _lowCover = 0.4;

  // پرسش‌های «X چیست / کیست / یعنی چه»: مادهٔ تعریف‌کننده باید جلو بیاید.
  static final RegExp _defQ = RegExp(
    r'چیست|چیه|کیست|یعنی چی|یعنی چه|چه معنی|تعریف|چی هست|به چه گویند|به چه کسی می گویند|به چی می گن|گفته می شود',
  );
  static const Set<String> _defWords = {
    'یعنی', 'چی', 'چه', 'معنی', 'تعریف', 'هست', 'چیست', 'چیه',
    'گویند', 'کسی', 'کیست', 'گفته', 'شود',
  };
  static const Set<String> _defMetaPrefixes = {
    'مجازات', 'مجازاتی', 'شرایط', 'حکم', 'مهلت', 'موارد', 'نحوه', 'میزان',
  };
  static final RegExp _defMark = RegExp(r'عقدی|عبارت|است|گویند|حاصل');
  static final RegExp _defStrong = RegExp(r'^[\s،]*(عقدی|عبارت|شرکتی|کسی)');

  // الگوهای ازپیش‌کامپایل‌شده برای جلوگیری از ساخت مکرر RegExp
  static final RegExp _obsoleteTrimRe = RegExp(r'^[\(\[\s]+');
  static final RegExp _paraSplitRe = RegExp(r'\n\s*\n');
  static final RegExp _hashPrefixRe = RegExp(r'^#+\s*');
  static final RegExp _artQueryRe = RegExp(
    r'(ماده|اصل)\s*(?:(واحده)(?![\u0600-\u06FFa-z0-9])|(\d+)(?:\s*(مکرر)(?:\s*(\d{1,2})(?!\d))?)?)(?!\s*(?:تومان|ریال|درصد|سکه|ماه|سال|روز))',
  );
  static final RegExp _punctOnlyRe = RegExp(r'[\p{P}]', unicode: true);
  static final RegExp _cleanBodyRe = RegExp(r'^[\(\[][^)\]]*[\)\]]\s*-?\s*');
  static final RegExp _articleTitleRe = RegExp(
    r'^(?:ماده|اصل)\s*(?:واحده|\d+(?:\s*مکرر(?:\s*\d{1,2})?)?)$',
  );

  // پارامترهای BM25F
  final double _k1 = AppConfig.k1;
  final double _b = AppConfig.b;
  final double _wT = AppConfig.wT;
  final double _wB = AppConfig.wB;
  final double _wC = AppConfig.wC;
  final Map<String, int> _lawCounts = {};
  List<String> _vocab = [];

  final List<CatalogLaw> catalog = [];
  final Map<String, String> categoryNames = {};
  final Map<String, Map<String, dynamic>> meta = {};
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

  int get size => _chunks.length;
  Map<String, int> get lawCounts => _lawCounts;
  bool isLoaded(String id) => (_lawCounts[id] ?? 0) > 0;

  // لایهٔ متن به persian_text.dart رفته؛ اینجا فقط نام‌های قدیمی نگه داشته شده‌اند.
  static String normalize(String s) => PersianText.normalize(s);

  static String _collapse(String s) => PersianText.collapse(s);

  static List<String> tokenizeIndex(String s) => PersianText.tokenizeIndex(s);

  static List<String> tokenize(String s) => PersianText.tokenize(s);

  static bool _isObsolete(String body) {
    var n = _collapse(normalize(body));
    if (n.length > 300) return false;
    n = n.replaceFirst(_obsoleteTrimRe, '');
    return n.startsWith('منسوخ') ||
        n.startsWith('ملغی') ||
        n.startsWith('ملغا') ||
        n.startsWith('حذف شد');
  }
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
  _chunks.clear();
  _idf.clear();
  _postings.clear();
  _byTitle.clear();
  _lawCounts.clear();
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

  _Built built;
  try {
    built = await _buildAsync(raw);
  } catch (_) {
    built = _build(raw); // اگر Isolate شکست خورد، روی همین رشته
  }
  _chunks
    ..clear()
    ..addAll(built.chunks);
  _lawCounts
    ..clear()
    ..addAll(built.lawCounts);
  _idf
    ..clear()
    ..addAll(built.idf);
  _postings
    ..clear()
    ..addAll(built.postings);
  _byTitle
    ..clear()
    ..addAll(built.byTitle);
  _avgLen = built.avgLen;
  _maxIdf = built.maxIdf;
  _vocab = built.vocab;
}

static Future<_Built> _buildAsync(List<List<String>> raw) =>
    Isolate.run(() => _build(raw));

static _Built _build(List<List<String>> raw) {
  final chunks = <Chunk>[];
  final counts = <String, int>{};
  for (final r in raw) {
    _parseInto(r[2], r[1], r[0], chunks, counts);
  }
  final df = <String, int>{};
  final postings = <String, List<int>>{};
  final byTitle = <String, List<int>>{};
  var totalLen = 0;
  for (var i = 0; i < chunks.length; i++) {
    final c = chunks[i];
    totalLen += c.len;
    byTitle.putIfAbsent(c.normTitle, () => <int>[]).add(i);
    final seen = <String>{...c.tfT.keys, ...c.tfB.keys, ...c.tfC.keys};
    for (final t in seen) {
      df[t] = (df[t] ?? 0) + 1;
      postings.putIfAbsent(t, () => <int>[]).add(i);
    }
  }
  final n = chunks.length;
  final avg = n == 0 ? 1.0 : math.max(1.0, totalLen / n);
  final idf = <String, double>{};
  var maxIdf = 1.0;
  df.forEach((t, d) {
    final v = math.log((n + 1) / (d + 1)) + 1.0;
    idf[t] = v;
    if (v > maxIdf) maxIdf = v;
  });
  final vocab = df.keys.toList()..sort();
  return _Built(chunks, counts, idf, postings, byTitle, avg, maxIdf, vocab);
}

static void _parseInto(
  String text,
  String defaultSource,
  String lawId,
  List<Chunk> out,
  Map<String, int> counts,
) {
  var source = defaultSource;
  var chapter = '';
  final parts = text.replaceAll('\r', '').split(_paraSplitRe);
  for (final p in parts) {
    final lines = p.trim().split('\n');
    if (lines.isEmpty || lines.first.trim().isEmpty) continue;
    final first = lines.first.trim();
    if (first.startsWith('##')) {
      chapter = first.replaceFirst(_hashPrefixRe, '').trim();
      continue;
    }
    if (first.startsWith('#')) {
      source = first.replaceFirst(_hashPrefixRe, '').trim();
      chapter = '';
      continue;
    }
    final body = lines.length > 1 ? lines.sublist(1).join('\n').trim() : first;
    final tfT = <String, int>{};
    final tfB = <String, int>{};
    final tfC = <String, int>{};
    var len = 0;
    for (final t in tokenizeIndex(first)) {
      tfT[t] = (tfT[t] ?? 0) + 1;
      len++;
    }
    for (final t in tokenizeIndex(body)) {
      tfB[t] = (tfB[t] ?? 0) + 1;
      len++;
    }
    for (final t in tokenizeIndex(chapter)) {
      tfC[t] = (tfC[t] ?? 0) + 1;
      len++;
    }
    for (final t in tokenizeIndex(source)) {
      tfC[t] = (tfC[t] ?? 0) + 1;
      len++;
    }
    out.add(Chunk(
      lawId,
      source,
      chapter,
      first,
      body,
      body != first && _isObsolete(body),
      tfT,
      tfB,
      tfC,
      len,
    ));
    counts[lawId] = (counts[lawId] ?? 0) + 1;
  }
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

static String _canonicalArticleTitle(String rawArticle) {
  var a = _collapse(normalize(rawArticle));
  if (a.isEmpty) return '';
  if (!a.startsWith('ماده ') && !a.startsWith('اصل ')) a = 'ماده $a';
  return _collapse(a);
}

static String _wantedArticleFromMatch(RegExpMatch m) {
  final kind = m.group(1) == 'اصل' ? 'اصل' : 'ماده';
  if (m.group(2) != null) return '$kind واحده';
  final num = m.group(3)!;
  final mk = m.group(4) != null
      ? (m.group(5) != null ? ' مکرر ${m.group(5)}' : ' مکرر')
      : '';
  return '$kind $num$mk';
}

static String _faArticleLabel(RegExpMatch m) {
  if (m.group(2) != null) return 'واحده';
  final num = PersianText.toFaDigits(m.group(3)!);
  final mk = m.group(4) != null
      ? (m.group(5) != null
          ? ' مکرر ${PersianText.toFaDigits(m.group(5)!)}'
          : ' مکرر')
      : '';
  return '$num$mk';
}

/// متن رسمی یک ماده را با نام قانون و شمارهٔ ماده پیدا می‌کند.
/// اگر در بستهٔ قوانین نباشد null برمی‌گرداند و هرگز متنی نمی‌سازد.
Chunk? findArticle(String law, String article) {
  final lawN = _collapse(normalize(law));
  final want = _canonicalArticleTitle(article);
  if (want.isEmpty || lawN.isEmpty) return null;
  var indices = _byTitle[want];
  if (indices == null && want.startsWith('ماده ')) {
    indices = _byTitle['اصل ${want.substring(5)}'];
  }
  if (indices == null) return null;
  final mentionedIds = _mentionedLaws(law).map((l) => l.id).toSet();
  for (final idx in indices) {
    final c = _chunks[idx];
    if (c.lawId == lawN || mentionedIds.contains(c.lawId)) return c;
    final s = c.normSource;
    if (s.isEmpty) continue;
    if (s == lawN || s.contains(lawN) || lawN.contains(s)) return c;
  }
  return null;
}

/// قوانین فهرست که نام یا نام رایجشان در متن آمده است.
List<CatalogLaw> mentionedLaws(String q) => _mentionedLaws(q);

List<CatalogLaw> _mentionedLaws(String q) {
  final n = _collapse(normalize(q));
  final matched = <CatalogLaw>[];

  for (final l in catalog) {
    var hit = false;
    for (final name in [l.title, ...l.aliases]) {
      final full = _collapse(normalize(name));
      if (full.isEmpty) continue;

      final isLawName =
          full.startsWith('قانون ') || full.startsWith('لایحه ');
      if (!isLawName) continue;

      if (n.contains(full)) {
        hit = true;
        break;
      }

      final short =
          full.startsWith('قانون ') ? full.substring(6).trim() : '';
      if (short.length >= 5 && n.contains('قانون $short')) {
        hit = true;
        break;
      }
    }
    if (hit) matched.add(l);
  }

  if (matched.length < 2) return matched;

  final matchedNames = <String, String>{};
  for (final l in matched) {
    for (final name in [l.title, ...l.aliases]) {
      final full = _collapse(normalize(name));
      if (full.isNotEmpty && n.contains(full)) {
        matchedNames[l.id] = full;
        break;
      }
    }
  }

  return matched.where((law) {
    final ownName = matchedNames[law.id];
    if (ownName == null) return true;

    for (final other in matched) {
      if (other.id == law.id) continue;
      final otherName = matchedNames[other.id];
      if (otherName != null &&
          otherName.length > ownName.length &&
          otherName.contains(ownName)) {
        return false;
      }
    }
    return true;
  }).toList();
}

List<CatalogLaw> _loadedLaws() =>
    catalog.where((l) => isLoaded(l.id)).toList();

bool _asksLawList(String n) {
  return n.contains('چه قوانین') ||
      n.contains('کدام قوانین') ||
      n.contains('فهرست قوانین') ||
      n.contains('قوانین موجود') ||
      n.contains('چه قانون');
}

String _lawListText() {
  final loaded = _loadedLaws();
  if (loaded.isEmpty) return replies.get('no_laws');
  final sb = StringBuffer('قوانینی که متنشان در برنامه است:');
  for (final l in loaded) {
    final n = _lawCounts[l.id] ?? 0;
    sb.write('\n• ${l.title} (${PersianText.toFaDigits(n.toString())} ماده)');
  }
  final rest = catalog.length - loaded.length;
  if (rest > 0) {
    sb.write(
      '\n\n${PersianText.toFaDigits(rest.toString())} قانون دیگر در فهرست هست ولی متنشان هنوز وارد نشده است.',
    );
  }
  return sb.toString();
}

String format(Chunk c) {
  final sb = StringBuffer();
  sb.write(c.title);
  if (c.body != c.title) sb.write('\n${c.body}');
  if (c.obsolete) {
    sb.write('\n\nتوجه: این ماده در متن رسمی منسوخ‌شده علامت خورده است.');
  }
  if (c.source.isNotEmpty) {
    sb.write('\n\nمنبع: ${c.source}');
    if (c.chapter.isNotEmpty) sb.write(' — ${c.chapter}');
    final date = (meta[c.lawId]?['date'] ?? '').toString().trim();
    if (date.isNotEmpty) {
      sb.write('\nتاریخ دریافت متن: ${PersianText.toFaDigits(date)}');
    }
  }
  return sb.toString();
}

/// چه کسری از وزن واژه‌های پرسش در این ماده (یا با کمک مترادف‌ها) پیدا می‌شود.
/// عددی بین ۰ و ۱؛ هرچه کمتر، احتمال بی‌ربط‌بودن ماده بیشتر است.
double coverage(String question, Chunk c) {
  final qt = tokenizeIndex(question).toSet().toList();
  if (qt.isEmpty || _idf.isEmpty) return 0.0;
  bool has(String t) =>
      c.tfT.containsKey(t) || c.tfB.containsKey(t) || c.tfC.containsKey(t);
  var den = 0.0;
  var got = 0.0;
  final covered = <String>{};
  for (final t in qt) {
    den += _idf[t] ?? _maxIdf;
    if (has(t)) {
      covered.add(t);
      got += _idf[t] ?? _maxIdf;
    } else if (!_idf.containsKey(t) && t.length >= 3) {
      var pref = false;
      for (final m in [c.tfT, c.tfB, c.tfC]) {
        for (final v in m.keys) {
          if (v.length >= 3 && (v.startsWith(t) || t.startsWith(v))) {
            pref = true;
            break;
          }
        }
        if (pref) break;
      }
      if (pref) {
        covered.add(t);
        got += 0.5 * _maxIdf;
      }
    }
  }
  final n = ' ${_phrase(question)} ';
  for (final r in _syn) {
    if (!n.contains(' ${r[0]} ')) continue;
    if (!tokenizeIndex(r[1]).any(has)) continue;
    for (final t in tokenizeIndex(r[0])) {
      if (qt.contains(t) && !covered.contains(t)) {
        covered.add(t);
        got += _idf[t] ?? _maxIdf;
      }
    }
  }
  return den > 0 ? got / den : 0.0;
}

static int _lowerBound(List<String> sorted, String target) {
  var lo = 0;
  var hi = sorted.length;
  while (lo < hi) {
    final mid = (lo + hi) >> 1;
    if (sorted[mid].compareTo(target) < 0) {
      lo = mid + 1;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// گسترش پیشوند در زمان O(log V + |t| + matches) به‌جای پیمایش خطی کل واژگان.
void _addPrefixTerms(String t, Map<String, double> terms) {
  for (var len = 3; len < t.length; len++) {
    final sub = t.substring(0, len);
    if (_idf.containsKey(sub)) {
      terms[sub] = math.max(terms[sub] ?? 0, 0.5);
    }
  }
  var i = _lowerBound(_vocab, t);
  while (i < _vocab.length && _vocab[i].startsWith(t)) {
    final v = _vocab[i];
    terms[v] = math.max(terms[v] ?? 0, 0.5);
    i++;
  }
}

RankResult rank(String question, {int k = 3}) {
  return _rankInternal(question, k: k);
}
  RankResult _rankInternal(
    String question, {
    List<CatalogLaw>? mentioned,
    int k = 3,
  }) {
    if (_chunks.isEmpty) return RankResult([]);
    final q = normalize(question);
    final qTokens = tokenizeIndex(question).toSet().toList();

    final laws = mentioned ?? _mentionedLaws(question);
    final ids = laws.where((l) => isLoaded(l.id)).map((l) => l.id).toSet();

    final art = _artQueryRe.firstMatch(q);
    if (art != null) {
      final want = _collapse(_wantedArticleFromMatch(art));
      final titleIndices = _byTitle[want];
      if (titleIndices != null && titleIndices.isNotEmpty) {
        final found = <Chunk>[];
        for (final idx in titleIndices) {
          final c = _chunks[idx];
          if (ids.isEmpty || ids.contains(c.lawId)) {
            found.add(c);
          }
        }
        if (found.isNotEmpty) {
          Chunk pick = found.first;
          var bestOverlap = -1;
          for (final c in found) {
            final st = tokenizeIndex(c.source).toSet();
            final ov = qTokens.where(st.contains).length;
            if (ov > bestOverlap) {
              bestOverlap = ov;
              pick = c;
            }
          }
          var note = '';
          if (found.length > 1 && bestOverlap <= 0) {
            final others = found
                .where((c) => c != pick && c.source.isNotEmpty)
                .map((c) => c.source)
                .take(3)
                .join('، ');
            if (others.isNotEmpty) {
              note =
                  'همین شمارهٔ ماده در این منابع هم هست: $others. نام قانون را هم بنویسید.';
            }
          }
          return RankResult([Hit(pick, 99)], note);
        }
      }
    }

    if (qTokens.isEmpty) return RankResult([]);

    final terms = <String, double>{};
    double total = 0;
    for (final t in qTokens) {
      total += _idf[t] ?? 1.0;
      if (_idf.containsKey(t)) {
        terms[t] = 1.0;
      } else if (t.length >= 3) {
        _addPrefixTerms(t, terms);
      }
    }
    for (final t in _expand(question)) {
      if (_idf.containsKey(t)) terms[t] = math.max(terms[t] ?? 0, 1.0);
    }
    if (terms.isEmpty) return RankResult([]);

    // استفاده از نمایهٔ معکوس (Inverted Index) به‌جای پیمایش همهٔ چانک‌ها
    final candSet = <int>{};
    for (final t in terms.keys) {
      final list = _postings[t];
      if (list != null) candSet.addAll(list);
    }
    if (candSet.isEmpty) return RankResult([]);
    final candIndices = candSet.toList()..sort();

    final hits = <Hit>[];
    for (final idx in candIndices) {
      final c = _chunks[idx];
      if (ids.isNotEmpty && !ids.contains(c.lawId)) continue;
      double s = 0;
      final lenNorm = 1 - _b + _b * c.len / _avgLen;
      terms.forEach((t, w) {
        final tf = _wT * (c.tfT[t] ?? 0) +
            _wB * (c.tfB[t] ?? 0) +
            _wC * (c.tfC[t] ?? 0);
        if (tf > 0) {
          final tfn = tf / lenNorm;
          s += w * (_idf[t] ?? 1.0) * tfn * (_k1 + 1) / (tfn + _k1);
        }
      });
      if (s <= 0) continue;
      s = s / (total > 0 ? total : 1.0);
      if (c.obsolete) s *= 0.1;
      hits.add(Hit(c, s));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return RankResult(_promoteDefinitions(question, hits).take(k).toList());
  }

  static String _cleanBody(String body) =>
      _collapse(normalize(body)).replaceFirst(_cleanBodyRe, '');

  /// اگر پرسش از نوع «X چیست» بود، تا دو مادهٔ منسوخ‌نشده‌ای که متنشان با
  /// همان واژه شروع می‌شود و حالت تعریفی دارد («عقدی است…»، «عبارت است…»)
  /// به ابتدای فهرست می‌آیند. دانش عمومی و ماده‌های منسوخ هیچ‌وقت نمی‌آیند.
  List<Hit> _promoteDefinitions(String question, List<Hit> hits) {
    if (hits.isEmpty || !_defQ.hasMatch(normalize(question))) return hits;
    var toks =
        tokenizeIndex(question).where((t) => !_defWords.contains(t)).toList();
    if (toks.length >= 2 && _defMetaPrefixes.contains(toks.first)) {
      toks = toks.skip(1).toList();
    }
    if (toks.isEmpty) return hits;
    var cands = <Hit>[];
    for (final n in [2, 1]) {
      if (toks.length < n) continue;
      final term = toks.take(n).join(' ');
      final strong = <Hit>[];
      final weak = <Hit>[];
      for (final h in hits) {
        final c = h.chunk;
        if (c.lawId == 'knowledge' || c.obsolete) continue;
        final body = _cleanBody(c.body);
        final p = body.startsWith(term)
            ? term
            : (body.startsWith('عقد $term') ? 'عقد $term' : null);
        if (p == null) continue;
        final end = math.min(body.length, p.length + 30);
        final tail = body.substring(p.length, end);
        if (!_defMark.hasMatch(tail)) continue;
        (_defStrong.hasMatch(tail) ? strong : weak).add(h);
      }
      cands = [...strong, ...weak];
      if (cands.isNotEmpty) break;
    }
    if (cands.isEmpty) return hits;
    final picked = cands.take(2).toList();
    final top = hits.first.score;
    final out = <Hit>[
      Hit(picked[0].chunk, math.max(picked[0].score, top)),
      ...picked.skip(1),
    ];
    for (final h in hits) {
      if (!picked.any((p) => identical(p.chunk, h.chunk))) out.add(h);
    }
    return out;
  }

  /// پردازش یکپارچهٔ پرسش با یک‌بار اجرای رتبه‌بندی (پاسخ نهایی + زمینهٔ LLM + پیشنهادهای نزدیک).
  EngineReply query(String question, {int maxAlternatives = 3}) {
    final n = normalize(question);
    if (QueryRouter.asksCapabilities(n)) {
      return EngineReply(text: replies.get('capabilities'));
    }
    if (QueryRouter.asksOutcomePrediction(n)) {
      return EngineReply(text: replies.get('outcome_prediction'));
    }
    final art = _artQueryRe.firstMatch(n);
    final qTokens = tokenize(question);
    if (qTokens.every((t) => t.replaceAll(_punctOnlyRe, '').isEmpty) &&
        art == null) {
      final txt =
          n.contains('سلام') ? replies.get('greeting') : replies.get('ask_more');
      return EngineReply(text: txt);
    }
    if (_chunks.isEmpty) {
      return EngineReply(text: replies.get('no_knowledge'));
    }

    if (_asksLawList(n)) {
      return EngineReply(text: _lawListText());
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
    final r = _rankInternal(question, mentioned: mentioned, k: rankK);
    final top4 = r.hits.take(4).toList();
    final ctx = top4.where((h) => h.score >= 0.3).toList();
    final alts = maxAlternatives > 0
        ? _alternativesFromRank(n, mentioned, r, max: maxAlternatives)
        : const <String>[];

    if (art != null &&
        loaded.isNotEmpty &&
        (top4.isEmpty || top4.first.score < 99)) {
      final kind = art.group(1) == 'اصل' ? 'اصل' : 'ماده';
      final num = _faArticleLabel(art);
      return EngineReply(
        text:
            '$kind $num در متن «${loaded.first.title}» که در برنامه است پیدا نشد. ممکن است چنین مادهٔ معتبری نباشد یا متن برنامه ناقص باشد. شمارهٔ ماده را دوباره بررسی کنید.${missingNote.isEmpty ? '' : '\n\n$missingNote'}',
        alternatives: alts,
      );
    }

    if (top4.isEmpty || top4.first.score < 0.3) {
      return EngineReply(text: _notFound(), alternatives: alts);
    }

    // صریح‌بودنِ پرسش (درخواست مستقیم ماده) از مسیرِ انتخابِ زیر عبور می‌کند:
    final explicit = art != null && top4.first.score >= 99;

    // انتخاب مادهٔ پاسخ: رتبهٔ نخستِ BM25F مبناست؛ اما گاهی مادهٔ هم‌جنسِ
    // نادرست (مثلاً نفقهٔ عقد موقت در برابر دائم) رتبهٔ نخست می‌گیرد. اگر
    // مادهٔ دیگری از برترین‌ها پوششِ پرسش را به‌مراتب (حاشیهٔ ۰٫۲۵) بهتر
    // بدهد، همان پاسخ می‌دهد. اگر هیچ ماده‌ای به آستانهٔ پوشش نرسد، صادقانه
    // «پیدا نکردم» گفته می‌شود.
    final topCov = explicit ? 1.0 : coverage(question, top4.first.chunk);
    var bestCov = topCov;
    Hit bestHit = top4.first;
    if (!explicit) {
      for (final h in top4.skip(1)) {
        final c = coverage(question, h.chunk);
        if (c > bestCov) {
          bestCov = c;
          bestHit = h;
        }
      }
      if (bestCov < _lowCover) {
        return EngineReply(
          text: _notFound(),
          contextHits: ctx,
          alternatives: alts,
        );
      }
      // بدون برتریِ محسوس، رتبهٔ نخست پاسخ می‌دهد.
      if (bestCov < topCov + 0.25) bestHit = top4.first;
    }

    if (art == null && _hitsUnloadedDomain(n, mentioned, bestHit.chunk)) {
      return EngineReply(text: _notFound(), alternatives: alts);
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
            res += '\n• ${h.chunk.title} — ${h.chunk.source}';
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

  static bool _chunkHasTerm(Chunk c, String t) =>
      c.tfT.containsKey(t) || c.tfB.containsKey(t) || c.tfC.containsKey(t);

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
          (!_chunkHasTerm(top, 'مالیات') &&
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
        if (!requiredAny.any((r) => _chunkHasTerm(top, r))) {
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
    final m = _artQueryRe.firstMatch(c.normTitle);
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

  /// نسخه‌ی ساخت‌یافته‌ی rank که برای planner در Phase 2 استفاده می‌شود.
  ///
  /// مواد منسوخ را فیلتر می‌کند تا EvidenceSet تنها شامل شواهد معتبر باشد.
  /// Coverage بر اساس بهترین نتیجه محاسبه می‌شود. برای Phase 0.4، فیلد
  /// `conflicts` خالی است و تشخیص تعارض معنادار به Phase 2 موکول می‌شود
  /// (چون conflictChainsFor زنجیره‌های ارجاع متقابل است، نه لزوماً
  /// تعارض واقعی بین مواد). planner در Phase 2 می‌تواند از
  /// conflictChainsFor مستقیماً استفاده کند اگر بخواهد.
  ///
  /// این متد **بدون تغییر** در `rank`، `query`، `coverage` یا
  /// `conflictChainsFor` کار می‌کند — فقط آن‌ها را در یک بسته‌ی
  /// ساخت‌یافته جمع می‌کند.
  EvidenceSet retrieveWithEvidence(String question, {int k = 3}) {
    final rankResult = rank(question, k: k);
    final filtered =
        rankResult.hits.where((h) => !h.chunk.obsolete).toList();

    final items = <Evidence>[];
    for (var i = 0; i < filtered.length; i++) {
      final h = filtered[i];
      final articleId = h.chunk.source.isNotEmpty
          ? '${h.chunk.source} — ${h.chunk.title}'
          : h.chunk.title;
      items.add(Evidence(
        articleId: articleId,
        text: h.chunk.body,
        rank: i + 1,
        score: h.score,
        matchedSlots: const [],
      ));
    }

    final top = filtered.isEmpty ? null : filtered.first;
    final cov = top == null ? 0.0 : coverage(question, top.chunk);

    return EvidenceSet(
      items: items,
      conflicts: const [],
      coverage: cov,
    );
  }

  String answer(String question) => query(question, maxAlternatives: 0).text;

  List<String> _alternativesFromRank(
    String normQuestion,
    List<CatalogLaw> mentioned,
    RankResult r, {
    int max = 3,
  }) {
    if (_artQueryRe.hasMatch(normQuestion)) return [];
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
    if (_artQueryRe.hasMatch(n)) return [];
    if (_asksLawList(n)) return [];
    final mentioned = _mentionedLaws(question);
    if (mentioned.any((l) => !isLoaded(l.id))) return [];
    final r = _rankInternal(question, mentioned: mentioned, k: 12);
    return _alternativesFromRank(n, mentioned, r, max: max);
  }

  String _notFound() {
    return replies.get('not_found');
  }
}

/// نتیجهٔ ساخت نمایه که از Isolate به رشتهٔ اصلی برمی‌گردد.
class _Built {
  final List<Chunk> chunks;
  final Map<String, int> lawCounts;
  final Map<String, double> idf;
  final Map<String, List<int>> postings;
  final Map<String, List<int>> byTitle;
  final double avgLen;
  final double maxIdf;
  final List<String> vocab;

  _Built(
    this.chunks,
    this.lawCounts,
    this.idf,
    this.postings,
    this.byTitle,
    this.avgLen,
    this.maxIdf,
    this.vocab,
  );
}
