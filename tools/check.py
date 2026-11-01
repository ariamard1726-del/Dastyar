import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAWS_DIR = os.path.join(ROOT, 'assets', 'laws')
TYPES = {'text', 'multiline', 'number', 'choice', 'check'}
errors = []
warnings = []

# با STRICT=1 یا --strict خالی‌بودن منبع و تاریخ قانون «خطا» می‌شود، نه هشدار.
STRICT = os.environ.get('STRICT') == '1' or '--strict' in sys.argv

# نشانهٔ متنی که ممکن است با هوش مصنوعی نوشته شده باشد، نه از منبع رسمی.
AI_MARKERS = [
    'هوش مصنوعی', 'تولید شده توسط', 'تولیدشده توسط', 'این متن توسط',
    'chatgpt', 'gemini', 'claude', 'as an ai', 'language model',
]

try:
    with open(os.path.join(LAWS_DIR, '_meta.json'), encoding='utf-8') as _f:
        META = json.load(_f)
except Exception as _e:
    META = {}
    errors.append('_meta.json: %s' % _e)


def digits(s):
    return s.translate(str.maketrans('۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789'))


def check_template(path):
    name = os.path.basename(path)
    try:
        with open(path, encoding='utf-8') as f:
            t = json.load(f)
    except Exception as e:
        errors.append('%s: JSON خراب است (%s)' % (name, e))
        return
    for k in ('id', 'title', 'fields', 'body'):
        if k not in t:
            errors.append('%s: کلید %s وجود ندارد' % (name, k))
            return
    ids = []
    for f in t['fields']:
        fid = f.get('id')
        if not fid:
            errors.append('%s: یک فیلد بدون id' % name)
            continue
        if fid in ids:
            errors.append('%s: id تکراری: %s' % (name, fid))
        ids.append(fid)
        ft = f.get('type', 'text')
        if ft not in TYPES:
            errors.append('%s: نوع نامعتبر برای %s: %s' % (name, fid, ft))
        if ft == 'choice' and not f.get('options'):
            errors.append('%s: فیلد گزینه‌ای %s گزینه ندارد' % (name, fid))
    body = t['body']
    if isinstance(body, list):
        body = '\n'.join(str(x) for x in body)
    opens = len(re.findall(r'\{\{\s*#if\s+\w+\s*\}\}', body))
    closes = len(re.findall(r'\{\{\s*/if\s*\}\}', body))
    if opens != closes:
        errors.append('%s: تعداد #if (%d) و /if (%d) برابر نیست' % (name, opens, closes))
    used = set(re.findall(r'\{\{\s*#if\s+(\w+)\s*\}\}', body))
    for m in re.finditer(r'\{\{\s*(\w+)(?:\|\w+)?\s*\}\}', body):
        if m.group(1) != 'else':
            used.add(m.group(1))
    bad = used - set(ids)
    if bad:
        errors.append('%s: جای‌نگهدار تعریف‌نشده: %s' % (name, ', '.join(sorted(bad))))
    for r in t.get('lawRefs', []):
        if not str(r.get('law', '')).strip() or not str(r.get('article', '')).strip():
            errors.append('%s: یک lawRefs بدون law یا article' % name)
    if not t.get('reviewed'):
        warnings.append('%s: بازبینی‌نشده' % name)
    print('قالب %s: %d فیلد' % (name, len(ids)))


def check_law(lid, path):
    rel_name = os.path.relpath(path, LAWS_DIR)
    if not os.path.isfile(path):
        errors.append('%s: فایل %s وجود ندارد' % (lid, rel_name))
        return
    with open(path, encoding='utf-8') as f:
        text = f.read().replace('\r', '')
    parts = [p.strip() for p in re.split(r'\n\s*\n', text) if p.strip()]
    if not parts:
        warnings.append('%s: فایل خالی است' % rel_name)
        return
    if not parts[0].startswith('#'):
        errors.append('%s: خط اول باید با # و نام قانون شروع شود' % rel_name)
    seen = set()
    n = 0
    for p in parts:
        if p.startswith('#'):
            continue
        lines = p.split('\n')
        title = digits(lines[0]).strip()
        n += 1
        if not title.startswith('ماده'):
            warnings.append('%s: بخشی بدون عنوان ماده: %s' % (rel_name, title[:30]))
        if title in seen:
            warnings.append('%s: عنوان تکراری: %s' % (rel_name, title))
        seen.add(title)
        if len(lines) < 2:
            warnings.append('%s: %s بدون متن است' % (rel_name, title))
    print('قانون %s (%s): %d بخش' % (lid, os.path.basename(path), n))

    low = text.lower()
    for m in AI_MARKERS:
        if m in low:
            errors.append('%s: عبارت مشکوک به متن تولیدشده با هوش مصنوعی: «%s»' % (rel_name, m))

    info = META.get(lid) if lid else None
    if not isinstance(info, dict):
        errors.append('%s: در _meta.json ثبت نشده' % rel_name)
        return
    problems = []
    if not str(info.get('source', '')).strip():
        problems.append('منبع (source) خالی است')
    if not str(info.get('date', '')).strip():
        problems.append('تاریخ (date) خالی است')
    for pr in problems:
        msg = '%s: %s' % (lid, pr)
        (errors if STRICT else warnings).append(msg)
    want = info.get('articles')
    if isinstance(want, int) and want != n:
        warnings.append('%s: در _meta.json %d ماده نوشته شده ولی %d بخش خوانده شد' % (lid, want, n))


for p in sorted(glob.glob(os.path.join(ROOT, 'assets', 'templates', '*.json'))):
    check_template(p)

checked_paths = set()
for lid, info in sorted(META.items()):
    if not isinstance(info, dict) or not info.get('path'):
        errors.append('%s: کلید path در _meta.json وجود ندارد' % lid)
        continue
    full = os.path.normpath(os.path.join(LAWS_DIR, info['path']))
    checked_paths.add(full)
    check_law(lid, full)

for root, _dirs, files in os.walk(LAWS_DIR):
    for fn in sorted(files):
        if not fn.endswith('.txt'):
            continue
        full = os.path.normpath(os.path.join(root, fn))
        if full not in checked_paths:
            check_law(None, full)

info = os.path.join(ROOT, 'assets', 'data_info.json')
try:
    with open(info, encoding='utf-8') as f:
        json.load(f)
except Exception as e:
    errors.append('data_info.json: %s' % e)

for w in warnings:
    print('هشدار:', w)
for e in errors:
    print('خطا:', e)
if errors:
    print('نتیجه: %d خطا؛ پوش نکنید.' % len(errors))
    sys.exit(1)
print('نتیجه: همه چیز درست است.')
