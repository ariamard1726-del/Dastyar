"""هستهٔ مرجعِ Noql به پایتون خالص + numpy.

این فایل دقیقاً همان الگوریتمی است که در برنامه (lib/domain/understanding) به Dart
نوشته شده: توکن‌ساز Unigram، گذر رو به جلوی ALBERT با وزن‌های int8 و سرِ طبقه‌بند.
export.py درستیِ این هسته را با کتابخانه‌های اصلی (tokenizers و transformers)
می‌سنجد و خروجی‌هایش را به‌عنوان مرجعِ تست‌های Dart ذخیره می‌کند.
"""

import json
import re
import struct

import numpy as np

MAGIC = b'NOQL1\x00\x00\x00'
MAX_TOKENS = 64        # با [CLS] و [SEP]
HEADS = 12
LAYERS = 12
EPS = 1e-12

# همان مجموعهٔ «فاصله» که موتور regex توکن‌سازِ اصلی (\s در Rust) می‌شناسد.
SPACE = '\t\n\x0b\x0c\r \x85\xa0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000'
_SPACES = re.compile(f'[{SPACE}]+')
_PIECES = re.compile('▁[^▁]*|^[^▁]+')


def prepare(text):
    """یکسان‌سازیِ کمینهٔ پیش از مدل (همان که در سنجش‌ها به‌کار رفت)."""
    return text.replace('ي', 'ی').replace('ك', 'ک').strip()


class Unigram:
    """توکن‌ساز Unigram با Metaspace و byte fallback (هم‌ارز tokenizer.json مدل)."""

    def __init__(self, pieces, scores, unk_id=1, cls_id=2, sep_id=3):
        self.ids = {}
        for i, p in enumerate(pieces):
            self.ids[p] = i
        self.scores = scores
        self.unk_id, self.cls_id, self.sep_id = unk_id, cls_id, sep_id
        self.unk_score = min(scores) - 10.0
        self.max_len = max(len(p) for p in pieces)
        self.byte0 = self.ids['<0x00>']

    @staticmethod
    def normalize(text):
        return _SPACES.sub(' ', text).strip(' ')

    def _viterbi(self, s):
        n = len(s)
        best = [0.0] * (n + 1)
        start = [-1] * (n + 1)
        tid = [0] * (n + 1)
        for at in range(n):
            here = best[at]
            single = False
            for ln in range(1, min(self.max_len, n - at) + 1):
                i = self.ids.get(s[at:at + ln])
                if i is None:
                    continue
                end = at + ln
                cand = self.scores[i] + here
                if start[end] < 0 or cand > best[end]:
                    best[end], start[end], tid[end] = cand, at, i
                if ln == 1:
                    single = True
            if not single:
                end = at + 1
                cand = self.unk_score + here
                if start[end] < 0 or cand > best[end]:
                    best[end], start[end], tid[end] = cand, at, self.unk_id
        out, fused, end = [], [], n
        while end > 0:
            at = start[end]
            if tid[end] == self.unk_id:
                fused.append(s[at:end])
            else:
                if fused:
                    out.append(''.join(reversed(fused)))
                    fused = []
                out.append(s[at:end])
            end = at
        if fused:
            out.append(''.join(reversed(fused)))
        out.reverse()
        return out

    def encode(self, text, max_tokens=MAX_TOKENS):
        norm = self.normalize(text)
        ids = []
        if norm:
            s = norm.replace(' ', '▁')
            if not s.startswith('▁'):
                s = '▁' + s
            for piece in _PIECES.findall(s):
                for tok in self._viterbi(piece):
                    i = self.ids.get(tok)
                    if i is not None:
                        ids.append(i)
                    else:
                        ids.extend(self.byte0 + b for b in tok.encode('utf-8'))
        return [self.cls_id] + ids[:max_tokens - 2] + [self.sep_id]


# ------------------------------------------------------------------ وزن‌ها

LAYER = 'encoder.albert_layer_groups.0.albert_layers.0.'
# نام کوتاه در فایل برنامه ← نام در مدل اصلی. ماتریس‌ها int8 می‌شوند، بقیه float32.
MATRICES = {
    'word': 'embeddings.word_embeddings.weight',
    'map.w': 'encoder.embedding_hidden_mapping_in.weight',
    'q.w': LAYER + 'attention.query.weight',
    'k.w': LAYER + 'attention.key.weight',
    'v.w': LAYER + 'attention.value.weight',
    'o.w': LAYER + 'attention.dense.weight',
    'f.w': LAYER + 'ffn.weight',
    'fo.w': LAYER + 'ffn_output.weight',
}
VECTORS = {
    'emb_ln.w': 'embeddings.LayerNorm.weight',
    'emb_ln.b': 'embeddings.LayerNorm.bias',
    'map.b': 'encoder.embedding_hidden_mapping_in.bias',
    'q.b': LAYER + 'attention.query.bias',
    'k.b': LAYER + 'attention.key.bias',
    'v.b': LAYER + 'attention.value.bias',
    'o.b': LAYER + 'attention.dense.bias',
    'att_ln.w': LAYER + 'attention.LayerNorm.weight',
    'att_ln.b': LAYER + 'attention.LayerNorm.bias',
    'f.b': LAYER + 'ffn.bias',
    'fo.b': LAYER + 'ffn_output.bias',
    'out_ln.w': LAYER + 'full_layer_layer_norm.weight',
    'out_ln.b': LAYER + 'full_layer_layer_norm.bias',
}


def pick(state):
    """وزن‌های لازم از مدل اصلی (float32)، با نام‌های کوتاه."""
    w = {k: np.asarray(state[v], dtype=np.float32) for k, v in MATRICES.items()}
    w.update({k: np.asarray(state[v], dtype=np.float32) for k, v in VECTORS.items()})
    w['pos'] = np.asarray(state['embeddings.position_embeddings.weight'][:MAX_TOKENS],
                          dtype=np.float32)
    w['type0'] = np.asarray(state['embeddings.token_type_embeddings.weight'][0],
                            dtype=np.float32)
    return w


def quantize(w):
    """هر سطرِ هر ماتریس: int8 متقارن با مقیاس خودش."""
    q = {}
    for k, m in w.items():
        if k in MATRICES:
            scale = np.abs(m).max(axis=1) / 127.0
            scale = np.where(scale > 0, scale, 1.0).astype(np.float32)
            q[k] = np.clip(np.rint(m / scale[:, None]), -127, 127).astype(np.int8)
            q[k + '.scale'] = scale
        else:
            q[k] = m.astype(np.float32)
    return q


def dequantize(q):
    w = {}
    for k, m in q.items():
        if k.endswith('.scale'):
            continue
        if m.dtype == np.int8:
            w[k] = m.astype(np.float32) * q[k + '.scale'][:, None]
        else:
            w[k] = m
    return w


def save(q, path):
    names = sorted(q)
    metas, blobs, off = [], [], 0
    for k in names:
        a = np.ascontiguousarray(q[k])
        raw = a.astype('<f4').tobytes() if a.dtype != np.int8 else a.tobytes()
        pad = (-len(raw)) % 16
        metas.append({'name': k, 'type': 'i8' if a.dtype == np.int8 else 'f32',
                      'shape': list(a.shape), 'offset': off})
        blobs.append(raw + b'\x00' * pad)
        off += len(raw) + pad
    head = json.dumps({'max_tokens': MAX_TOKENS, 'heads': HEADS, 'layers': LAYERS,
                       'tensors': metas}).encode('utf-8')
    head += b' ' * ((-(len(MAGIC) + 4 + len(head))) % 16)
    with open(path, 'wb') as f:
        f.write(MAGIC + struct.pack('<I', len(head)) + head)
        for b in blobs:
            f.write(b)


def load(path):
    raw = open(path, 'rb').read()
    assert raw[:8] == MAGIC
    n = struct.unpack('<I', raw[8:12])[0]
    head = json.loads(raw[12:12 + n].decode('utf-8'))
    base = 12 + n
    q = {}
    for t in head['tensors']:
        count = int(np.prod(t['shape']))
        dt = np.int8 if t['type'] == 'i8' else np.dtype('<f4')
        q[t['name']] = np.frombuffer(raw, dtype=dt, count=count,
                                     offset=base + t['offset']).reshape(t['shape'])
    return q


# ------------------------------------------------------------------ گذر رو به جلو

def _ln(x, w, b):
    mu = x.mean(axis=-1, keepdims=True)
    var = ((x - mu) ** 2).mean(axis=-1, keepdims=True)
    return (x - mu) / np.sqrt(var + EPS) * w + b


def _gelu_new(x):
    return 0.5 * x * (1.0 + np.tanh(0.7978845608028654 * (x + 0.044715 * x ** 3)))


def embed(w, ids):
    """بردار جمله (میانگین توکن‌ها، یکه‌شده) برای فهرست شناسهٔ توکن."""
    t = len(ids)
    x = w['word'][ids] + w['type0'] + w['pos'][:t]
    x = _ln(x, w['emb_ln.w'], w['emb_ln.b'])
    h = x @ w['map.w'].T + w['map.b']
    d = h.shape[1] // HEADS
    for _ in range(LAYERS):
        q = (h @ w['q.w'].T + w['q.b']).reshape(t, HEADS, d).transpose(1, 0, 2)
        k = (h @ w['k.w'].T + w['k.b']).reshape(t, HEADS, d).transpose(1, 0, 2)
        v = (h @ w['v.w'].T + w['v.b']).reshape(t, HEADS, d).transpose(1, 0, 2)
        s = q @ k.transpose(0, 2, 1) / np.sqrt(d)
        s = s - s.max(axis=-1, keepdims=True)
        p = np.exp(s)
        p = p / p.sum(axis=-1, keepdims=True)
        ctx = (p @ v).transpose(1, 0, 2).reshape(t, HEADS * d)
        a = _ln(h + ctx @ w['o.w'].T + w['o.b'], w['att_ln.w'], w['att_ln.b'])
        f = _gelu_new(a @ w['f.w'].T + w['f.b'])
        h = _ln(a + f @ w['fo.w'].T + w['fo.b'], w['out_ln.w'], w['out_ln.b'])
    e = h.mean(axis=0)
    return (e / max(float(np.linalg.norm(e)), 1e-12)).astype(np.float32)


def head_probs(hw, hb, e):
    z = hw @ e + hb
    z = z - z.max()
    p = np.exp(z)
    return p / p.sum()
