import hashlib
import sys

P = 'lib/engine.dart'
OLD_SHA = '501d5d85de5adf33a7d908f29717988057d179ad'
NEW_SHA = 'df51e01e94dd961af6f2855e489e707956de030f'

raw = open(P, 'rb').read()
if hashlib.sha1(raw).hexdigest() == NEW_SHA:
    print('قبلاً اعمال شده است؛ تغییری نداده شد.')
    sys.exit(0)
if hashlib.sha1(raw).hexdigest() != OLD_SHA:
    print('engine.dart با نسخهٔ مورد انتظار فرق دارد؛ چیزی تغییر نکرد.')
    print('sha1 فعلی:', hashlib.sha1(raw).hexdigest())
    sys.exit(1)
s = raw.decode('utf-8')

A1 = "  static const double _lowCover = 0.4;\n"
B1 = A1 + r"""
  // پرسش‌های «X چیست / یعنی چه»: مادهٔ تعریف‌کننده باید جلو بیاید.
  static final RegExp _defQ = RegExp(
    r'چیست|چیه|یعنی چی|یعنی چه|چه معنی|تعریف|چی هست|به چه گویند|به چه کسی می گویند|به چی می گن',
  );
  static const Set<String> _defWords = {
    'یعنی', 'چی', 'چه', 'معنی', 'تعریف', 'هست', 'چیست', 'چیه',
    'گویند', 'کسی', 'کیست',
  };
  static final RegExp _defMark = RegExp(r'عقدی|عبارت|است|گویند');
"""
A2 = ("    hits.sort((a, b) => b.score.compareTo(a.score));\n"
      "    return RankResult(hits.take(k).toList());\n  }\n")
B2 = r"""    hits.sort((a, b) => b.score.compareTo(a.score));
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
    final cands = <Hit>[];
    for (final n in [2, 1]) {
      if (toks.length < n) continue;
      final term = toks.take(n).join(' ');
      for (final h in hits) {
        final c = h.chunk;
        if (c.lawId == 'knowledge' || c.obsolete) continue;
        final body = _cleanBody(c.body);
        if (!body.startsWith(term)) continue;
        final end = math.min(body.length, term.length + 30);
        if (_defMark.hasMatch(body.substring(term.length, end))) cands.add(h);
      }
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
"""
for a in (A1, A2):
    if s.count(a) != 1:
        print('نقطهٔ اتصال پیدا نشد؛ چیزی تغییر نکرد.')
        sys.exit(1)
s = s.replace(A1, B1).replace(A2, B2)
out = s.encode('utf-8')
if hashlib.sha1(out).hexdigest() != NEW_SHA:
    print('نتیجه با انتظار نمی‌خواند؛ چیزی نوشته نشد.')
    sys.exit(1)
open(P, 'wb').write(out)
print('engine.dart با موفقیت به‌روز شد.')
