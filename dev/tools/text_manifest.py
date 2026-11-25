"""هش‌نامهٔ متنِ حقوقی: هیچ تغییرِ متنی بی‌اعلام نمی‌ماند.

متنِ حقوقیِ این برنامه در دو جا زندگی می‌کند:

* **دارایی‌ها**: متنِ ۲۴ قانون (`assets/laws/**/*.txt`)، راهنماهای آماده
  (`assets/brain/guides/legal_guides.json`)، بانک پرسش‌وپاسخ (`assets/qa/`)،
  پاسخ‌های ثابت (`assets/replies.json`) و متادیتای قوانین (`_meta.json`)؛
* **کدِ Dart**: فایل‌هایی که متنِ پاسخِ موضوع‌ها در آن‌ها نوشته شده است
  (`rent_bodies*`، `rent_claims`، `rent_plan`، `rent_fill`، `labor_bodies`،
  `family_bodies`، `shared`).

`_meta.json` امروز فقط هشِ متنِ قوانین را دارد. این ابزار همان کار را برای
**همهٔ** متن‌ها می‌کند تا وقتی نسخهٔ اعتبارسنجی‌شدهٔ قانون می‌آید، تفاضلِ متن
قابلِ بازبینی باشد و هیچ جمله‌ای بی‌آنکه کسی ببیند عوض نشود.

اجرا:

    python3 dev/tools/text_manifest.py           # بررسی (خروج ۱ اگر عوض شده)
    python3 dev/tools/text_manifest.py --write   # بازنویسیِ هش‌نامه
"""

import hashlib
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MANIFEST = 'assets/brain/text_manifest.json'
SCHEMA = 1

# دارایی‌هایی که متنِ حقوقی یا پاسخِ آماده در آن‌هاست.
ASSET_FILES = [
    'assets/brain/guides/legal_guides.json',
    'assets/qa/lease_qa.json',
    'assets/replies.json',
    'assets/laws/_meta.json',
]

# فایل‌های Dart که متنِ پاسخ در آن‌ها نوشته شده است (نه منطق).
DART_TEXT_FILES = [
    'lib/domain/advocate/topics/rent_bodies.dart',
    'lib/domain/advocate/topics/rent_bodies_landlord.dart',
    'lib/domain/advocate/topics/rent_claims.dart',
    'lib/domain/advocate/topics/rent_plan.dart',
    'lib/domain/advocate/topics/rent_fill.dart',
    'lib/domain/advocate/topics/labor_bodies.dart',
    'lib/domain/advocate/topics/family_bodies.dart',
    'lib/domain/advocate/topics/shared.dart',
]


def _abs(root, *parts):
    return os.path.join(root, *parts)


def law_texts(root):
    """همهٔ فایل‌های متنِ قانون، به مسیرِ نسبیِ مرتب."""
    out = []
    base = os.path.join(root, 'assets', 'laws')
    for dirpath, _, names in os.walk(base):
        for name in names:
            if not name.endswith('.txt'):
                continue
            full = os.path.join(dirpath, name)
            out.append(os.path.relpath(full, root).replace(os.sep, '/'))
    return sorted(out)


def text_files(root):
    """هر فایلی که متنِ حقوقی دارد — قانون، دارایی، یا فایلِ متنِ Dart."""
    files = law_texts(root)
    files += [rel for rel in ASSET_FILES if os.path.exists(_abs(root, rel))]
    files += [rel for rel in DART_TEXT_FILES if os.path.exists(_abs(root, rel))]
    return sorted(set(files))


def _digest(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(65536), b''):
            h.update(chunk)
    return h.hexdigest()


def _lines(path):
    with open(path, encoding='utf-8') as f:
        return f.read().count('\n')


def build(root=ROOT):
    files = {}
    for rel in text_files(root):
        path = _abs(root, rel)
        files[rel] = {'sha256': _digest(path), 'lines': _lines(path)}
    return {'schema': SCHEMA, 'files': files}


def load(root=ROOT):
    with open(_abs(root, MANIFEST), encoding='utf-8') as f:
        return json.load(f)


def meta(root=ROOT):
    with open(_abs(root, 'assets', 'laws', '_meta.json'), encoding='utf-8') as f:
        return json.load(f)


def diff(root=ROOT, manifest=None):
    """فهرستِ تغییرها: `[{'path', 'reason'}]`. خالی یعنی متن دست‌نخورده است."""
    current = build(root)['files']
    stored = (manifest or load(root))['files']
    out = []
    for rel in sorted(set(current) | set(stored)):
        if rel not in stored:
            out.append({'path': rel, 'reason': 'added'})
        elif rel not in current:
            out.append({'path': rel, 'reason': 'removed'})
        elif current[rel]['sha256'] != stored[rel]['sha256']:
            out.append({'path': rel, 'reason': 'sha256'})
        elif current[rel]['lines'] != stored[rel]['lines']:
            out.append({'path': rel, 'reason': 'lines'})
    return out


def write(root=ROOT):
    data = build(root)
    data['note'] = ('هشِ متن هر فایل؛ با هر تغییرِ متن باید آگاهانه بازنویسی شود '
                    '(dev/tools/text_manifest.py --write).')
    with open(_abs(root, MANIFEST), 'w', encoding='utf-8') as f:
        f.write(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    return len(data['files'])


def main(argv):
    write_mode = '--write' in argv
    if write_mode:
        print('text: %d فایل هش شد' % write())
        return 0
    changed = diff()
    if not changed:
        print('text: %d فایل، همه دست‌نخورده' % len(build()['files']))
        return 0
    for row in changed:
        print('text: %s عوض شده (%s) — اگر آگاهانه است: --write' %
              (row['path'], row['reason']))
    return 1


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
