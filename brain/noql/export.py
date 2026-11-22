"""Noql را برای خودِ برنامه آماده می‌کند و همان چیزی را می‌سنجد که برنامه اجرا می‌کند.

خروجی‌ها:
  assets/brain/noql.bin          وزن‌های مدل، int8 سطربه‌سطر (قالب NOQL1 در core.py)
  assets/brain/noql_vocab.json   واژگان توکن‌ساز (قطعه‌ها و امتیازها)
  assets/brain/noql_head.json    سرِ طبقه‌بند (۱۹ دسته) + آستانه‌ها + شناسنامه
  assets/brain/noql_licenses.txt پروانه‌های مدل (همان فایل‌های مخزن سازنده)
  test/understanding/noql_ref.json   خروجیِ مرجع برای تست‌های Dart
  brain/reports/noql_export.md   گزارش

هیچ جملهٔ محک (eval/understanding_probe.tsv) یا مجموعهٔ ب در آموزشِ سر یا انتخاب
آستانه‌ها به‌کار نمی‌رود؛ آن‌ها فقط سنجیده می‌شوند.
"""

import json
import os
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
BRAIN = os.path.dirname(HERE)
ROOT = os.path.dirname(BRAIN)
sys.path.insert(0, HERE)
sys.path.insert(0, BRAIN)
import core  # noqa: E402
from embed_bench import Data, PAIRS  # noqa: E402

REPO = 'shekar-ai/Noql'
REV = os.environ.get('NOQL_REV', '')
ASSETS = os.path.join(ROOT, 'assets', 'brain')
REF = os.path.join(ROOT, 'test', 'understanding', 'noql_ref.json')
OUT = os.path.join(BRAIN, 'reports', 'noql_export.md')

OPEN_PRECISION = float(os.environ.get('OPEN_PRECISION', '0.90'))
ASK_PRECISION = float(os.environ.get('ASK_PRECISION', '0.70'))
C_GRID = (1.0, 4.0, 16.0, 64.0)

ODD = [
    '', ' ', 'سلام', 'می‌خواهم طلاق بگیرم', 'می خواهم   از همسرم  طلاق بگیرم',
    '  سلام.  من یک سوال حقوقی دارم ', 'کارفرماي من حقوقم را پرداخت نكرده است',
    'پسرم ۱۶ ساله است', 'ماده 10 قانون کار', 'iPhone خریدم 😀 خراب بود',
    'مهریه‌ام ۱۱۰ سکه است، شوهرم می‌گوید «ندارم»!', 'آیا حق دارد؟', 'هٔ ۀ ة ئ أ إ آ',
    'خانه‌ام\u200c را', 'a\tb\nc', 'قرار\u200cداد', 'ﻻ ﷲ ﺳﻼﻡ', 'چِکِ بَرگَشتی',
    'صاحبخونه\u00a0پول\u2003پیشم\u3000رو نمیده', 'ABC abc ÀÉ ß', '۱۲۳٬۴۵۶ ریال',
    'http://example.com/a?b=c', '...!!!؟؟؟', '«»()[]{}', 'x' * 50,
    'کلمهٔ‌خیلی‌بلندِ‌به‌هم‌چسبیده‌ای‌که‌در‌واژگان‌نیست',
    ' '.join(['صاحبخانه پول پیش را پس نمی‌دهد و می‌گوید خسارت زده‌ام'] * 8),
]


def lines_of(path):
    out = []
    if os.path.exists(path):
        for line in open(path, encoding='utf-8'):
            line = line.strip()
            if line and not line.startswith('#') and '|' in line:
                out.append(line.split('|', 1)[1].strip())
    return out


def sweep(conf, ok, grid):
    rows = []
    for t in grid:
        m = conf >= t
        rows.append((t, int(m.sum()), int((ok & m).sum())))
    return rows


def pick_threshold(conf, ok, target):
    """کوچک‌ترین آستانه‌ای که دقتِ پاسخ‌های بالای آن به هدف برسد."""
    best = None
    for t in np.unique(np.round(conf, 3)):
        m = conf >= t
        if m.sum() >= 10 and (ok & m).sum() / m.sum() >= target:
            best = float(t)
            break
    return best if best is not None else float(np.quantile(conf, 0.9))


def pick_open(conf, gap, ok, target):
    """آستانه و فاصلهٔ لازم از دستهٔ دوم برای «باز کردن پرونده».

    بین همهٔ جفت‌های (آستانه، فاصله) که دقتشان در اعتبارسنجی به هدف می‌رسد،
    آن‌که جمله‌های بیشتری را پوشش می‌دهد.
    """
    best = None
    for m in (0.0, 0.02, 0.04, 0.06, 0.08, 0.10):
        for t in np.unique(np.round(conf, 3)):
            mask = (conf >= t) & (gap >= m)
            n = int(mask.sum())
            if n < 10 or (ok & mask).sum() / n < target:
                continue
            if best is None or n > best[2]:
                best = (float(t), m, n)
            break
    if best is None:
        return float(np.quantile(conf, 0.9)), 0.0
    return best[0], best[1]


def main():
    from huggingface_hub import HfApi, hf_hub_download
    from safetensors.numpy import load_file
    from sklearn.linear_model import LogisticRegression
    from sklearn.model_selection import StratifiedKFold
    from tokenizers import Tokenizer

    L = ['# آماده‌سازی Noql برای برنامه', '']
    rev = REV or HfApi().model_info(REPO).sha
    L.append(f'- مدل: `{REPO}`، نسخهٔ `{rev}`')

    tj = hf_hub_download(REPO, 'tokenizer.json', revision=rev)
    vocab = json.load(open(tj, encoding='utf-8'))['model']['vocab']
    pieces = [p for p, _ in vocab]
    scores = [float(s) for _, s in vocab]
    uni = core.Unigram(pieces, scores)
    hf_tok = Tokenizer.from_file(tj)
    hf_tok.no_truncation()

    data = Data()
    texts = list(data.texts)
    extra = lines_of(os.path.join(BRAIN, 'intent_data.txt')) \
        + lines_of(os.path.join(BRAIN, 'intent_data_extra.txt')) \
        + lines_of(os.path.join(BRAIN, 'eval', 'intent_eval.txt'))

    # ---------------------------------------------------------- توکن‌ساز
    def hf_ids(t):
        ids = hf_tok.encode(core.prepare(t)).ids
        return [ids[0]] + ids[1:-1][:core.MAX_TOKENS - 2] + [ids[-1]]

    bad = []
    checked = 0
    lens = []
    for t in texts + extra + ODD:
        mine = uni.encode(core.prepare(t))
        ref = hf_ids(t)
        checked += 1
        lens.append(len(ref))
        if mine != ref:
            bad.append((t, mine, ref))
    L.append(f'- توکن‌ساز: {checked} متن با کتابخانهٔ اصلی مقایسه شد؛ '
             f'ناهمخوان: **{len(bad)}**. طول (توکن): میانه {int(np.median(lens))}، '
             f'صدک ۹۵ {int(np.quantile(lens, 0.95))}، بیشینه {max(lens)} '
             f'(سقف برنامه {core.MAX_TOKENS})')
    for t, mine, ref in bad[:10]:
        L.append(f'  - `{t[:60]!r}`: برنامه {mine[:12]} / اصلی {ref[:12]}')

    # ---------------------------------------------------------- وزن‌ها
    state = load_file(hf_hub_download(REPO, 'model.safetensors', revision=rev))
    w32 = core.pick(state)
    q = core.quantize(w32)
    os.makedirs(ASSETS, exist_ok=True)
    bin_path = os.path.join(ASSETS, 'noql.bin')
    core.save(q, bin_path)
    w8 = core.dequantize(core.load(bin_path))
    size_mb = os.path.getsize(bin_path) / 1e6
    L.append(f'- فایل وزن‌ها برای برنامه: `assets/brain/noql.bin`، **{size_mb:.1f} MB** '
             '(همهٔ ماتریس‌ها int8 سطربه‌سطر؛ بدون ONNX)')

    def run(w, items):
        return np.stack([core.embed(w, uni.encode(core.prepare(t))) for t in items])

    t0 = time.time()
    e8 = run(w8, texts)
    per = (time.time() - t0) / len(texts) * 1000
    L.append(f'- زمان هستهٔ مرجع (numpy روی CI): {per:.0f} ms برای هر جمله')

    # مقایسه با مدل اصلی
    try:
        from sentence_transformers import SentenceTransformer
        st = SentenceTransformer(REPO, revision=rev, device='cpu')
        sample = texts[:120]
        ref = st.encode([core.prepare(t) for t in sample], normalize_embeddings=True,
                        batch_size=1, convert_to_numpy=True)
        e32 = run(w32, sample)
        c32 = (e32 * ref).sum(axis=1)
        c8 = (e8[:120] * ref).sum(axis=1)
        L.append(f'- هستهٔ مرجع با وزن fp32 در برابر مدل اصلی (sentence-transformers)، '
                 f'{len(sample)} جمله: کسینوس میانگین {c32.mean():.6f}، کمینه {c32.min():.6f}')
        L.append(f'- همان با وزن int8 برنامه: کسینوس میانگین **{c8.mean():.4f}**، '
                 f'کمینه {c8.min():.4f}')
    except Exception as exc:  # noqa: BLE001
        L.append(f'- مقایسه با sentence-transformers انجام نشد: {exc!r}')

    # ---------------------------------------------------------- سرِ طبقه‌بند
    eex, epr, eb, _, epairs = data.split(e8)
    y = np.array([k for k, _ in data.examples])
    skf = StratifiedKFold(n_splits=4, shuffle=True, random_state=0)
    L += ['', '## سرِ طبقه‌بند (رگرسیون لجستیک روی بردار ۷۶۸تایی)', '',
          '| C | دقت ۴-تایی روی ۲۵۰ نمونه | محک (۳۹) | مجموعهٔ ب (۶۲) |', '|---|---|---|---|']
    best = None
    oofs = {}
    for c in C_GRID:
        oof = np.zeros((len(y), len(set(y))), dtype=np.float64)
        for tr, te in skf.split(eex, y):
            m = LogisticRegression(C=c, max_iter=3000).fit(eex[tr], y[tr])
            oof[te] = m.predict_proba(eex[te])
        m = LogisticRegression(C=c, max_iter=3000).fit(eex, y)
        acc = int((m.classes_[oof.argmax(1)] == y).sum())
        pr = m.classes_[m.predict_proba(epr).argmax(1)]
        bb = m.classes_[m.predict_proba(eb).argmax(1)]
        p_ok = sum(1 for (g, _), k in zip(data.probe, pr) if k in g)
        b_ok = sum(1 for (g, _), k in zip(data.set_b, bb) if k in g)
        L.append(f'| {c:g} | {acc} ({acc / len(y):.0%}) | {p_ok} | {b_ok} |')
        oofs[c] = (oof, m)
        if best is None or acc > best[1]:
            best = (c, acc)
    c = best[0]
    oof, model = oofs[c]
    labels = [str(k) for k in model.classes_]
    L += ['', f'C انتخاب‌شده با اعتبارسنجی روی خودِ نمونه‌ها (نه محک): **{c:g}**', '']

    hw = model.coef_.astype(np.float32)
    hb = model.intercept_.astype(np.float32)

    def probs(e):
        return np.stack([core.head_probs(hw, hb, v) for v in e])

    oof_conf = oof.max(1)
    oof_gap = oof_conf - np.sort(oof, axis=1)[:, -2]
    oof_ok = model.classes_[oof.argmax(1)] == y
    t_open, margin = pick_open(oof_conf, oof_gap, oof_ok, OPEN_PRECISION)
    t_ask = min(pick_threshold(oof_conf, oof_ok, ASK_PRECISION), t_open)

    pp, pb = probs(epr), probs(eb)
    gold = [g for g, _ in data.probe] + [g for g, _ in data.set_b]
    pall = np.concatenate([pp, pb])
    top = pall.argmax(1)
    conf = pall.max(1)
    gap = conf - np.sort(pall, axis=1)[:, -2]
    ok = np.array([labels[i] in g for i, g in zip(top, gold)])
    order = np.argsort(-pall, axis=1)
    ok2 = np.array([labels[o[0]] in g or labels[o[1]] in g for o, g in zip(order, gold)])

    grid = sorted(set([0.0, 0.08, 0.1, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18,
                       0.2, 0.25, 0.3, 0.4, 0.5, round(t_open, 3), round(t_ask, 3)]))
    L += ['## اطمینان و آستانه', '',
          f'- «باز کردن پرونده» (دقت ≥ {OPEN_PRECISION:.0%} در اعتبارسنجی): اطمینان ≥ **{t_open:.3f}** '
          f'و فاصله از دستهٔ دوم ≥ **{margin:.2f}** '
          f'(در اعتبارسنجی: {int(((oof_conf >= t_open) & (oof_gap >= margin)).sum())} پاسخ، '
          f'{int((oof_ok & (oof_conf >= t_open) & (oof_gap >= margin)).sum())} درست)',
          f'- آستانهٔ «پرسیدن از کاربر» (دقت ≥ {ASK_PRECISION:.0%} در اعتبارسنجی): **{t_ask:.3f}**',
          '', '| آستانه | اعتبارسنجی: پاسخ / درست | محک + ب (۱۰۱): پاسخ / درست |',
          '|---|---|---|']
    for (t, a1, c1), (_, a2, c2) in zip(sweep(oof_conf, oof_ok, grid), sweep(conf, ok, grid)):
        L.append(f'| {t:.3f} | {a1} / {c1} | {a2} / {c2} |')
    hi = (conf >= t_open) & (gap >= margin)
    mid = (conf >= t_ask) & ~hi
    low = conf < t_ask
    L += ['', 'رفتار برنامه روی ۱۰۱ جملهٔ سنجش با این دو آستانه:', '',
          f'- حدسِ مطمئن (پرونده مستقیم باز می‌شود): {int(hi.sum())} جمله، {int((ok & hi).sum())} درست، '
          f'**{int((~ok & hi).sum())} غلط**',
          f'- از کاربر می‌پرسد (دو گزینه): {int(mid.sum())} جمله؛ در {int((ok2 & mid).sum())} '
          'مورد گزینهٔ درست بین دو پیشنهاد هست',
          f'- مدل ساکت می‌ماند (مثل الان): {int(low.sum())} جمله '
          f'(اگر حدس می‌زد {int((ok & low).sum())} تا درست بود)',
          f'- بدون آستانه: محک {int(ok[:len(pp)].sum())} از {len(pp)}، '
          f'مجموعهٔ ب {int(ok[len(pp):].sum())} از {len(pb)}', '']
    L += ['### جمله‌های محک', '', '| جمله | درست | مدل | اطمینان | دوم |', '|---|---|---|---|---|']
    for (g, t), o, pr in zip(data.probe, order, pp):
        mark = '' if labels[o[0]] in g else ' ✗'
        L.append(f'| {t[:70]} | {"/".join(g)} | {labels[o[0]]}{mark} | {pr[o[0]]:.2f} | '
                 f'{labels[o[1]]} {pr[o[1]]:.2f} |')
    L += ['', '### نفی (سرِ طبقه‌بند موضوع را می‌گوید، نه نفی را)', '']
    for i, (a, b) in enumerate(PAIRS):
        L.append(f'- «{a}» / «{b}»: کسینوس {float(epairs[2 * i] @ epairs[2 * i + 1]):.2f}')

    # ---------------------------------------------------------- فایل‌های برنامه
    json.dump({'pieces': pieces, 'scores': [round(s, 5) for s in scores]},
              open(os.path.join(ASSETS, 'noql_vocab.json'), 'w', encoding='utf-8'),
              ensure_ascii=False, separators=(',', ':'))
    json.dump({
        'model': REPO, 'revision': rev,
        'license': 'MIT (model) + Apache-2.0 (base ALBERT)',
        'labels': labels, 'dim': int(hw.shape[1]),
        'open': round(t_open, 4), 'margin': round(margin, 4), 'ask': round(t_ask, 4), 'c': c,
        'examples': len(y), 'cv_accuracy': round(best[1] / len(y), 4),
        'b': [round(float(v), 6) for v in hb],
        'w': [round(float(v), 6) for v in hw.reshape(-1)],
    }, open(os.path.join(ASSETS, 'noql_head.json'), 'w', encoding='utf-8'),
        ensure_ascii=False, separators=(',', ':'))

    # سرِ ذخیره‌شده گرد شده است؛ مرجع تست‌ها را با همان می‌سازم.
    head = json.load(open(os.path.join(ASSETS, 'noql_head.json'), encoding='utf-8'))
    hw2 = np.array(head['w'], dtype=np.float32).reshape(len(labels), -1)
    hb2 = np.array(head['b'], dtype=np.float32)
    tok_cases = ODD + [t for _, t in data.probe] + [t for _, t in data.examples[::5]]
    emb_cases = [data.probe[i][1] for i in (0, 7, 19, 30)] + [ODD[9], ODD[-1]]
    ref = {
        'tokens': [{'text': t, 'ids': uni.encode(core.prepare(t))} for t in tok_cases],
        'embeds': [{'text': t, 'vec': [round(float(v), 6) for v in
                                       core.embed(w8, uni.encode(core.prepare(t)))]}
                   for t in emb_cases],
        'probe': [],
    }
    for (g, t), e in zip(data.probe, epr):
        p = core.head_probs(hw2, hb2, e)
        i = int(p.argmax())
        second = float(np.sort(p)[-2])
        ref['probe'].append({'text': t, 'gold': list(g), 'label': labels[i],
                             'score': round(float(p[i]), 4),
                             'confident': bool(p[i] >= head['open']
                                               and p[i] - second >= head['margin']),
                             'plausible': bool(p[i] >= head['ask'])})
    os.makedirs(os.path.dirname(REF), exist_ok=True)
    json.dump(ref, open(REF, 'w', encoding='utf-8'), ensure_ascii=False, indent=0)

    # پروانه‌ها: همان دو فایل مخزن سازنده، به‌علاوهٔ یادداشتِ تغییر.
    lic = open(hf_hub_download(REPO, 'LICENSE', revision=rev), encoding='utf-8').read()
    base = open(hf_hub_download(REPO, 'LICENSE.base-albert', revision=rev),
                encoding='utf-8').read()
    kind = 'MIT' if 'MIT License' in lic else ('Apache-2.0' if 'Apache License' in lic else '?')
    with open(os.path.join(ASSETS, 'noql_licenses.txt'), 'w', encoding='utf-8') as f:
        f.write(f'Noql sentence-embedding model\nSource: https://huggingface.co/{REPO} '
                f'(revision {rev})\n\n'
                'Changes made for this app: the weights were converted to 8-bit integers '
                '(per-row quantization) and stored in a custom file (noql.bin); the tokenizer '
                'vocabulary was re-saved as JSON (noql_vocab.json). The model itself was not '
                'retrained.\n\n'
                '==================== LICENSE ====================\n\n' + lic.strip() + '\n\n'
                '==================== LICENSE.base-albert ====================\n\n'
                + base.strip() + '\n')
    L += ['', '## پروانه', '',
          f'- فایل `LICENSE` مخزن مدل: **{kind}** ({lic.strip().splitlines()[2] if kind == "MIT" else ""})',
          '- فایل `LICENSE.base-albert` (مدل پایه): Apache-2.0',
          '- هر دو متن به‌همراه یادداشتِ تغییرها در `assets/brain/noql_licenses.txt` '
          'گذاشته شده و در صفحهٔ پروانه‌های برنامه نشان داده می‌شود.']

    sizes = {n: os.path.getsize(os.path.join(ASSETS, n)) / 1e6
             for n in ('noql.bin', 'noql_vocab.json', 'noql_head.json')}
    L += ['', '## حجم افزوده به برنامه', '']
    L += [f'- `{n}`: {v:.2f} MB' for n, v in sizes.items()]
    L.append(f'- جمع: **{sum(sizes.values()):.1f} MB** (پیش از فشرده‌سازی APK)')
    open(OUT, 'w', encoding='utf-8').write('\n'.join(L) + '\n')
    print('\n'.join(L))
    if bad:
        sys.exit(f'{len(bad)} tokenizer mismatches')


if __name__ == '__main__':
    main()
