"""آزمایش: آیا یک مدل embedding کوچک بازیابی را بهتر می‌کند؟
فقط اندازه‌گیری است؛ به اپ دست نمی‌زند.
اجرا: MODEL=intfloat/multilingual-e5-small python brain/embed_eval.py
خروجی: brain/reports/embed_<مدل>.txt"""
import os
import re
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(os.path.dirname(HERE), 'tools'))
from common import ROOT, normalize, load_articles  # noqa: E402
from eval_py import Engine  # noqa: E402
from sentence_transformers import SentenceTransformer  # noqa: E402

MODEL = os.environ.get('MODEL', 'intfloat/multilingual-e5-small')
E5 = 'e5' in MODEL.lower()
RRF_K = 60
OUT = os.path.join(HERE, 'reports')
os.makedirs(OUT, exist_ok=True)
LINES = []


def log(*a):
    s = ' '.join(str(x) for x in a)
    print(s, flush=True)
    LINES.append(s)


def read_rows(name):
    rows = []
    p = os.path.join(HERE, name)
    if not os.path.exists(p):
        return rows
    for l in open(p, encoding='utf-8'):
        l = l.strip()
        if l and not l.startswith('#'):
            rows.append([x.strip() for x in l.split('|')])
    return rows


t0 = time.time()
log('مدل:', MODEL)
arts = load_articles()
model = SentenceTransformer(MODEL)
model.max_seq_length = 256


def ptxt(a):
    s = ' '.join([a['source'], a['chapter'], a['title'], a['body']])
    s = normalize(s)
    return ('passage: ' if E5 else '') + s


def qtxt(q):
    return ('query: ' if E5 else '') + normalize(q)


P = model.encode([ptxt(a) for a in arts], batch_size=32,
                 normalize_embeddings=True, show_progress_bar=False)
P = np.asarray(P, dtype=np.float32)
log('تعداد ماده:', len(arts), '| زمان رمزگذاری: %.0f ثانیه' % (time.time() - t0))
keys = [(a['law'], a['title']) for a in arts]
eng = Engine()


def dense_rank(q, k=60):
    v = np.asarray(model.encode([qtxt(q)], normalize_embeddings=True),
                   dtype=np.float32)[0]
    sims = P @ v
    idx = np.argsort(-sims)[:k]
    return [(keys[i], float(sims[i])) for i in idx]


def lex_rank(q, k=60):
    return [((c['law'], c['title']), s) for c, s in eng.rank(q, k=k)]


def rrf(lists):
    sc = {}
    for lst in lists:
        for r, (key, _) in enumerate(lst):
            sc[key] = sc.get(key, 0.0) + 1.0 / (RRF_K + r + 1)
    return sorted(sc.items(), key=lambda x: -x[1])


def metrics(rank_fn, rows):
    r1 = r5 = 0
    mrr = 0.0
    for q, law, title in rows:
        rank = 0
        for i, (key, _) in enumerate(rank_fn(q)):
            if key == (law, title):
                rank = i + 1
                break
        r1 += rank == 1
        r5 += 1 <= rank <= 5
        mrr += 1.0 / rank if rank else 0.0
    n = len(rows)
    return r1 / n, r5 / n, mrr / n


cache = {}


def hybrid(q):
    if q not in cache:
        cache[q] = (dense_rank(q), lex_rank(q))
    d, l = cache[q]
    return rrf([d, l])


def dense_c(q):
    if q not in cache:
        cache[q] = (dense_rank(q), lex_rank(q))
    return cache[q][0]


def lex_c(q):
    if q not in cache:
        cache[q] = (dense_rank(q), lex_rank(q))
    return cache[q][1]


log('\nمجموعه | روش | recall@1 | recall@5 | MRR')
for f in ('eval.txt', 'eval_extra.txt', 'eval_blind.txt', 'eval_v2.txt', 'eval_v3.txt', 'eval_v4.txt'):
    rows = [r for r in read_rows(f) if len(r) == 3]
    if not rows:
        continue
    for name, fn in (('واژه‌ای', lex_c), ('embedding', dense_c), ('ترکیبی', hybrid)):
        a, b, c = metrics(fn, rows)
        log('%s | %s | %.2f | %.2f | %.3f' % (f, name, a, b, c))

# آیا شباهت بالاترین نتیجه، پرسش بی‌پاسخ را از پرسش درست جدا می‌کند؟
pos, neg = [], []
for f in ('eval.txt', 'eval_extra.txt', 'eval_blind.txt', 'eval_v2.txt', 'eval_v3.txt', 'eval_v4.txt'):
    for r in read_rows(f):
        if len(r) == 3:
            pos.append(dense_c(r[0])[0][1])
for r in read_rows('eval_none.txt'):
    if r and not re.search(r'ماده\s*[\d۰-۹]+', r[0]):
        neg.append(dense_c(r[0])[0][1])
if pos and neg:
    wins = sum((p > n) + 0.5 * (p == n) for p in pos for n in neg)
    auc = wins / (len(pos) * len(neg))
    log('\nجداسازی پرسش بی‌پاسخ با شباهت بالاترین نتیجه:')
    log('میانگین شباهت پرسش‌های درست: %.3f | بی‌پاسخ: %.3f' % (
        float(np.mean(pos)), float(np.mean(neg))))
    log('AUC = %.2f (۰٫۵ یعنی بی‌فایده، ۱ یعنی جداسازی کامل)' % auc)
log('\nزمان کل: %.0f ثانیه' % (time.time() - t0))

name = re.sub(r'[^A-Za-z0-9_.-]+', '_', MODEL)
with open(os.path.join(OUT, 'embed_%s.txt' % name), 'w', encoding='utf-8') as f:
    f.write('\n'.join(LINES) + '\n')
