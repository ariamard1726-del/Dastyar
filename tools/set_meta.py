import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, 'assets', 'laws', '_meta.json')
KEYS = ('title', 'articles', 'path', 'source_verified')

if len(sys.argv) != 4 or sys.argv[2] not in KEYS:
    print('استفاده: python tools/set_meta.py ID KEY "مقدار"')
    print('KEY یکی از: ' + ', '.join(KEYS))
    print('منبع و تاریخ تا تأیید منبع رسمی ثبت نمی\u200cشوند؛ source_verified فقط false است.')
    sys.exit(1)

law, key, value = sys.argv[1], sys.argv[2], sys.argv[3]
if key == 'source_verified' and value.lower() != 'false':
    print('خطا: تا تأیید منبع رسمی فقط source_verified=false مجاز است.')
    sys.exit(1)

with open(P, encoding='utf-8') as f:
    d = json.load(f)
if law not in d:
    print('قانونی با شناسهٔ %s در _meta.json نیست.' % law)
    sys.exit(1)

if key == 'articles':
    d[law][key] = int(value)
elif key == 'source_verified':
    d[law][key] = False
else:
    d[law][key] = value

with open(P, 'w', encoding='utf-8') as f:
    json.dump(d, f, ensure_ascii=False, indent=2)
    f.write('\n')
print(d[law])
