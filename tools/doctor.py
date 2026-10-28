# -*- coding: utf-8 -*-
"""سلامت‌سنج کل پروژه: python tools/doctor.py   (با --strict هشدارها هم خطا می‌شوند)

آنچه می‌سنجد:
  ۱. هر فایل زیر assets/laws (به‌صورت بازگشتی) ثبت‌شده در _meta.json باشد و برعکس
  ۲. فایل‌های نگه‌دارندهٔ پوشه (.gitkeep) خالی باشند
  ۳. متن قانون: UTF-8 سالم، بدون نویسهٔ خراب، بدون ماده‌های تکراری یا برگشت شماره‌گذاری،
     پایان کامل، بدون نشانهٔ متن ساختگی
  ۴. شمار مواد با _meta.json بخواند؛ مواد جاافتاده فهرست شوند
  ۵. شناسه‌ها در _meta.json و laws_catalog.json هماهنگ باشند
  ۶. lawRefs قالب‌ها به مادهٔ واقعی اشاره کنند
  ۷. پوشه‌های assets در pubspec.yaml وجود داشته باشند
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAWS = os.path.join(ROOT, 'assets', 'laws')
STRICT = '--strict' in sys.argv or os.environ.get('STRICT') == '1'

errors, warnings, infos = [], [], []

AI_MARKERS = ['هوش مصنوعی', 'تولید شده توسط', 'تولیدشده توسط', 'این متن توسط',
              'chatgpt', 'gemini', 'claude', 'as an ai', 'language model']
FA_DIGITS = str.maketrans('۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789')
ARTICLE = re.compile(r'^ماده\s*(\d+)(?:\s*(مکرر(?:\s*\d+)?))?\s*$')


def norm(s):
    s = s.translate(FA_DIGITS).replace('ي', 'ی').replace('ك', 'ک')
    s = re.sub('[\u200c\u200d\u200e\u200f]', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def load_json(path, label):
    try:
        with open(path, encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        errors.append('%s: %s' % (label, e))
        return None


def rng(nums):
    out, i = [], 0
    nums = sorted(nums)
    while i < len(nums):
        j = i
        while j + 1 < len(nums) and nums[j + 1] == nums[j] + 1:
            j += 1
        out.append(str(nums[i]) if i == j else '%d-%d' % (nums[i], nums[j]))
        i = j + 1
    return '، '.join(out)


def parse(text):
    """مثل _parse در engine.dart: بخش‌ها با خط خالی جدا می‌شوند."""
    source, blocks = '', []
    for p in re.split(r'\n\s*\n', text.replace('\r', '')):
        lines = p.strip().split('\n')
        if not lines or not lines[0].strip():
            continue
        first = lines[0].strip()
        if first.startswith('##'):
            continue
        if first.startswith('#'):
            source = first.lstrip('#').strip()
            continue
        body = '\n'.join(lines[1:]).strip() if len(lines) > 1 else first
        blocks.append((first, body, source))
    return blocks


# ---------- ۱ و ۲: فایل‌ها ----------
meta = load_json(os.path.join(LAWS, '_meta.json'), '_meta.json') or {}
catalog = load_json(os.path.join(ROOT, 'assets', 'laws_catalog.json'), 'laws_catalog.json') or {}
cat_ids = {l.get('id') for l in catalog.get('laws', [])}

registered = {}
for lid, info in meta.items():
    if not isinstance(info, dict):
        errors.append('%s: ساختار _meta نادرست است' % lid)
        continue
    p = info.get('path')
    if not p:
        errors.append('%s: path ندارد' % lid)
        continue
    full = os.path.join(LAWS, p)
    if not os.path.isfile(full):
        errors.append('%s: فایل %s پیدا نشد' % (lid, p))
        continue
    registered[os.path.normpath(full)] = lid
    if lid not in cat_ids:
        warnings.append('%s: در laws_catalog.json نیست' % lid)

all_files = []
for d, _dirs, names in os.walk(LAWS):  # os.walk فایل‌های نقطه‌دار مثل .gitkeep را هم می‌بیند
    all_files += [os.path.join(d, n) for n in names]
for full in sorted(all_files):
    if full.endswith('_meta.json'):
        continue
    rel = os.path.relpath(full, LAWS)
    size = os.path.getsize(full)
    if os.path.basename(full) == '.gitkeep':
        if size > 0:
            errors.append('%s: فایل .gitkeep باید خالی باشد ولی %d بایت دارد '
                          '(احتمالاً متن قانون اشتباهی داخل آن چسبانده شده)' % (rel, size))
        continue
    if os.path.normpath(full) not in registered:
        errors.append('%s: در _meta.json ثبت نشده؛ برنامه آن را نمی‌خواند' % rel)

# ---------- ۳ و ۴: متن قانون‌ها ----------
sources_by_law = {}   # lid -> (فهرست منبع‌ها، مجموعهٔ عنوان مواد نرمال‌شده)
for full, lid in sorted(registered.items(), key=lambda x: x[1]):
    rel = os.path.relpath(full, LAWS)
    raw = open(full, 'rb').read()
    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError as e:
        errors.append('%s: UTF-8 معتبر نیست (%s)' % (rel, e))
        continue
    if '\ufffd' in text:
        errors.append('%s: نویسهٔ خراب (�) دارد؛ متن بریده یا خراب چسبانده شده' % rel)
    if re.search('[يك]', text):
        warnings.append('%s: حروف عربی ي/ك دارد (برنامه یکسانش می‌کند؛ convert.py آن را درست می‌کند)' % rel)
    low = text.lower()
    for m in AI_MARKERS:
        if m in low:
            errors.append('%s: عبارت مشکوک به متن ساختگی: «%s»' % (rel, m))

    blocks = parse(text)
    if not blocks:
        errors.append('%s: هیچ بخشی خوانده نشد' % rel)
        continue
    if not text.lstrip().startswith('#'):
        warnings.append('%s: خط اول با # و نام قانون شروع نمی‌شود' % rel)

    seen, plain, prev = {}, [], 0
    for first, body, src in blocks:
        t = norm(first)
        m = ARTICLE.match(t)
        if not m:
            continue
        if t in seen:
            errors.append('%s: «%s» تکراری است' % (rel, t))
        seen[t] = True
        if not m.group(2):
            n = int(m.group(1))
            if n < prev:
                errors.append('%s: شمارهٔ ماده برگشت دارد (%d بعد از %d)' % (rel, n, prev))
            prev = max(prev, n)
            plain.append(n)
        if body == first:
            warnings.append('%s: %s بدون متن است' % (rel, t))

    last_body = blocks[-1][1].strip()
    if last_body and last_body[-1] not in '.؛:)»!؟?"”':
        warnings.append('%s: آخرین بخش با نشانهٔ پایان جمله تمام نشده؛ شاید متن بریده شده' % rel)

    want = meta[lid].get('articles')
    if isinstance(want, int) and want != len(blocks):
        warnings.append('%s: _meta.json می‌گوید %d ماده، متن %d بخش دارد' % (lid, want, len(blocks)))
    if plain:
        have = set(plain)
        miss = [i for i in range(min(plain), max(plain) + 1) if i not in have]
        if miss:
            infos.append('%s: مادهٔ جاافتاده (%d): %s' % (lid, len(miss), rng(miss) if len(miss) <= 40 else 'بیش از ۴۰ مورد'))
    sources_by_law[lid] = ({norm(b[2]) for b in blocks if b[2]}, set(seen))

    info = meta[lid]
    for k in ('source', 'date'):
        if not str(info.get(k, '')).strip():
            warnings.append('%s: %s در _meta.json خالی است' % (lid, k))

# ---------- ۶: lawRefs ----------
for tp in sorted(glob.glob(os.path.join(ROOT, 'assets', 'templates', '*.json'))):
    t = load_json(tp, os.path.basename(tp))
    if not t:
        continue
    for r in t.get('lawRefs', []):
        law, art = norm(str(r.get('law', ''))), norm(str(r.get('article', '')))
        title = 'ماده ' + art
        found = False
        for srcs, titles in sources_by_law.values():
            if title in titles and any(s == law or law in s or s in law for s in srcs):
                found = True
                break
        if not found:
            warnings.append('%s: lawRefs «%s ماده %s» در متن‌های برنامه پیدا نشد'
                            % (os.path.basename(tp), r.get('law'), r.get('article')))

# ---------- ۷: pubspec ----------
try:
    ps = open(os.path.join(ROOT, 'pubspec.yaml'), encoding='utf-8').read()
    for m in re.finditer(r'^\s*-\s+(assets/\S+)\s*$', ps, re.M):
        if not os.path.exists(os.path.join(ROOT, m.group(1))):
            errors.append('pubspec.yaml: %s وجود ندارد' % m.group(1))
except Exception as e:
    errors.append('pubspec.yaml: %s' % e)

for i in infos:
    print('اطلاع:', i)
for w in warnings:
    print('هشدار:', w)
for e in errors:
    print('خطا:', e)
bad = len(errors) + (len(warnings) if STRICT else 0)
print('قانون‌های بررسی‌شده: %d | خطا: %d | هشدار: %d' % (len(registered), len(errors), len(warnings)))
if bad:
    print('نتیجه: ناموفق؛ پوش نکنید.')
    sys.exit(1)
print('نتیجه: سالم.')
