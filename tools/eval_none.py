"""ارزیابی «رد کردن درست»: پرسش‌هایی که پاسخشان در برنامه نیست.
خروجی تقریبی است (بازنویسی پایتونی موتور)؛ مرجع نهایی تست‌های Dart است.
اجرا: python3 tools/eval_none.py [-v]"""
import math
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eval_py import ROOT, Engine, tok, normalize, collapse  # noqa: E402

MIN_SCORE = 0.3
LOW_COVER = 0.4


def coverage(eng, q, c):
    qt = list(dict.fromkeys(tok(q)))
    if not qt:
        return 0.0
    mx = max(eng.idf.values()) if eng.idf else 1.0
    den = got = 0.0
    for t in qt:
        w = eng.idf.get(t, mx)
        den += w
        if t in c['T'] or t in c['B'] or t in c['C']:
            got += w
    return got / den if den else 0.0


def mentions_missing_law(eng, q):
    n = collapse(normalize(q))
    for l in eng.catalog:
        if eng.lawcount.get(l['id'], 0) > 0:
            continue
        for name in [l['title']] + list(l.get('aliases', [])):
            full = collapse(normalize(name))
            if not full:
                continue
            short = full[6:].strip() if full.startswith('قانون ') else full
            if full in n or (len(short) >= 5 and short in n):
                return True
    return False


def gate(eng, q):
    """True یعنی برنامه با اطمینان جواب می‌دهد (برای پرسش بی‌پاسخ = خطا)."""
    if mentions_missing_law(eng, q):
        return False
    n = normalize(q)
    art = re.search(r'ماده\s*(\d+)', n)
    if art and not eng.mentioned(q) and 'قانون' in n:
        return False
    hits = eng.rank(q, k=4)
    if art and eng.mentioned(q) and not (hits and hits[0][1] >= 99):
        return False
    if not hits or hits[0][1] < MIN_SCORE:
        return False
    if hits[0][1] < 99 and coverage(eng, q, hits[0][0]) < LOW_COVER:
        return False
    return True


if __name__ == '__main__':
    eng = Engine()
    path = os.path.join(ROOT, 'brain', 'eval_none.txt')
    qs = [l.strip() for l in open(path, encoding='utf-8')
          if l.strip() and not l.startswith('#')]
    bad = [q for q in qs if gate(eng, q)]
    print('eval_none.txt: n=%d رد درست %d | پاسخ غلط با اطمینان %d (%.0f%%)' % (
        len(qs), len(qs) - len(bad), len(bad), 100.0 * len(bad) / len(qs)))
    if '-v' in sys.argv:
        for q in bad:
            h = eng.rank(q, k=1)
            top = '%s | %s' % (h[0][0]['source'], h[0][0]['title']) if h else '-'
            print('  پاسخ داده شد: %s  →  %s' % (q, top))
