"""هر «یک چیز، دو پیاده‌سازی» با نگهبانش در `dev/tools/contracts/duplicated_logic.json`.

این جدول پیش‌تر فقط در `docs/ROADMAP.md` نوشته شده بود: اگر یک طرف از مجموعهٔ
نمونه‌های مشترک دست می‌کشید (یا آزمونش حذف می‌شد)، هیچ چیز قرمز نمی‌شد و بدهی
بی‌صدا از فهرست بیرون می‌رفت. حالا خودِ جدول داده است و بررسی می‌شود:

۱. هر مسیرِ نوشته‌شده وجود دارد؛
۲. هر مجموعهٔ نمونهٔ مشترک واقعاً وجود دارد و **از هر دو زبان** خوانده می‌شود؛
۳. هر جفت در `docs/ROADMAP.md` بخش بدهی‌های موقت ذکر شده است — اگر بدهی
   رفع شد و از ROADMAP رفت، این ردیف هم باید برود، نه اینکه بی‌صدا بماند.

اجرا: `python3 dev/tools/debt_check.py` (و `python3 dev/tools/check.py debt`).
"""

import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

CONTRACT_REL = os.path.join('dev', 'tools', 'contracts', 'duplicated_logic.json')
ROADMAP_REL = os.path.join('docs', 'ROADMAP.md')

DART_ROOTS = ['test', 'lib']
PY_ROOTS = ['tests/python', 'dev/tools', 'dev/brain']


def contract_path():
    return os.path.join(ROOT, CONTRACT_REL)


def roadmap_path():
    return os.path.join(ROOT, ROADMAP_REL)


def load():
    with open(contract_path(), encoding='utf-8') as f:
        return json.load(f)


def _walk(root, exts):
    base = os.path.join(ROOT, root)
    for dirpath, _dirs, files in os.walk(base):
        for f in files:
            if f.endswith(exts):
                yield os.path.join(dirpath, f)


def _texts(roots, exts):
    out = {}
    for r in roots:
        for p in _walk(r, exts):
            try:
                with open(p, encoding='utf-8') as f:
                    out[os.path.relpath(p, ROOT)] = f.read()
            except UnicodeDecodeError:
                continue
    return out


def _needle(pattern):
    """بخشی از مسیر که باید در فایلِ خواننده دیده شود.

    نامِ فایل کافی است: پایتون مسیر را با `os.path.join` می‌سازد و مسیرِ کامل
    در سورس دیده نمی‌شود. برای الگوی `tests/topics/*_gold.json` نامِ فایل ثابت
    نیست (آزمون همان پوشه را با نام‌های مختلف می‌خواند)، پس خودِ پوشه سنجیده
    می‌شود.
    """
    star = pattern.find('*')
    if star >= 0:
        return pattern[:star].rstrip('/')
    return os.path.basename(pattern)


def _read_by(texts, needle):
    return sorted([p for p, body in texts.items() if needle in body])


def check():
    """فهرست خطاها؛ فهرست خالی یعنی سالم."""
    errors = []
    try:
        c = load()
    except Exception as e:  # noqa: BLE001 — پیام باید در CI خوانا باشد
        return ['قرارداد خوانده نشد: %s' % e]

    pairs = c.get('pairs')
    if not isinstance(pairs, list) or not pairs:
        return ['قرارداد هیچ جفتی ندارد']

    dart_texts = _texts(DART_ROOTS, ('.dart',))
    py_texts = _texts(PY_ROOTS, ('.py',))
    try:
        with open(roadmap_path(), encoding='utf-8') as f:
            roadmap = f.read()
    except OSError:
        roadmap = ''

    seen = set()
    for p in pairs:
        pid = p.get('id') or '(بی‌نام)'
        if pid in seen:
            errors.append('%s: شناسهٔ تکراری' % pid)
        seen.add(pid)
        for key in ('what', 'dart', 'py', 'shared', 'fix'):
            if not p.get(key):
                errors.append('%s: کلید %s خالی است' % (pid, key))
        for key in ('dart', 'py'):
            rel = p.get(key)
            if rel and not os.path.exists(os.path.join(ROOT, rel)):
                errors.append('%s: %s وجود ندارد (%s)' % (pid, key, rel))
        shared = p.get('shared') or []
        if not shared:
            errors.append('%s: مجموعهٔ نمونهٔ مشترک ندارد' % pid)
        for pattern in shared:
            hits = glob.glob(os.path.join(ROOT, pattern))
            if not hits:
                errors.append('%s: نمونهٔ مشترک پیدا نشد (%s)' % (pid, pattern))
                continue
            needle = _needle(pattern)
            if not _read_by(dart_texts, needle):
                errors.append('%s: سمت دارت %s را نمی‌خواند' % (pid, pattern))
            if not _read_by(py_texts, needle):
                errors.append('%s: سمت پایتون %s را نمی‌خواند' % (pid, pattern))
        if roadmap and pid not in roadmap and (p.get('dart') or '') not in roadmap:
            errors.append('%s: در docs/ROADMAP.md (بدهی‌های موقت) نیست' % pid)
    return errors


def main(argv):
    errors = check()
    if '--check' in argv or not argv:
        if errors:
            print('debt: %d ایراد' % len(errors))
            for e in errors:
                print(' - %s' % e)
            return 1
        print('debt: %d جفت، همه با نگهبانِ دوطرفه' % len(load()['pairs']))
        return 0
    print(__doc__)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
