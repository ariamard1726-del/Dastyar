"""آزمایش: آیا تنظیم دقیق (fine-tune) مدل Noql فهم موضوع را بهتر می‌کند؟

داده و محک همان‌هایی است که dev/brain/embed_bench.py به کار می‌برد، تا عددها با
reports/embed_bench.md قابل مقایسه باشند. سه روش کنار هم سنجیده می‌شود:
  ۱. Noql دست‌نخورده، نزدیک‌ترین نمونه (همان ردیف گزارش قبلی)
  ۲. Noql دست‌نخورده + یک طبقه‌بند کوچک روی بردارها (بدنهٔ مدل عوض نمی‌شود)
  ۳. Noql تنظیم‌شده روی نمونه‌ها با زیان تقابلیِ نظارت‌شده، نزدیک‌ترین نمونه

هیچ تنظیمی از روی جمله‌های محک انتخاب نمی‌شود: تعداد گام آموزش و ضریب طبقه‌بند
با اعتبارسنجی متقابل روی خودِ نمونه‌ها (eval/topic_examples.tsv) برگزیده می‌شود.

اجرا (در GitHub Actions):  python dev/brain/noql_finetune.py
خروجی: reports/noql_finetune.md و (برای استفادهٔ بعدی) مدل int8 در SAVE_DIR
"""

import copy
import os
import random
import shutil
import sys
import tempfile
import time
import traceback

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from embed_bench import (  # noqa: E402
    PAIRS, Data, export_onnx, file_mb, make_ort_encoder, pct, score, unit,
)

REPO = 'shekar-ai/Noql'
OUT = os.path.join(HERE, 'reports', 'noql_finetune.md')
SAVE = os.environ.get('SAVE_DIR', '/tmp/noql_ft')

FOLDS = 4
CHECKS = [50, 100, 200]      # گام‌هایی که در اعتبارسنجی سنجیده می‌شوند
HEAD_C = [1.0, 10.0, 100.0]  # ضریب‌های طبقه‌بند
SEEDS = [0, 1, 2]
CLASSES_PER_BATCH = 8
PER_CLASS = 4
LR = 2e-5
TAU = 0.1


def encode(st, texts):
    return unit(st.encode(texts, batch_size=64, convert_to_numpy=True,
                          normalize_embeddings=True))


def train(st, texts, labels, steps, seed, on_check=None):
    """زیان تقابلی نظارت‌شده: جمله‌های هم‌موضوع به هم نزدیک، بقیه دور."""
    import torch
    import torch.nn.functional as F

    rng = random.Random(seed)
    torch.manual_seed(seed)
    auto = st[0].auto_model
    tok = st.tokenizer
    by = {}
    for i, y in enumerate(labels):
        by.setdefault(y, []).append(i)
    classes = sorted(by)
    num = {c: k for k, c in enumerate(classes)}
    opt = torch.optim.AdamW(auto.parameters(), lr=LR, weight_decay=0.01)
    warm = max(1, steps // 10)
    losses = []
    for step in range(1, steps + 1):
        auto.train()
        for g in opt.param_groups:
            g['lr'] = LR * min(1.0, step / warm)
        idx = []
        for c in rng.sample(classes, min(CLASSES_PER_BATCH, len(classes))):
            pool = by[c]
            if len(pool) >= PER_CLASS:
                idx += rng.sample(pool, PER_CLASS)
            else:
                idx += [rng.choice(pool) for _ in range(PER_CLASS)]
        enc = tok([texts[i] for i in idx], padding=True, truncation=True,
                  max_length=64, return_tensors='pt')
        hid = auto(**enc)[0]
        mask = enc['attention_mask'].unsqueeze(-1).to(hid.dtype)
        z = F.normalize((hid * mask).sum(1) / mask.sum(1).clamp(min=1e-9), dim=-1)
        y = torch.tensor([num[labels[i]] for i in idx])
        n = z.size(0)
        eye = torch.eye(n, dtype=torch.bool)
        sim = (z @ z.T / TAU).masked_fill(eye, -1e9)
        logp = sim - torch.logsumexp(sim, dim=1, keepdim=True)
        pos = (y[:, None] == y[None, :]) & ~eye
        cnt = pos.sum(1)
        ok = cnt > 0
        loss = (-(logp * pos).sum(1)[ok] / cnt[ok]).mean()
        opt.zero_grad()
        loss.backward()
        torch.nn.utils.clip_grad_norm_(auto.parameters(), 1.0)
        opt.step()
        losses.append(float(loss))
        if step % 25 == 0:
            print(f'    step {step}: loss {np.mean(losses[-25:]):.3f}', flush=True)
        if on_check and step in CHECKS:
            on_check(step)
    auto.eval()
    return losses


def cross_validate(st, base, texts, labels):
    from sklearn.linear_model import LogisticRegression
    from sklearn.model_selection import StratifiedKFold

    knn = {0: 0, **{c: 0 for c in CHECKS}}
    head = {c: 0 for c in HEAD_C}
    skf = StratifiedKFold(n_splits=FOLDS, shuffle=True, random_state=0)
    for f, (tr, te) in enumerate(skf.split(texts, labels)):
        print(f'  fold {f + 1}/{FOLDS}', flush=True)
        st[0].auto_model.load_state_dict(base)
        trt = [texts[i] for i in tr]
        trl = [labels[i] for i in tr]
        tet = [texts[i] for i in te]
        tel = [labels[i] for i in te]

        def check(step):
            etr = encode(st, trt)
            ete = encode(st, tet)
            idx = (ete @ etr.T).argmax(axis=1)
            knn[step] += sum(1 for i, y in zip(idx, tel) if trl[i] == y)
            if step == 0:
                for c in HEAD_C:
                    clf = LogisticRegression(C=c, max_iter=3000).fit(etr, trl)
                    head[c] += int((clf.predict(ete) == np.array(tel)).sum())

        check(0)
        train(st, trt, trl, max(CHECKS), seed=100 + f, on_check=check)
    return knn, head


def head_scores(data, emb, c):
    from sklearn.linear_model import LogisticRegression

    eex, epr, eb, _, _ = data.split(emb)
    labels = [k for k, _ in data.examples]
    clf = LogisticRegression(C=c, max_iter=3000).fit(eex, labels)
    p = clf.predict(epr)
    b = clf.predict(eb) if len(data.set_b) else []
    return (sum(1 for (g, _), y in zip(data.probe, p) if y in g),
            sum(1 for (g, _), y in zip(data.set_b, b) if y in g))


def write(data, S):
    n, nb = len(data.probe), len(data.set_b)
    ne = len(data.examples)
    L = ['# آزمایش تنظیم دقیق (fine-tune) مدل Noql برای فهم موضوع', '']
    L.append(f'دادهٔ آموزش: فقط {ne} نمونه‌جملهٔ `eval/topic_examples.tsv` '
             f'({len(set(k for k, _ in data.examples))} موضوع). '
             f'محک اصلی {n} جمله و محک دوم {nb} جمله در آموزش نیستند.')
    L.append('«اعتبارسنجی روی نمونه‌ها» یعنی نمونه‌ها چهار بخش شده‌اند و هر بار یک بخش '
             'کنار گذاشته و با سه بخش دیگر سنجیده شده است (جمعاً هر نمونه یک بار آزمون شده).')
    L.append(f'تنظیم‌های آموزش (از پیش ثابت): نرخ یادگیری {LR}، هر دسته '
             f'{CLASSES_PER_BATCH}×{PER_CLASS} جمله، دما {TAU}.')
    L.append('')
    if 'stage' in S:
        L.append(f"وضعیت: {S['stage']}")
        L.append('')
    L.append('| روش | اعتبارسنجی روی نمونه‌ها | محک اصلی | محک دوم | جمع دو محک |')
    L.append('|---|---|---|---|---|')

    def row(name, cv, p, b):
        tot = pct(p + b, n + nb) if p is not None else '—'
        L.append(f"| {name} | {pct(cv, ne) if cv is not None else '—'} | "
                 f"{pct(p, n) if p is not None else '—'} | "
                 f"{pct(b, nb) if b is not None else '—'} | {tot} |")

    cv = S.get('cv_knn', {})
    if 'base' in S:
        row('Noql دست‌نخورده، نزدیک‌ترین نمونه', cv.get(0),
            S['base']['knn_ok'], S['base']['b_ok'])
    if 'head' in S:
        h = S['head']
        row(f"Noql دست‌نخورده + طبقه‌بند کوچک (C={h['c']:g})", h['cv'], h['p'], h['b'])
    for r in S.get('ft', []):
        row(f"Noql تنظیم‌شده ({S['steps']} گام)، دانهٔ تصادفی {r['seed']}",
            cv.get(S['steps']) if r['seed'] == SEEDS[0] else None,
            r['knn_ok'], r['b_ok'])
    if 'int8' in S:
        row(f"همان مدل تنظیم‌شده (دانهٔ {SEEDS[0]})، نسخهٔ int8 "
            f"({S['int8']['mb']:.0f} MB)", None,
            S['int8']['knn_ok'], S['int8']['b_ok'])
    L.append('')
    if cv:
        L.append('اعتبارسنجی روی نمونه‌ها بر حسب تعداد گام آموزش (۰ یعنی بدون آموزش): '
                 + '، '.join(f'{k} گام: {pct(v, ne)}' for k, v in sorted(cv.items())))
        L.append('')
    if 'cv_head' in S:
        L.append('اعتبارسنجی طبقه‌بند کوچک بر حسب ضریب C: '
                 + '، '.join(f'{k:g}: {pct(v, ne)}' for k, v in S['cv_head'].items()))
        L.append('')
    if S.get('ft'):
        ps = [r['knn_ok'] for r in S['ft']]
        bs = [r['b_ok'] for r in S['ft']]
        L.append(f'میانگین مدل تنظیم‌شده روی {len(ps)} دانهٔ تصادفی: محک اصلی '
                 f'{np.mean(ps):.1f} از {n} (بازه {min(ps)}–{max(ps)})، محک دوم '
                 f'{np.mean(bs):.1f} از {nb} (بازه {min(bs)}–{max(bs)}).')
        L.append('')
        L.append('## نفی، پیش و پس از تنظیم')
        L.append('')
        L.append('| جملهٔ اول | جملهٔ دوم | دست‌نخورده | تنظیم‌شده |')
        L.append('|---|---|---|---|')
        for i, (a, b) in enumerate(PAIRS):
            L.append(f"| {a} | {b} | {S['base']['pairs'][i]:.2f} | "
                     f"{S['ft'][0]['pairs'][i]:.2f} |")
        L.append('')
        L.append(f'## جمله‌هایی که با تنظیم عوض شدند (محک اصلی، دانهٔ {SEEDS[0]})')
        L.append('')
        L.append('| | جمله | موضوع درست | دست‌نخورده | تنظیم‌شده | نزدیک‌ترین نمونه پس از تنظیم |')
        L.append('|---|---|---|---|---|---|')
        for a, b in zip(S['base']['rows'], S['ft'][0]['rows']):
            if a['ok'] == b['ok'] and a['pred'] == b['pred']:
                continue
            mark = 'بهتر' if b['ok'] and not a['ok'] else (
                'بدتر' if a['ok'] and not b['ok'] else 'همان')
            L.append(f"| {mark} | {a['text']} | {'/'.join(a['gold'])} | {a['pred']} | "
                     f"{b['pred']} | {b['near']} |")
        L.append('')
        L.append(f'## خطاهای باقی‌مانده پس از تنظیم (محک اصلی، دانهٔ {SEEDS[0]})')
        L.append('')
        L.append('| جمله | موضوع درست | گفت | نزدیک‌ترین نمونه | شباهت |')
        L.append('|---|---|---|---|---|')
        for r in S['ft'][0]['rows']:
            if not r['ok']:
                L.append(f"| {r['text']} | {'/'.join(r['gold'])} | {r['pred']} | "
                         f"{r['near']} | {r['sim']:.2f} |")
        L.append('')
    if 'sec' in S:
        L.append(f"زمان کل آزمایش روی پردازندهٔ GitHub Actions: {S['sec'] / 60:.1f} دقیقه "
                 f"(هر گام آموزش حدود {S.get('step_sec', 0):.2f} ثانیه).")
    for e in S.get('errors', []):
        L += ['', 'خطا:', '```', e, '```']
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(L) + '\n')


def main():
    import torch
    from sentence_transformers import SentenceTransformer

    torch.set_num_threads(os.cpu_count() or 4)
    t0 = time.time()
    data = Data()
    S = {'errors': [], 'stage': 'در حال اجرا'}
    st = SentenceTransformer(REPO, device='cpu')
    auto = st[0].auto_model
    base = copy.deepcopy(auto.state_dict())
    emb0 = encode(st, data.texts)
    S['base'] = score(data, emb0)
    print(f"base: probe {S['base']['knn_ok']}, set B {S['base']['b_ok']}", flush=True)
    write(data, S)

    texts = data.texts[:data.cut[0]]
    labels = [k for k, _ in data.examples]
    s = time.time()
    S['cv_knn'], S['cv_head'] = cross_validate(st, base, texts, labels)
    S['step_sec'] = (time.time() - s) / (FOLDS * max(CHECKS))
    print('cv knn', S['cv_knn'], 'cv head', S['cv_head'], flush=True)

    c = max(HEAD_C, key=lambda k: (S['cv_head'][k], -k))
    p, b = head_scores(data, emb0, c)
    S['head'] = {'c': c, 'cv': S['cv_head'][c], 'p': p, 'b': b}
    # بهترین تعداد گام از روی اعتبارسنجی؛ در تساوی، گام کمتر.
    S['steps'] = max(CHECKS, key=lambda k: (S['cv_knn'][k], -k))
    write(data, S)

    S['ft'] = []
    for seed in SEEDS:
        print(f'final seed {seed}', flush=True)
        auto.load_state_dict(base)
        train(st, texts, labels, S['steps'], seed)
        r = score(data, encode(st, data.texts))
        r['seed'] = seed
        S['ft'].append(r)
        print(f"  probe {r['knn_ok']}, set B {r['b_ok']}", flush=True)
        if seed == SEEDS[0]:
            try:
                with tempfile.TemporaryDirectory() as work:
                    files = export_onnx(st, work)
                    q = files.get('int8-s8')
                    if q:
                        enc = make_ort_encoder(st, q)
                        S['int8'] = {**score(data, enc(data.texts)),
                                     'mb': file_mb(q)}
                        os.makedirs(SAVE, exist_ok=True)
                        shutil.copy(q, os.path.join(SAVE, 'noql_ft_int8.onnx'))
                        st.tokenizer.save_pretrained(SAVE)
            except Exception:  # noqa: BLE001
                S['errors'].append(traceback.format_exc()[-1200:])
        write(data, S)
    S['sec'] = time.time() - t0
    S['stage'] = 'کامل'
    write(data, S)


if __name__ == '__main__':
    main()
