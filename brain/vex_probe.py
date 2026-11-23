"""بررسی مدل DENLIAI/Vex-Base-3.5M-x1 برای کار این برنامه.

این مدل یک مولد متنِ خیلی کوچک (GRU دو لایه) است. دو چیز سنجیده می‌شود:
  ۱. برای جمله‌های محک (eval/understanding_probe.tsv) چه «تفکر» و پاسخی تولید می‌کند.
  ۲. اگر به‌جای تولید متن، حالت درونی‌اش را به‌عنوان بردار جمله برداریم، موضوع را
     چقدر درست تشخیص می‌دهد (همان روش و همان نمونه‌های brain/embed_bench.py).

اجرا (در GitHub Actions):  python brain/vex_probe.py
خروجی: brain/reports/vex_probe.md
"""

import os
import statistics
import sys
import time

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from embed_bench import Data, ngram_vectors, pct, score, unit  # noqa: E402

REPO = 'DENLIAI/Vex-Base-3.5M-x1'
OUT = os.path.join(HERE, 'reports', 'vex_probe.md')
NOQL = 'Noql int8 (از brain/reports/embed_bench.md): محک اصلی 33/39، محک دوم 55/62'


def main():
    import torch
    import torch.nn as nn
    from huggingface_hub import hf_hub_download
    from tokenizers import Tokenizer

    # ساختار مدل، همان که در کارت مدل آمده است.
    class Vex(nn.Module):
        def __init__(self, vocab, embed=256, hidden=384, layers=2):
            super().__init__()
            self.embedding = nn.Embedding(vocab, embed, padding_idx=0)
            self.gru = nn.GRU(embed, hidden, layers, batch_first=True, dropout=0.4)
            self.fc = nn.Linear(hidden, vocab)

        def forward(self, x, hidden=None):
            out, hidden = self.gru(self.embedding(x), hidden)
            return self.fc(out), hidden

    wpath = hf_hub_download(REPO, 'vex_reasoning_weights.pth')
    tok = Tokenizer.from_file(hf_hub_download(REPO, 'bpe_tokenizer.json'))
    model = Vex(tok.get_vocab_size())
    model.load_state_dict(torch.load(wpath, map_location='cpu', weights_only=True))
    model.eval()
    params = sum(p.numel() for p in model.parameters())
    unk = tok.token_to_id('[UNK]')
    if unk is None:
        unk = tok.token_to_id('<unk>')

    def generate(prompt, max_len=100):
        ids = tok.encode(f'A: {prompt}\nC:').ids
        x = torch.tensor([ids], dtype=torch.long)
        out, hidden = [], None
        with torch.no_grad():
            for _ in range(max_len):
                logits, hidden = model(x, hidden)
                nxt = int(logits[0, -1].argmax())
                if nxt == 0:
                    break
                out.append(nxt)
                x = torch.tensor([[nxt]], dtype=torch.long)
        return tok.decode(out)

    def vectors(texts, mode):
        rows = []
        with torch.no_grad():
            for t in texts:
                ids = tok.encode(f'A: {t}').ids or [0]
                o, h = model.gru(model.embedding(torch.tensor([ids])))
                rows.append((h[-1, 0] if mode == 'last' else o[0].mean(0)).numpy())
        return unit(np.stack(rows))

    data = Data()
    n, nb = len(data.probe), len(data.set_b)
    lens, unks = [], 0
    for _, t in data.probe:
        ids = tok.encode(t).ids
        lens.append(len(ids))
        unks += sum(1 for i in ids if unk is not None and i == unk)

    gens, secs = [], []
    for _, t in data.probe:
        s = time.time()
        g = generate(t)
        secs.append(time.time() - s)
        gens.append(g)
        print(t, '=>', g.replace('\n', ' / '), flush=True)

    control = score(data, ngram_vectors(data))
    last = score(data, vectors(data.texts, 'last'))
    mean = score(data, vectors(data.texts, 'mean'))

    L = [f'# بررسی مدل {REPO}', '']
    L.append(f'- نوع: مولد متن، GRU دو لایه؛ پارامتر اندازه‌گیری‌شده: {params / 1e6:.2f} میلیون؛ '
             f'فایل وزن: {os.path.getsize(wpath) / 1e6:.1f} مگابایت؛ واژگان توکن‌ساز: {tok.get_vocab_size()}')
    L.append(f'- میانگین توکن در هر جملهٔ محک: {statistics.mean(lens):.1f}؛ '
             f'توکنِ ناشناخته در کل جمله‌های محک: {unks} از {sum(lens)}')
    L.append(f'- زمان تولید هر پاسخ روی پردازندهٔ GitHub Actions: میانهٔ {statistics.median(secs):.2f} ثانیه')
    L.append('')
    L.append('## ۱. اگر حالت درونی مدل را به‌جای بردار جمله بگیریم')
    L.append('')
    L.append('روش و نمونه‌ها همان brain/embed_bench.py است (نزدیک‌ترین نمونه).')
    L.append('')
    L.append('| روش | محک اصلی | محک دوم |')
    L.append('|---|---|---|')
    L.append(f"| شاهد بدون مدل (n-gram نویسه‌ای) | {pct(control['knn_ok'], n)} | {pct(control['b_ok'], nb)} |")
    L.append(f"| Vex، آخرین حالت پنهان | {pct(last['knn_ok'], n)} | {pct(last['b_ok'], nb)} |")
    L.append(f"| Vex، میانگین حالت‌ها | {pct(mean['knn_ok'], n)} | {pct(mean['b_ok'], nb)} |")
    L.append('')
    L.append(f'برای مقایسه: {NOQL}.')
    L.append('')
    L.append('## ۲. آنچه مدل برای جمله‌های محک تولید می‌کند')
    L.append('')
    L.append('خروجی خام مدل پس از «C:» (تفکر و پاسخ)، بدون هیچ دست‌کاری.')
    L.append('')
    L.append('| جملهٔ کاربر | خروجی مدل |')
    L.append('|---|---|')
    for (_, t), g in zip(data.probe, gens):
        L.append(f"| {t} | {g.replace(chr(10), ' ⏎ ').replace('|', '/')} |")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write('\n'.join(L) + '\n')


if __name__ == '__main__':
    main()
