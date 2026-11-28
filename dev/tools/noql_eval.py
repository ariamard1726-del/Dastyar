#!/usr/bin/env python3
"""سنجش آفلاین و بازتولیدپذیرِ Noqlِ بسته‌بندی‌شده (`assets/brain/noql*`).

این ابزار تصمیم‌های «هویتِ موضوع» برنامه را با همان هستهٔ مرجع (`dev/brain/noql/core.py`،
آینهٔ Dart) می‌سنجد؛ چیزی را تغییر نمی‌دهد و صرفاً گزارش می‌کند (همیشه با کد ۰ خارج می‌شود).

روی دو مجموعهٔ علامت‌گذاری‌شده می‌خواند:
  ۱. `eval/topic_examples.tsv` — همان نمونه‌هایی که سرِ طبقه‌بند رویشان تنظیم شده
     (گزارش «در-نمونه‌ای» است و نباید به‌عنوان عملکرد جهان‌واقعی خوانده شود)؛
  ۲. `eval/understanding_probe.tsv` — جمله‌های واقعی با داوری دستی، **مستقل از تنظیم مدل**
     (تنها عدد قابل‌تعمیم برای پیکربندی فعلی).

معیارها (برای هر دو مجموعه): دقت argmax؛ تعداد و دقت «مطمئن» (p ≥ open و p − p دوم ≥ margin)
و «plausible» (p ≥ ask) با آستانه‌های خودِ noql_head.json.

اجرا:
  python3 dev/tools/noql_eval.py
"""

import json
import os
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'brain', 'noql'))

import numpy as np  # noqa: E402
import core  # noqa: E402

HEAD = os.path.join(ROOT, 'assets', 'brain', 'noql_head.json')
BIN = os.path.join(ROOT, 'assets', 'brain', 'noql.bin')
VOCAB = os.path.join(ROOT, 'assets', 'brain', 'noql_vocab.json')
TOPICS = os.path.join(ROOT, 'eval', 'topic_examples.tsv')
PROBE = os.path.join(ROOT, 'eval', 'understanding_probe.tsv')


def load_all():
    head = json.load(open(HEAD, encoding='utf-8'))
    labels = head['labels']
    dim = head['dim']
    w = np.array(head['w'], dtype=np.float32).reshape(len(labels), dim)
    b = np.array(head['b'], dtype=np.float32)
    model = core.dequantize(core.load(BIN))
    vocab = json.load(open(VOCAB, encoding='utf-8'))
    tok = core.Unigram(vocab['pieces'], vocab['scores'])
    return head, labels, w, b, model, tok


def make_probs(labels, w, b, model, tok):
    def probs(text):
        ids = tok.encode(core.prepare(text))
        e = core.embed(model, ids)
        z = w @ e + b
        z = z - z.max()
        p = np.exp(z)
        return p / p.sum()

    return probs


def read_topics(path):
    rows = []
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        if not line or line.startswith('#'):
            continue
        t, s = line.split('\t', 1)
        rows.append(([t.strip()], s.strip()))
    return rows


def read_probe(path):
    rows = []
    for line in open(path, encoding='utf-8'):
        line = line.rstrip('\n')
        if not line or line.startswith('#'):
            continue
        gold, _rule, text = line.split('\t', 2)
        rows.append(([g.strip() for g in gold.split('|') if g.strip()], text.strip()))
    return rows


def report(name, rows, labels, probs, open_t, margin, ask):
    n = len(rows)
    argmax_ok = 0
    conf = conf_ok = plaus = plaus_ok = 0
    t0 = time.time()
    for gold, text in rows:
        p = probs(text)
        order = np.argsort(p)[::-1]
        a, bidx = int(order[0]), int(order[1])
        pred = labels[a]
        hit = pred in gold
        argmax_ok += hit
        if p[a] >= open_t and (p[a] - p[bidx]) >= margin:
            conf += 1
            conf_ok += hit
        if p[a] >= ask:
            plaus += 1
            plaus_ok += hit
    print('== %s (n=%d) ==' % (name, n))
    print('argmax accuracy        : %.3f (%d/%d)' % (argmax_ok / n, argmax_ok, n))
    print('confident (p≥%.3f, Δ≥%.2f): %d مورد، دقت %.2f' % (
        open_t, margin, conf, conf_ok / conf if conf else 1.0))
    print('plausible (p≥%.3f)       : %d مورد، دقت %.2f' % (
        ask, plaus, plaus_ok / plaus if plaus else 1.0))
    print('(%.1fs)\n' % (time.time() - t0))


def main():
    if np is None:  # pragma: no cover
        print('numpy لازم است')
        return 0
    head, labels, w, b, model, tok = load_all()
    open_t, margin, ask = head['open'], head['margin'], head['ask']
    probs = make_probs(labels, w, b, model, tok)
    print('Noql %s | open=%.3f margin=%.2f ask=%.3f\n' % (
        head.get('model', '?'), open_t, margin, ask))
    report('topic_examples.tsv (در-نمونه‌ای)', read_topics(TOPICS),
           labels, probs, open_t, margin, ask)
    report('understanding_probe.tsv (مستقل)', read_probe(PROBE),
           labels, probs, open_t, margin, ask)
    return 0


if __name__ == '__main__':
    sys.exit(main())
