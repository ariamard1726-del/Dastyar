import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, 'assets', 'laws', '_meta.json')
FIELDS = [
    ('source', 'منبع رسمی متن (نام سایت یا سازمان)'),
    ('date', 'تاریخ دریافت متن (مثلاً ۱۴۰۵/۰۸/۰۲)'),
    ('amended', 'تاریخ آخرین اصلاحیه طبق منبع'),
]

with open(P, encoding='utf-8') as f:
    d = json.load(f)

changed = 0
for lid, info in d.items():
    if not isinstance(info, dict):
        continue
    for key, label in FIELDS:
        if str(info.get(key, '')).strip():
            continue
        print('\n[%s] %s' % (info.get('title', lid), lid))
        v = input('%s\n(خالی = بعداً): ' % label).strip()
        if v:
            info[key] = v
            changed += 1

with open(P, 'w', encoding='utf-8') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
    f.write('\n')
print('\nتغییرها: %d' % changed)
