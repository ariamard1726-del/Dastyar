import 'dart:convert';

/// توکن‌سازِ مدل Noql به Dart خالص.
///
/// هم‌ارزِ `tokenizer.json` مدل است: یکدست‌کردن فاصله‌ها، Metaspace (هر واژه
/// با «▁» شروع می‌شود)، مدل Unigram با جست‌وجوی بهترین مسیر، و برای نویسهٔ
/// ناشناخته بایت‌های UTF-8 آن. مرجعِ درستی‌اش `brain/noql/core.py` است که
/// خودش روی CI با کتابخانهٔ اصلی مقایسه می‌شود؛ خروجی هر دو در
/// `test/understanding/noql_ref.json` با همین کد سنجیده می‌شود.
class NoqlTokenizer {
  NoqlTokenizer(List<String> pieces, List<double> scores)
      : _scores = scores,
        _ids = <String, int>{} {
    var longest = 1;
    var lowest = double.infinity;
    for (var i = 0; i < pieces.length; i++) {
      final p = pieces[i];
      _ids[p] = i;
      final len = p.runes.length;
      if (len > longest) longest = len;
      if (scores[i] < lowest) lowest = scores[i];
    }
    _maxLen = longest;
    _unkScore = lowest - 10.0;
    _byte0 = _ids['<0x00>'] ?? -1;
  }

  factory NoqlTokenizer.fromJson(String source) {
    final m = jsonDecode(source) as Map<String, dynamic>;
    return NoqlTokenizer(
      (m['pieces'] as List).cast<String>(),
      [for (final s in m['scores'] as List) (s as num).toDouble()],
    );
  }

  static const int unk = 1;
  static const int cls = 2;
  static const int sep = 3;
  static const int _bar = 0x2581; // ▁

  final Map<String, int> _ids;
  final List<double> _scores;
  late final int _maxLen;
  late final double _unkScore;
  late final int _byte0;

  int get vocabSize => _scores.length;

  /// همان نویسه‌هایی که توکن‌سازِ اصلی «فاصله» می‌داند (نیم‌فاصله جزو آن‌ها
  /// نیست و خودش یک توکن است).
  static bool _isSpace(int r) =>
      (r >= 0x09 && r <= 0x0D) ||
      r == 0x20 ||
      r == 0x85 ||
      r == 0xA0 ||
      r == 0x1680 ||
      (r >= 0x2000 && r <= 0x200A) ||
      r == 0x2028 ||
      r == 0x2029 ||
      r == 0x202F ||
      r == 0x205F ||
      r == 0x3000;

  /// یکسان‌سازیِ کمینهٔ پیش از مدل: «ي» و «ك» عربی به فارسی.
  static String prepare(String text) =>
      text.replaceAll('ي', 'ی').replaceAll('ك', 'ک').trim();

  /// رشتهٔ فاصله‌ها یک «▁» می‌شود، سر و ته پاک می‌شود و یک «▁» اول می‌آید.
  static List<int> _metaspace(String text) {
    final out = <int>[];
    var gap = false;
    for (final r in text.runes) {
      if (_isSpace(r)) {
        gap = true;
        continue;
      }
      if (out.isEmpty) {
        if (r != _bar) out.add(_bar);
      } else if (gap) {
        out.add(_bar);
      }
      gap = false;
      out.add(r);
    }
    return out;
  }

  /// شناسهٔ توکن‌ها با `[CLS]` در آغاز و `[SEP]` در پایان؛ حداکثر [maxTokens].
  List<int> encode(String text, {int maxTokens = 64}) {
    final s = _metaspace(text);
    final ids = <int>[cls];
    var from = 0;
    while (from < s.length && ids.length < maxTokens - 1) {
      var to = from + 1;
      while (to < s.length && s[to] != _bar) {
        to++;
      }
      _word(s, from, to, ids);
      from = to;
    }
    if (ids.length > maxTokens - 1) ids.length = maxTokens - 1;
    ids.add(sep);
    return ids;
  }

  /// بهترین تقسیمِ یک واژه (از [from] تا [to]) به قطعه‌های واژگان.
  void _word(List<int> s, int from, int to, List<int> out) {
    final n = to - from;
    final best = List<double>.filled(n + 1, 0);
    final start = List<int>.filled(n + 1, -1);
    final tid = List<int>.filled(n + 1, 0);
    for (var at = 0; at < n; at++) {
      final here = best[at];
      var single = false;
      final lim = n - at < _maxLen ? n - at : _maxLen;
      for (var len = 1; len <= lim; len++) {
        final id =
            _ids[String.fromCharCodes(s, from + at, from + at + len)];
        if (id == null) continue;
        final end = at + len;
        final cand = _scores[id] + here;
        if (start[end] < 0 || cand > best[end]) {
          best[end] = cand;
          start[end] = at;
          tid[end] = id;
        }
        if (len == 1) single = true;
      }
      if (!single) {
        final end = at + 1;
        final cand = _unkScore + here;
        if (start[end] < 0 || cand > best[end]) {
          best[end] = cand;
          start[end] = at;
          tid[end] = unk;
        }
      }
    }
    // مسیر از آخر به اول خوانده می‌شود؛ ناشناخته‌های پشت‌سرهم یکی می‌شوند.
    final spans = <int>[];
    var end = n;
    while (end > 0) {
      final at = start[end];
      spans
        ..add(tid[end])
        ..add(at)
        ..add(end);
      end = at;
    }
    for (var i = spans.length - 3; i >= 0; i -= 3) {
      final id = spans[i];
      if (id != unk) {
        out.add(id);
        continue;
      }
      final a = spans[i + 1];
      var b = spans[i + 2];
      while (i >= 3 && spans[i - 3] == unk) {
        i -= 3;
        b = spans[i + 2];
      }
      final piece = String.fromCharCodes(s, from + a, from + b);
      if (_byte0 < 0) {
        out.add(unk);
      } else {
        for (final byte in utf8.encode(piece)) {
          out.add(_byte0 + byte);
        }
      }
    }
  }
}
