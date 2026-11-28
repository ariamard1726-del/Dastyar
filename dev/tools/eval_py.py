"""بازنویسی پایتونیِ همگام با موتور lib/core/engine.dart برای ارزیابی سریع آفلاین.
شامل نمایهٔ معکوس (Inverted Index)، جستجوی دودویی پیشوند، پشتیبانی از ماده واحده و مکرر شماره‌دار،
و ارتقای مواد تعریفی (X چیست / یعنی چه) منطبق بر موتور Dart.
اجرا: python3 dev/tools/eval_py.py [-v]"""
from bisect import bisect_left
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'brain'))
from common import (  # noqa: E402
    collapse,
    is_obsolete as obsolete,
    iter_law_files,
    normalize,
    phrase,
    tok,
)
import engine_rules as _ER  # noqa: E402
import law_terms_rules as _LR  # noqa: E402
import text_norm_rules as _TR  # noqa: E402

NONWORD = re.compile(_TR.NONWORD_PATTERN)
ART_QUERY_RE = re.compile(_ER.ARTICLE_QUERY_PATTERN)
DEF_Q_RE = re.compile(_ER.DEF_QUESTION_PATTERN)
DEF_WORDS = _ER.DEF_WORDS
DEF_META_PREFIXES = _ER.DEF_META_PREFIXES
DEF_MARK_RE = re.compile(_ER.DEF_MARK_PATTERN)
DEF_STRONG_RE = re.compile(_ER.DEF_STRONG_PATTERN)
CLEAN_BODY_RE = re.compile(_ER.CLEAN_BODY_PATTERN)
OBSOLETE_TRIM_RE = re.compile(_ER.OBSOLETE_TRIM_PATTERN)

STOP = _TR.STOP
SUF = _TR.SUFFIXES_INDEX
STEM_MIN_STEM = _TR.STEM_MIN_STEM
K1, B, WT, WB, WC = _ER.BM25_K1, _ER.BM25_B, _ER.BM25_WT, _ER.BM25_WB, _ER.BM25_WC


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

        k_path = os.path.join(assets_dir, 'knowledge.txt')
        if os.path.isfile(k_path):
            with open(k_path, encoding='utf-8') as f:
                text = f.read().replace('\r', '')
            self.parse(text, _LR.GENERAL_SOURCE, 'knowledge')

        for lid, fallback, p in iter_law_files(preserve_order=True):
            with open(p, encoding='utf-8') as f:
                text = f.read().replace('\r', '')
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

        self.topics = {'specialistPenalty': 1.0, 'specialist': {}, 'topics': []}
        tp = os.path.join(assets_dir, 'brain', 'law_topics.json')
        if os.path.isfile(tp):
            with open(tp, encoding='utf-8') as f:
                self.topics = json.load(f)

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
                    chapter=chapter,
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
                if not full.startswith(_ER.LAW_PREFIXES):
                    continue
                if full in n:
                    hit = True
                    break
                short = (
                    full[len(_ER.SHORT_LAW_PREFIX):].strip()
                    if full.startswith(_ER.SHORT_LAW_PREFIX)
                    else ''
                )
                if len(short) >= _ER.SHORT_LAW_MIN_LEN and (_ER.SHORT_LAW_PREFIX + short) in n:
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
        for ln in range(_ER.PREFIX_MIN_LEN, len(t)):
            sub = t[:ln]
            if sub in self.idf:
                terms[sub] = max(terms.get(sub, 0.0), _ER.PREFIX_WEIGHT)
        idx = bisect_left(self.vocab, t)
        while idx < len(self.vocab) and self.vocab[idx].startswith(t):
            v = self.vocab[idx]
            terms[v] = max(terms.get(v, 0.0), _ER.PREFIX_WEIGHT)
            idx += 1

    def _promote_definitions(self, question, hits, factors=None):
        if not hits or not DEF_Q_RE.search(normalize(question)):
            return hits
        factors = factors or {}
        boosted = {l for l, f in factors.items() if f > 1.0}
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
                # تعریفِ قانونِ نامرتبط با موضوع پرسش جلو نمی‌آید.
                if factors.get(c['law'], 1.0) < 1.0:
                    continue
                if boosted and c['law'] not in boosted:
                    continue
                body = CLEAN_BODY_RE.sub('', collapse(normalize(c['body'])), count=1)
                p = term if body.startswith(term) else (
                    f'عقد {term}' if body.startswith(f'عقد {term}') else None
                )
                if p is None:
                    continue
                tail = body[len(p):len(p) + _ER.DEF_TAIL_WINDOW]
                if not DEF_MARK_RE.search(tail):
                    continue
                (strong if DEF_STRONG_RE.search(tail) else weak).append(h)
            cands = strong + weak
            if cands:
                break
        if not cands:
            return hits
        picked = cands[:_ER.DEF_MAX_PICKED]
        top_score = hits[0][1]
        picked_ids = {id(p[0]) for p in picked}
        out = [(picked[0][0], max(picked[0][1], top_score))] + list(picked[1:])
        for h in hits:
            if id(h[0]) not in picked_ids:
                out.append(h)
        return out

    def law_factors(self, question):
        """ضریب موضوعی هر قانون (آینهٔ LawTopicPrior.factors در Dart)."""
        n = f' {phrase(question)} '

        def hit(sigs):
            return any(f' {phrase(s)}' in n for s in sigs)

        out = {}
        pen = float(self.topics.get('specialistPenalty', 1.0))
        for law, sigs in self.topics.get('specialist', {}).items():
            if not hit(sigs):
                out[law] = pen
        for t in self.topics.get('topics', []):
            if hit(t.get('signals', [])):
                for law, w in t.get('laws', {}).items():
                    out[law] = out.get(law, 1.0) * float(w)
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
                return [(best, _ER.EXPLICIT_SCORE)]

        if not qt:
            return []

        terms, total = {}, 0.0
        for t in qt:
            total += self.idf.get(t, 1.0)
            if t in self.idf:
                terms[t] = 1.0
            elif len(t) >= _ER.PREFIX_MIN_LEN:
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

        factors = {} if ids else self.law_factors(question)
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
                s *= _ER.OBSOLETE_PENALTY
            s *= factors.get(c['law'], 1.0)
            hits.append((c, s))

        hits.sort(key=lambda h: -h[1])
        return self._promote_definitions(question, hits, factors)[:k]


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


def run_laws(eng, path, verbose):
    """سنجش در سطح قانون: آیا top-1 در یکی از قانون‌های مجاز پرسش است."""
    rows = []
    with open(path, encoding='utf-8') as f:
        for l in f:
            l = l.strip()
            if l and not l.startswith('#'):
                rows.append([x.strip() for x in l.split('|')])
    ok = 0
    bad = []
    for q, laws in rows:
        allowed = {x.strip() for x in laws.split(',') if x.strip()}
        hits = eng.rank(q, k=1)
        got = hits[0][0]['law'] if hits else None
        if got in allowed:
            ok += 1
        else:
            bad.append((got, q))
    n = len(rows)
    print('%s: n=%d law@1 %.2f' % (os.path.basename(path), n, ok / n))
    if verbose:
        for got, q in bad:
            print('  got %s | %s' % (got, q))
    return ok / n


if __name__ == '__main__':
    e = Engine()
    verbose = '-v' in sys.argv
    check_mode = '--check' in sys.argv
    thresholds = {
        'eval.txt': (0.75, 0.85, 0.80),
        'eval_extra.txt': (0.70, 0.90, 0.78),
        'eval_blind.txt': (0.55, 0.80, 0.65),
        'eval_all_laws.txt': (0.75, 0.90, 0.80),
        'eval_feedback.txt': (0.45, 0.78, 0.60),
    }
    failed = False
    for f in ('eval.txt', 'eval_extra.txt', 'eval_blind.txt', 'eval_all_laws.txt', 'eval_feedback.txt'):
        p = os.path.join(ROOT, 'eval', f)
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
    p = os.path.join(ROOT, 'eval', 'eval_everyday_laws.txt')
    if os.path.exists(p):
        acc = run_laws(e, p, verbose)
        if check_mode and acc < 0.90:
            print(f'FAIL eval_everyday_laws.txt: law@1 {acc:.2f} < 0.90')
            failed = True
    if failed:
        sys.exit(1)
