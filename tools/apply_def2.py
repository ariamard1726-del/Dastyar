import hashlib
import sys

P = 'lib/engine.dart'
OLD_SHA = 'df51e01e94dd961af6f2855e489e707956de030f'
NEW_SHA = '228c9c4f81c6da5075ce9a413726fcea70f534bb'

raw = open(P, 'rb').read()
cur = hashlib.sha1(raw).hexdigest()
if cur == NEW_SHA:
    print('قبلاً اعمال شده است؛ تغییری نداده شد.')
    sys.exit(0)
if cur != OLD_SHA:
    print('engine.dart با نسخهٔ مورد انتظار فرق دارد؛ چیزی تغییر نکرد.')
    print('sha1 فعلی:', cur)
    sys.exit(1)
s = raw.decode('utf-8')

A1 = "  static final RegExp _defMark = RegExp(r'عقدی|عبارت|است|گویند');\n"
B1 = A1 + "  static final RegExp _defStrong = RegExp(r'^[\\s،]*(عقدی|عبارت|شرکتی|کسی)');\n"

A2 = r"""    final cands = <Hit>[];
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
"""
B2 = r"""    var cands = <Hit>[];
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
"""
for a in (A1, A2):
    if s.count(a) != 1:
        print('نقطهٔ اتصال پیدا نشد؛ چیزی تغییر نکرد.')
        sys.exit(1)
s = s.replace(A1, B1).replace(A2, B2)
out = s.encode('utf-8')
if hashlib.sha1(out).hexdigest() != NEW_SHA:
    print('نتیجه با انتظار نمی‌خواند؛ چیزی نوشته نشد.')
    print(hashlib.sha1(out).hexdigest())
    sys.exit(1)
open(P, 'wb').write(out)
print('engine.dart با موفقیت به‌روز شد.')
