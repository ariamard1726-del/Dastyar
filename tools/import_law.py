#!/usr/bin/env python3
# tools/import_law.py
# متن خام یک قانون (مثلاً چسبانده‌شده از سایت) را به قالب موتور تبدیل می‌کند.
#
# فقط گزارش (چیزی نمی‌نویسد):
#   python3 tools/import_law.py RAW.txt
# نوشتن فایل قانون و ثبت در _meta.json:
#   python3 tools/import_law.py RAW.txt --id labor --title "قانون کار" \
#     --source "نام سایت یا سازمان" --date 1405/08/08 \
#     --out Hoghough_e_Khosousi/Hoghough_e_Kar/ghanoun_e_kar.txt
import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAWS = os.path.join(ROOT, 'assets', 'laws')

ap = argparse.ArgumentParser()
ap.add_argument('raw')
ap.add_argument('--id')
ap.add_argument('--title')
ap.add_argument('--source')
ap.add_argument('--date')
ap.add_argument('--amended', default='')
ap.add_argument('--out')
ap.add_argument('--force', action='store_true', help='با وجود تعارض بنویس و نسخهٔ بلندتر را نگه دار')
a = ap.parse_args()

text = open(a.raw, encoding='utf-8').read().replace('\r', '')

# --- یکدست‌سازی حروف (ي ك عربی، کشیده، فاصلهٔ قبل از نیم‌فاصله)
for old, new in (('ي', 'ی'), ('ك', 'ک'), ('ة', 'ه'), ('ـ', ''), ('ۀ', 'هٔ'),
                 ('\u00a0', ' ')):
    text = text.replace(old, new)
text = re.sub(r' +\u200c', '\u200c', text)
text = re.sub(r'\u200c +', '\u200c', text)
text = re.sub(r'[ \t]+', ' ', text)

CHAPTER = re.compile(r'^(فصل|باب|بخش|مبحث)\s.{0,80}$')
MARK = re.compile(r'ماده\s*([0-9۰-۹]+)\s*(مکرر\s*[0-9۰-۹]*)?\s*[-–—]\s*')
FA = str.maketrans('۰۱۲۳۴۵۶۷۸۹', '0123456789')

arts = []          # (key, chapter, text)
chapter = ''
cur = None


def flush():
    global cur
    if cur:
        arts.append(cur)
    cur = None


for line in text.split('\n'):
    s = line.strip()
    if not s:
        continue
    if cur is None and not MARK.search(s) and not CHAPTER.match(s):
        continue  # عنوان یا متن بیرون از مواد
    if CHAPTER.match(s) and not MARK.match(s):
        flush()
        chapter = s
        continue
    ms = list(MARK.finditer(s))
    if not ms:
        if cur:
            cur[2] += '\n' + s
        continue
    if cur and s[:ms[0].start()].strip():
        cur[2] += '\n' + s[:ms[0].start()].strip()
    for i, m in enumerate(ms):
        flush()
        end = ms[i + 1].start() if i + 1 < len(ms) else len(s)
        num = m.group(1).translate(FA)
        mk = (' ' + re.sub(r'\s+', ' ', m.group(2).strip().translate(FA))) if m.group(2) else ''
        cur = ['ماده ' + num + mk, chapter, s[m.end():end].strip()]
flush()

# --- تبصره‌ها و بندهای چسبیده را روی خط جدا ببر
NOTE = re.compile(r'(?<=\S)(?=تبصره\s*[0-9۰-۹]*\s*(?:\([^)]*\))?\s*[-–—])')
by = {}
order = []
dups = 0
conflicts = []
cands = {}


def squash(t):
    return re.sub(r'[\s\u200c]+', '', t)


for key, ch, body in arts:
    body = NOTE.sub('\n', body).strip()
    body = re.sub(r'\n{2,}', '\n', body)
    if key in by:
        old = by[key][1]
        so, sn = squash(old), squash(body)
        if so == sn:
            dups += 1
        elif so.startswith(sn):
            dups += 1                      # نسخهٔ جدید بریده‌شده است
        elif sn.startswith(so):
            dups += 1                      # نسخهٔ قبلی بریده بود؛ بلندتر را نگه دار
            by[key] = (by[key][0], body)
        else:
            conflicts.append(key)
            cands.setdefault(key, [old]).append(body)
            if a.force and len(body) > len(old):
                by[key] = (by[key][0], body)
        continue
    by[key] = (ch, body)
    order.append(key)

nums = sorted({int(re.match(r'ماده (\d+)', k).group(1)) for k in order})
missing = [n for n in range(nums[0], nums[-1] + 1) if n not in set(nums)] if nums else []

print('مواد یکتا: %d | تکراریِ یکسان حذف‌شده: %d | تعارض متن: %d' % (len(order), dups, len(conflicts)))
if nums:
    print('بازهٔ شماره: %d تا %d' % (nums[0], nums[-1]))
print('مواد جاافتاده در بازه: %s' % (', '.join(map(str, missing[:60])) or 'ندارد'))
if conflicts:
    print('تعارض (دو متن واقعاً متفاوت برای یک ماده): ' + '، '.join(conflicts))
    for k in conflicts:
        print('  %s: طول نسخه‌ها %s' % (k, [len(x) for x in cands[k]]))

if not a.out:
    print('\n(فقط گزارش؛ برای نوشتن --out و --id و --title و --source و --date بدهید.)')
    sys.exit(0)
if not (a.id and a.title and a.source and a.date):
    print('خطا: با --out باید --id و --title و --source و --date هم بدهید.')
    sys.exit(1)
if conflicts and not a.force:
    print('خطا: تعارض متن وجود دارد. اول متن خام را اصلاح کنید یا --force بدهید.')
    sys.exit(1)

out_lines = ['# ' + a.title, '']
last_ch = None
for key in order:
    ch, body = by[key]
    if ch and ch != last_ch:
        out_lines += ['## ' + ch, '']
        last_ch = ch
    out_lines += [key, body, '']
dest = os.path.join(LAWS, a.out)
os.makedirs(os.path.dirname(dest), exist_ok=True)
open(dest, 'w', encoding='utf-8').write('\n'.join(out_lines).rstrip() + '\n')

mp = os.path.join(LAWS, '_meta.json')
meta = json.load(open(mp, encoding='utf-8'))
meta[a.id] = {'title': a.title, 'source': a.source, 'date': a.date,
              'articles': len(order), 'amended': a.amended, 'path': a.out}
json.dump(meta, open(mp, 'w', encoding='utf-8'), ensure_ascii=False, indent=2)
open(mp, 'a', encoding='utf-8').write('\n')
print('نوشته شد: assets/laws/%s و _meta.json (%s).' % (a.out, a.id))
