import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, 'assets', 'laws', '_meta.json')
KEYS = ('title', 'source', 'date', 'amended')

if len(sys.argv) != 4 or sys.argv[2] not in KEYS:
    print('استفاده: python tools/set_meta.py ID KEY "مقدار"')
    print('KEY یکی از: ' + ', '.join(KEYS))
    print('date = تاریخ دریافت متن توسط شما؛ amended = آخرین اصلاحیه طبق منبع')
    sys.exit(1)

law, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
with open(P, encoding='utf-8') as f:
    d = json.load(f)
if law not in d:
    print('قانونی با شناسهٔ %s در _meta.json نیست.' % law)
    sys.exit(1)
d[law][key] = value
with open(P, 'w', encoding='utf-8') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
    f.write('\n')
print(d[law])
