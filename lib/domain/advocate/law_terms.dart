import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/text_norm_rules.dart';
import 'package:dastyar/domain/advocate/law_terms_rules.dart';

/// نتیجهٔ تطبیق واژه‌های پرسش با متن قوانین.
class TermMatch {
  /// آیا ماده‌ای با دلیل کافی پیدا شد که متنش نشان داده شود.
  final bool accepted;

  /// بهترین ماده (یا null اگر هیچ ماده‌ای واژه‌ای از پرسش نداشت).
  final Chunk? chunk;

  /// سهم وزنیِ واژه‌های پرسش که در بهترین ماده هست (۰ تا ۱).
  final double cover;

  /// واژه‌های پرسش که در بهترین ماده آمده‌اند.
  final List<String> matched;

  /// واژه‌های پرسش که در بهترین ماده نیستند.
  final List<String> missing;

  /// واژه‌هایی که اصلاً در هیچ قانونی نیستند.
  final List<String> unknown;

  /// عبارت‌های دوواژه‌ای پرسش که عیناً در ماده‌اند («بیع شرط»).
  final List<String> phrases;

  const TermMatch({
    required this.accepted,
    required this.chunk,
    required this.cover,
    required this.matched,
    required this.missing,
    required this.unknown,
    required this.phrases,
  });
}

/// تطبیق واژه‌های متن کاربر با متن قوانین (نسخهٔ دارت آیینهٔ dev/tools/law_terms.py).
///
/// هر پرسش به «دنباله‌های پیوسته» از واژه‌های معنادار شکسته می‌شود؛ ایست‌واژه،
/// واژهٔ بی‌بار و علامت دنباله را می‌شکنند. سپس ماده‌ای انتخاب می‌شود که بیشترین
/// پوشش وزنی را دارد، و فقط وقتی پذیرفته می‌شود که دلیل روشن داشته باشد:
/// عبارت دوواژه‌ای عیناً در متن باشد، یا چند واژهٔ نادرِ پرسش در فاصلهٔ نزدیک
/// هم در ماده باشند. هیچ متنی ساخته نمی‌شود؛ فقط متن رسمی ماده نشان داده می‌شود.
class LawTerms {
  LawTerms(this.engine);

  final KnowledgeEngine engine;

  // قاعده‌ها در `dev/tools/contracts/law_terms.json` هستند و از آن‌جا تولید
  // می‌شوند (`law_terms_rules.dart`). پیش‌تر فهرست ۱۵۳ واژه‌ای و آستانه‌ها
  // این‌جا و در `dev/tools/law_terms.py` دستی نگه داشته می‌شد و آزمون آینه فقط
  // از واگرایی جلوگیری می‌کرد، نه از خودِ دوتا‌بودن.
  /// املای محاوره‌ای یا عربیِ رایج که در متن قوانین جور دیگری است.
  static const Map<String, String> alias = LawTermsRules.alias;

  /// واژه‌های گفتاری یا عمومیِ بی‌بار که در تطبیق شرکت نمی‌کنند.
  static const Set<String> generic = LawTermsRules.generic;

  /// کوتاه‌تر از این تعداد نویسه، واژهٔ معنادار حساب نمی‌شود.
  static const int minLen = LawTermsRules.minLen;

  static const int topCount = LawTermsRules.topCount;

  static const int rareDf = LawTermsRules.rareDf;

  static const double minCover = LawTermsRules.minCover;

  static const double phraseMinIdf = LawTermsRules.phraseMinIdf;

  static const int maxSpan = LawTermsRules.maxSpan;

  static const int defaultPriority = LawTermsRules.defaultPriority;
  static const int missingSpan = LawTermsRules.missingSpan;
  static const int coverDigits = LawTermsRules.coverDigits;
  static const int rankCoverDigits = LawTermsRules.rankCoverDigits;
  static const int rankDensityDigits = LawTermsRules.rankDensityDigits;
  static const int minPhraseWords = LawTermsRules.minPhraseWords;
  static const int minRareHits = LawTermsRules.minRareHits;

  static const String generalSource = LawTermsRules.generalSource;

  static final RegExp _punct = RegExp(TextNormRules.spacedTermsPunct);
  static final RegExp _nonWord = RegExp(TextNormRules.nonWord);

  final Map<int, List<String>> _bodyCache = {};
  final Map<int, List<String>> _headCache = {};

  /// واژه‌های پرسش در دنباله‌های پیوسته.
  static List<List<String>> runs(String q) {
    final out = <List<String>>[];
    for (final seg in PersianText.normalize(q).split(_punct)) {
      var cur = <String>[];
      for (final raw in seg.replaceAll(_nonWord, ' ').split(' ')) {
        if (raw.isEmpty) continue;
        final w = alias[raw] ?? raw;
        final short = w.length < minLen;
        final st = generic.contains(w) || short ? const <String>[] : PersianText.tokenizeIndex(w);
        if (st.isEmpty) {
          if (cur.isNotEmpty) out.add(cur);
          cur = <String>[];
          continue;
        }
        cur.add(st.first);
      }
      if (cur.isNotEmpty) out.add(cur);
    }
    return out;
  }

  static List<(String, String)> _pairsOf(List<List<String>> rs, Map<String, double> idf) {
    final out = <(String, String)>[];
    for (final run in rs) {
      for (var i = 0; i + 1 < run.length; i++) {
        if (run[i] == run[i + 1]) continue;
        final w = (idf[run[i]] ?? 0) + (idf[run[i + 1]] ?? 0);
        if (w >= phraseMinIdf) out.add((run[i], run[i + 1]));
      }
    }
    return out;
  }

  static bool _hasPair(List<String> toks, (String, String) p) {
    for (var k = 0; k + 1 < toks.length; k++) {
      if (toks[k] == p.$1 && toks[k + 1] == p.$2) return true;
    }
    return false;
  }

  static int _span(List<String> toks, List<String> words) {
    final need = words.toSet();
    if (need.isEmpty) return 0;
    int? best;
    final count = <String, int>{};
    var left = 0;
    var have = 0;
    for (var right = 0; right < toks.length; right++) {
      final t = toks[right];
      if (need.contains(t)) {
        count[t] = (count[t] ?? 0) + 1;
        if (count[t] == 1) have++;
      }
      while (have == need.length && left <= right) {
        final span = right - left + 1;
        if (best == null || span < best) best = span;
        final lt = toks[left];
        if (need.contains(lt)) {
          count[lt] = count[lt]! - 1;
          if (count[lt] == 0) have--;
        }
        left++;
      }
    }
    return best ?? missingSpan;
  }

  List<String> _body(int i, Chunk c) =>
      _bodyCache.putIfAbsent(i, () => PersianText.tokenizeIndex('${c.body} ${c.title}'));

  List<String> _head(int i, Chunk c) =>
      _headCache.putIfAbsent(i, () => PersianText.tokenizeIndex('${c.chapter} ${c.title}'));

  static double _round(double v, int digits) {
    final f = _pow10(digits);
    return (v * f).roundToDouble() / f;
  }

  static double _pow10(int d) {
    var f = 1.0;
    for (var i = 0; i < d; i++) {
      f *= 10;
    }
    return f;
  }

  /// همتای `glossary_match` در dev/tools/law_terms.py: اگر عبارتی از فهرست واژه‌های
  /// حقوقی در پرسش باشد، ماده‌ٔ همان عبارت پذیرفته می‌شود (بلندترین عبارت برنده است).
  TermMatch? _glossary(String q) {
    final entries = engine.legalTerms['entries'];
    if (entries is! List) return null;
    final text = spaced(q);
    String? bestPhrase;
    Map<String, dynamic>? bestEntry;
    for (final entry in entries.cast<Map<String, dynamic>>()) {
      for (final ph in (entry['phrases'] as List).cast<String>()) {
        final p = spaced(ph);
        if (text.contains(p) && (bestPhrase == null || p.length > spaced(bestPhrase).length)) {
          bestPhrase = ph;
          bestEntry = entry;
        }
      }
    }
    if (bestPhrase == null || bestEntry == null) return null;
    final at = engine.chunkOf(
        (bestEntry['law'] ?? '').toString(), (bestEntry['title'] ?? '').toString());
    if (at == null) return null;
    final target = engine.chunks[at];
    return TermMatch(
      accepted: true,
      chunk: target,
      cover: 1.0,
      matched: bestPhrase.split(' '),
      missing: const [],
      unknown: const [],
      phrases: [bestPhrase],
    );
  }

  /// یکدست‌سازی متن برای تطبیق عبارت از روی قرارداد `text_norm.json` (`spaced.terms`).
  static String spaced(String s) => PersianText.spacedWith(
        s,
        charMap: TextNormRules.spacedTermsMap,
        dropRanges: TextNormRules.spacedTermsDropRanges,
        punct: _punct,
        pad: TextNormRules.spacedTermsPad,
      );

  /// بهترین ماده برای پرسش، با دلیل پذیرش.
  TermMatch match(String q) {
    final g = _glossary(q);
    if (g != null) return g;
    final rs = runs(q);
    final seq = <String>[for (final r in rs) ...r];
    // Set در دارت ترتیب درج را نگه می‌دارد، پس ترتیب اولین آمدن واژه‌ها حفظ می‌شود.
    final uniq = seq.toSet().toList();
    final idf = engine.idf;
    final postings = engine.postings;
    final chunks = engine.chunks;
    final known = [for (final t in uniq) if (idf.containsKey(t)) t];
    final unknown = [for (final t in uniq) if (!idf.containsKey(t)) t];
    var total = 0.0;
    for (final t in known) {
      total += idf[t]!;
    }
    if (total == 0) total = 1.0;

    final score = <int, double>{};
    final hits = <int, List<String>>{};
    for (final t in known) {
      for (final i in postings[t] ?? const <int>[]) {
        final c = chunks[i];
        if (c.source == generalSource || c.obsolete) continue;
        score[i] = (score[i] ?? 0) + idf[t]!;
        (hits[i] ??= <String>[]).add(t);
      }
    }
    final pairs = _pairsOf(rs, idf);
    final prio = {for (final l in engine.catalog) l.id: l.priority};

    final ranked = score.keys.toList()
      ..sort((a, b) {
        final c1 = score[b]!.compareTo(score[a]!);
        if (c1 != 0) return c1;
        final c2 = hits[b]!.length.compareTo(hits[a]!.length);
        if (c2 != 0) return c2;
        return a.compareTo(b);
      });
    final top = ranked.length > topCount ? ranked.sublist(0, topCount) : ranked;

    int? best;
    List<num>? bestKey;
    for (final i in top) {
      final key = _rankKey(i, chunks[i], score[i]! / total, hits[i]!, pairs, prio);
      if (bestKey == null || _greater(key, bestKey)) {
        best = i;
        bestKey = key;
      }
    }
    if (best == null) {
      return TermMatch(
        accepted: false,
        chunk: null,
        cover: 0,
        matched: const [],
        missing: uniq,
        unknown: unknown,
        phrases: const [],
      );
    }
    final c = chunks[best];
    final bt = _body(best, c);
    final ph = [for (final p in pairs) if (_hasPair(bt, p)) '${p.$1} ${p.$2}'];
    final matched = hits[best]!;
    final cover = score[best]! / total;
    final m = matched.length;
    final headToks = _head(best, c);
    final headHit = pairs.any((p) => _hasPair(headToks, p));
    var rareN = 0;
    for (final t in matched) {
      if ((postings[t]?.length ?? 0) <= rareDf) rareN++;
    }
    final near = _span(bt, matched) <= maxSpan;
    // واژهٔ نادرِ پرسش که در ماده نیست یعنی ماده بخشی از پرسش را پوشش می‌دهد؛
    // با عبارت یا عنوان پذیرفته نمی‌شود (همتای dev/tools/law_terms.py).
    final rareMissing = [
      for (final t in known)
        if ((postings[t]?.length ?? 0) <= rareDf && !matched.contains(t)) t
    ];
    final accepted = (((ph.isNotEmpty && m >= minPhraseWords) || headHit) && rareMissing.isEmpty) ||
        (cover >= minCover && rareN >= minRareHits && near);
    return TermMatch(
      accepted: accepted,
      chunk: c,
      cover: _round(cover, coverDigits),
      matched: matched,
      missing: [for (final t in uniq) if (!matched.contains(t)) t],
      unknown: unknown,
      phrases: ph,
    );
  }

  List<num> _rankKey(int i, Chunk c, double cover, List<String> matched,
      List<(String, String)> pairs, Map<String, int> prio) {
    final bt = _body(i, c);
    var ph = 0;
    for (final p in pairs) {
      if (_hasPair(bt, p)) ph++;
    }
    final headToks = _head(i, c);
    var headPairs = 0;
    for (final p in pairs) {
      if (_hasPair(headToks, p)) headPairs++;
    }
    var headWords = 0;
    for (final t in matched) {
      if (headToks.contains(t)) headWords++;
    }
    var tf = 0;
    for (final t in matched) {
      tf += (c.tfT[t] ?? 0) + (c.tfB[t] ?? 0);
    }
    final density = tf / (c.len < 1 ? 1 : c.len);
    return [
      ph > 0 ? 1 : 0,
      headPairs,
      headWords,
      _round(cover, rankCoverDigits),
      -(prio[c.lawId] ?? defaultPriority),
      _round(density, rankDensityDigits),
      -i,
    ];
  }

  static bool _greater(List<num> a, List<num> b) {
    for (var k = 0; k < a.length; k++) {
      final d = a[k].compareTo(b[k]);
      if (d != 0) return d > 0;
    }
    return false;
  }
}
