# tools/patch_isolate.py
# بارگذاری و ساخت نمایه را به Isolate منتقل می‌کند؛ رفتار جست‌وجو تغییر نمی‌کند.
# اگر هر قسمت از engine.dart با انتظار نخواند، هیچ چیز نوشته نمی‌شود.
import sys

P = 'lib/engine.dart'
s = open(P, encoding='utf-8').read()

if 'Isolate.run' in s:
    print('قبلاً اعمال شده است.')
    sys.exit(0)

def once(marker):
    if s.count(marker) != 1:
        print('خطا: بخش مورد انتظار پیدا نشد یا تکراری است:\n' + marker)
        sys.exit(1)

IMPORT = "import 'dart:convert';\n"
LOAD_START = "    // ۱. لود فایل دانش عمومی\n"
LOAD_END = "    _buildIndex();\n  }\n"
PARSE_START = "  Future<void> _parse(String text, String defaultSource, String lawId) async {\n"
PARSE_END = "  final List<List<String>> _syn = [];\n"

for m in (IMPORT, LOAD_START, LOAD_END, PARSE_START, PARSE_END):
    once(m)

a = s.index(LOAD_START)
b = s.index(LOAD_END) + len(LOAD_END)
c = s.index(PARSE_START)
d = s.index(PARSE_END)
if not (a < b <= c < d):
    print('خطا: ترتیب بخش‌ها با انتظار نمی‌خواند.')
    sys.exit(1)

NEW_LOAD = r'''    // متن همهٔ فایل‌ها را اینجا می‌خوانیم؛ پارس و ساخت نمایه در Isolate انجام می‌شود.
    final raw = <List<String>>[];
    try {
      final text = await rootBundle.loadString('assets/knowledge.txt');
      raw.add(['knowledge', 'دانش عمومی', text]);
    } catch (e) {
      warnings.add('assets/knowledge.txt: $e');
    }

    for (final entry in meta.entries) {
      final lawId = entry.key;
      final path = entry.value['path'];
      if (path != null && path is String) {
        final fullPath = 'assets/laws/$path';
        try {
          final text = await rootBundle.loadString(fullPath);
          raw.add([lawId, '', text]);
        } catch (e) {
          warnings.add('$fullPath: $e');
        }
      }
    }
    await _loadSynonyms();

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
    _avgLen = built.avgLen;
    _maxIdf = built.maxIdf;
    _vocab = built.vocab;
  }

'''

NEW_PARSE = r'''  static Future<_Built> _buildAsync(List<List<String>> raw) =>
      Isolate.run(() => _build(raw));

  static _Built _build(List<List<String>> raw) {
    final chunks = <Chunk>[];
    final counts = <String, int>{};
    for (final r in raw) {
      _parseInto(r[2], r[1], r[0], chunks, counts);
    }
    final df = <String, int>{};
    var totalLen = 0;
    for (final c in chunks) {
      totalLen += c.len;
      final seen = <String>{...c.tfT.keys, ...c.tfB.keys, ...c.tfC.keys};
      for (final t in seen) {
        df[t] = (df[t] ?? 0) + 1;
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
    return _Built(chunks, counts, idf, avg, maxIdf, df.keys.toList());
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
    final parts = text.replaceAll('\r', '').split(RegExp(r'\n\s*\n'));
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

'''

TAIL = r'''
/// نتیجهٔ ساخت نمایه که از Isolate به رشتهٔ اصلی برمی‌گردد.
class _Built {
  final List<Chunk> chunks;
  final Map<String, int> lawCounts;
  final Map<String, double> idf;
  final double avgLen;
  final double maxIdf;
  final List<String> vocab;
  _Built(this.chunks, this.lawCounts, this.idf, this.avgLen, this.maxIdf,
      this.vocab);
}
'''

out = s[:a] + NEW_LOAD + s[b:c] + NEW_PARSE + s[d:]
out = out.replace(IMPORT, IMPORT + "import 'dart:isolate';\n", 1)
if not out.endswith('\n'):
    out += '\n'
out += TAIL
open(P, 'w', encoding='utf-8').write(out)
print('انجام شد: بارگذاری حالا در Isolate است.')
