"""همگام‌سازی متادیتای قوانین از منبع یکتا.

منبع کانونیک: assets/laws/_meta.json  (عنوان، منبع، تاریخ، تعداد مواد، مسیر)
مشتق‌ها:
  - assets/laws_catalog.json → عنوان هر قانون از _meta گرفته می‌شود؛
    عنوان قبلی کاتالوگ اگر متفاوت باشد به aliases منتقل می‌شود (تا جستجوی نام رایج نشکند).
  - assets/data_info.json   → lawsUpdated = آخرین تاریخ دریافت متن در _meta.

اجرا:
  python3 dev/tools/sync_meta.py           # فقط بررسی تازگی (خروج ۱ اگر مشتق‌ها کهنه‌اند)
  python3 dev/tools/sync_meta.py --write   # بازنویسی مشتق‌ها از _meta.json
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lawtext import digits, load_meta, to_fa  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CATALOG = os.path.join(ROOT, 'assets', 'laws_catalog.json')
INFO = os.path.join(ROOT, 'assets', 'data_info.json')


def load(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def dump(obj):
    return json.dumps(obj, ensure_ascii=False, indent=2) + '\n'


def build():
    meta = load_meta()
    catalog = json.loads(load(CATALOG))
    info = json.loads(load(INFO))

    for law in catalog.get('laws', []):
        m = meta.get(law.get('id'))
        if not isinstance(m, dict):
            continue
        title = str(m.get('title', '')).strip()
        if not title:
            continue
        old = str(law.get('title', '')).strip()
        law['title'] = title
        existing = law.get('aliases')
        new_aliases = [str(a) for a in (existing or []) if str(a) != title]
        if old and old != title and old not in new_aliases:
            new_aliases.insert(0, old)
        if (new_aliases or existing is not None) and new_aliases != existing:
            law['aliases'] = new_aliases

    dates = []
    for m in meta.values():
        if isinstance(m, dict):
            d = str(m.get('date', '')).strip()
            if d:
                dates.append(d)
    if dates:
        info['lawsUpdated'] = to_fa(max(dates, key=digits))

    return dump(catalog), dump(info)


def main():
    want_catalog, want_info = build()
    have_catalog, have_info = load(CATALOG), load(INFO)
    stale = []
    if have_catalog != want_catalog:
        stale.append('laws_catalog.json')
    if have_info != want_info:
        stale.append('data_info.json')
    if not stale:
        print('sync_meta: مشتق‌ها تازه‌اند (کاتالوگ و data_info هم‌راستا با _meta.json).')
        return 0
    if '--write' not in sys.argv:
        print('خطا: %s از _meta.json مشتق نشده (کهنه است). اجرا: python3 dev/tools/sync_meta.py --write'
              % ' و '.join(stale))
        return 1
    if 'laws_catalog.json' in stale:
        with open(CATALOG, 'w', encoding='utf-8') as f:
            f.write(want_catalog)
    if 'data_info.json' in stale:
        with open(INFO, 'w', encoding='utf-8') as f:
            f.write(want_info)
    print('sync_meta: بازنویسی شد: %s' % '، '.join(stale))
    return 0


if __name__ == '__main__':
    sys.exit(main())
