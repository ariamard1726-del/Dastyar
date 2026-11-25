import json, os, re, collections, sys
BASE = 'assets/laws'
meta = json.load(open(os.path.join(BASE, '_meta.json'), encoding='utf-8'))
AR = str.maketrans({'ي': 'ی', 'ك': 'ک', '‌': ' '})
WORD = re.compile(r'[\u0600-\u06FF]{3,}')
cnt = {}
for lid, m in meta.items():
    p = os.path.join(BASE, m['path'])
    cnt[lid] = collections.Counter(WORD.findall(open(p, encoding='utf-8').read().translate(AR)))
df = collections.Counter()
for c in cnt.values():
    for w in c: df[w] += 1
for lid in sys.argv[1:]:
    words = [(w, n) for w, n in cnt[lid].items() if n >= 3 and df[w] <= 3]
    words.sort(key=lambda x: -x[1])
    print(lid, ':', ' '.join(w for w, _ in words[:60]))
    print()
