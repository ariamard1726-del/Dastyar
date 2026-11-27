import json, os, re, math, collections

BASE = 'assets/laws'
meta = json.load(open(os.path.join(BASE, '_meta.json'), encoding='utf-8'))

AR = str.maketrans({'ي': 'ی', 'ك': 'ک', '‌': ' '})
def norm(s):
    return s.translate(AR)

WORD = re.compile(r'[\u0600-\u06FF]{3,}')
ART = re.compile(r'^(ماده|اصل)\s+(\d+)', re.M)

syn_lines = []
for l in open('assets/synonyms.txt', encoding='utf-8'):
    l = l.strip()
    if l and not l.startswith('#') and '|' in l:
        syn_lines.append(norm(l))

law_words = {}
law_articles = {}
for lid, m in meta.items():
    p = os.path.join(BASE, m['path'])
    if not os.path.exists(p):
        law_words[lid] = None
        law_articles[lid] = 0
        continue
    txt = norm(open(p, encoding='utf-8').read())
    law_articles[lid] = len(ART.findall(txt))
    law_words[lid] = collections.Counter(WORD.findall(txt))

# document frequency of words across laws (rare words identify a law)
df = collections.Counter()
for c in law_words.values():
    if c:
        for w in c:
            df[w] += 1
N = len(meta)

lines = []
lines.append('# Coverage report (auto-generated, read-only analysis)\n')
lines.append('| law | title | articles(meta) | articles(found) | synonym rows touching law |')
lines.append('|---|---|---|---|---|')
for lid, m in meta.items():
    c = law_words[lid]
    if c is None:
        lines.append(f"| {lid} | {m['title']} | {m['articles']} | FILE MISSING | - |")
        continue
    # distinctive words: frequent in this law, in at most 2 laws overall
    distinct = {w for w, n in c.items() if n >= 3 and df[w] <= 2}
    touching = sum(1 for s in syn_lines
                   if any(w in distinct for w in WORD.findall(s.split('|', 1)[1])))
    flag = '' if law_articles[lid] else ' NO ARTICLES PARSED'
    lines.append(f"| {lid} | {m['title']} | {m['articles']} | {law_articles[lid]}{flag} | {touching} |")

open('docs/coverage_report.md', 'w', encoding='utf-8').write('\n'.join(lines) + '\n')
print('\n'.join(lines))
print('\nsynonym rows:', len(syn_lines))
