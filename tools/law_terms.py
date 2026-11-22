"""تطبیق واژه‌های متن کاربر با متن قوانین (آینهٔ پایتون).

هر پرسش به واژه‌های معنادار شکسته می‌شود (همان نشانه‌گذاری فهرست وارونهٔ
موتور دانش، پس نتیجه با دارت یکسان است). سپس:

* هر واژه را در کل متن قوانین می‌سنجیم: یا در آن هست (و در چند ماده)، یا نیست.
* ماده‌ای که بیشترین پوشش واژه‌ها را دارد پیدا می‌کنیم. عبارت‌های دوواژه‌ای
  پرسش («بیع شرط») اگر عیناً در متن ماده باشند امتیاز اضافه می‌گیرند.
* ماده فقط وقتی «پذیرفته» می‌شود که دست‌کم دو واژه‌ی معنادار یا یک عبارت
  دوواژه‌ای را با هم داشته باشد؛ در غیر این صورت به کاربر می‌گوییم کدام
  واژه‌ها در قوانین پیدا نشد.

اجرا:
  python3 tools/law_terms.py "متن کوتاه قرارداد شامل طرفین، مبلغ و تاریخ"
  python3 tools/law_terms.py --check      # بررسی همهٔ نمونه‌های tests/law_terms/cases.json
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))

import eval_py as E  # noqa: E402

CASES = os.path.join(ROOT, 'tests', 'law_terms', 'cases.json')

# املای محاوره‌ای یا عربیِ رایج که در متن قوانین به صورت دیگری آمده است.
ALIAS = {
    'افحش': 'فاحش',
}

# واژه‌های گفتاری یا عمومیِ بی‌بار که در تطبیق شرکت نمی‌کنند.
GENERIC = {
    'دارم', 'داریم', 'داره', 'دارد', 'بگو', 'بگید', 'بگویید', 'بدونم', 'بدانم',
    'خوام', 'خواستم', 'میخوام', 'بخوام', 'کنم', 'کنیم', 'باید', 'چکار', 'کار',
    'چیکار', 'بشه', 'شده', 'شد', 'کرد', 'کردم', 'کرده', 'نیست', 'باشه',
    'ایا', 'یه', 'اون', 'اینو', 'اونو', 'ما', 'شما', 'حالا', 'الان', 'خیلی',
    'واقعا', 'فقط', 'همه', 'چی', 'یکی', 'کسی', 'جای', 'نکنه', 'بکنم',
    'نمی', 'ام', 'رو', 'را', 'های', 'ها', 'ای', 'ی', 'ت', 'م', 'ش', 'ه', 'گزارش',
    'دو', 'سه', 'چهار', 'پنج', 'شش', 'هفت', 'هشت', 'نه', 'ده', 'صد', 'هزار',
    'نمیده', 'نداده', 'ندادن', 'داده', 'برده', 'اومده', 'خورده', 'شده', 'بوده',
    'میشه', 'میکنم', 'نکرده', 'کرده', 'دادم', 'گرفتم', 'بدم', 'بده', 'برم',
    'ترین', 'کدام', 'بهترین', 'بهتر', 'خواهد', 'تواند', 'کدوم', 'منو', 'برام',
    'بهتره', 'میخواد', 'می‌خواهد', 'میخواد',
}
# کوتاه‌تر از این تعداد نویسه، واژهٔ معنادار حساب نمی‌شود.
MIN_LEN = 2

# بیشترین تعداد ماده‌ای که یک واژه می‌تواند داشته باشد تا «تمایزدهنده» باشد.
DISTINCT_DF = 300
# تعداد نامزدهای برتر که عبارت‌ها روی آن‌ها سنجیده می‌شود.
TOP = 300
# کمترین پوشش برای پذیرش همراه با دو واژه.
MIN_COVER = 0.5
# واژه‌ای که در بیش از این تعداد ماده آمده، «نادر» نیست؛ پذیرش بی‌عبارت
# به دو واژهٔ نادر نیاز دارد.
RARE_DF = 60
# بیشترین فاصلهٔ (به تعداد واژه) میان واژه‌های پرسش در متن ماده، تا آن‌ها
# «با هم» در یک جمله حساب شوند. «رشوه» و «گرفتن» در دو بند دور از هم، دلیل نیستند.
MAX_SPAN = 15
# کمترین مجموع وزن (idf) دو واژهٔ یک عبارت تا آن عبارت حساب شود؛ جفت‌های
# پرتکرارِ بی‌بار («مبلغ تاریخ») حساب نمی‌شوند.
PHRASE_MIN_IDF = 4.0

_engine = None
_tok_cache = {}


def engine():
    global _engine
    if _engine is None:
        _engine = E.Engine()
    return _engine


def _body_tokens(i, body):
    if i not in _tok_cache:
        _tok_cache[i] = E.tok(body)
    return _tok_cache[i]


_PUNCT_RE = re.compile(r'[،,.;:!?؟()\[\]«»"\-/]+')


def query_runs(q):
    """واژه‌های پرسش در «دنباله‌های پیوسته» (هر دنباله بی‌وقفه از واژهٔ معنادار).

    ایستواژه‌ها، واژه‌های بی‌بار و علامت‌ها دنباله را می‌شکنند؛ پس «مبلغ و
    تاریخ» دو دنبالهٔ جدا می‌شود و عبارتِ ساختگیِ «مبلغ تاریخ» ساخته نمی‌شود.
    """
    runs = []
    for seg in _PUNCT_RE.split(E.normalize(q)):
        cur = []
        for w in E.NONWORD.sub(' ', seg).split():
            w = ALIAS.get(w, w)
            if w in E.STOP or w in GENERIC or len(w) < MIN_LEN:
                if cur:
                    runs.append(cur)
                    cur = []
                continue
            st = E.tok(w)
            if not st:
                if cur:
                    runs.append(cur)
                    cur = []
                continue
            cur.append(st[0])
        if cur:
            runs.append(cur)
    return runs


def query_terms(q):
    """واژه‌های معنادار پرسش به ترتیب (با تکرار)."""
    return [t for run in query_runs(q) for t in run]


def _tok_head(i, c):
    key = ('h', i)
    if key not in _tok_cache:
        _tok_cache[key] = E.tok(c['chapter'] + ' ' + c['title'])
    return _tok_cache[key]


def _pairs(runs):
    out = []
    for run in runs:
        for i in range(len(run) - 1):
            if run[i] != run[i + 1]:
                out.append((run[i], run[i + 1]))
    return out


def _has_pair(toks, pair):
    a, b = pair
    for k in range(len(toks) - 1):
        if toks[k] == a and toks[k + 1] == b:
            return True
    return False


def word_report(q, e=None):
    """هر واژهٔ پرسش: در چند ماده‌ی قوانین آمده، یا اصلاً نیامده."""
    e = e or engine()
    report = []
    for t in dict.fromkeys(query_terms(q)):
        df = len(e.postings.get(t, []))
        report.append((t, df))
    return report


def match(q, e=None):
    """بهترین ماده برای پرسش، با دلیل پذیرش و واژه‌های پیدانشده."""
    e = e or engine()
    runs = query_runs(q)
    seq = [t for run in runs for t in run]
    uniq = list(dict.fromkeys(seq))
    known = [t for t in uniq if t in e.idf]
    unknown = [t for t in uniq if t not in e.idf]
    total = sum(e.idf[t] for t in known) or 1.0
    score, hits = {}, {}
    for t in known:
        for i in e.postings[t]:
            c = e.chunks[i]
            if c['source'] == 'دانش عمومی' or c['obs']:
                continue
            score[i] = score.get(i, 0.0) + e.idf[t]
            hits.setdefault(i, []).append(t)
    pairs = [p for p in _pairs(runs) if e.idf.get(p[0], 0) + e.idf.get(p[1], 0) >= PHRASE_MIN_IDF]
    prio = _priorities()
    ranked = sorted(score, key=lambda i: (-score[i], -len(hits[i]), i))[:TOP]
    best = None
    best_key = None
    for i in ranked:
        key = _rank_key(e, i, score[i] / total, hits[i], pairs, prio)
        if best_key is None or key > best_key:
            best, best_key = i, key
    if best is None:
        return {'accepted': False, 'unknown': unknown, 'missing': uniq,
                'law': None, 'title': None, 'cover': 0.0, 'matched': [],
                'phrases': []}
    c = e.chunks[best]
    btoks = _body_tokens(best, c['body'] + ' ' + c['title'])
    ph = [' '.join(p) for p in pairs if _has_pair(btoks, p)]
    matched = hits[best]
    cover = score[best] / total
    m = len(matched)
    head = _tok_head(best, c)
    head_hit = any(_has_pair(head, p) for p in pairs)
    span = _span(btoks, matched)
    near = span <= MAX_SPAN
    rare_n = sum(1 for t in matched if len(e.postings[t]) <= RARE_DF)
    accepted = (bool(ph) and m >= 2) or (cover >= MIN_COVER and rare_n >= 2 and near) or head_hit
    return {
        'accepted': accepted,
        'law': c['law'],
        'title': c['title'],
        'cover': round(cover, 3),
        'span': span,
        'matched': matched,
        'phrases': ph,
        'missing': [t for t in uniq if t not in matched],
        'unknown': unknown,
    }


def _span(btoks, words):
    """کوتاه‌ترین بازه در متن ماده که همهٔ واژه‌های داده‌شده را دربرگیرد."""
    need = set(words)
    if not need:
        return 0
    best = None
    count = {}
    left = 0
    have = 0
    for right, t in enumerate(btoks):
        if t in need:
            count[t] = count.get(t, 0) + 1
            if count[t] == 1:
                have += 1
        while have == len(need) and left <= right:
            span = right - left + 1
            if best is None or span < best:
                best = span
            lt = btoks[left]
            if lt in need:
                count[lt] -= 1
                if count[lt] == 0:
                    have -= 1
            left += 1
    return best if best is not None else 10 ** 6


def _priorities():
    """اولویت هر قانون در کاتالوگ (عدد کمتر = مهم‌تر)."""
    e = engine()
    out = {}
    for l in e.catalog:
        out[l['id']] = l.get('priority', 50)
    return out


def _rank_key(e, i, cover, matched, pairs, prio):
    """کلید رتبه‌بندی نامزد: عنوان و فصلِ مرتبط، عبارت، پوشش، تمرکز واژه‌ها
    در متن (بسامد به طول)، سپس اولویت قانون، و در آخر ترتیب ثابت."""
    c = e.chunks[i]
    btoks = _body_tokens(i, c['body'] + ' ' + c['title'])
    ph = sum(1 for p in pairs if _has_pair(btoks, p))
    head = _tok_head(i, c)
    head_pairs = sum(1 for p in pairs if _has_pair(head, p))
    head_words = sum(1 for t in matched if t in head)
    tf = sum(c['T'].get(t, 0) + c['B'].get(t, 0) for t in matched)
    density = tf / max(1, c['len'])
    return (ph > 0, head_pairs, head_words, round(cover, 6),
            -prio.get(c['law'], 50), round(density, 2), -i)


def run_cases(path=CASES):
    with open(path, encoding='utf-8') as f:
        cases = json.load(f)
    fails = []
    for case in cases:
        r = match(case['q'])
        exp = case['expect']
        bad = []
        if r['accepted'] != exp['accepted']:
            bad.append(f"accepted={r['accepted']}")
        if 'law' in exp and r['law'] != exp['law']:
            bad.append(f"law={r['law']}")
        if 'title' in exp and r['title'] != exp['title']:
            bad.append(f"title={r['title']}")
        for w in exp.get('missing', []):
            if w not in r['missing']:
                bad.append(f"expected missing {w}")
        if bad:
            fails.append((case['q'], bad, r))
    return cases, fails


def main(argv):
    if len(argv) >= 2 and argv[1] == '--check':
        cases, fails = run_cases()
        for q, bad, r in fails:
            print('FAIL', q, bad, r['law'], r['title'], r['matched'], r['missing'])
        print(f'{len(cases) - len(fails)} از {len(cases)} نمونه درست است.')
        return 1 if fails else 0
    q = ' '.join(argv[1:])
    print(json.dumps(match(q), ensure_ascii=False, indent=1))
    print(word_report(q))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
