import glob
import math
import os
import re
import sys
import time

import torch
import torch.nn as nn
import torch.nn.functional as F

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import ROOT

torch.manual_seed(0)
OUT = os.path.join(ROOT, 'nano_out')
os.makedirs(OUT, exist_ok=True)
ITERS = int(os.environ.get('ITERS', '2500'))
BLOCK, BATCH = 128, 32
NL, NH, NE = 4, 4, 128
LOG = []


def log(*a):
    s = ' '.join(str(x) for x in a)
    print(s, flush=True)
    LOG.append(s)


parts = []
for p in sorted(glob.glob(os.path.join(ROOT, 'assets', 'laws', '*.txt'))):
    with open(p, encoding='utf-8') as f:
        parts.append(f.read().replace('\r', ''))
text = '\n'.join(parts)
if len(text) < 20000:
    sys.exit('Too little text')
chars = sorted(set(text))
stoi = {c: i for i, c in enumerate(chars)}
V = len(chars)
data = torch.tensor([stoi[c] for c in text], dtype=torch.long)
cut = int(len(data) * 0.9)
train, val = data[:cut], data[cut:]


def batch(split):
    d = train if split == 'train' else val
    ix = torch.randint(len(d) - BLOCK - 1, (BATCH,))
    x = torch.stack([d[i:i + BLOCK] for i in ix])
    y = torch.stack([d[i + 1:i + BLOCK + 1] for i in ix])
    return x, y


class Block(nn.Module):
    def __init__(self):
        super().__init__()
        self.ln1 = nn.LayerNorm(NE)
        self.attn = nn.MultiheadAttention(NE, NH, batch_first=True)
        self.ln2 = nn.LayerNorm(NE)
        self.mlp = nn.Sequential(nn.Linear(NE, 4 * NE), nn.GELU(), nn.Linear(4 * NE, NE))
        self.register_buffer('mask', torch.triu(torch.ones(BLOCK, BLOCK, dtype=torch.bool), 1))

    def forward(self, x):
        T = x.size(1)
        h = self.ln1(x)
        a, _ = self.attn(h, h, h, attn_mask=self.mask[:T, :T], need_weights=False)
        x = x + a
        return x + self.mlp(self.ln2(x))


class GPT(nn.Module):
    def __init__(self):
        super().__init__()
        self.tok = nn.Embedding(V, NE)
        self.pos = nn.Embedding(BLOCK, NE)
        self.blocks = nn.ModuleList([Block() for _ in range(NL)])
        self.ln = nn.LayerNorm(NE)
        self.head = nn.Linear(NE, V, bias=False)

    def forward(self, idx):
        x = self.tok(idx) + self.pos(torch.arange(idx.size(1)))
        for b in self.blocks:
            x = b(x)
        return self.head(self.ln(x))


model = GPT()
log('chars: %d | vocab: %d | params: %d' % (len(text), V, sum(p.numel() for p in model.parameters())))
opt = torch.optim.AdamW(model.parameters(), lr=3e-3)


@torch.no_grad()
def est(split):
    model.eval()
    ls = []
    for _ in range(10):
        x, y = batch(split)
        ls.append(F.cross_entropy(model(x).view(-1, V), y.view(-1)).item())
    model.train()
    return sum(ls) / len(ls)


t0 = time.time()
for it in range(1, ITERS + 1):
    lr = 3e-3 * (0.1 + 0.9 * 0.5 * (1 + math.cos(math.pi * it / ITERS)))
    for g in opt.param_groups:
        g['lr'] = lr
    x, y = batch('train')
    loss = F.cross_entropy(model(x).view(-1, V), y.view(-1))
    opt.zero_grad()
    loss.backward()
    opt.step()
    if it == 1 or it % 250 == 0:
        log('iter %d train %.3f val %.3f time %ds' % (it, est('train'), est('val'), time.time() - t0))


@torch.no_grad()
def generate(prompt, n=600, temp=0.8):
    model.eval()
    idx = torch.tensor([[stoi.get(c, 0) for c in prompt]])
    for _ in range(n):
        lg = model(idx[:, -BLOCK:])[:, -1, :] / temp
        idx = torch.cat([idx, torch.multinomial(F.softmax(lg, dim=-1), 1)], 1)
    return ''.join(chars[i] for i in idx[0].tolist())


def verbatim(sample):
    pcs = [p.strip() for p in re.split(r'[.\n]', sample) if len(p.strip()) >= 30]
    if len(pcs) > 2:
        pcs = pcs[1:-1]
    if not pcs:
        return 'n/a'
    hit = sum(1 for p in pcs if p in text)
    return '%d of %d sentences appear verbatim in the real law text' % (hit, len(pcs))


samples = []
for prompt in ('ماده 10\n', 'ماده 6\n', 'قانون'):
    for temp in (0.5, 0.8):
        s = generate(prompt, 600, temp)
        samples.append('=== prompt %r temp %.1f ===\n%s\n--- %s\n' % (prompt, temp, s, verbatim(s)))
        log('sample prompt %r temp %.1f: %s' % (prompt, temp, verbatim(s)))
with open(os.path.join(OUT, 'samples.txt'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(samples))
with open(os.path.join(OUT, 'report.txt'), 'w', encoding='utf-8') as f:
    f.write('\n'.join(LOG) + '\n')
