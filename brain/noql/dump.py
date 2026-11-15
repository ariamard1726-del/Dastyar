"""یک‌بارمصرف: ساختار توکن‌ساز و وزن‌های Noql را در brain/reports/noql_dump.md می‌نویسد."""
import json
import os

from huggingface_hub import hf_hub_download
from safetensors.numpy import load_file
from tokenizers import Tokenizer

REPO = 'shekar-ai/Noql'
REV = '59f459b443132eb51d967e5436068a510c60281c'
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'reports', 'noql_dump.md')

tj = hf_hub_download(REPO, 'tokenizer.json', revision=REV)
j = json.load(open(tj, encoding='utf-8'))
vocab = j['model'].pop('vocab')
L = ['# Noql dump', '', '```json', json.dumps(j, ensure_ascii=False, indent=1), '```', '']
L.append(f'vocab size {len(vocab)}; first 12: {vocab[:12]}')
scores = [s for _, s in vocab]
L.append(f'min score {min(scores)}; max piece len {max(len(p) for p, _ in vocab)}')
L.append(f"pieces containing ▁ not at start: {sum(1 for p, _ in vocab if '▁' in p[1:])}")
L.append(f"pieces containing ZWNJ: {sum(1 for p, _ in vocab if chr(0x200c) in p)}")
L.append('')
tok = Tokenizer.from_file(tj)
samples = [
    'سلام', 'می‌خواهم طلاق بگیرم', 'می خواهم   از همسرم  طلاق بگیرم',
    '  سلام.  من یک سوال حقوقی دارم ', 'کارفرماي من حقوقم را پرداخت نكرده است',
    'پسرم ۱۶ ساله است', 'ماده 10 قانون کار', 'iPhone خریدم 😀 خراب بود',
    'مهریه‌ام ۱۱۰ سکه است، شوهرم می‌گوید «ندارم»!', 'آیا حق دارد؟', 'هٔ ۀ ة ئ أ إ آ',
    'خانه‌ام\u200c را', 'a\tb\nc', 'قرار\u200cداد', 'ﻻ ﷲ ﺳﻼﻡ', '', ' ',
]
for s in samples:
    e = tok.encode(s)
    L.append(f'- {s!r}')
    L.append(f'  - norm: {tok.normalizer.normalize_str(s)!r}' if tok.normalizer else '  - no normalizer')
    L.append(f'  - tokens: {e.tokens}')
    L.append(f'  - ids: {e.ids}  types: {e.type_ids}')
L.append('')
w = load_file(hf_hub_download(REPO, 'model.safetensors', revision=REV))
L.append('## weights')
for k in sorted(w):
    L.append(f'- {k}: {w[k].shape} {w[k].dtype}')
for name in ('1_Pooling/config.json', 'modules.json', 'config_sentence_transformers.json', 'sentence_bert_config.json'):
    L += ['', f'## {name}', '```json', open(hf_hub_download(REPO, name, revision=REV), encoding='utf-8').read(), '```']
open(OUT, 'w', encoding='utf-8').write('\n'.join(L) + '\n')
