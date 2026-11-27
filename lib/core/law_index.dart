import 'dart:isolate';
import 'dart:math' as math;

import 'package:dastyar/core/engine_rules.dart';
import 'package:dastyar/core/models.dart';
import 'package:dastyar/core/persian_text.dart';

/// ایندکسِ متنِ قوانین: بخش‌ها، نمایهٔ واژه‌ها (BM25F)، فهرستِ وارونه و
/// فهرستِ «شناسهٔ قانون + عنوان ماده» → شمارهٔ بخش.
///
/// این داده و ساختِ آن پیش‌تر داخلِ `KnowledgeEngine` بود، کنارِ امتیازدهی و
/// قالب‌بندیِ پاسخ و بارگذاریِ دارایی‌ها؛ یعنی یک کلاس هم بانک می‌ساخت، هم
/// جست‌وجو می‌کرد، هم متن می‌نوشت. حالا ایندکس صاحبِ خودش را دارد.
class LawIndex {
  final List<Chunk> chunks = [];
  final Map<String, int> lawCounts = {};
  final Map<String, double> idf = {};
  final Map<String, List<int>> postings = {};
  final Map<String, List<int>> byTitle = {};
  double avgLen = 1.0;
  double maxIdf = 1.0;
  List<String> vocab = [];

  /// «شناسهٔ قانون + عنوان ماده» → شمارهٔ بخش؛ یک بار ساخته می‌شود تا
  /// یافتن متن یک ماده در هر پیام روی کل بانک خطی نگردد.
  Map<String, int>? _articleIndex;

  int get size => chunks.length;

  /// پیش از هر بارگذاریِ تازه.
  void clear() {
    chunks.clear();
    lawCounts.clear();
    idf.clear();
    postings.clear();
    byTitle.clear();
    vocab = [];
    avgLen = 1.0;
    maxIdf = 1.0;
    _articleIndex = null;
  }

  /// نتیجهٔ ساختِ نمایه (که ممکن است از Isolate برگشته باشد) را بپذیر.
  void adopt(IndexBuild b) {
    chunks
      ..clear()
      ..addAll(b.chunks);
    lawCounts
      ..clear()
      ..addAll(b.lawCounts);
    idf
      ..clear()
      ..addAll(b.idf);
    postings
      ..clear()
      ..addAll(b.postings);
    byTitle
      ..clear()
      ..addAll(b.byTitle);
    avgLen = b.avgLen;
    maxIdf = b.maxIdf;
    vocab = b.vocab;
    _articleIndex = null;
  }

  static final RegExp _obsoleteTrimRe = RegExp(EngineRules.obsoleteTrimPattern);
  static final RegExp _paraSplitRe = RegExp(r'\n\s*\n');
  static final RegExp _hashPrefixRe = RegExp(r'^#+\s*');
  static final RegExp _cleanBodyRe = RegExp(EngineRules.cleanBodyPattern);
  static bool isObsolete(String body) {
    var n = PersianText.collapse(PersianText.normalize(body));
    if (n.length > EngineRules.obsoleteMaxLen) return false;
    n = n.replaceFirst(_obsoleteTrimRe, '');
    return EngineRules.obsoletePrefixes.any(n.startsWith);
  }

  static Future<IndexBuild> buildAsync(List<List<String>> raw) =>
      Isolate.run(() => build(raw));
  static IndexBuild build(List<List<String>> raw) {
    final chunks = <Chunk>[];
    final counts = <String, int>{};
    for (final r in raw) {
      parseInto(r[2], r[1], r[0], chunks, counts);
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
    return IndexBuild(chunks, counts, idf, postings, byTitle, avg, maxIdf, vocab);
  }

  static void parseInto(
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
      for (final t in PersianText.tokenizeIndex(first)) {
        tfT[t] = (tfT[t] ?? 0) + 1;
        len++;
      }
      for (final t in PersianText.tokenizeIndex(body)) {
        tfB[t] = (tfB[t] ?? 0) + 1;
        len++;
      }
      for (final t in PersianText.tokenizeIndex(chapter)) {
        tfC[t] = (tfC[t] ?? 0) + 1;
        len++;
      }
      for (final t in PersianText.tokenizeIndex(source)) {
        tfC[t] = (tfC[t] ?? 0) + 1;
        len++;
      }
      out.add(Chunk(
        lawId,
        source,
        chapter,
        first,
        body,
        body != first && isObsolete(body),
        tfT,
        tfB,
        tfC,
        len,
      ));
      counts[lawId] = (counts[lawId] ?? 0) + 1;
    }
  }
  /// متنِ ماده بدونِ سرِ پرانتزی («(اصلاحی …)») برای مقایسه.

  static String cleanBody(String body) => PersianText.collapse(
          PersianText.normalize(body))
      .replaceFirst(_cleanBodyRe, '');

  static bool chunkHasTerm(Chunk c, String t) =>
      c.tfT.containsKey(t) || c.tfB.containsKey(t) || c.tfC.containsKey(t);

  int? chunkOf(String lawId, String title) {
    var idx = _articleIndex;
    if (idx == null) {
      idx = <String, int>{};
      for (var i = 0; i < chunks.length; i++) {
        final c = chunks[i];
        idx.putIfAbsent('${c.lawId}\u0000${c.title}', () => i);
      }
      _articleIndex = idx;
    }
    return idx['$lawId\u0000$title'];
  }
}

/// نتیجهٔ ساختِ نمایه که از Isolate به رشتهٔ اصلی برمی‌گردد.
class IndexBuild {
  final List<Chunk> chunks;
  final Map<String, int> lawCounts;
  final Map<String, double> idf;
  final Map<String, List<int>> postings;
  final Map<String, List<int>> byTitle;
  final double avgLen;
  final double maxIdf;
  final List<String> vocab;

  IndexBuild(
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
