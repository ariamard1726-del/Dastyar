"""آزمایش: آیا BM25 روی n-gram حرفی از موتور واژه‌ای بهتر است؟
فقط اندازه‌گیری است؛ به اپ دست نمی‌زند.
اجرا: python brain/ngram_eval.py
خروجی: brain/reports/ngram.txt"""
import math
import os
import random
import re
import sys
import time
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from common import normalize  # noqa: E402
from eval_py import Engine, tok, phrase  # noqa: E402

K1, B = 1.2, 0.4
WT, WB, WC = 3.0, 1.0, 0.5
RRF_K = 60
NEAR = 2
OUT = os.path.join(HERE, 'reports')
os.makedirs(OUT, exist_ok=True)
LINES = []


def log(*a):
    s = ' '.join(str(x) for x in a)
    print(s, flush=True)
    LINES.append(s)


def grams(w, nmin, nmax):
    t = '<' + w + '>'
    return [t[i:i + n] for n in range(nmin, nmax + 1)
            for i in range(len(t) - n + 1)]


class NG:
    def __init__(self, eng, nmin, nmax):
        self.eng, self.nmin, self.nmax = eng, nmin, nmax
        self.post = defaultdict(list)
        self.len = []
        for i, c in enumerate(eng.chunks):
            tf = defaultdict(float)
            for fld, wt in (('T', WT), ('B', WB), ('C', WC)):
                for w, cnt in c[fld].items():
                    for g in grams(w, nmin, nmax):
                        tf[g] += wt * cnt
            self.len.append(sum(tf.values()))
            for g, v in tf.items():
                self.post[g].append((i, v))
        n = len(eng.chunks)
        self.avg = max(1.0, sum(self.len) / n)
        self.idf = {g: math.log((n + 1) / (len(p) + 1)) + 1.0
                    for g, p in self.post.items()}

    def rank(self, question, k=60):
        eng = self.eng
        terms = set()
        for w in tok(question):
            terms.update(grams(w, self.nmin, self.nmax))
        n = ' %s ' % phrase(question)
        for kk, v in eng.syn:
            if (' %s ' % kk) in n:
                for w in tok(v):
                    terms.update(grams(w, self.nmin, self.nmax))
        ids = {i for i in eng.mentioned(question) if eng.lawcount.get(i, 0) > 0}
        sc = defaultdict(float)
        for g in terms:
            p = self.post.get(g)
            if not p:
                continue
            idf = self.idf[g]
            for i, v in p:
                if ids and eng.chunks[i]['law'] not in ids:
                    continue
                tfn = v / (1 - B + B * self.len[i] / self.avg)
                sc[i] += idf * tfn * (K1 + 1) / (tfn + K1)
        out = []
        for i, s in sc.items():
            c = eng.chunks[i]
            if c['obs']:
                s *= 0.1
            out.append((c, s))
        out.sort(key=lambda x: -x[1])
        return out[:k]


def keys(res):
    return [(c['law'], c['title']) for c, _ in res]


def rrf(lists):
    sc = {}
    for lst in lists:
        for r, key in enumerate(lst):
            sc[key] = sc.get(key, 0.0) + 1.0 / (RRF_K + r + 1)
    return [k for k, _ in sorted(sc.items(), key=lambda x: -x[1])]


def num(title):
    m = re.search(r'(\d+)', normalize(title))
    return int(m.group(1)) if m else None


def read_rows(name):
    rows = []
    p = os.path.join(HERE, name)
    if not os.path.exists(p):
        return rows
    for l in open(p, encoding='utf-8'):
        l = l.strip()
        if l and not l.startswith('#'):
            r = [x.strip() for x in l.split('|')]
            if len(r) == 3:
                rows.append(r)
    return rows


def ci(v):
    r = random.Random(1)
    n = len(v)
    xs = sorted(sum(v[r.randrange(n)] for _ in range(n)) / n for _ in range(2000))
    return xs[50], xs[1949]


def evaluate(fn, rows):
    hit1, hit5, near, mrr = [], 0, 0, 0.0
    for q, law, title in rows:
        ks = fn(q)
        rank = 0
        for i, k in enumerate(ks):
            if k == (law, title):
                rank = i + 1
                break
        hit1.append(1 if rank == 1 else 0)
        hit5 += 1 <= rank <= 5
        mrr += 1.0 / rank if rank else 0.0
        if ks:
            a, b = num(ks[0][1]), num(title)
            if ks[0][0] == law and a is not None and b is not None \
                    and abs(a - b) <= NEAR:
                near += 1
    n = len(rows)
    lo, hi = ci(hit1)
    return (sum(hit1) / n, lo, hi, hit5 / n, mrr / n, near / n)


t0 = time.time()
eng = Engine()
log('تعداد chunk:', len(eng.chunks))
ng34 = NG(eng, 3, 4)
ng35 = NG(eng, 3, 5)
log('ساخت نمایه: %.0f ثانیه' % (time.time() - t0))

cache = {}


def both(q):
    if q not in cache:
        cache[q] = (keys(eng.rank(q, k=60)),
                    keys(ng34.rank(q)), keys(ng35.rank(q)))
    return cache[q]


methods = [
    ('واژه‌ای (فعلی)', lambda q: both(q)[0]),
    ('n-gram ۳-۴', lambda q: both(q)[1]),
    ('n-gram ۳-۵', lambda q: both(q)[2]),
    ('ترکیب واژه‌ای + ۳-۴', lambda q: rrf([both(q)[0], both(q)[1]])),
    ('ترکیب واژه‌ای + ۳-۵', lambda q: rrf([both(q)[0], both(q)[2]])),
]

allrows = []
log('\nمجموعه | روش | recall@1 [بازهٔ ۹۵٪] | recall@5 | MRR | نزدیک‌خطا@1')
for f in ('eval.txt', 'eval_extra.txt', 'eval_blind.txt'):
    rows = read_rows(f)
    allrows += rows
    for name, fn in methods:
        a, lo, hi, b, m, nr = evaluate(fn, rows)
        log('%s (n=%d) | %s | %.2f [%.2f-%.2f] | %.2f | %.3f | %.2f'
            % (f, len(rows), name, a, lo, hi, b, m, nr))
log('')
for name, fn in methods:
    a, lo, hi, b, m, nr = evaluate(fn, allrows)
    log('همهٔ مجموعه‌ها (n=%d) | %s | %.2f [%.2f-%.2f] | %.2f | %.3f | %.2f'
        % (len(allrows), name, a, lo, hi, b, m, nr))
log('\nزمان کل: %.0f ثانیه' % (time.time() - t0))

with open(os.path.join(OUT, 'ngram.txt'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(LINES) + '\n')
