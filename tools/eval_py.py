"""بازنویسی پایتونیِ همگام با موتور lib/core/engine.dart برای ارزیابی سریع آفلاین.
شامل نمایهٔ معکوس (Inverted Index)، جستجوی دودویی پیشوند، پشتیبانی از ماده واحده و مکرر شماره‌دار،
و ارتقای مواد تعریفی (X چیست / یعنی چه) منطبق بر موتور Dart.
اجرا: python3 tools/eval_py.py [-v]"""
from bisect import bisect_left
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'brain'))
from common import normalize  # noqa: E402

NONWORD = re.compile(
    r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+'
)
ART_QUERY_RE = re.compile(
    r'(ماده|اصل)\s*(?:(واحده)(?![\u0600-\u06FFa-z0-9])|(\d+)(?:\s*(مکرر)(?:\s*(\d{1,2})(?!\d))?)?)(?!\s*(?:تومان|ریال|درصد|سکه|ماه|سال|روز))'
)
DEF_Q_RE = re.compile(
    r'چیست|چیه|کیست|یعنی چی|یعنی چه|چه معنی|تعریف|چی هست|به چه گویند|به چه کسی می گویند|به چی می گن|گفته می شود'
)
DEF_WORDS = {
    'یعنی', 'چی', 'چه', 'معنی', 'تعریف', 'هست', 'چیست', 'چیه',
    'گویند', 'کسی', 'کیست', 'گفته', 'شود',
}
DEF_META_PREFIXES = {
    'مجازات', 'مجازاتی', 'شرایط', 'حکم', 'مهلت', 'موارد', 'نحوه', 'میزان',
}
DEF_MARK_RE = re.compile(r'عقدی|عبارت|است|گویند|حاصل')
DEF_STRONG_RE = re.compile(r'^[\s،]*(عقدی|عبارت|شرکتی|کسی)')
CLEAN_BODY_RE = re.compile(r'^[(\[][^)\]]*[)\]]\s*-?\s*')

STOP = set(
    'و در به از که را با این آن برای یک است هست چه چی چیست کی کجا چرا چطور چگونه '
    'آیا من تو شما می هم یا تا بر هر بود شد باشد کند کنم کن بگو درباره مورد لطفا ممنون ماده قانون'.split()
)
SUF = ['ترین', 'هایی', 'های', 'ها']
K1, B, WT, WB, WC = 0.9, 0.7, 3.0, 1.0, 0.5


def collapse(s):
    return re.sub(r'\s+', ' ', s).strip()


def tok(s):
    out = []
    for w in NONWORD.sub(' ', normalize(s)).split(' '):
        if not w or w in STOP:
            continue
        for suf in SUF:
            if len(w) - len(suf) >= 3 and w.endswith(suf):
                w = w[:-len(suf)]
                break
        out.append(w)
    return out


def phrase(s):
    return collapse(NONWORD.sub(' ', normalize(s)))


def obsolete(body):
    n = collapse(normalize(body))
    if len(n) > 300:
        return False
    n = re.sub(r'^[(\[\s]+', '', n)
    return n.startswith(('منسوخ', 'ملغی', 'ملغا', 'حذف شد'))


def _wanted_article(m):
    kind = 'اصل' if m.group(1) == 'اصل' else 'ماده'
    if m.group(2):
        return f'{kind} واحده'
    num = m.group(3)
    mk = (' مکرر ' + m.group(5)) if (m.group(4) and m.group(5)) else (' مکرر' if m.group(4) else '')
    return f'{kind} {num}{mk}'


class Engine:
    def __init__(self):
        self.chunks = []
        self.lawcount = {}
        assets_dir = os.path.join(ROOT, 'assets')
        with open(os.path.join(assets_dir, 'laws_catalog.json'), encoding='utf-8') as f:
            cat = json.load(f)
        self.catalog = cat.get('laws', [])
        meta_path = os.path.join(assets_dir, 'laws', '_meta.json')
        if os.path.isfile(meta_path):
            with open(meta_path, encoding='utf-8') as f:
                meta = json.load(f)
        else:
            meta = {}

        k_path = os.path.join(assets_dir, 'knowledge.txt')
        if os.path.isfile(k_path):
            with open(k_path, encoding='utf-8') as f:
                text = f.read().replace('\r', '')
            self.parse(text, 'دانش عمومی', 'knowledge')

        for lid, info in meta.items():
            if not isinstance(info, dict) or not info.get('path'):
                continue
            p = os.path.join(assets_dir, 'laws', info['path'])
            if os.path.isfile(p):
                with open(p, encoding='utf-8') as f:
                    text = f.read().replace('\r', '')
                fallback = str(info.get('title', '')).strip()
                self.parse(text, fallback, lid)

        self.syn = []
        with open(os.path.join(assets_dir, 'synonyms.txt'), encoding='utf-8') as f:
            for line in f:
                l = line.strip()
                if not l or l.startswith('#') or '|' not in l:
                    continue
                k, v = l.split('|', 1)
                k, v = phrase(k), v.strip()
                if k and v:
                    self.syn.append((k, v))

        df = {}
        self.postings = {}
        self.by_title = {}
        total = 0
        for idx, c in enumerate(self.chunks):
            total += c['len']
            self.by_title.setdefault(c['norm_title'], []).append(idx)
            for t in set(c['T']) | set(c['B']) | set(c['C']):
                df[t] = df.get(t, 0) + 1
                self.postings.setdefault(t, []).append(idx)

        n = len(self.chunks)
        self.avg = max(1.0, total / n) if n else 1.0
        self.idf = {t: math.log((n + 1) / (d + 1)) + 1.0 for t, d in df.items()}
        self.max_idf = max(self.idf.values()) if self.idf else 1.0
        self.vocab = sorted(df.keys())

    def parse(self, text, source, law):
        chapter = ''
        for p in re.split(r'\n\s*\n', text):
            lines = p.strip().split('\n')
            if not lines or not lines[0].strip():
                continue
            first = lines[0].strip()
            if first.startswith('##'):
                chapter = first.lstrip('#').strip()
                continue
            if first.startswith('#'):
                source = first.lstrip('#').strip()
                chapter = ''
                continue
            body = '\n'.join(lines[1:]).strip() if len(lines) > 1 else first
            t_map, b_map, c_map = {}, {}, {}
            ln = 0
            for t in tok(first):
                t_map[t] = t_map.get(t, 0) + 1
                ln += 1
            for t in tok(body):
                b_map[t] = b_map.get(t, 0) + 1
                ln += 1
            for t in tok(chapter) + tok(source):
                c_map[t] = c_map.get(t, 0) + 1
                ln += 1
            self.chunks.append(
                dict(
                    law=law,
                    source=source,
                    title=first,
                    norm_title=collapse(normalize(first)),
                    body=body,
                    obs=(body != first and obsolete(body)),
                    T=t_map,
                    B=b_map,
                    C=c_map,
                    len=ln,
                )
            )
            self.lawcount[law] = self.lawcount.get(law, 0) + 1

    def mentioned(self, q):
        n = collapse(normalize(q))
        matched = []
        for l in self.catalog:
            hit = False
            for name in [l['title']] + list(l.get('aliases', [])):
                full = collapse(normalize(name))
                if not full:
                    continue
                if not (full.startswith('قانون ') or full.startswith('لایحه ')):
                    continue
                if full in n:
                    hit = True
                    break
                short = full[6:].strip() if full.startswith('قانون ') else ''
                if len(short) >= 5 and ('قانون ' + short) in n:
                    hit = True
                    break
            if hit:
                matched.append(l)

        if len(matched) < 2:
            return [l['id'] for l in matched]

        matched_names = {}
        for l in matched:
            for name in [l['title']] + list(l.get('aliases', [])):
                full = collapse(normalize(name))
                if full and full in n:
                    matched_names[l['id']] = full
                    break

        out = []
        for l in matched:
            own = matched_names.get(l['id'])
            if own is None:
                out.append(l['id'])
                continue
            shadowed = any(
                other['id'] != l['id']
                and matched_names.get(other['id'])
                and len(matched_names[other['id']]) > len(own)
                and own in matched_names[other['id']]
                for other in matched
            )
            if not shadowed:
                out.append(l['id'])
        return out

    def _add_prefix_terms(self, t, terms):
        for ln in range(3, len(t)):
            sub = t[:ln]
            if sub in self.idf:
                terms[sub] = max(terms.get(sub, 0.0), 0.5)
        idx = bisect_left(self.vocab, t)
        while idx < len(self.vocab) and self.vocab[idx].startswith(t):
            v = self.vocab[idx]
            terms[v] = max(terms.get(v, 0.0), 0.5)
            idx += 1

    def _promote_definitions(self, question, hits):
        if not hits or not DEF_Q_RE.search(normalize(question)):
            return hits
        toks = [t for t in tok(question) if t not in DEF_WORDS]
        if len(toks) >= 2 and toks[0] in DEF_META_PREFIXES:
            toks = toks[1:]
        if not toks:
            return hits
        cands = []
        for n in (2, 1):
            if len(toks) < n:
                continue
            term = ' '.join(toks[:n])
            strong, weak = [], []
            for h in hits:
                c = h[0]
                if c['law'] == 'knowledge' or c['obs']:
                    continue
                body = CLEAN_BODY_RE.sub('', collapse(normalize(c['body'])), count=1)
                p = term if body.startswith(term) else (
                    f'عقد {term}' if body.startswith(f'عقد {term}') else None
                )
                if p is None:
                    continue
                tail = body[len(p):len(p) + 30]
                if not DEF_MARK_RE.search(tail):
                    continue
                (strong if DEF_STRONG_RE.search(tail) else weak).append(h)
            cands = strong + weak
            if cands:
                break
        if not cands:
            return hits
        picked = cands[:2]
        top_score = hits[0][1]
        picked_ids = {id(p[0]) for p in picked}
        out = [(picked[0][0], max(picked[0][1], top_score))] + list(picked[1:])
        for h in hits:
            if id(h[0]) not in picked_ids:
                out.append(h)
        return out

    def rank(self, question, k=60):
        q = normalize(question)
        qt = list(dict.fromkeys(tok(question)))
        ids = {i for i in self.mentioned(question) if self.lawcount.get(i, 0) > 0}

        m = ART_QUERY_RE.search(q)
        if m:
            want = collapse(_wanted_article(m))
            title_indices = self.by_title.get(want, [])
            found = [
                self.chunks[idx]
                for idx in title_indices
                if not ids or self.chunks[idx]['law'] in ids
            ]
            if found:
                qs = set(qt)
                best = max(found, key=lambda c: len(qs & set(tok(c['source']))))
                return [(best, 99.0)]

        if not qt:
            return []

        terms, total = {}, 0.0
        for t in qt:
            total += self.idf.get(t, 1.0)
            if t in self.idf:
                terms[t] = 1.0
            elif len(t) >= 3:
                self._add_prefix_terms(t, terms)

        n = f' {phrase(question)} '
        for kk, v in self.syn:
            if f' {kk} ' in n:
                for t in tok(v):
                    if t in self.idf:
                        terms[t] = max(terms.get(t, 0.0), 1.0)

        if not terms:
            return []

        cand_set = set()
        for t in terms:
            cand_set.update(self.postings.get(t, ()))
        if not cand_set:
            return []

        hits = []
        for idx in sorted(cand_set):
            c = self.chunks[idx]
            if ids and c['law'] not in ids:
                continue
            s = 0.0
            ln = 1 - B + B * c['len'] / self.avg
            for t, w in terms.items():
                tf = WT * c['T'].get(t, 0) + WB * c['B'].get(t, 0) + WC * c['C'].get(t, 0)
                if tf > 0:
                    tfn = tf / ln
                    s += w * self.idf.get(t, 1.0) * tfn * (K1 + 1) / (tfn + K1)
            if s <= 0:
                continue
            s /= total if total > 0 else 1.0
            if c['obs']:
                s *= 0.1
            hits.append((c, s))

        hits.sort(key=lambda h: -h[1])
        return self._promote_definitions(question, hits)[:k]


def run(eng, path, verbose):
    rows = []
    with open(path, encoding='utf-8') as f:
        for l in f:
            l = l.strip()
            if l and not l.startswith('#'):
                rows.append([x.strip() for x in l.split('|')])
    r1 = r5 = 0
    mrr = 0.0
    bad = []
    for q, law, title in rows:
        rank = 0
        for i, (c, _) in enumerate(eng.rank(q)):
            if c['law'] == law and c['title'] == title:
                rank = i + 1
                break
        r1 += rank == 1
        r5 += 1 <= rank <= 5
        mrr += 1 / rank if rank else 0
        if rank != 1:
            bad.append((rank, q))
    n = len(rows)
    print(
        '%s: n=%d recall@1 %.2f recall@5 %.2f MRR %.3f'
        % (os.path.basename(path), n, r1 / n, r5 / n, mrr / n)
    )
    if verbose:
        for rank, q in bad:
            print('  rank %s | %s' % (rank or '>60', q))
    return (r1 / n, r5 / n, mrr / n)


if __name__ == '__main__':
    e = Engine()
    verbose = '-v' in sys.argv
    check_mode = '--check' in sys.argv
    thresholds = {
        'eval.txt': (0.75, 0.85, 0.80),
        'eval_extra.txt': (0.70, 0.90, 0.78),
        'eval_blind.txt': (0.55, 0.80, 0.65),
        'eval_all_laws.txt': (0.75, 0.90, 0.80),
    }
    failed = False
    for f in ('eval.txt', 'eval_extra.txt', 'eval_blind.txt', 'eval_all_laws.txt'):
        p = os.path.join(ROOT, 'brain', 'eval', f)
        if os.path.exists(p):
            r1, r5, mrr = run(e, p, verbose)
            if check_mode and f in thresholds:
                min_r1, min_r5, min_mrr = thresholds[f]
                if r1 < min_r1 or r5 < min_r5 or mrr < min_mrr:
                    print(
                        f'FAIL {f}: got ({r1:.2f}, {r5:.2f}, {mrr:.3f}) < '
                        f'min ({min_r1:.2f}, {min_r5:.2f}, {min_mrr:.3f})'
                    )
                    failed = True
    if failed:
        sys.exit(1)
