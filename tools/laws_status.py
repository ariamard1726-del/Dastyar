import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAT = os.path.join(ROOT, 'tools', 'laws_catalog.json')
LAWS = os.path.join(ROOT, 'assets', 'laws')


def digits(s):
    return s.translate(str.maketrans('۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789'))


def analyze(path):
    with open(path, encoding='utf-8') as f:
        text = f.read().replace('\r', '')
    parts = [p.strip() for p in re.split(r'\n\s*\n', text) if p.strip()]
    total = 0
    seen = set()
    dups = 0
    nums = set()
    for p in parts:
        first = p.split('\n')[0].strip()
        if first.startswith('#'):
            continue
        t = digits(first)
        total += 1
        if t in seen:
            dups += 1
        seen.add(t)
        m = re.match(r'^ماده\s*(\d+)$', t)
        if m:
            nums.add(int(m.group(1)))
    gaps = [i for i in range(1, max(nums) + 1) if i not in nums] if nums else []
    return total, dups, gaps


with open(CAT, encoding='utf-8') as f:
    cat = json.load(f)

meta = {}
mp = os.path.join(LAWS, '_meta.json')
if os.path.exists(mp):
    try:
        with open(mp, encoding='utf-8') as f:
            meta = json.load(f)
    except Exception:
        meta = {}

known = set()
done = {1: 0, 2: 0, 3: 0}
allp = {1: 0, 2: 0, 3: 0}
total_articles = 0

for cid, cname in cat['categories'].items():
    laws = sorted(
        [l for l in cat['laws'] if l['category'] == cid],
        key=lambda l: (l['priority'], l['title']),
    )
    if not laws:
        continue
    print('\n== %s ==' % cname)
    for l in laws:
        known.add(l['id'] + '.txt')
        path = os.path.join(LAWS, l['id'] + '.txt')
        pr = l['priority']
        allp[pr] += 1
        if not os.path.exists(path):
            print('  ❌ [%d] %s' % (pr, l['title']))
            continue
        n, dups, gaps = analyze(path)
        total_articles += n
        info = meta.get(l['id'], {})
        mark = '✅'
        extra = []
        if n == 0:
            mark = '❌'
        if gaps:
            mark = '⚠️'
            extra.append('%d شمارهٔ جاافتاده' % len(gaps))
        if dups:
            mark = '⚠️'
            extra.append('%d تکراری' % dups)
        if not info.get('date'):
            extra.append('تاریخ ثبت نشده')
        if n > 0:
            done[pr] += 1
        print('  %s [%d] %s (%d ماده)%s' % (
            mark, pr, l['title'], n, ' | ' + '، '.join(extra) if extra else ''))

others = []
if os.path.isdir(LAWS):
    for fn in sorted(os.listdir(LAWS)):
        if fn.endswith('.txt') and fn not in known:
            others.append(fn)
if others:
    print('\nفایل‌هایی که در فهرست نیستند: ' + ', '.join(others))

print('\nخلاصه:')
for pr in (1, 2, 3):
    print('  اولویت %d: %d از %d' % (pr, done[pr], allp[pr]))
print('  مجموع مواد: %d' % total_articles)
