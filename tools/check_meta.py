import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
P = os.path.join(ROOT, 'assets', 'laws', '_meta.json')

DATE = re.compile(r'^[0-9۰-۹]{4}/[0-9۰-۹]{1,2}/[0-9۰-۹]{1,2}$')
PERSIAN = re.compile(r'[\u0600-\u06FF]')
SHELL = re.compile(
    r'(\bgit\b|\bpython3?\b|\bcat\b|\bnano\b|\btail\b|\bgrep\b|\bpush\b|'
    r'\bcommit\b|\bcd\b|[|$><]|--|\.py\b|\.txt\b|\.json\b)',
    re.IGNORECASE,
)

errors = []
with open(P, encoding='utf-8') as f:
    meta = json.load(f)

for lid, info in meta.items():
    if not isinstance(info, dict):
        errors.append('%s: ساختار نادرست' % lid)
        continue
    src = str(info.get('source', '')).strip()
    if src:
        if SHELL.search(src):
            errors.append('%s: منبع شبیه دستور ترمینال است: %s' % (lid, src))
        elif not PERSIAN.search(src):
            errors.append('%s: منبع باید نام فارسی سازمان یا سایت باشد: %s' % (lid, src))
    for key in ('date', 'amended'):
        v = str(info.get(key, '')).strip()
        if v and not DATE.match(v):
            errors.append('%s: %s باید به شکل ۱۴۰۵/۰۸/۰۲ باشد: %s' % (lid, key, v))

for e in errors:
    print('خطا:', e)
if errors:
    print('نتیجه: %d خطا در _meta.json؛ پوش نکنید.' % len(errors))
    sys.exit(1)
print('_meta.json درست است.')
