import collections
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAWS_DIR = os.path.join(ROOT, 'assets', 'laws')

meta_path = os.path.join(LAWS_DIR, '_meta.json')
meta = json.load(open(meta_path, encoding='utf-8')) if os.path.isfile(meta_path) else {}

entries = []
seen_paths = set()
for lid, info in sorted(meta.items()):
    if isinstance(info, dict) and info.get('path'):
        full = os.path.normpath(os.path.join(LAWS_DIR, info['path']))
        if os.path.isfile(full):
            entries.append((lid, full))
            seen_paths.add(full)

for root, _dirs, files in os.walk(LAWS_DIR):
    for fn in sorted(files):
        if fn.endswith('.txt'):
            full = os.path.normpath(os.path.join(root, fn))
            if full not in seen_paths:
                entries.append((os.path.relpath(full, LAWS_DIR), full))

total = 0
for law, p in entries:
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
