"""سنجش مدل‌های برداری (embedding) فارسی روی «فهم موضوع جملهٔ کاربر».

پرسش این آزمایش: اگر جملهٔ کاربر به بردار تبدیل و با نمونه‌جمله‌های هر موضوع
(eval/topic_examples.tsv) مقایسه شود، موضوع را بهتر از الگوهای متنیِ فعلی می‌فهمیم؟
هر مدل در سه شکل سنجیده می‌شود: نسخهٔ اصلی (fp32)، و دو نسخهٔ فشردهٔ int8 که همان
چیزی است که در برنامه می‌شود گذاشت. یک «شاهد» بدون مدل هم هست (نزدیک‌ترین نمونه با
n-gram نویسه‌ای روی همان نمونه‌ها) تا معلوم شود سود از مدل است یا فقط از نمونه‌ها.

اجرا (در GitHub Actions، چون مدل‌ها باید از اینترنت گرفته شوند):
    python dev/brain/embed_bench.py
    DRY=1 python dev/brain/embed_bench.py     # بدون مدل؛ فقط شاهد و قالب گزارش
خروجی: reports/embed_bench.md
"""

import json
import os
import statistics
import sys
import tempfile
import time
import traceback

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
from common import normalize  # noqa: E402
from llm_bench import TOPICS, load as load_probe  # noqa: E402

EXAMPLES = os.path.join(ROOT, 'eval', 'topic_examples.tsv')
SET_B = os.path.join(ROOT, 'eval', 'intent_eval.txt')
OUT = os.path.join(ROOT, 'reports', 'embed_bench.md')

# (مخزن، بُعدهای کوتاه‌شدهٔ قابل آزمون برای مدل‌های Matryoshka)
MODELS = [
    ('shekar-ai/Noql', [256, 64]),
    ('PartAI/Tooka-SBERT-V2-Small', []),
]

# برچسب‌های تمیزِ مجموعهٔ قدیمیِ طبقه‌بند نیت → موضوع. برچسب‌های مبهم کنار رفته‌اند.
SET_B_MAP = {
    'cheque': 'cheque', 'labor': 'labor', 'lease': 'rent', 'debt': 'debt',
    'family': 'family', 'litigation_defense': 'accused', 'chitchat': 'chat',
    'out_of_scope': 'other',
}

# جفت‌هایی که فقط در نفی فرق دارند، و یک جفت بی‌ربط برای مقایسه.
PAIRS = [
    ('کارفرما مرا بیمه می‌کند', 'کارفرما مرا بیمه نمی‌کند'),
    ('قرارداد کتبی دارم', 'قرارداد کتبی ندارم'),
    ('حقوقم را داده‌اند', 'حقوقم را نداده‌اند'),
    ('خانه را تخلیه کرده‌ام', 'خانه را تخلیه نکرده‌ام'),
    ('کارفرما اخراجم کرده', 'همسایه سر و صدا می‌کند'),
]

RULES_OK = None  # از فایل محک خوانده می‌شود
LLM_BEST = 'Gemma 3 4B / Gemma 3n E2B: 37/39 (reports/llm_bench.md)'


def fix(s):
    """همان یکسان‌سازیِ کمینه‌ای که برنامه پیش از مدل انجام می‌دهد."""
    return s.replace('ي', 'ی').replace('ك', 'ک').strip()


def load_examples():
    rows = []
    with open(EXAMPLES, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip('\n')
            if not line.strip() or line.startswith('#'):
                continue
            topic, text = line.split('\t', 1)
            rows.append((topic.strip(), text.strip()))
    return rows


def load_set_b():
    rows = []
    if not os.path.exists(SET_B):
        return rows
    with open(SET_B, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#') or '|' not in line:
                continue
            label, text = line.split('|', 1)
            if label in SET_B_MAP:
                rows.append(([SET_B_MAP[label]], text.strip()))
    return rows


def unit(m):
    m = np.asarray(m, dtype=np.float32)
    n = np.linalg.norm(m, axis=1, keepdims=True)
    return m / np.clip(n, 1e-9, None)


class Data:
    def __init__(self):
        self.examples = load_examples()
        probe = load_probe()
        self.probe = [(g, t) for g, _, t in probe]
        self.rules_ok = sum(1 for _, r, _ in probe if r)
        self.set_b = load_set_b()
        self.descs = [f'{v}' for _, v in TOPICS]
        self.desc_ids = [k for k, _ in TOPICS]
        self.pairs = [s for p in PAIRS for s in p]
        # همهٔ متن‌ها یک‌جا بردار می‌شوند و بعد بریده می‌شوند.
        self.texts = ([t for _, t in self.examples] + [t for _, t in self.probe]
                      + [t for _, t in self.set_b] + self.descs + self.pairs)
        self.texts = [fix(t) for t in self.texts]
        a = len(self.examples)
        b = a + len(self.probe)
        c = b + len(self.set_b)
        d = c + len(self.descs)
        self.cut = (a, b, c, d)

    def split(self, emb):
        a, b, c, d = self.cut
        return emb[:a], emb[a:b], emb[b:c], emb[c:d], emb[d:]


def nearest(eq, eex):
    sims = eq @ eex.T
    idx = sims.argmax(axis=1)
    return idx, sims[np.arange(len(idx)), idx]


def centroids(eex, labels):
    ids = sorted(set(labels))
    cs = []
    for k in ids:
        rows = eex[[i for i, lab in enumerate(labels) if lab == k]]
        cs.append(rows.mean(axis=0))
    return ids, unit(np.stack(cs))


def score(data, emb):
    """دقت‌ها و جزئیات برای یک مجموعه بردار (همهٔ متن‌ها، یکه‌شده)."""
    eex, epr, eb, eds, epairs = data.split(emb)
    labels = [k for k, _ in data.examples]
    idx, sim = nearest(epr, eex)
    rows = []
    for (gold, text), i, s in zip(data.probe, idx, sim):
        rows.append({
            'text': text, 'gold': gold, 'pred': labels[i],
            'ok': labels[i] in gold, 'near': data.examples[i][1],
            'sim': float(s),
        })
    cid, cmat = centroids(eex, labels)
    ci, _ = nearest(epr, cmat)
    cen_ok = sum(1 for (g, _), i in zip(data.probe, ci) if cid[i] in g)
    zi, _ = nearest(epr, eds)
    zero_ok = sum(1 for (g, _), i in zip(data.probe, zi)
                  if data.desc_ids[i] in g)
    b_ok = b_cen = 0
    conf = [(r['sim'], r['ok']) for r in rows]
    if len(data.set_b):
        bi, bs = nearest(eb, eex)
        b_ok = sum(1 for (g, _), i in zip(data.set_b, bi) if labels[i] in g)
        conf += [(float(s), labels[i] in g)
                 for (g, _), i, s in zip(data.set_b, bi, bs)]
        bc, _ = nearest(eb, cmat)
        b_cen = sum(1 for (g, _), i in zip(data.set_b, bc) if cid[i] in g)
    pair_sims = [float(epairs[2 * i] @ epairs[2 * i + 1])
                 for i in range(len(PAIRS))]
    return {
        'rows': rows, 'knn_ok': sum(r['ok'] for r in rows),
        'cen_ok': cen_ok, 'zero_ok': zero_ok, 'b_ok': b_ok, 'b_cen': b_cen,
        'pairs': pair_sims, 'conf': conf,
    }


# ------------------------------------------------------------ شاهدِ بدون مدل

def ngram_vectors(data):
    from sklearn.feature_extraction.text import TfidfVectorizer

    a = data.cut[0]
    texts = [normalize(t) for t in data.texts]
    vec = TfidfVectorizer(analyzer='char_wb', ngram_range=(2, 4),
                          sublinear_tf=True)
    vec.fit(texts[:a])
    return unit(vec.transform(texts).toarray())


def overlap(data):
    """بیشترین هم‌پوشانی واژه‌ایِ هر جملهٔ محک با نمونه‌ها (Jaccard سه‌نویسه‌ای)."""
    def grams(s):
        s = ' ' + ' '.join(normalize(s).split()) + ' '
        return {s[i:i + 3] for i in range(len(s) - 2)}

    ex = [(t, grams(t)) for _, t in data.examples]
    out = []
    for _, text in data.probe:
        g = grams(text)
        best = max(ex, key=lambda e: len(g & e[1]) / max(1, len(g | e[1])))
        j = len(g & best[1]) / max(1, len(g | best[1]))
        out.append((j, text, best[0]))
    out.sort(reverse=True)
    return out


# ------------------------------------------------------------------ مدل‌ها

def tokenizer_info(tok):
    def kind(node):
        if not node:
            return '—'
        if node.get('type') == 'Sequence':
            key = 'normalizers' if 'normalizers' in node else (
                'pretokenizers' if 'pretokenizers' in node else 'processors')
            return ' + '.join(kind(x) for x in node.get(key, []))
        return str(node.get('type'))

    try:
        j = json.loads(tok.backend_tokenizer.to_str())
    except Exception as e:  # noqa: BLE001
        return f'نامشخص ({type(tok).__name__}: {e})'
    model = j.get('model', {})
    vocab = model.get('vocab', [])
    return (f"نوع {model.get('type')}، واژگان {len(vocab)}، "
            f"normalizer: {kind(j.get('normalizer'))}، "
            f"pre-tokenizer: {kind(j.get('pre_tokenizer'))}")


def repo_info(repo):
    try:
        from huggingface_hub import model_info

        mi = model_info(repo)
        lic = None
        if mi.card_data is not None:
            lic = getattr(mi.card_data, 'license', None)
        if not lic:
            lic = ', '.join(t.split(':', 1)[1] for t in (mi.tags or [])
                            if t.startswith('license:')) or 'در کارت مدل نیامده'
        onnx = [s.rfilename for s in (mi.siblings or [])
                if s.rfilename.endswith('.onnx')]
        return str(lic), onnx
    except Exception as e:  # noqa: BLE001
        return f'خوانده نشد ({e})', []


def export_onnx(st, workdir):
    """بدنهٔ مدل را به ONNX می‌برد و دو نسخهٔ int8 می‌سازد."""
    import torch
    from onnxruntime.quantization import QuantType, quantize_dynamic

    auto = st[0].auto_model.eval()
    tok = st.tokenizer

    class Wrap(torch.nn.Module):
        def __init__(self, m):
            super().__init__()
            self.m = m

        def forward(self, input_ids, attention_mask):
            return self.m(input_ids=input_ids,
                          attention_mask=attention_mask)[0]

    enc = tok(['سلام دنیا', 'این یک جملهٔ آزمایشیِ کمی بلندتر است'],
              padding=True, return_tensors='pt')
    fp = os.path.join(workdir, 'model.onnx')
    kw = dict(
        input_names=['input_ids', 'attention_mask'],
        output_names=['last_hidden_state'],
        dynamic_axes={
            'input_ids': {0: 'batch', 1: 'tokens'},
            'attention_mask': {0: 'batch', 1: 'tokens'},
            'last_hidden_state': {0: 'batch', 1: 'tokens'},
        },
        opset_version=17,
        do_constant_folding=True,
    )
    args = (enc['input_ids'], enc['attention_mask'])
    with torch.no_grad():
        try:
            torch.onnx.export(Wrap(auto), args, fp, dynamo=False, **kw)
        except TypeError:
            torch.onnx.export(Wrap(auto), args, fp, **kw)
    files = {'onnx-fp32': fp}
    for name, qt in (('int8-s8', QuantType.QInt8), ('int8-u8', QuantType.QUInt8)):
        q = os.path.join(workdir, f'model_{name}.onnx')
        try:
            quantize_dynamic(fp, q, weight_type=qt)
            files[name] = q
        except Exception:  # noqa: BLE001
            print(f'quantize {name} failed', flush=True)
            traceback.print_exc()
    return files


def file_mb(path):
    total = os.path.getsize(path)
    data = path + '.data'  # وزن‌های بیرونی، اگر صادرکننده جدا نوشته باشد
    if os.path.exists(data):
        total += os.path.getsize(data)
    return total / 1e6


def make_ort_encoder(st, path):
    import onnxruntime as ort
    import torch

    so = ort.SessionOptions()
    so.intra_op_num_threads = min(4, os.cpu_count() or 4)
    sess = ort.InferenceSession(path, so, providers=['CPUExecutionProvider'])
    names = {i.name for i in sess.get_inputs()}
    tok = st.tokenizer
    mods = list(st)
    pool_at = next(i for i, m in enumerate(mods)
                   if type(m).__name__ == 'Pooling')
    pool = mods[pool_at]
    use_cls = bool(getattr(pool, 'pooling_mode_cls_token', False))
    post = mods[pool_at + 1:]
    max_len = min(int(st.max_seq_length or 128), 128)

    def encode(texts):
        out = []
        for i in range(0, len(texts), 16):
            enc = tok(texts[i:i + 16], padding=True, truncation=True,
                      max_length=max_len, return_tensors='np')
            feed = {k: v.astype(np.int64) for k, v in enc.items() if k in names}
            h = sess.run(None, feed)[0]
            if use_cls:
                v = h[:, 0]
            else:
                mask = enc['attention_mask'][..., None].astype(np.float32)
                v = (h * mask).sum(axis=1) / np.clip(mask.sum(axis=1), 1e-9, None)
            out.append(v)
        v = np.concatenate(out).astype(np.float32)
        if post:
            feats = {'sentence_embedding': torch.from_numpy(v)}
            with torch.no_grad():
                for m in post:
                    feats = m(feats)
            v = feats['sentence_embedding'].numpy()
        return unit(v)

    return encode


def run_model(repo, dims, data):
    from sentence_transformers import SentenceTransformer

    t0 = time.time()
    st = SentenceTransformer(repo, device='cpu')
    lic, onnx_in_repo = repo_info(repo)
    params = sum(p.numel() for p in st.parameters())
    info = {
        'repo': repo, 'license': lic, 'onnx_in_repo': onnx_in_repo,
        'params_m': params / 1e6,
        'modules': ' → '.join(type(m).__name__ for m in st),
        'dim': st.get_sentence_embedding_dimension(),
        'max_len': st.max_seq_length,
        'prompts': dict(getattr(st, 'prompts', {}) or {}),
        'tokenizer': tokenizer_info(st.tokenizer),
        'tokens': statistics.mean(
            len(st.tokenizer(fix(t))['input_ids']) for _, t in data.probe),
        'variants': [], 'errors': [],
    }
    ref = unit(st.encode(data.texts, batch_size=32, convert_to_numpy=True,
                         normalize_embeddings=True))
    probe_texts = [fix(t) for _, t in data.probe]

    def timed(fn):
        fn(probe_texts[:2])
        ts = []
        for t in probe_texts:
            s = time.time()
            fn([t])
            ts.append((time.time() - s) * 1000)
        return statistics.median(ts)

    def add(name, emb, mb=None, ms=None):
        v = {'name': name, 'mb': mb, 'ms': ms, **score(data, emb)}
        if emb.shape == ref.shape:
            cos = (emb * ref).sum(axis=1)
            v['cos'] = (float(cos.mean()), float(cos.min()))
        info['variants'].append(v)
        print(f"  {repo} {name}: probe {v['knn_ok']}/{len(data.probe)}",
              flush=True)

    add('fp32 (مرجع)', ref, mb=params * 4 / 1e6,
        ms=timed(lambda x: st.encode(x, convert_to_numpy=True)))
    try:
        with tempfile.TemporaryDirectory() as work:
            files = export_onnx(st, work)
            for name, path in files.items():
                try:
                    enc = make_ort_encoder(st, path)
                    emb = enc(data.texts)
                    add(name, emb, mb=file_mb(path), ms=timed(enc))
                    if name == 'int8-s8':
                        for d in dims:
                            if d < emb.shape[1]:
                                add(f'int8-s8، {d} بُعد', unit(emb[:, :d]),
                                    mb=file_mb(path))
                except Exception:  # noqa: BLE001
                    info['errors'].append(f'{name}: ' + traceback.format_exc()[-900:])
    except Exception:  # noqa: BLE001
        info['errors'].append('export: ' + traceback.format_exc()[-1200:])
    info['total_sec'] = time.time() - t0
    return info


# ------------------------------------------------------------------ گزارش

def pct(a, n):
    return f'{a}/{n} ({round(100 * a / n)}%)' if n else '—'


def write(data, control, over, models, fails):
    n = len(data.probe)
    nb = len(data.set_b)
    L = []
    L.append('# سنجش فهم موضوع: مدل برداری فارسی در برابر الگوهای متنی')
    L.append('')
    L.append(f'محک اصلی: {n} جمله (`eval/understanding_probe.tsv`). '
             f'نمونه‌ها: {len(data.examples)} جمله در {len(set(k for k, _ in data.examples))} '
             'موضوع (`eval/topic_examples.tsv`). '
             f'محک دوم: {nb} جملهٔ قدیمیِ محاوره‌ای با برچسب تمیز '
             '(`eval/intent_eval.txt`).')
    L.append('روش اصلی: «نزدیک‌ترین نمونه» (موضوعِ شبیه‌ترین نمونه‌جمله). '
             'زمان روی پردازندهٔ GitHub Actions است و فقط برای مقایسهٔ مدل‌ها با هم معتبر است، نه گوشی.')
    L.append('')
    L.append('| روش | حجم (MB) | محک اصلی: نزدیک‌ترین نمونه | محک اصلی: میانگین هر موضوع | '
             'محک اصلی: فقط شرح موضوع | محک دوم: نزدیک‌ترین نمونه | محک دوم: میانگین هر موضوع | '
             'ms هر جمله | شباهت به fp32 (میانگین/کمینه) |')
    L.append('|---|---|---|---|---|---|---|---|---|')
    L.append(f'| وکیل قاعده‌ای فعلی (داوری دستی) | — | {pct(data.rules_ok, n)} | — | — | — | — | — | — |')
    L.append(f'| مدل زبانی، برای مقایسه | ۲۵۰۰–۳۰۰۰ | {LLM_BEST} | — | — | — | — | — | — |')
    L.append(f"| شاهد بدون مدل: n-gram نویسه‌ای روی همان نمونه‌ها | ~0 | {pct(control['knn_ok'], n)} | "
             f"{pct(control['cen_ok'], n)} | {pct(control['zero_ok'], n)} | {pct(control['b_ok'], nb)} | {pct(control['b_cen'], nb)} | — | — |")
    for m in models:
        for v in m['variants']:
            mb = f"{v['mb']:.0f}" if v.get('mb') else '—'
            ms = f"{v['ms']:.0f}" if v.get('ms') else '—'
            cos = (f"{v['cos'][0]:.3f} / {v['cos'][1]:.3f}"
                   if v.get('cos') else '—')
            L.append(f"| {m['repo']} — {v['name']} | {mb} | {pct(v['knn_ok'], n)} | "
                     f"{pct(v['cen_ok'], n)} | {pct(v['zero_ok'], n)} | "
                     f"{pct(v['b_ok'], nb)} | {pct(v['b_cen'], nb)} | {ms} | {cos} |")
    for repo, err in fails:
        L.append(f'| {repo} | — | اجرا نشد | — | — | — | — | — | — |')
    L.append('')
    L.append('## هم‌پوشانی واژه‌ای محک با نمونه‌ها')
    L.append('')
    L.append('پنج جملهٔ محک که بیشترین شباهت نویسه‌ای را به یک نمونه دارند '
             '(۱ یعنی یکسان). برای داوری دربارهٔ این‌که نمونه‌ها از روی محک نوشته نشده باشند.')
    L.append('')
    L.append('| شباهت | جملهٔ محک | نزدیک‌ترین نمونه |')
    L.append('|---|---|---|')
    for j, text, ex in over[:5]:
        L.append(f'| {j:.2f} | {text} | {ex} |')
    L.append('')
    L.append('## شاهد بدون مدل (n-gram): خطاها')
    L.append('')
    L.append('| جمله | موضوع درست | گفت | نزدیک‌ترین نمونه |')
    L.append('|---|---|---|---|')
    for r in control['rows']:
        if not r['ok']:
            L.append(f"| {r['text']} | {'/'.join(r['gold'])} | {r['pred']} | {r['near']} |")
    for m in models:
        L.append('')
        L.append(f"## {m['repo']}")
        L.append('')
        L.append(f"- پارامتر: {m['params_m']:.1f} میلیون؛ بُعد بردار: {m['dim']}؛ "
                 f"ساختار: {m['modules']}؛ بیشینهٔ طول: {m['max_len']}")
        L.append(f"- مجوز (از کارت مدل): {m['license']}")
        L.append(f"- توکن‌ساز: {m['tokenizer']}؛ میانگین توکن در هر جملهٔ محک: {m['tokens']:.1f}")
        L.append('- فایل ONNX آماده در مخزن مدل: '
                 + (', '.join(m['onnx_in_repo']) if m['onnx_in_repo'] else 'ندارد'))
        if m['prompts']:
            L.append(f"- پیشوندهای تعریف‌شدهٔ مدل: {m['prompts']}")
        L.append(f"- زمان کل این مدل در آزمایش: {m['total_sec']:.0f} ثانیه")
        for e in m['errors']:
            L.append('')
            L.append('خطا:')
            L.append('```')
            L.append(e)
            L.append('```')
        L.append('')
        L.append('شباهت جفت‌هایی که فقط در نفی فرق دارند (۱ یعنی مدل آن دو را یکی می‌بیند؛ ردیف آخر جفت بی‌ربط است):')
        L.append('')
        L.append('| جملهٔ اول | جملهٔ دوم | ' + ' | '.join(v['name'] for v in m['variants']) + ' |')
        L.append('|---|---|' + '---|' * len(m['variants']))
        for i, (a, b) in enumerate(PAIRS):
            L.append(f'| {a} | {b} | '
                     + ' | '.join(f"{v['pairs'][i]:.2f}" for v in m['variants']) + ' |')
        pick = next((v for v in m['variants'] if v['name'] == 'int8-s8'),
                    m['variants'][0] if m['variants'] else None)
        if pick:
            L.append('')
            L.append(f"آستانهٔ اطمینان برای «{pick['name']}» روی هر دو محک با هم "
                     f"({len(pick['conf'])} جمله): اگر فقط وقتی جواب بدهد که شباهت از آستانه بیشتر است:")
            L.append('')
            L.append('| آستانه | جواب می‌دهد | از این‌ها درست | جواب نمی‌دهد |')
            L.append('|---|---|---|---|')
            for t in (0.0, 0.5, 0.55, 0.6, 0.65, 0.7):
                ans = [ok for s, ok in pick['conf'] if s >= t]
                L.append(f"| {t:.2f} | {len(ans)} | {pct(sum(ans), len(ans))} | "
                         f"{len(pick['conf']) - len(ans)} |")
            L.append('')
            L.append(f"جمله‌به‌جمله برای «{pick['name']}»:")
            L.append('')
            L.append('| | جمله | موضوع درست | گفت | نزدیک‌ترین نمونه | شباهت |')
            L.append('|---|---|---|---|---|---|')
            for r in pick['rows']:
                L.append(f"| {'✓' if r['ok'] else '✗'} | {r['text']} | {'/'.join(r['gold'])} | "
                         f"{r['pred']} | {r['near']} | {r['sim']:.2f} |")
    for repo, err in fails:
        L.append('')
        L.append(f'## {repo}: اجرا نشد')
        L.append('')
        L.append('```')
        L.append(err)
        L.append('```')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(L) + '\n')


def main():
    data = Data()
    print(f'examples {len(data.examples)}, probe {len(data.probe)}, '
          f'set B {len(data.set_b)}', flush=True)
    dup = {fix(t) for _, t in data.examples} & {fix(t) for _, t in data.probe}
    if dup:
        raise SystemExit(f'نمونه و محک جملهٔ مشترک دارند: {dup}')
    control = score(data, ngram_vectors(data))
    over = overlap(data)
    print(f"control n-gram: {control['knn_ok']}/{len(data.probe)}", flush=True)
    models, fails = [], []
    write(data, control, over, models, fails)
    if os.environ.get('DRY'):
        return
    only = os.environ.get('MODELS')
    for repo, dims in MODELS:
        if only and not any(x in repo for x in only.split(',')):
            continue
        print(f'== {repo}', flush=True)
        try:
            models.append(run_model(repo, dims, data))
        except Exception:  # noqa: BLE001
            traceback.print_exc()
            fails.append((repo, traceback.format_exc()[-1500:]))
        write(data, control, over, models, fails)


if __name__ == '__main__':
    main()
