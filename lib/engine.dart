import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle, AssetManifest;

import 'templates.dart' show TemplateRenderer;

class Chunk {
  final String lawId;
  final String source;
  final String chapter;
  final String title;
  final String body;
  final bool obsolete;
  final Map<String, int> tf;
  Chunk(
    this.lawId,
    this.source,
    this.chapter,
    this.title,
    this.body,
    this.obsolete,
    this.tf,
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
  final List<Chunk> _chunks = [];
  final Map<String, double> _idf = {};
  final Map<String, int> _lawCounts = {};
  List<String> _vocab = [];

  final List<CatalogLaw> catalog = [];
  final Map<String, String> categoryNames = {};
  final Map<String, Map<String, dynamic>> meta = {};

  int get size => _chunks.length;
  Map<String, int> get lawCounts => _lawCounts;
  bool isLoaded(String id) => (_lawCounts[id] ?? 0) > 0;

  static const Set<String> _stop = {
    'و', 'در', 'به', 'از', 'که', 'را', 'با', 'این', 'آن', 'برای', 'یک',
    'است', 'هست', 'چه', 'چی', 'چیست', 'کی', 'کجا', 'چرا', 'چطور',
    'چگونه', 'آیا', 'من', 'تو', 'شما', 'می', 'هم', 'یا', 'تا', 'بر',
    'هر', 'بود', 'شد', 'باشد', 'کند', 'کنم', 'کن', 'بگو',
    'درباره', 'مورد', 'لطفا', 'ممنون', 'ماده', 'قانون',
  };

  static const List<String> _suffixes = [
    'ترین', 'هایی', 'های', 'ها', 'تر', 'ان', 'ات', 'ی',
  ];

  static String normalize(String s) {
    const map = {
      'ي': 'ی', 'ى': 'ی', 'ك': 'ک', 'ۀ': 'ه', 'ة': 'ه',
      'أ': 'ا', 'إ': 'ا', 'ٱ': 'ا',
    };
    final sb = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x06F0 && r <= 0x06F9) {
        sb.write(r - 0x06F0);
        continue;
      }
      if (r >= 0x0660 && r <= 0x0669) {
        sb.write(r - 0x0660);
        continue;
      }
      if (r == 0x200C || r == 0x200D || r == 0x200E || r == 0x200F) {
        sb.write(' ');
        continue;
      }
      if (r >= 0x064B && r <= 0x065F) continue;
      if (r == 0x0640) continue;
      final ch = String.fromCharCode(r);
      sb.write(map[ch] ?? ch);
    }
    return sb.toString().toLowerCase();
  }

  static String _collapse(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String _stem(String w) {
    for (final suf in _suffixes) {
      if (w.length - suf.length >= 3 && w.endsWith(suf)) {
        return w.substring(0, w.length - suf.length);
      }
    }
    return w;
  }

  static final RegExp _nonWord = RegExp(
    r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+',
  );

  static List<String> tokenize(String s) {
    final cleaned = normalize(s).replaceAll(_nonWord, ' ');
    final out = <String>[];
    for (final w in cleaned.split(' ')) {
      if (w.isEmpty || _stop.contains(w)) continue;
      out.add(_stem(w));
    }
    return out;
  }

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
    } catch (_) {}

    try {
      final t = await rootBundle.loadString('assets/laws/_meta.json');
      final m = jsonDecode(t) as Map<String, dynamic>;
      m.forEach((k, v) {
        if (v is Map<String, dynamic>) meta[k] = v;
      });
    } catch (_) {}

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where((p) =>
            p == 'assets/knowledge.txt' ||
            (p.startsWith('assets/laws/') && p.endsWith('.txt')))
        .toList()
      ..sort();
    for (final p in paths) {
      String text;
      try {
        text = await rootBundle.loadString(p);
      } catch (_) {
        continue;
      }
      if (p == 'assets/knowledge.txt') {
        await _parse(text, 'دانش عمومی', 'knowledge');
      } else {
        final stem = p.split('/').last.replaceAll('.txt', '');
        await _parse(text, '', stem);
      }
    }
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
      final tf = <String, int>{};
      for (final t in tokenize(first)) {
        tf[t] = (tf[t] ?? 0) + 2;
      }
      for (final t in tokenize(body)) {
        tf[t] = (tf[t] ?? 0) + 1;
      }
      for (final t in tokenize(chapter)) {
        tf[t] = (tf[t] ?? 0) + 1;
      }
      for (final t in tokenize(source)) {
        tf[t] = (tf[t] ?? 0) + 1;
      }
      _chunks.add(Chunk(
        lawId,
        source,
        chapter,
        first,
        body,
        body != first && _isObsolete(body),
        tf,
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
    for (final c in _chunks) {
      for (final t in c.tf.keys) {
        df[t] = (df[t] ?? 0) + 1;
      }
    }
    final n = _chunks.length;
    df.forEach((t, d) {
      _idf[t] = math.log((n + 1) / (d + 1)) + 1.0;
    });
    _vocab = df.keys.toList();
  }

  /// متن رسمی یک ماده را با نام قانون و شمارهٔ ماده پیدا می‌کند.
  /// اگر در بستهٔ قوانین نباشد null برمی‌گرداند و هرگز متنی نمی‌سازد.
  Chunk? findArticle(String law, String article) {
    final want = 'ماده ${_collapse(normalize(article))}';
    final lawN = _collapse(normalize(law));
    if (lawN.isEmpty) return null;
    for (final c in _chunks) {
      if (_collapse(normalize(c.title)) != want) continue;
      final s = _collapse(normalize(c.source));
      if (s.isEmpty) continue;
      if (s == lawN || s.contains(lawN) || lawN.contains(s)) return c;
    }
    return null;
  }

  /// قوانین فهرست که نام یا نام رایجشان در پرسش آمده است.
  List<CatalogLaw> _mentionedLaws(String q) {
    final n = _collapse(normalize(q));
    final out = <CatalogLaw>[];
    for (final l in catalog) {
      var hit = false;
      for (final name in [l.title, ...l.aliases]) {
        final full = _collapse(normalize(name));
        if (full.isEmpty) continue;
        if (n.contains(full)) {
          hit = true;
          break;
        }
        final short =
            full.startsWith('قانون ') ? full.substring(6).trim() : full;
        if (short.length >= 5 && n.contains(short)) {
          hit = true;
          break;
        }
      }
      if (hit) out.add(l);
    }
    return out;
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
    if (loaded.isEmpty) return 'هنوز متن هیچ قانونی در برنامه نیست.';
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

  RankResult rank(String question, {int k = 3}) {
    if (_chunks.isEmpty) return RankResult([]);
    final q = normalize(question);
    final qTokens = tokenize(question).toSet().toList();

    final ids = _mentionedLaws(question)
        .where((l) => isLoaded(l.id))
        .map((l) => l.id)
        .toSet();
    final pool =
        ids.isEmpty ? _chunks : _chunks.where((c) => ids.contains(c.lawId)).toList();

    final art = RegExp(r'ماده\s*(\d+)').firstMatch(q);
    if (art != null) {
      final want = 'ماده ${art.group(1)}';
      final found =
          pool.where((c) => normalize(c.title).trim() == want).toList();
      if (found.isNotEmpty) {
        Chunk pick = found.first;
        var bestOverlap = -1;
        for (final c in found) {
          final st = tokenize(c.source).toSet();
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
    if (terms.isEmpty) return RankResult([]);

    final hits = <Hit>[];
    for (final c in pool) {
      double s = 0;
      terms.forEach((t, w) {
        final tf = c.tf[t];
        if (tf != null) s += w * (_idf[t] ?? 1.0) * (1 + math.log(tf));
      });
      if (s <= 0) continue;
      s = s / total;
      if (c.obsolete) s *= 0.1;
      hits.add(Hit(c, s));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return RankResult(hits.take(k).toList());
  }

  String answer(String question) {
    final n = normalize(question);
    final art = RegExp(r'ماده\s*(\d+)').firstMatch(n);
    final qTokens = tokenize(question);
    if (qTokens.isEmpty && art == null) {
      if (n.contains('سلام')) return 'سلام! چه کمکی از من برمی‌آید؟';
      return 'لطفاً پرسش خود را کامل‌تر بنویسید.';
    }
    if (_chunks.isEmpty) return 'هنوز دانشی در برنامه نیست.';

    if (_asksLawList(n)) return _lawListText();

    final mentioned = _mentionedLaws(question);
    final missing = mentioned.where((l) => !isLoaded(l.id)).toList();
    final loaded = mentioned.where((l) => isLoaded(l.id)).toList();
    final missingNote = missing.isEmpty
        ? ''
        : 'توجه: متن «${missing.first.title}» هنوز در برنامه نیست.';

    if (loaded.isEmpty && missing.isNotEmpty) {
      return '$missingNote برای همین نمی‌توانم از روی آن جواب بدهم. می‌توانید از منبع رسمی قوانین، دفتر خدمات قضایی یا یک کارشناس حقوقی بپرسید.';
    }

    // شمارهٔ ماده با «قانون» ولی نام قانونی که نمی‌شناسیم
    if (art != null && mentioned.isEmpty && n.contains('قانون')) {
      final names = _loadedLaws().map((l) => l.title).join('، ');
      return 'نام این قانون را در فهرست خودم پیدا نکردم یا متنش در برنامه نیست.${names.isEmpty ? '' : ' قوانین موجود: $names.'} نام کامل قانون را بنویسید، مثلاً «ماده ۱۰ قانون مدنی».';
    }

    final r = rank(question, k: 2);

    if (art != null &&
        loaded.isNotEmpty &&
        (r.hits.isEmpty || r.hits.first.score < 99)) {
      final num = TemplateRenderer.toFa(art.group(1)!);
      return 'ماده $num در متن «${loaded.first.title}» که در برنامه است پیدا نشد. ممکن است چنین مادهٔ معتبری نباشد یا متن برنامه ناقص باشد. شمارهٔ ماده را دوباره بررسی کنید.${missingNote.isEmpty ? '' : '\n\n$missingNote'}';
    }

    if (r.hits.isEmpty || r.hits.first.score < 0.3) return _notFound();

    var res = format(r.hits.first.chunk);
    if (r.note.isNotEmpty) res += '\n\n${r.note}';
    if (r.hits.length > 1) {
      final b = r.hits[0].score;
      final s = r.hits[1];
      if (b < 99 && s.score >= b * 0.8 && s.score >= 0.3) {
        res += '\n\nموضوع مرتبط: ${s.chunk.title}';
      }
    }
    if (missingNote.isNotEmpty) res += '\n\n$missingNote';
    return res;
  }

  String _notFound() {
    return 'پاسخ این پرسش را در دانش خودم پیدا نکردم. پرسش را با کلمات دیگر بنویسید.';
  }
}
