"""تفاضلِ ماده‌به‌مادهٔ متنِ قوانین.

وقتی نسخهٔ اعتبارسنجی‌شدهٔ یک قانون می‌آید، پرسشِ درست این نیست «فایل عوض
شد؟» بلکه «کدام ماده‌ها عوض شدند، کدام اضافه و کدام حذف شدند؟». این ابزار
همان را می‌گوید و هیچ‌وقت متن را نمی‌نویسد — فقط می‌خواند و گزارش می‌دهد.

اجرا:

    python3 dev/tools/law_diff.py                       # تفاضلِ درختِ کاری با HEAD
    python3 dev/tools/law_diff.py --ref origin/main     # با هر مرجعِ گیت
    python3 dev/tools/law_diff.py --report              # + گزارشِ متنی برای بازبینی
    python3 dev/tools/law_diff.py --dir ../new-text     # با پوشه‌ای که نسخهٔ نو در آن است
    python3 dev/tools/law_diff.py --counts              # شمارِ مواد ↔ _meta.json
"""

import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lawtext import articles_of, load_meta, to_fa as _fa  # noqa: E402  خوانندهٔ یکتای متنِ قانون


def parse_law(text):
    """{کلیدِ بخش: متن} — از خوانندهٔ مشترک، تا تعریفِ «ماده» یکی بماند."""
    return articles_of(text)


def _key(k):
    """ترتیبِ انسانی: ماده‌ها به ترتیبِ شماره، یادداشت‌ها آخر."""
    m = re.search(r'(\d+)', k)
    base = int(m.group(1)) if m else -1
    kind = 0 if k.startswith(('ماده', 'اصل')) else 1
    return (kind, base, k)


def diff_articles(old, new):
    added = sorted([k for k in new if k not in old], key=_key)
    removed = sorted([k for k in old if k not in new], key=_key)
    changed = sorted([k for k in new if k in old and new[k] != old[k]], key=_key)
    return {'added': added, 'removed': removed, 'changed': changed}


def law_texts(root=ROOT):
    out = []
    base = os.path.join(root, 'assets', 'laws')
    for dirpath, _, names in os.walk(base):
        for name in sorted(names):
            if name.endswith('.txt'):
                full = os.path.join(dirpath, name)
                out.append(os.path.relpath(full, root).replace(os.sep, '/'))
    return sorted(out)


def _read(root, rel):
    with open(os.path.join(root, rel), encoding='utf-8') as f:
        return f.read()


def _read_ref(root, ref, rel):
    try:
        return subprocess.run(['git', '-C', root, 'show', '%s:%s' % (ref, rel)],
                              capture_output=True, text=True, check=True).stdout
    except subprocess.CalledProcessError:
        return ''


def diff_against_ref(root=ROOT, ref='HEAD'):
    """برای هر قانون: شمارِ موادِ قدیم/جدید و سه فهرستِ تفاضل."""
    rows = []
    for rel in law_texts(root):
        old = parse_law(_read_ref(root, ref, rel))
        new = parse_law(_read(root, rel))
        d = diff_articles(old, new)
        rows.append({'path': rel, 'old': len(old), 'new': len(new), **d})
    return rows


def diff_against_dir(root=ROOT, other='.'):
    """مقایسه با درختِ دیگری (نسخهٔ نوِ رسیده) پیش از جای‌گذاری."""
    rows = []
    for rel in law_texts(root):
        old_rel = os.path.join(other, rel)
        old = parse_law(_read(other, rel)) if os.path.exists(old_rel) else {}
        new = parse_law(_read(root, rel))
        d = diff_articles(old, new)
        rows.append({'path': rel, 'old': len(old), 'new': len(new), **d})
    return rows


def count_mismatches(root=ROOT):
    """[(شناسه، شمارِ متادیتا، شمارِ واقعی)] برای هر قانونی که نمی‌خواند."""
    meta = load_meta(root=root)
    bad = []
    for key, law in sorted(meta.items()):
        rel = 'assets/laws/' + str(law.get('path', ''))
        if not os.path.exists(os.path.join(root, rel)):
            bad.append((key, law.get('articles'), None))
            continue
        real = len(parse_law(_read(root, rel)))
        if real != law.get('articles'):
            bad.append((key, law.get('articles'), real))
    return bad


def _brief(nums, limit=12):
    head = '، '.join(_fa(n) for n in nums[:limit])
    if len(nums) > limit:
        head += ' و %s مادهٔ دیگر' % _fa(len(nums) - limit)
    return head


def render(rows):
    lines = []
    for row in rows:
        if not (row['added'] or row['removed'] or row['changed']):
            continue
        name = row['path'].split('/')[-1]
        lines.append('%s: %s → %s ماده' % (name, _fa(row['old']), _fa(row['new'])))
        if row['added']:
            lines.append('  + %s' % _brief(row['added']))
        if row['removed']:
            lines.append('  − %s' % _brief(row['removed']))
        if row['changed']:
            lines.append('  ~ %s' % _brief(row['changed']))
    if not lines:
        return 'تفاضلی نیست: هر ۲۴ متنِ قانون همان است که بود.'
    return '\n'.join(lines)


def main(argv):
    ref = 'HEAD'
    if '--ref' in argv:
        ref = argv[argv.index('--ref') + 1]
    if '--counts' in argv:
        bad = count_mismatches()
        if not bad:
            print('law_diff: شمارِ موادِ همهٔ قانون‌ها با _meta.json می‌خواند.')
            return 0
        for key, meta_n, real in bad:
            print('law_diff: %s — متادیتا %s، متن %s' % (key, meta_n, real))
        return 1
    if '--dir' in argv:
        rows = diff_against_dir(ROOT, argv[argv.index('--dir') + 1])
    else:
        rows = diff_against_ref(ROOT, ref)
    print(render(rows))
    has = any(r['added'] or r['removed'] or r['changed'] for r in rows)
    # --report یک دروازهٔ بازبینی است: تفاضلِ غیرخالی یعنی کسی باید بخواند.
    return 1 if (has and '--report' in argv) else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
