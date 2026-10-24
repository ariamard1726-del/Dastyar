import json
import math
import os
import random
import sys
import time

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import ROOT, NB, D, feats, words, load_articles

STEPS = int(os.environ.get('STEPS', '3000'))
CAND = 256
OUT = os.path.join(ROOT, 'brain_out')
os.makedirs(OUT, exist_ok=True)
LOG = []


def log(*a):
    s = ' '.join(str(x) for x in a)
    print(s, flush=True)
    LOG.append(s)


torch.manual_seed(0)
arts = load_articles()
if len(arts) < 50:
    sys.exit('Too few articles')
N = len(arts)
texts = [(a['chapter'] + ' ' + a['body']).strip() for a in arts]
fullw = [words(t) for t in texts]
awords = [w[:150] for w in fullw]
afeats = [feats(' '.join(w)) for w in awords]


class Enc(nn.Module):
    def __init__(self):
        super().__init__()
        self.emb = nn.EmbeddingBag(NB, D, mode='mean', sparse=True)
        nn.init.normal_(self.emb.weight, std=0.1)

    def forward(self, lists):
        flat = []
        offs = []
        for ids in lists:
            offs.append(len(flat))
            flat.extend(ids if ids else [0])
        x = self.emb(torch.tensor(flat), torch.tensor(offs))
        return F.normalize(x, dim=-1)


def make_query(ws, rng):
    n = len(ws)
    span = rng.randint(4, 10)
    if n <= span:
        s = ws[:]
    else:
        st = rng.randint(0, n - span)
        s = ws[st:st + span]
    out = []
    for w in s:
        r = rng.random()
        if r < 0.10:
            continue
        if r < 0.20 and len(w) > 3:
            i = rng.randint(0, len(w) - 2)
            w = w[:i] + w[i + 1:]
        out.append(w)
    return ' '.join(out) or ' '.join(s)


model = Enc()
opt = torch.optim.SparseAdam(list(model.parameters()), lr=0.01)
rng = random.Random(1)
used = np.zeros(NB, dtype=bool)
for f in afeats:
    used[f] = True

t0 = time.time()
for step in range(1, STEPS + 1):
    idx = rng.sample(range(N), min(CAND, N))
    qs = [feats(make_query(awords[i], rng)) for i in idx]
    for l in qs:
        used[l] = True
    q = model(qs)
    a = model([afeats[i] for i in idx])
    loss = F.cross_entropy(q @ a.T / 0.05, torch.arange(len(idx)))
    opt.zero_grad()
    loss.backward()
    opt.step()
    if step == 1 or step % 250 == 0:
        log('step %d loss %.4f time %ds' % (step, loss.item(), time.time() - t0))

W = model.emb.weight.detach().cpu().numpy().copy()
W[~used] = 0.0
scale = np.abs(W).max(axis=1) / 127.0
scale[scale == 0] = 1.0
Q = np.clip(np.round(W / scale[:, None]), -127, 127).astype(np.int8)
Wd = Q.astype(np.float32) * scale[:, None].astype(np.float32)


def enc_np(ids):
    if not ids:
        return np.zeros(D, np.float32)
    v = Wd[np.array(ids)].mean(axis=0)
    return (v / max(float(np.linalg.norm(v)), 1e-12)).astype(np.float32)


A = np.stack([enc_np(f) for f in afeats])

# ---------- پایهٔ مقایسه: TF-IDF کلمه‌ای ----------
df = {}
for ws in fullw:
    for t in set(ws):
        df[t] = df.get(t, 0) + 1
idf = {t: math.log((N + 1) / (d + 1)) + 1.0 for t, d in df.items()}


def tvec(ws):
    tf = {}
    for t in ws:
        tf[t] = tf.get(t, 0) + 1
    v = {t: (1 + math.log(c)) * idf.get(t, 1.0) for t, c in tf.items()}
    nrm = math.sqrt(sum(x * x for x in v.values())) or 1.0
    return {t: x / nrm for t, x in v.items()}


dvecs = [tvec(ws) for ws in fullw]


def tfidf_scores(q):
    qv = tvec(words(q))
    return np.array([sum(x * dv.get(t, 0.0) for t, x in qv.items()) for dv in dvecs])


def brain_scores(q):
    return A @ enc_np(feats(q))


def rrf(lists):
    tot = np.zeros(N)
    for s in lists:
        order = np.argsort(-s)
        r = np.empty(N)
        r[order] = np.arange(1, N + 1)
        tot += 1.0 / (60 + r)
    return tot


def rank_of(s, gold):
    return int(np.where(np.argsort(-s) == gold)[0][0]) + 1


def read_rows(path):
    rows = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#'):
                rows.append([p.strip() for p in line.split('|')])
    return rows


key = {(a['law'], a['title']): i for i, a in enumerate(arts)}
ev = []
missing = 0
for q, law, title in read_rows(os.path.join(ROOT, 'brain', 'eval.txt')):
    if (law, title) in key:
        ev.append((q, key[(law, title)]))
    else:
        missing += 1
log('eval queries: %d (skipped, article not found: %d)' % (len(ev), missing))
res = {'tfidf': [], 'brain': [], 'hybrid': []}
for q, g in ev:
    st, sb = tfidf_scores(q), brain_scores(q)
    sh = rrf([st, sb])
    r = (rank_of(st, g), rank_of(sb, g), rank_of(sh, g))
    res['tfidf'].append(r[0])
    res['brain'].append(r[1])
    res['hybrid'].append(r[2])
    log('tfidf %3d | brain %3d | hybrid %3d | %s' % (r[0], r[1], r[2], q[:40]))
for name, rs in res.items():
    if rs:
        log('%-7s recall@1 %.2f recall@5 %.2f MRR %.3f' % (
            name, np.mean([r == 1 for r in rs]), np.mean([r <= 5 for r in rs]),
            np.mean([1.0 / r for r in rs])))

# ---------- تشخیص منظور ----------
rows = [r for r in read_rows(os.path.join(ROOT, 'brain', 'intents.txt')) if len(r) >= 2]
labels = sorted(set(r[0] for r in rows))
X = np.stack([enc_np(feats(r[1])) for r in rows]).astype(np.float32)
y = np.array([labels.index(r[0]) for r in rows])


def fit(Xt, yt, k):
    Wt = torch.zeros(D, k, requires_grad=True)
    bt = torch.zeros(k, requires_grad=True)
    o = torch.optim.Adam([Wt, bt], lr=0.1)
    xt = torch.tensor(Xt)
    ytt = torch.tensor(yt)
    for _ in range(400):
        l = F.cross_entropy(xt @ Wt + bt, ytt) + 1e-3 * (Wt ** 2).sum()
        o.zero_grad()
        l.backward()
        o.step()
    return Wt.detach().numpy(), bt.detach().numpy()


perm = np.random.RandomState(0).permutation(len(y))
pred = np.zeros(len(y), dtype=int)
for k in range(5):
    te = perm[k::5]
    tr = np.setdiff1d(perm, te)
    Wi, bi = fit(X[tr], y[tr], len(labels))
    pred[te] = (X[te] @ Wi + bi).argmax(1)
log('intent examples: %d | classes: %s' % (len(y), labels))
log('intent 5-fold accuracy: %.2f' % float((pred == y).mean()))
for i in np.where(pred != y)[0][:10]:
    log('  wrong: %s -> %s | %s' % (labels[y[i]], labels[pred[i]], rows[i][1][:40]))
Wi, bi = fit(X, y, len(labels))

# ---------- خروجی ----------
with open(os.path.join(OUT, 'emb_q8.bin'), 'wb') as f:
    f.write(Q.tobytes())
with open(os.path.join(OUT, 'emb_scale.bin'), 'wb') as f:
    f.write(scale.astype('<f4').tobytes())
with open(os.path.join(OUT, 'art_vecs.bin'), 'wb') as f:
    f.write(A.astype('<f4').tobytes())
with open(os.path.join(OUT, 'art_ids.json'), 'w', encoding='utf-8') as f:
    json.dump([{'law': a['law'], 'title': a['title']} for a in arts],
              f, ensure_ascii=False)
with open(os.path.join(OUT, 'intent.json'), 'w', encoding='utf-8') as f:
    json.dump({'classes': labels, 'W': Wi.tolist(), 'b': bi.tolist()}, f)
with open(os.path.join(OUT, 'meta.json'), 'w', encoding='utf-8') as f:
    json.dump({'dim': D, 'buckets': NB, 'ngram_min': 3, 'ngram_max': 5,
               'hash': 'fnv1a32 over code points; features: w:+word and n-grams of <word>',
               'articles': N, 'steps': STEPS}, f, ensure_ascii=False, indent=2)
log('model size MB: %.1f' % (Q.nbytes / 1e6))
with open(os.path.join(OUT, 'report.txt'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(LOG) + '\n')
