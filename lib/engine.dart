import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle;

import 'persian_text.dart';
import 'replies.dart';
import 'templates.dart' show TemplateRenderer;

class Chunk {
  final String lawId;
  final String source;
  final String chapter;
  final String title;
  final String body;
  final bool obsolete;
  final Map<String, int> tfT; // واژه‌های عنوان
  final Map<String, int> tfB; // واژه‌های متن
  final Map<String, int> tfC; // واژه‌های فصل و نام قانون
  final int len;
  late final String normTitle = KnowledgeEngine.normalize(title).trim();
  Chunk(
    this.lawId,
    this.source,
    this.chapter,
    this.title,
    this.body,
    this.obsolete,
    this.tfT,
    this.tfB,
    this.tfC,
    this.len,
  );
}

class Hit {
  final Chunk chunk;
  final double score;
  Hit(this.chunk, this.score);
}

class RankResult {
  final List<Hit> hits;
  final String note;
  RankResult(this.hits, [this.note = '']);
}

class CatalogLaw {
  final String id;
  final String title;
  final String category;
  final int priority;
  final List<String> aliases;
  CatalogLaw(this.id, this.title, this.category, this.priority, this.aliases);
}

class KnowledgeEngine {
  /// پاسخ‌های ثابت؛ از assets/replies.json خوانده می‌شوند.
  final Replies replies = Replies();
  final List<Chunk> _chunks = [];
  final Map<String, double> _idf = {};
  double _avgLen = 1.0;
  double _maxIdf = 1.0;

  // زیر این پوشش، پاسخ با هشدار «مطمئن نیستم» نشان داده می‌شود.
  static const double _lowCover = 0.4;

  // پرسش‌های «X چیست / یعنی چه»: مادهٔ تعریف‌کننده باید جلو بیاید.
  static final RegExp _defQ = RegExp(
    r'چیست|چیه|یعنی چی|یعنی چه|چه معنی|تعریف|چی هست|به چه گویند|به چه کسی می گویند|به چی می گن',
  );
  static const Set<String> _defWords = {
    'یعنی', 'چی', 'چه', 'معنی', 'تعریف', 'هست', 'چیست', 'چیه',
    'گویند', 'کسی', 'کیست',
  };
  static final RegExp _defMark = RegExp(r'عقدی|عبارت|است|گویند');
  static final RegExp _defStrong = RegExp(r'^[\s،]*(عقدی|عبارت|شرکتی|کسی)');

  // پارامترهای BM25F
  static const double _k1 = 1.2;
  static const double _b = 0.4;
  static const double _wT = 3.0;
  static const double _wB = 1.0;
  static const double _wC = 0.5;
  final Map<String, int> _lawCounts = {};
  List<String> _vocab = [];

  final List<CatalogLaw> catalog = [];
  final Map<String, String> categoryNames = {};
  final Map<String, Map<String, dynamic>> meta = {};

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
    n = n.replaceFirst(RegExp(r'^[\(\[\s]+'), '');
    return n.startsWith('منسوخ') ||
        n.startsWith('ملغی') ||
        n.startsWith('ملغا') ||
        n.startsWith('حذف شد');
  }

  Future<void> load() async {
    _chunks.clear();
    _idf.clear();
    _lawCounts.clear();
    catalog.clear();
    categoryNames.clear();
    meta.clear();
    warnings.clear();

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

    try {
      final t = await rootBundle.loadString('assets/laws/_meta.json');
      final m = jsonDecode(t) as Map<String, dynamic>;
      m.forEach((k, v) {
        if (v is Map<String, dynamic>) meta[k] = v;
      });
    } catch (e) {
      warnings.add('_meta.json: $e');
    }

    try {
      final t = await rootBundle.loadString('assets/replies.json');
      final m = jsonDecode(t) as Map<String, dynamic>;
      replies.setOverrides(m.map((k, v) => MapEntry(k, v.toString())));
    } catch (e) {
      warnings.add('replies.json: $e');
    }

    // ۱. لود فایل دانش عمومی
    try {
      final text = await rootBundle.loadString('assets/knowledge.txt');
      await _parse(text, 'دانش عمومی', 'knowledge');
    } catch (e) {
      warnings.add('assets/knowledge.txt: $e');
    }

    // ۲. لود قوانین بر اساس مسیرهای ثبت شده در _meta.json
    for (final entry in meta.entries) {
      final lawId = entry.key;
      final path = entry.value['path'];
      
      if (path != null && path is String) {
        final fullPath = 'assets/laws/$path';
        try {
          final text = await rootBundle.loadString(fullPath);
          await _parse(text, '', lawId);
        } catch (e) {
          warnings.add('$fullPath: $e');
        }
      }
    }
    await _loadSynonyms();
    _buildIndex();
  }

  Future<void> _parse(String text, String defaultSource, String lawId) async {
    var source = defaultSource;
    var chapter = '';
    final parts = text.replaceAll('\r', '').split(RegExp(r'\n\s*\n'));
    var n = 0;
    for (final p in parts) {
      final lines = p.trim().split('\n');
      if (lines.isEmpty || lines.first.trim().isEmpty) continue;
      final first = lines.first.trim();
      if (first.startsWith('##')) {
        chapter = first.replaceFirst(RegExp(r'^#+\s*'), '').trim();
        continue;
      }
      if (first.startsWith('#')) {
        source = first.replaceFirst(RegExp(r'^#+\s*'), '').trim();
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
      _chunks.add(Chunk(
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
      _lawCounts[lawId] = (_lawCounts[lawId] ?? 0) + 1;
      n++;
      if (n % 200 == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  void _buildIndex() {
    final df = <String, int>{};
    var totalLen = 0;
    for (final c in _chunks) {
      totalLen += c.len;
      final seen = <String>{...c.tfT.keys, ...c.tfB.keys, ...c.tfC.keys};
      for (final t in seen) {
        df[t] = (df[t] ?? 0) + 1;
      }
    }
    final n = _chunks.length;
    _avgLen = n == 0 ? 1.0 : math.max(1.0, totalLen / n);
    df.forEach((t, d) {
      _idf[t] = math.log((n + 1) / (d + 1)) + 1.0;
    });
    _maxIdf = 1.0;
    for (final v in _idf.values) {
      if (v > _maxIdf) _maxIdf = v;
    }
    _vocab = df.keys.toList();
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

  /// متن رسمی یک ماده را با نام قانون و شمارهٔ ماده پیدا می‌کند.
  /// اگر در بستهٔ قوانین نباشد null برمی‌گرداند و هرگز متنی نمی‌سازد.
  Chunk? findArticle(String law, String article) {
    final want = 'ماده ${_collapse(normalize(article))}';
    final lawN = _collapse(normalize(law));
    if (lawN.isEmpty) return null;
    for (final c in _chunks) {
      if (_collapse(c.normTitle) != want) continue;
      final s = _collapse(normalize(c.source));
      if (s.isEmpty) continue;
      if (s == lawN || s.contains(lawN) || lawN.contains(s)) return c;
    }
    return null;
  }

  /// قوانین فهرست که نام یا نام رایجشان در پرسش آمده است.
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
      sb.write('\n• ${l.title} (${TemplateRenderer.toFa(n.toString())} ماده)');
    }
    final rest = catalog.length - loaded.length;
    if (rest > 0) {
      sb.write(
        '\n\n${TemplateRenderer.toFa(rest.toString())} قانون دیگر در فهرست هست ولی متنشان هنوز وارد نشده است.',
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
        sb.write('\nتاریخ دریافت متن: ${TemplateRenderer.toFa(date)}');
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

  RankResult rank(String question, {int k = 3}) {
    if (_chunks.isEmpty) return RankResult([]);
    final q = normalize(question);
    final qTokens = tokenizeIndex(question).toSet().toList();

    final ids = _mentionedLaws(question)
        .where((l) => isLoaded(l.id))
        .map((l) => l.id)
        .toSet();
    final pool =
        ids.isEmpty ? _chunks : _chunks.where((c) => ids.contains(c.lawId)).toList();

    final art = RegExp(r'ماده\s*(\d+)(\s*مکرر)?').firstMatch(q);
    if (art != null) {
      final want =
          'ماده ${art.group(1)}${art.group(2) != null ? ' مکرر' : ''}';
      final found =
          pool.where((c) => c.normTitle == want).toList();
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

    if (qTokens.isEmpty) return RankResult([]);

    final terms = <String, double>{};
    double total = 0;
    for (final t in qTokens) {
      total += _idf[t] ?? 1.0;
      if (_idf.containsKey(t)) {
        terms[t] = 1.0;
      } else if (t.length >= 3) {
        for (final v in _vocab) {
          if (v.length >= 3 && (v.startsWith(t) || t.startsWith(v))) {
            terms[v] = math.max(terms[v] ?? 0, 0.5);
          }
        }
      }
    }
    for (final t in _expand(question)) {
      if (_idf.containsKey(t)) terms[t] = math.max(terms[t] ?? 0, 1.0);
    }
    if (terms.isEmpty) return RankResult([]);

    final hits = <Hit>[];
    for (final c in pool) {
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

  static String _cleanBody(String body) => _collapse(normalize(body))
      .replaceFirst(RegExp(r'^[\(\[][^)\]]*[\)\]]\s*-?\s*'), '');

  /// اگر پرسش از نوع «X چیست» بود، تا دو مادهٔ منسوخ‌نشده‌ای که متنشان با
  /// همان واژه شروع می‌شود و حالت تعریفی دارد («عقدی است…»، «عبارت است…»)
  /// به ابتدای فهرست می‌آیند. دانش عمومی و ماده‌های منسوخ هیچ‌وقت نمی‌آیند.
  List<Hit> _promoteDefinitions(String question, List<Hit> hits) {
    if (hits.isEmpty || !_defQ.hasMatch(normalize(question))) return hits;
    final toks =
        tokenizeIndex(question).where((t) => !_defWords.contains(t)).toList();
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



  bool _asksAssistantCapabilities(String n) {
    final compact = n.replaceAll(RegExp(r'[\s‌‍‎‏،؛؟,.!?:]+'), '');
    final asksWhat =
        compact.contains('چهکاری') || compact.contains('چهکارهایی');
    final capabilityVerb =
        compact.contains('انجاممیدهی') ||
        compact.contains('انجاممیدی') ||
        compact.contains('میتوانی') ||
        compact.contains('میتونی') ||
        compact.contains('میکنی') ||
        compact.contains('ازدستتبرمیاد');
    final asksAboutCapabilities =
        (compact.contains('قابلیتهای') ||
         compact.contains('تواناییهای')) &&
        (compact.contains('دستیار') ||
         compact.contains('برنامه') ||
         compact.contains('تو'));
    return (asksWhat && capabilityVerb) || asksAboutCapabilities;
  }

  bool _asksOutcomePrediction(String n) {
    final compact = n.replaceAll(RegExp(r'[\s‌‍‎‏،؛؟,.!?:]+'), '');
    final asksCase = compact.contains('پرونده') ||
        compact.contains('حکمقاضی') ||
        compact.contains('نتیجهدادگاه');
    final asksPrediction =
        compact.contains('چهحکمی') ||
        compact.contains('صادرخواهدکرد') ||
        compact.contains('پیشبینینتیجه') ||
        compact.contains('نتیجهقطعی') ||
        compact.contains('حکمدقیق');
    return asksCase && asksPrediction;
  }

  String _assistantCapabilitiesText() {
    return replies.get('capabilities');
  }

  String _outcomePredictionText() {
    return replies.get('outcome_prediction');
  }

  String answer(String question) {
    final n = normalize(question);
    if (_asksAssistantCapabilities(n)) {
      return _assistantCapabilitiesText();
    }
    if (_asksOutcomePrediction(n)) {
      return _outcomePredictionText();
    }
    final art = RegExp(r'ماده\s*(\d+)(\s*مکرر)?').firstMatch(n);
    final qTokens = tokenize(question);
    if (qTokens.isEmpty && art == null) {
      if (n.contains('سلام')) return replies.get('greeting');
      return replies.get('ask_more');
    }
    if (_chunks.isEmpty) return replies.get('no_knowledge');

    if (_asksLawList(n)) return _lawListText();

    final mentioned = _mentionedLaws(question);
    final missing = mentioned.where((l) => !isLoaded(l.id)).toList();
    final loaded = mentioned.where((l) => isLoaded(l.id)).toList();
    final missingNote = missing.isEmpty
        ? ''
        : replies.get('missing_law', {'law': missing.first.title});

    if (loaded.isEmpty && missing.isNotEmpty) {
      return '$missingNote برای همین نمی‌توانم از روی آن جواب بدهم. می‌توانید از منبع رسمی قوانین، دفتر خدمات قضایی یا یک کارشناس حقوقی بپرسید.';
    }

    // شمارهٔ ماده با «قانون» ولی نام قانونی که نمی‌شناسیم
    if (art != null && mentioned.isEmpty && n.contains('قانون')) {
      final names = _loadedLaws().map((l) => l.title).join('، ');
      return 'نام این قانون را در فهرست خودم پیدا نکردم یا متنش در برنامه نیست.${names.isEmpty ? '' : ' قوانین موجود: $names.'} نام کامل قانون را بنویسید، مثلاً «ماده ۱۰ قانون مدنی».';
    }

    final r = rank(question, k: 4);

    if (art != null &&
        loaded.isNotEmpty &&
        (r.hits.isEmpty || r.hits.first.score < 99)) {
      final num = TemplateRenderer.toFa(art.group(1)!) +
          (art.group(2) != null ? ' مکرر' : '');
      return 'ماده $num در متن «${loaded.first.title}» که در برنامه است پیدا نشد. ممکن است چنین مادهٔ معتبری نباشد یا متن برنامه ناقص باشد. شمارهٔ ماده را دوباره بررسی کنید.${missingNote.isEmpty ? '' : '\n\n$missingNote'}';
    }

    if (r.hits.isEmpty || r.hits.first.score < 0.3) return _notFound();

    if ((art == null || r.hits.first.score < 99) &&
        coverage(question, r.hits.first.chunk) < _lowCover) {
      return _notFound();
    }
    final topBody = r.hits.first.chunk.body;
    if (art == null &&
        n.contains('کلاهبرداری') &&
        n.contains('مجازات') &&
        topBody.contains('اعلامیه پذیره‌نویسی')) {
      return _notFound();
    }
    var res = format(r.hits.first.chunk);
    if (r.note.isNotEmpty) res += '\n\n${r.note}';
    if (r.hits.length > 1) {
      final b = r.hits[0].score;
      if (b < 99) {
        final others = r.hits
            .skip(1)
            .where((h) => h.score >= 0.3 && h.score >= b * 0.5)
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
    return res;
  }

  /// پیشنهاد مواد نزدیک برای دکمه‌های گفتگو.
  /// هر پیشنهاد به شکل «ماده ۲۰۲ قانون مدنی» است و اگر کاربر آن را بزند،
  /// همان ماده دقیقاً پیدا می‌شود. در موارد نامطمئن فهرست خالی است.
  List<String> alternatives(String question, {int max = 3}) {
    final n = normalize(question);
    if (RegExp(r'ماده\s*\d+').hasMatch(n)) return [];
    if (_asksLawList(n)) return [];
    if (_mentionedLaws(question).any((l) => !isLoaded(l.id))) return [];
    final r = rank(question, k: 12);
    if (r.hits.length < 2) return [];
    final top = r.hits.first.score;
    if (top >= 99) return [];
    final articleTitle = RegExp(r'^ماده\s*\d+( مکرر)?$');
    final out = <String>[];
    for (final h in r.hits.skip(1)) {
      if (h.score < 0.3 || h.score < top * 0.4) continue;
      final c = h.chunk;
      if (c.source.isEmpty) continue;
      if (!articleTitle.hasMatch(normalize(c.title).trim())) continue;
      if (!_mentionedLaws(c.source).any((l) => l.id == c.lawId)) continue;
      out.add(TemplateRenderer.toFa('${c.title} ${c.source}'));
      if (out.length >= max) break;
    }
    return out;
  }

  String _notFound() {
    return replies.get('not_found');
  }
}
