import collections
import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
total = 0
for p in sorted(glob.glob(os.path.join(ROOT, 'assets', 'laws', '*.txt'))):
    law = os.path.basename(p)[:-4]
    text = open(p, encoding='utf-8').read().replace('\r', '')
    groups = collections.defaultdict(list)
    for part in re.split(r'\n\s*\n', text):
        ls = part.strip().split('\n')
        if len(ls) < 2 or not ls[0].strip().startswith('ماده'):
            continue
        body = re.sub(r'\s+', ' ', ' '.join(ls[1:])).strip()
        if len(body) >= 60:
            groups[body].append(ls[0].strip())
    bad = [v for v in groups.values() if len(v) > 1]
    for v in bad:
        total += len(v)
        print('%s: %d ماده با متن یکسان: %s' % (law, len(v), '، '.join(v[:6]) + (' ...' if len(v) > 6 else '')))
print('مجموع مواد با متن تکراری: %d' % total)
