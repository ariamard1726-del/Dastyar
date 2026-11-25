"""آیا مدل برداریِ کوچکِ آزادِ دیگری روی جمله‌های ما از Noql بهتر است؟

همان سنجشِ برنامه: بردار جمله → سرِ طبقه‌بند (رگرسیون لجستیک، C=1) که روی
eval/topic_examples.tsv آموخته و روی محک (۳۹) و مجموعهٔ ب (۶۲) سنجیده می‌شود.
هیچ جملهٔ محک در آموزش نیست. همهٔ مدل‌ها با وزن اصلی (fp32) سنجیده می‌شوند تا
مقایسه منصفانه باشد. خروجی: reports/alt_bench.md
"""

import os
import statistics
import sys
import time
import traceback

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from embed_bench import Data, fix, ngram_vectors, unit  # noqa: E402

OUT = os.path.join(HERE, 'reports', 'alt_bench.md')

# (مخزن، پیشوندی که کارتِ مدل برای جمله می‌خواهد)
MODELS = [
    ('shekar-ai/Noql', ''),
    ('intfloat/multilingual-e5-small', 'query: '),
    ('sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2', ''),
    ('ibm-granite/granite-embedding-107m-multilingual', ''),
    ('PartAI/Tooka-SBERT-V2-Small', ''),
]


def head_scores(data, emb):
    from sklearn.linear_model import LogisticRegression
    from sklearn.model_selection import StratifiedKFold

    eex, epr, eb, _, epairs = data.split(emb)
    y = np.array([k for k, _ in data.examples])
    cv = 0
    for tr, te in StratifiedKFold(4, shuffle=True, random_state=0).split(eex, y):
        m = LogisticRegression(C=1.0, max_iter=3000).fit(eex[tr], y[tr])
        cv += int((m.predict(eex[te]) == y[te]).sum())
    m = LogisticRegression(C=1.0, max_iter=3000).fit(eex, y)
    pp = m.classes_[m.predict_proba(epr).argmax(1)]
    pb = m.classes_[m.predict_proba(eb).argmax(1)]
    p_ok = [k in g for (g, _), k in zip(data.probe, pp)]
    b_ok = [k in g for (g, _), k in zip(data.set_b, pb)]
    sims = epr @ eex.T
    knn = y[sims.argmax(1)]
    knn_ok = sum(k in g for (g, _), k in zip(data.probe, knn))
    knn_b = sum(k in g for (g, _), k in zip(data.set_b, y[(eb @ eex.T).argmax(1)]))
    neg = [float(epairs[2 * i] @ epairs[2 * i + 1]) for i in range(len(epairs) // 2)]
    return {
        'cv': cv, 'n': len(y), 'probe': sum(p_ok), 'b': sum(b_ok),
        'knn': knn_ok, 'knn_b': knn_b, 'neg': neg,
        'miss': [(t, '/'.join(g), k) for (g, t), k, ok in zip(data.probe, pp, p_ok) if not ok],
    }


def run(repo, prefix, data):
    from huggingface_hub import HfApi
    from sentence_transformers import SentenceTransformer

    info = HfApi().model_info(repo)
    lic = next((t.split(':', 1)[1] for t in info.tags or [] if t.startswith('license:')), 'نامشخص')
    st = SentenceTransformer(repo, device='cpu')
    params = sum(p.numel() for p in st.parameters())
    table = 0
    for name, p in st.named_parameters():
        if 'word_embeddings' in name:
            table = p.numel()
    texts = [prefix + fix(t) for t in data.texts]
    emb = unit(st.encode(texts, batch_size=32, convert_to_numpy=True,
                         normalize_embeddings=True))
    probe = [prefix + fix(t) for _, t in data.probe]
    st.encode(probe[:2])
    ts = []
    for t in probe:
        s = time.time()
        st.encode([t])
        ts.append((time.time() - s) * 1000)
    cfg = st[0].auto_model.config
    return {
        'repo': repo, 'license': lic, 'params': params / 1e6, 'table': table / 1e6,
        'dim': emb.shape[1], 'hidden': getattr(cfg, 'hidden_size', 0),
        'layers': getattr(cfg, 'num_hidden_layers', 0),
        'vocab': getattr(cfg, 'vocab_size', 0),
        'ms': statistics.median(ts),
        'tokens': statistics.mean(len(st.tokenizer(t)['input_ids']) for t in probe),
        **head_scores(data, emb),
    }


def write(data, control, rows, fails):
    n_p, n_b = len(data.probe), len(data.set_b)
    L = ['# مدل‌های برداری کوچکِ آزاد در برابر Noql', '',
         f'نمونه‌ها {len(data.examples)}، محک {n_p}، مجموعهٔ ب {n_b}. روش: همان سرِ طبقه‌بندِ برنامه '
         '(رگرسیون لجستیک، C=1) روی بردار fp32 هر مدل.', '',
         '`MCINext/Hakim-small` در این جدول نیست: وزن‌هایش منتشر نشده است '
         '(کارت مدل: «Proprietary / Closed-weight»؛ مخزن فقط README دارد).', '',
         '| مدل | پروانه | پارامتر (M) | سهم جدول واژه (M) | لایه × پهنا | سر: اعتبارسنجی | سر: محک | سر: ب | **جمع ۱۰۱** | نزدیک‌ترین نمونه (محک + ب) | ms/جمله |',
         '|---|---|---|---|---|---|---|---|---|---|---|',
         f"| شاهد بدون مدل (n-gram حرفی) | — | 0 | — | — | {control['cv']} | {control['probe']} | "
         f"{control['b']} | **{control['probe'] + control['b']}** | {control['knn'] + control['knn_b']} | — |"]
    for r in rows:
        L.append(f"| `{r['repo']}` | {r['license']} | {r['params']:.1f} | {r['table']:.1f} | "
                 f"{r['layers']} × {r['hidden']} | {r['cv']} ({r['cv'] / r['n']:.0%}) | {r['probe']} | "
                 f"{r['b']} | **{r['probe'] + r['b']}** | {r['knn'] + r['knn_b']} | {r['ms']:.0f} |")
    L += ['', '«سهم جدول واژه» بخشی از پارامترهاست که فقط جدول توکن‌هاست و محاسبه نمی‌برد؛ '
          'در مدل‌های چندزبانه بیشترِ حجم همین است.', '']
    for r in rows:
        L += [f"## `{r['repo']}`", '',
              f"- بُعد {r['dim']}، واژگان {r['vocab']}، میانگین توکنِ جملهٔ محک {r['tokens']:.1f}",
              '- شباهت جمله با نفیِ خودش (چهار جفت) و یک جفت بی‌ربط: '
              + '، '.join(f'{v:.2f}' for v in r['neg']),
              f"- خطاهای محک ({len(r['miss'])}):"]
        L += [f'  - «{t[:70]}» [{g}] → {k}' for t, g, k in r['miss']]
        L.append('')
    for repo, err in fails:
        L += [f'## اجرا نشد: `{repo}`', '', '```', err, '```', '']
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    open(OUT, 'w', encoding='utf-8').write('\n'.join(L) + '\n')


def main():
    data = Data()
    control = head_scores(data, ngram_vectors(data))
    rows, fails = [], []
    write(data, control, rows, fails)
    only = os.environ.get('MODELS')
    for repo, prefix in MODELS:
        if only and not any(x in repo for x in only.split(',')):
            continue
        print('==', repo, flush=True)
        try:
            rows.append(run(repo, prefix, data))
            print(rows[-1]['probe'], rows[-1]['b'], flush=True)
        except Exception:  # noqa: BLE001
            traceback.print_exc()
            fails.append((repo, traceback.format_exc()[-1200:]))
        write(data, control, rows, fails)


if __name__ == '__main__':
    main()
