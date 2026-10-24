"""بازنویسی پایتونیِ موتور lib/engine.dart برای ارزیابی سریع.
خروجی تقریباً با Dart یکی است ولی مرجع نهایی، تست‌های Dart در GitHub است.
اجرا: python3 tools/eval_py.py [-v]"""
import glob, json, math, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'brain'))
from common import normalize  # noqa: E402

NONWORD = re.compile(
    r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+')
STOP = set('و در به از که را با این آن برای یک است هست چه چی چیست کی کجا چرا چطور چگونه آیا من تو شما می هم یا تا بر هر بود شد باشد کند کنم کن بگو درباره مورد لطفا ممنون ماده قانون'.split())
SUF = ['ترین', 'هایی', 'های', 'ها']
K1, B, WT, WB, WC = 1.2, 0.4, 3.0, 1.0, 0.5


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


class Engine:
    def __init__(self):
        self.chunks, self.lawcount = [], {}
        A = os.path.join(ROOT, 'assets')
        cat = json.load(open(os.path.join(A, 'laws_catalog.json'), encoding='utf-8'))
        self.catalog = cat.get('laws', [])
        paths = [os.path.join(A, 'knowledge.txt')] + sorted(glob.glob(os.path.join(A, 'laws', '*.txt')))
        for p in paths:
            text = open(p, encoding='utf-8').read().replace('\r', '')
            if p.endswith('knowledge.txt'):
                self.parse(text, 'دانش عمومی', 'knowledge')
            else:
                self.parse(text, '', os.path.basename(p)[:-4])
        self.syn = []
        for line in open(os.path.join(A, 'synonyms.txt'), encoding='utf-8'):
            l = line.strip()
            if not l or l.startswith('#') or '|' not in l:
                continue
            k, v = l.split('|', 1)
            k, v = phrase(k), v.strip()
            if k and v:
                self.syn.append((k, v))
        df = {}
        total = 0
        for c in self.chunks:
            total += c['len']
            for t in set(c['T']) | set(c['B']) | set(c['C']):
                df[t] = df.get(t, 0) + 1
        n = len(self.chunks)
        self.avg = max(1.0, total / n)
        self.idf = {t: math.log((n + 1) / (d + 1)) + 1.0 for t, d in df.items()}
        self.vocab = list(df)

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
            T, Bd, C = {}, {}, {}
            ln = 0
            for t in tok(first):
                T[t] = T.get(t, 0) + 1; ln += 1
            for t in tok(body):
                Bd[t] = Bd.get(t, 0) + 1; ln += 1
            for t in tok(chapter) + tok(source):
                C[t] = C.get(t, 0) + 1; ln += 1
            self.chunks.append(dict(law=law, source=source, title=first, body=body,
                                    obs=(body != first and obsolete(body)),
                                    T=T, B=Bd, C=C, len=ln))
            self.lawcount[law] = self.lawcount.get(law, 0) + 1

    def mentioned(self, q):
        n = collapse(normalize(q))
        out = []
        for l in self.catalog:
            for name in [l['title']] + list(l.get('aliases', [])):
                full = collapse(normalize(name))
                if not full:
                    continue
                short = full[6:].strip() if full.startswith('قانون ') else full
                if full in n or (len(short) >= 5 and short in n):
                    out.append(l['id']); break
        return out

    def rank(self, question, k=60):
        q = normalize(question)
        qt = list(dict.fromkeys(tok(question)))
        ids = {i for i in self.mentioned(question) if self.lawcount.get(i, 0) > 0}
        pool = [c for c in self.chunks if c['law'] in ids] if ids else self.chunks
        m = re.search(r'ماده\s*(\d+)(\s*مکرر)?', q)
        if m:
            want = 'ماده %s%s' % (m.group(1), ' مکرر' if m.group(2) else '')
            found = [c for c in pool if normalize(c['title']).strip() == want]
            if found:
                return [(found[0], 99.0)]
        if not qt:
            return []
        terms, total = {}, 0.0
        for t in qt:
            total += self.idf.get(t, 1.0)
            if t in self.idf:
                terms[t] = 1.0
            elif len(t) >= 3:
                for v in self.vocab:
                    if len(v) >= 3 and (v.startswith(t) or t.startswith(v)):
                        terms[v] = max(terms.get(v, 0), 0.5)
        n = ' %s ' % phrase(question)
        for kk, v in self.syn:
            if (' %s ' % kk) in n:
                for t in tok(v):
                    if t in self.idf:
                        terms[t] = max(terms.get(t, 0), 1.0)
        if not terms:
            return []
        hits = []
        for c in pool:
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
        return hits[:k]


def run(eng, path, verbose):
    rows = []
    for l in open(path, encoding='utf-8'):
        l = l.strip()
        if l and not l.startswith('#'):
            rows.append([x.strip() for x in l.split('|')])
    r1 = r5 = 0; mrr = 0.0; bad = []
    for q, law, title in rows:
        rank = 0
        for i, (c, _) in enumerate(eng.rank(q)):
            if c['law'] == law and c['title'] == title:
                rank = i + 1; break
        r1 += rank == 1; r5 += 1 <= rank <= 5
        mrr += 1 / rank if rank else 0
        if rank != 1:
            bad.append((rank, q))
    n = len(rows)
    print('%s: n=%d recall@1 %.2f recall@5 %.2f MRR %.3f' % (
        os.path.basename(path), n, r1 / n, r5 / n, mrr / n))
    if verbose:
        for rank, q in bad:
            print('  rank %s | %s' % (rank or '>60', q))


if __name__ == '__main__':
    e = Engine()
    for f in ('eval.txt', 'eval_extra.txt'):
        p = os.path.join(ROOT, 'brain', f)
        if os.path.exists(p):
            run(e, p, '-v' in sys.argv)
