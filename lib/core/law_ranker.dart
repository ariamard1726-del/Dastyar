import 'dart:math' as math;

import 'package:dastyar/core/article_query.dart';
import 'package:dastyar/core/engine_rules.dart';
import 'package:dastyar/core/law_index.dart';
import 'package:dastyar/core/law_mention.dart';
import 'package:dastyar/core/models.dart';
import 'package:dastyar/core/persian_text.dart';

/// امتیازدهیِ پرسش به بخش‌های قوانین (BM25F) و گسترشِ پیشوند.
///
/// پیش‌تر این منطق داخلِ `KnowledgeEngine` بود، کنارِ بارگذاریِ دارایی‌ها و
/// نوشتنِ متنِ پاسخ. حالا فقط دو چیز می‌داند: ایندکس (که آن هم صاحب دارد) و
/// چند تابعِ تزریق‌شده — کدام قانون نام برده شده، کدام متن موجود است،
/// ضریبِ موضوعیِ هر قانون، و مترادف‌ها. همین باعث می‌شود امتیازدهی را بتوان
/// بدونِ بانکِ قوانین آزمود (`test/core/law_ranker_test.dart`).
class LawRanker {
  LawRanker({
    required this.index,
    required this.mention,
    required this.isLoaded,
    required this.topicFactors,
    required this.expand,
    required this.synonyms,
  });

  final LawIndex index;
  final LawMention mention;
  final bool Function(String lawId) isLoaded;

  /// ضریبِ موضوعی هر قانون وقتی کاربر نامِ قانونی نگفته است.
  final Map<String, double> Function(String question) topicFactors;

  /// واژه‌های مترادفِ پرسش (از assets/synonyms.txt).
  final List<String> Function(String question) expand;

  /// جفت‌های مترادف، به‌همان ترتیبی که در فایل آمده‌اند.
  final List<List<String>> synonyms;

  // پارامترهای BM25F و قواعد تعریف از `dev/tools/contracts/engine_rules.json` می‌آیند.
  final double _k1 = EngineRules.bm25K1;
  final double _b = EngineRules.bm25B;
  final double _wT = EngineRules.bm25WT;
  final double _wB = EngineRules.bm25WB;
  final double _wC = EngineRules.bm25WC;

  static final RegExp _defQ = RegExp(EngineRules.defQuestionPattern);
  static const Set<String> _defWords = EngineRules.defWords;
  static const Set<String> _defMetaPrefixes = EngineRules.defMetaPrefixes;
  static final RegExp _defMark = RegExp(EngineRules.defMarkPattern);
  static final RegExp _defStrong = RegExp(EngineRules.defStrongPattern);

  RankResult rank(String question, {int k = 3}) {
  return rankInternal(question, k: k);
}

  RankResult rankInternal(
    String question, {
    List<CatalogLaw>? mentioned,
    int k = 3,
  }) {
    if (index.chunks.isEmpty) return RankResult([]);
    final q = PersianText.normalize(question);
    final qTokens = PersianText.tokenizeIndex(question).toSet().toList();

    final laws = mentioned ?? mention.mentioned(question);
    final ids = laws.where((l) => isLoaded(l.id)).map((l) => l.id).toSet();

    final art = ArticleQuery.re.firstMatch(q);
    if (art != null) {
      final want = ArticleQuery.canonical(ArticleQuery.wanted(art));
      final titleIndices = index.byTitle[want];
      if (titleIndices != null && titleIndices.isNotEmpty) {
        final found = <Chunk>[];
        for (final idx in titleIndices) {
          final c = index.chunks[idx];
          if (ids.isEmpty || ids.contains(c.lawId)) {
            found.add(c);
          }
        }
        if (found.isNotEmpty) {
          Chunk pick = found.first;
          var bestOverlap = -1;
          for (final c in found) {
            final st = PersianText.tokenizeIndex(c.source).toSet();
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
          return RankResult([Hit(pick, EngineRules.explicitScore)], note);
        }
      }
    }

    if (qTokens.isEmpty) return RankResult([]);

    final terms = <String, double>{};
    double total = 0;
    for (final t in qTokens) {
      total += index.idf[t] ?? 1.0;
      if (index.idf.containsKey(t)) {
        terms[t] = 1.0;
      } else if (t.length >= EngineRules.prefixMinLen) {
        _addPrefixTerms(t, terms);
      }
    }
    for (final t in expand(question)) {
      if (index.idf.containsKey(t)) terms[t] = math.max(terms[t] ?? 0, 1.0);
    }
    if (terms.isEmpty) return RankResult([]);

    // استفاده از نمایهٔ معکوس (Inverted Index) به‌جای پیمایش همهٔ چانک‌ها
    final candSet = <int>{};
    for (final t in terms.keys) {
      final list = index.postings[t];
      if (list != null) candSet.addAll(list);
    }
    if (candSet.isEmpty) return RankResult([]);
    final candIndices = candSet.toList()..sort();

    // ضریب موضوعی قانون‌ها؛ وقتی کاربر نام قانون را آورده، بی‌اثر است.
    final factors =
        ids.isEmpty ? topicFactors(question) : const <String, double>{};
    final hits = <Hit>[];
    for (final idx in candIndices) {
      final c = index.chunks[idx];
      if (ids.isNotEmpty && !ids.contains(c.lawId)) continue;
      double s = 0;
      final lenNorm = 1 - _b + _b * c.len / index.avgLen;
      terms.forEach((t, w) {
        final tf = _wT * (c.tfT[t] ?? 0) +
            _wB * (c.tfB[t] ?? 0) +
            _wC * (c.tfC[t] ?? 0);
        if (tf > 0) {
          final tfn = tf / lenNorm;
          s += w * (index.idf[t] ?? 1.0) * tfn * (_k1 + 1) / (tfn + _k1);
        }
      });
      if (s <= 0) continue;
      s = s / (total > 0 ? total : 1.0);
      if (c.obsolete) s *= EngineRules.obsoletePenalty;
      s *= factors[c.lawId] ?? 1.0;
      hits.add(Hit(c, s));
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return RankResult(
      promoteDefinitions(question, hits, factors).take(k).toList(),
    );
  }

  /// اگر پرسش از نوع «X چیست» بود، تا دو مادهٔ منسوخ‌نشده‌ای که متنشان با
  /// همان واژه شروع می‌شود و حالت تعریفی دارد («عقدی است…»، «عبارت است…»)
  /// به ابتدای فهرست می‌آیند. دانش عمومی و ماده‌های منسوخ هیچ‌وقت نمی‌آیند.
  List<Hit> promoteDefinitions(
    String question,
    List<Hit> hits, [
    Map<String, double> factors = const {},
  ]) {
    if (hits.isEmpty || !_defQ.hasMatch(PersianText.normalize(question))) return hits;
    final boosted = {
      for (final e in factors.entries)
        if (e.value > 1.0) e.key,
    };
    var toks =
        PersianText.tokenizeIndex(question).where((t) => !_defWords.contains(t)).toList();
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
        // تعریفِ قانونِ نامرتبط با موضوع پرسش جلو نمی‌آید.
        if ((factors[c.lawId] ?? 1.0) < 1.0) continue;
        if (boosted.isNotEmpty && !boosted.contains(c.lawId)) continue;
        final body = LawIndex.cleanBody(c.body);
        final p = body.startsWith(term)
            ? term
            : (body.startsWith('عقد $term') ? 'عقد $term' : null);
        if (p == null) continue;
        final end = math.min(body.length, p.length + EngineRules.defTailWindow);
        final tail = body.substring(p.length, end);
        if (!_defMark.hasMatch(tail)) continue;
        (_defStrong.hasMatch(tail) ? strong : weak).add(h);
      }
      cands = [...strong, ...weak];
      if (cands.isNotEmpty) break;
    }
    if (cands.isEmpty) return hits;
    final picked = cands.take(EngineRules.defMaxPicked).toList();
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

  double coverage(String question, Chunk c) {
  final qt = PersianText.tokenizeIndex(question).toSet().toList();
  if (qt.isEmpty || index.idf.isEmpty) return 0.0;
  bool has(String t) =>
      c.tfT.containsKey(t) || c.tfB.containsKey(t) || c.tfC.containsKey(t);
  var den = 0.0;
  var got = 0.0;
  final covered = <String>{};
  for (final t in qt) {
    den += index.idf[t] ?? index.maxIdf;
    if (has(t)) {
      covered.add(t);
      got += index.idf[t] ?? index.maxIdf;
    } else if (!index.idf.containsKey(t) && t.length >= EngineRules.prefixMinLen) {
      var pref = false;
      for (final m in [c.tfT, c.tfB, c.tfC]) {
        for (final v in m.keys) {
          if (v.length >= EngineRules.prefixMinLen && (v.startsWith(t) || t.startsWith(v))) {
            pref = true;
            break;
          }
        }
        if (pref) break;
      }
      if (pref) {
        covered.add(t);
        got += EngineRules.prefixWeight * index.maxIdf;
      }
    }
  }
  final n = ' ${PersianText.phrase(question)} ';
  for (final r in synonyms) {
    if (!n.contains(' ${r[0]} ')) continue;
    if (!PersianText.tokenizeIndex(r[1]).any(has)) continue;
    for (final t in PersianText.tokenizeIndex(r[0])) {
      if (qt.contains(t) && !covered.contains(t)) {
        covered.add(t);
        got += index.idf[t] ?? index.maxIdf;
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

  void _addPrefixTerms(String t, Map<String, double> terms) {
  for (var len = EngineRules.prefixMinLen; len < t.length; len++) {
    final sub = t.substring(0, len);
    if (index.idf.containsKey(sub)) {
      terms[sub] = math.max(terms[sub] ?? 0, EngineRules.prefixWeight);
    }
  }
  var i = _lowerBound(index.vocab, t);
  while (i < index.vocab.length && index.vocab[i].startsWith(t)) {
    final v = index.vocab[i];
    terms[v] = math.max(terms[v] ?? 0, EngineRules.prefixWeight);
    i++;
  }
}
}
