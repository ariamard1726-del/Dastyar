import 'dart:math' as math;

import 'package:flutter/services.dart' show rootBundle, AssetManifest;

class Chunk {
  final String source;
  final String title;
  final String body;
  final Map<String, int> tf;
  Chunk(this.source, this.title, this.body, this.tf);
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

class KnowledgeEngine {
  final List<Chunk> _chunks = [];
  final Map<String, double> _idf = {};
  List<String> _vocab = [];

  int get size => _chunks.length;

  static const Set<String> _stop = {
    'و', 'در', 'به', 'از', 'که', 'را', 'با', 'این', 'آن', 'برای', 'یک',
    'است', 'هست', 'چه', 'چی', 'چیست', 'کی', 'کجا', 'چرا', 'چطور',
    'چگونه', 'آیا', 'من', 'تو', 'شما', 'می', 'هم', 'یا', 'تا', 'بر',
    'هر', 'بود', 'شد', 'باشد', 'کند', 'کنم', 'کن', 'بگو',
    'درباره', 'مورد', 'لطفا', 'ممنون',
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

  Future<void> load() async {
    _chunks.clear();
    _idf.clear();
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
      await _parse(text, p == 'assets/knowledge.txt' ? 'دانش عمومی' : '');
    }
    _buildIndex();
  }

  Future<void> _parse(String text, String defaultSource) async {
    var source = defaultSource;
    final parts = text.replaceAll('\r', '').split(RegExp(r'\n\s*\n'));
    var n = 0;
    for (final p in parts) {
      final lines = p.trim().split('\n');
      if (lines.isEmpty || lines.first.trim().isEmpty) continue;
      final first = lines.first.trim();
      if (first.startsWith('#')) {
        source = first.replaceFirst(RegExp(r'^#+\s*'), '').trim();
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
      _chunks.add(Chunk(source, first, body, tf));
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

  String format(Chunk c) {
    final src = c.source.isEmpty ? '' : '\n\nمنبع: ${c.source}';
    if (c.body == c.title) return '${c.title}$src';
    return '${c.title}\n${c.body}$src';
  }

  RankResult rank(String question, {int k = 3}) {
    final q = normalize(question);
    final qTokens = tokenize(question).toSet().toList();
    if (qTokens.isEmpty || _chunks.isEmpty) return RankResult([]);

    final art = RegExp(r'ماده\s*(\d+)').firstMatch(q);
    if (art != null) {
      final want = 'ماده ${art.group(1)}';
      final found =
          _chunks.where((c) => normalize(c.title).trim() == want).toList();
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
    for (final c in _chunks) {
      double s = 0;
      terms.forEach((t, w) {
        final tf = c.tf[t];
        if (tf != null) s += w * (_idf[t] ?? 1.0) * (1 + math.log(tf));
      });
      if (s > 0) hits.add(Hit(c, s / total));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return RankResult(hits.take(k).toList());
  }

  String answer(String question) {
    final qTokens = tokenize(question);
    if (qTokens.isEmpty) {
      if (normalize(question).contains('سلام')) {
        return 'سلام! چه کمکی از من برمی‌آید؟';
      }
      return 'لطفاً پرسش خود را کامل‌تر بنویسید.';
    }
    if (_chunks.isEmpty) return 'هنوز دانشی در برنامه نیست.';

    final r = rank(question, k: 2);
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
    return res;
  }

  String _notFound() {
    return 'پاسخ این پرسش را در دانش خودم پیدا نکردم. پرسش را با کلمات دیگر بنویسید.';
  }
}
