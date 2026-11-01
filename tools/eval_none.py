"""ارزیابی «رد کردن درست»: پرسش‌هایی که پاسخشان در برنامه نیست.
همگام با پوشش واژگانی (شامل پیشوند و مترادف) و نگهبان‌های lib/engine.dart.
اجرا: python3 tools/eval_none.py [-v]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from eval_py import ART_QUERY_RE, ROOT, Engine, normalize, phrase, tok  # noqa: E402

MIN_SCORE = 0.3
LOW_COVER = 0.4


def _has_term(c, t):
    return t in c['T'] or t in c['B'] or t in c['C']


def coverage(eng, q, c):
    qt = list(dict.fromkeys(tok(q)))
    if not qt or not eng.idf:
        return 0.0
    mx = eng.max_idf
    den = got = 0.0
    covered = set()
    for t in qt:
        w = eng.idf.get(t, mx)
        den += w
        if _has_term(c, t):
            covered.add(t)
            got += w
        elif len(t) >= 3:
            pref = False
            for m in (c['T'], c['B'], c['C']):
                for k in m:
                    if len(k) >= 3 and (k.startswith(t) or t.startswith(k)):
                        pref = True
                        break
                if pref:
                    break
            if pref:
                covered.add(t)
                got += 0.5 * mx

    n = f' {phrase(q)} '
    for kk, v in eng.syn:
        if f' {kk} ' not in n:
            continue
        if not any(_has_term(c, t) for t in tok(v)):
            continue
        for t in tok(kk):
            if t in qt and t not in covered:
                covered.add(t)
                got += eng.idf.get(t, mx)

    return got / den if den > 0 else 0.0


def mentions_missing_law(eng, q):
    m = eng.mentioned(q)
    return bool(m) and all(eng.lawcount.get(i, 0) <= 0 for i in m)


def gate(eng, q):
    """True یعنی برنامه با اطمینان جواب می‌دهد (برای پرسش بی‌پاسخ = خطا)."""
    if mentions_missing_law(eng, q):
        return False
    n = normalize(q)
    art = ART_QUERY_RE.search(n)
    if art and not eng.mentioned(q) and 'قانون' in n:
        return False
    hits = eng.rank(q, k=4)
    if art and eng.mentioned(q) and not (hits and hits[0][1] >= 99):
        return False
    if not hits or hits[0][1] < MIN_SCORE:
        return False
    if (art is None or hits[0][1] < 99) and coverage(eng, q, hits[0][0]) < LOW_COVER:
        return False
    if art is None and 'کلاهبرداری' in n and 'مجازات' in n and 'اعلامیه پذیره‌نویسی' in hits[0][0]['body']:
        return False
    return True


if __name__ == '__main__':
    eng = Engine()
    path = os.path.join(ROOT, 'brain', 'eval_none.txt')
    with open(path, encoding='utf-8') as f:
        qs = [l.strip() for l in f if l.strip() and not l.startswith('#')]
    bad = [q for q in qs if gate(eng, q)]
    print(
        'eval_none.txt: n=%d رد درست %d | پاسخ غلط با اطمینان %d (%.0f%%)'
        % (len(qs), len(qs) - len(bad), len(bad), 100.0 * len(bad) / len(qs))
    )
    if '-v' in sys.argv:
        for q in bad:
            h = eng.rank(q, k=1)
            top = '%s | %s' % (h[0][0]['source'], h[0][0]['title']) if h else '-'
            print('  پاسخ داده شد: %s  →  %s' % (q, top))
