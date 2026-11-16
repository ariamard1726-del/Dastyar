import json, os, re, sys
BASE='assets/laws'
meta=json.load(open(BASE+'/_meta.json',encoding='utf-8'))
T=str.maketrans({'ي':'ی','ك':'ک','‌':' ','ٌ':'','ً':'','ٍ':'','َ':'','ُ':'','ِ':'','ّ':''})
text=''
for m in meta.values():
    text+=open(os.path.join(BASE,m['path']),encoding='utf-8').read().translate(T)+'\n'
ok=bad=0
for l in open(sys.argv[1],encoding='utf-8'):
    l=l.strip()
    if not l or l.startswith('#') or '|' not in l: continue
    left,right=[x.strip() for x in l.split('|',1)]
    miss=[w for w in right.translate(T).split() if w not in text]
    if miss: bad+=1; print('REJECT',left,'| missing:',' '.join(miss))
    else: ok+=1
print('ok',ok,'rejected',bad)
