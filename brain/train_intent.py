"""آموزش شبکهٔ عصبی کوچکِ طبقه‌بندی نیت (کاملاً آفلاین) و صدور وزن‌ها برای اپ.

معماری: ویژگی‌های هش‌شدهٔ واژه + n-gram حرفی (همان الگوریتم brain/common.py
با NB کوچک‌تر) → ورودی L1-نرمال → MLP یک لایهٔ نهان (relu) → softmax.
وزن‌ها به int8 متقارن کوانتیده و به‌صورت base64 در assets/brain/intent_model.json
ذخیره می‌شوند تا lib/intent_net.dart بتواند بدون هیچ افزونهٔ بومی (tflite و…)
استنتاج را دقیقاً همین‌جا، آفلاین، اجرا کند.

اجرا:  python3 brain/train_intent.py   (به numpy نیاز دارد)
ورودی: brain/intent_data.txt (آموزش) و brain/eval/intent_eval.txt (سنجش generalization)
خروجی: assets/brain/intent_model.json + کپی و معیارها در artifacts/brain-model/
"""
import base64
import json
import math
import os
import re
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from common import ROOT, fnv, normalize  # noqa: E402

NB = int(os.environ.get('NB', '4096'))   # سطل‌های هش ویژگی
HIDDEN = 64                              # نورون‌های لایهٔ نهان
NGRAM_MIN, NGRAM_MAX = 3, 5
EPOCHS = int(os.environ.get('EPOCHS', '160'))
BATCH = 64
LR = 2e-3
L2 = 2e-5
SEED = 0
IN_DROP = 0.15       # dropout روی سطل‌های ویژگی ورودی
H_DROP = 0.35        # dropout روی لایهٔ نهان
LABEL_SMOOTH = 0.06
PATIENCE = 35        # توقف زودهنگام بر اساس اعتبارسنجی داخلی

OUT_MODEL = os.path.join(ROOT, 'assets', 'brain', 'intent_model.json')
OUT_DIR = os.path.join(ROOT, 'artifacts', 'brain-model')

_NONWORD = re.compile(
    r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+')

FILLERS = ['ببین ', 'راستی ', 'آقا ', 'یه مشکل دارم: ', 'سلام، ', 'لطفاً ',
           'به نظرت ', 'یه سوال: ', 'راهنمایی می‌خوام؛ ', 'عجله‌ایه، ']
SUFFIXES = [' به نظرت چیه؟', ' فکری به حالش بکن', ' تکلیفم چیه؟',
            ' چه‌کار باید بکنم؟', ' کمکم کن', '']
COLLOQ = [('می‌خواهم', 'میخوام'), ('نمی‌خواهم', 'نمیخوام'), ('می‌دهد', 'میده'),
          ('نمی‌دهد', 'نمیده'), ('می‌دهم', 'میدم'), ('را ', ' رو '),
          ('خانه', 'خونه'), ('چه کار', 'چکار'), ('چطور است', 'چطوره'),
          ('می‌شود', 'میشه'), ('نمی‌شود', 'نمیشه'), ('رفته است', 'رفته'),
          ('گفته است', 'گفته'), ('نیست', 'نیس')]


def strip_nonbmp(s):
    return ''.join(ch for ch in s if ord(ch) <= 0xFFFF)


def words(s):
    return [w for w in _NONWORD.sub(' ', normalize(strip_nonbmp(s))).split(' ')
            if w]


def feats(text):
    """دقیقاً هم‌الگوریتم با lib/intent_net.dart — تغییرش = شکستن آینهٔ Dart."""
    ids = []
    for w in words(text):
        ids.append(fnv('w:' + w) % NB)
        t = '<' + w + '>'
        for n in range(NGRAM_MIN, NGRAM_MAX + 1):
            for i in range(len(t) - n + 1):
                ids.append(fnv(t[i:i + n]) % NB)
    return ids


def load_rows(path):
    rows = []
    with open(path, encoding='utf-8') as f:
        for l in f:
            l = l.strip()
            if not l or l.startswith('#') or '|' not in l:
                continue
            label, text = l.split('|', 1)
            rows.append((label.strip(), text.strip()))
    return rows


def augment(rows, rng):
    """تنوع سطحی برای جلوگیری از حفظ‌کردن: نویز واژه، محاوره‌ای‌سازی و پرکننده."""
    out = list(rows)
    for label, text in rows:
        ws = text.split(' ')
        if len(ws) >= 4:
            i = int(rng.integers(1, len(ws) - 1))
            cand = ' '.join(ws[:i] + ws[i + 1:])
            if cand.strip():
                out.append((label, cand))
        t2 = text
        for a, b in COLLOQ:
            if a in t2:
                t2 = t2.replace(a, b, 1)
        if t2 != text:
            out.append((label, t2))
        if rng.random() < 0.5:
            f = FILLERS[int(rng.integers(len(FILLERS)))]
            s = SUFFIXES[int(rng.integers(len(SUFFIXES)))]
            cand = (f + text + s).strip()
            if cand != text:
                out.append((label, cand))
        if '\u200c' in text:
            out.append((label, text.replace('\u200c', ' ')))
    seen, uniq = set(), []
    for label, text in out:
        k = (label, text)
        if k in seen or not text.strip():
            continue
        seen.add(k)
        uniq.append(k)
    return uniq


def vectorize(rows, labels):
    li = {l: i for i, l in enumerate(labels)}
    X = np.zeros((len(rows), NB), dtype=np.float32)
    Y = np.zeros((len(rows), len(labels)), dtype=np.float32)
    for r, (label, text) in enumerate(rows):
        for b in feats(text):
            X[r, b] += 1.0
        s = X[r].sum()
        if s > 0:
            X[r] /= s
        Y[r, li[label]] = 1.0
    return X, Y


def softmax(z):
    z = z - z.max(axis=1, keepdims=True)
    e = np.exp(z)
    return e / e.sum(axis=1, keepdims=True)


def quantize_int8(arr):
    m = float(np.max(np.abs(arr))) or 1.0
    scale = m / 127.0
    q = np.clip(np.round(arr / scale), -127, 127).astype(np.int8)
    return q, scale


def dequantize(q, scale):
    return q.astype(np.float32) * np.float32(scale)


def predict(params, X):
    W1, b1, W2, b2 = params
    H = np.maximum(X @ W1 + b1, 0.0)
    return softmax(H @ W2 + b2)


def accuracy(params, X, Y):
    p = predict(params, X)
    return float((p.argmax(axis=1) == Y.argmax(axis=1)).mean())


def main():
    rng = np.random.default_rng(SEED)
    t0 = time.time()

    train = load_rows(os.path.join(ROOT, 'brain', 'intent_data.txt'))
    extra_path = os.path.join(ROOT, 'brain', 'intent_data_extra.txt')
    if os.path.isfile(extra_path):
        train += load_rows(extra_path)
    evl = load_rows(os.path.join(ROOT, 'brain', 'eval', 'intent_eval.txt'))
    labels = sorted({l for l, _ in train} | {l for l, _ in evl})
    base_n = len(train)
    train = augment(train, rng)
    train = [train[i] for i in rng.permutation(len(train))]
    cut = int(len(train) * 0.9)
    tr, va = train[:cut], train[cut:]
    print('train=%d (aug->%d) val=%d eval=%d labels=%d nb=%d' % (
        base_n, len(tr), len(va), len(evl), len(labels), NB))

    X, Y = vectorize(tr, labels)
    Xv, Yv = vectorize(va, labels)
    Xe, Ye = vectorize(evl, labels)
    n = len(X)

    W1 = (rng.standard_normal((NB, HIDDEN)) / math.sqrt(NB)).astype(np.float32)
    b1 = np.zeros(HIDDEN, dtype=np.float32)
    W2 = (rng.standard_normal((HIDDEN, len(labels))) / math.sqrt(HIDDEN)).astype(np.float32)
    b2 = np.zeros(len(labels), dtype=np.float32)
    params = [W1, b1, W2, b2]
    mW = [np.zeros_like(p) for p in params]
    mV = [np.zeros_like(p) for p in params]
    beta1, beta2, eps = 0.9, 0.999, 1e-8
    step = 0

    ys = Y * (1 - LABEL_SMOOTH) + LABEL_SMOOTH / len(labels)
    # وزن کلاس‌ها برای مقابله با نامتوازنی (legal_question/article_lookup بزرگ‌اند)
    counts = Y.sum(axis=0)
    cw = len(Y) / (len(labels) * np.maximum(counts, 1.0))
    cw = np.clip(cw, 0.3, 3.0).astype(np.float32)
    sw = cw[Y.argmax(axis=1)]
    print('class weights: ' + ', '.join(
        '%s=%.2f' % (l, cw[i]) for i, l in enumerate(labels)))
    best_val, best_state, bad = -1.0, None, 0
    for ep in range(EPOCHS):
        perm = rng.permutation(n)
        tot = 0.0
        for i in range(0, n, BATCH):
            idx = perm[i:i + BATCH]
            xb, yb = X[idx], ys[idx]
            if IN_DROP > 0:
                mask = (rng.random(xb.shape) >= IN_DROP).astype(np.float32)
                xb = xb * mask
                rs = xb.sum(axis=1, keepdims=True)
                xb = xb / np.where(rs > 0, rs, 1.0)
            H = np.maximum(xb @ W1 + b1, 0.0)
            if H_DROP > 0:
                hmask = ((rng.random(H.shape) >= H_DROP).astype(np.float32)
                         / (1 - H_DROP))
                Hd = H * hmask
            else:
                hmask = None
                Hd = H
            logits = Hd @ W2 + b2
            p = softmax(logits)
            wb = sw[idx]
            loss = (-np.sum(wb * np.sum(yb * np.log(p + 1e-12), axis=1))
                    / wb.sum())
            tot += loss * len(idx)
            dlogits = (p - yb) * (wb / wb.sum())[:, None]
            gW2 = Hd.T @ dlogits + L2 * W2
            gb2 = dlogits.sum(axis=0)
            dH = (dlogits @ W2.T) * (H > 0)
            if hmask is not None:
                dH = dH * hmask
            gW1 = xb.T @ dH + L2 * W1
            gb1 = dH.sum(axis=0)
            step += 1
            for j, g in enumerate((gW1, gb1, gW2, gb2)):
                mW[j] = beta1 * mW[j] + (1 - beta1) * g
                mV[j] = beta2 * mV[j] + (1 - beta2) * (g * g)
                mh = mW[j] / (1 - beta1 ** step)
                vh = mV[j] / (1 - beta2 ** step)
                params[j] = (params[j]
                             - np.float32(LR) * (mh / (np.sqrt(vh) + eps)).astype(np.float32))
            W1, b1, W2, b2 = params
        val_acc = accuracy(params, Xv, Yv)
        if val_acc > best_val:
            best_val = val_acc
            best_state = [p.copy() for p in params]
            bad = 0
        else:
            bad += 1
        if (ep + 1) % 20 == 0 or ep == 0:
            print('ep %3d loss %.4f train %.3f val %.3f eval %.3f' % (
                ep + 1, tot / n, accuracy(params, X, Y), val_acc,
                accuracy(params, Xe, Ye)))
        if bad >= PATIENCE:
            print('early stop at epoch %d (best val %.3f)' % (ep + 1, best_val))
            break

    if best_state is not None:
        params = best_state
        W1, b1, W2, b2 = params
    acc_train = accuracy(params, X, Y)
    acc_eval = accuracy(params, Xe, Ye)
    print('FINAL float  train %.4f eval %.4f (best val %.4f)' % (
        acc_train, acc_eval, best_val))

    qW1, sW1 = quantize_int8(W1)
    qb1, sb1 = quantize_int8(b1)
    qW2, sW2 = quantize_int8(W2)
    qb2, sb2 = quantize_int8(b2)
    qparams = (dequantize(qW1, sW1), dequantize(qb1, sb1),
               dequantize(qW2, sW2), dequantize(qb2, sb2))
    acc_train_q = accuracy(qparams, X, Y)
    acc_eval_q = accuracy(qparams, Xe, Ye)
    print('FINAL int8   train %.4f eval %.4f' % (acc_train_q, acc_eval_q))

    def b64(q):
        return base64.b64encode(np.asarray(q, dtype=np.int8).tobytes()).decode()

    model = {
        'version': 1,
        'created': time.strftime('%Y-%m-%d'),
        'script': 'brain/train_intent.py',
        'nb': NB,
        'hidden': HIDDEN,
        'activation': 'relu',
        'input_norm': 'l1',
        'ngram': [NGRAM_MIN, NGRAM_MAX],
        'labels': labels,
        'thresholds': {'topic_min': 0.45, 'rag_min': 0.50, 'cancel_min': 0.60},
        'w1': {'shape': [NB, HIDDEN], 'scale': sW1, 'b64': b64(qW1)},
        'b1': {'shape': [HIDDEN], 'scale': sb1, 'b64': b64(qb1)},
        'w2': {'shape': [HIDDEN, len(labels)], 'scale': sW2, 'b64': b64(qW2)},
        'b2': {'shape': [len(labels)], 'scale': sb2, 'b64': b64(qb2)},
        'metrics': {
            'train_samples': base_n,
            'train_samples_aug': len(tr),
            'eval_samples': len(evl),
            'train_accuracy': round(acc_train, 4),
            'eval_accuracy': round(acc_eval, 4),
            'train_accuracy_int8': round(acc_train_q, 4),
            'eval_accuracy_int8': round(acc_eval_q, 4),
            'train_seconds': round(time.time() - t0, 1),
        },
    }
    os.makedirs(os.path.dirname(OUT_MODEL), exist_ok=True)
    with open(OUT_MODEL, 'w', encoding='utf-8') as f:
        json.dump(model, f, ensure_ascii=False)
    size = os.path.getsize(OUT_MODEL)
    print('wrote %s (%.1f KB)' % (OUT_MODEL, size / 1024))

    os.makedirs(OUT_DIR, exist_ok=True)
    with open(os.path.join(OUT_DIR, 'intent_model.json'), 'w', encoding='utf-8') as f:
        json.dump(model, f, ensure_ascii=False)
    with open(os.path.join(OUT_DIR, 'metrics.txt'), 'w', encoding='utf-8') as f:
        f.write(json.dumps(model['metrics'], indent=2, ensure_ascii=False) + '\n')
        f.write('labels: %s\n' % ', '.join(labels))
    print('copied to %s' % OUT_DIR)

    if acc_eval_q < 0.88:
        sys.exit('eval accuracy too low: %.4f' % acc_eval_q)


if __name__ == '__main__':
    main()
