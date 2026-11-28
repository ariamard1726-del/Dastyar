"""بررسی یکپارچگی ارجاع‌های حقوقی در داده‌ها: هر ارجاع باید به متن واقعی قانون برسد.

سه جا ارجاع قانونی داریم و هر سه پیش‌تر بی‌نگهبان بودند:

* `assets/brain/topics/*.json`  → `leaves[*].articles` (قانون + «ماده N»)
* `assets/templates/*.json`     → `lawRefs[*]` (عنوان قانون + شمارهٔ ماده)
* `assets/qa/*.json`            → `refs` به شکل «شناسه‌قانون:ماده N»

اگر ارجاعی به مادهٔ ناموجود یا قانون ناشناخته اشاره کند، برنامه در زمان
اجرا بی‌صدا آن استناد را دور می‌ریزد (`engine.chunkOf` نال می‌دهد) و کاربر
پاسخی می‌بیند که هیچ ماده‌ای پشتش نیست. این ابزار همان سکوت را به خطا
تبدیل می‌کند.

اجرا:
  python3 dev/tools/data_refs.py            # همهٔ منابع
  python3 dev/tools/data_refs.py --count    # فقط شمارش
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lawtext  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOPIC_GLOB = os.path.join(ROOT, 'assets', 'brain', 'topics', '*.json')
# مسیرهای در دست ساخت (در APK نیستند) هم بررسی می‌شوند تا ارجاع شکسته‌شان
# وقتی live شد غافلگیرمان نکند.
LAB_TOPIC_GLOB = os.path.join(ROOT, 'lab', 'topics', '*.json')
TEMPLATE_GLOB = os.path.join(ROOT, 'assets', 'templates', '*.json')
QA_GLOB = os.path.join(ROOT, 'assets', 'qa', '*.json')

QA_REF_RE = re.compile(r'^([^:]+):\s*(ماده|اصل)?\s*(\d+)$')

_article_cache = {}


def norm_digits(s):
    return lawtext.digits(s).strip()


def load_meta():
    return lawtext.load_meta()


def articles(law_id, meta):
    """شمارهٔ ماده‌های موجود در متن قانون (با حافظهٔ میان‌اجرایی)."""
    if law_id in _article_cache:
        return _article_cache[law_id]
    ent = meta.get(law_id)
    if not ent or not ent.get('path'):
        _article_cache[law_id] = None
        return None
    path = os.path.join(ROOT, 'assets', 'laws', ent['path'])
    if not os.path.isfile(path):
        _article_cache[law_id] = None
        return None
    out = set()
    with open(path, encoding='utf-8') as f:
        for line in f:
            m = lawtext.ARTICLE.match(lawtext.norm(line))
            if m and m.group(2):
                out.add(m.group(2))
    _article_cache[law_id] = out
    return out


def _law_id_by_title(meta):
    return {v.get('title', '').strip(): k for k, v in meta.items()}


def check_flow_refs(name, flow, meta, errors):
    """ارجاع‌های یک مسیر موضوعی را می‌سنجد؛ خروجی: شمار ارجاع‌ها."""
    n = 0
    leaves = flow.get('leaves')
    if not isinstance(leaves, dict):
        return n
    for leaf_id, leaf in leaves.items():
        for a in (leaf.get('articles') or []):
            n += 1
            law = str(a.get('law', ''))
            title = str(a.get('title', ''))
            arts = articles(law, meta)
            if arts is None:
                errors.append('%s/%s: قانون ناشناخته %r' % (name, leaf_id, law))
                continue
            m = lawtext.ARTICLE.match(lawtext.norm(title))
            if not m or not m.group(2):
                errors.append('%s/%s: عنوان ماده نامعتبر %r' % (name, leaf_id, title))
                continue
            if m.group(2) not in arts:
                errors.append('%s/%s: %s در متن قانون %s نیست' % (name, leaf_id, title, law))
    return n


def check_topic_refs(meta, errors):
    n = 0
    for path in sorted(glob.glob(TOPIC_GLOB) + glob.glob(LAB_TOPIC_GLOB)):
        name = os.path.basename(path)
        if name == 'index.json':
            continue
        with open(path, encoding='utf-8') as f:
            flow = json.load(f)
        n += check_flow_refs(name, flow, meta, errors)
    return n


def check_template_refs(meta, errors):
    by_title = _law_id_by_title(meta)
    n = 0
    for path in sorted(glob.glob(TEMPLATE_GLOB)):
        name = os.path.basename(path)
        with open(path, encoding='utf-8') as f:
            tpl = json.load(f)
        for r in (tpl.get('lawRefs') or []):
            n += 1
            title = str(r.get('law', '')).strip()
            art = norm_digits(r.get('article', ''))
            law_id = by_title.get(title)
            if not law_id:
                errors.append('%s: قانون %r در _meta.json نیست' % (name, title))
                continue
            arts = articles(law_id, meta)
            if not arts:
                errors.append('%s: متن قانون %s در دسترس نیست' % (name, title))
                continue
            if art not in arts:
                errors.append('%s: مادهٔ %s در %s نیست' % (name, art, title))
    return n


def check_qa_refs(meta, errors):
    n = 0
    for path in sorted(glob.glob(QA_GLOB)):
        name = os.path.basename(path)
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
        for item in (data.get('items') or []):
            for ref in (item.get('refs') or []):
                n += 1
                m = QA_REF_RE.match(norm_digits(ref))
                if not m:
                    errors.append('%s/%s: قالب ارجاع نامعتبر %r' % (name, item.get('id'), ref))
                    continue
                law_id, art = m.group(1).strip(), norm_digits(m.group(3))
                arts = articles(law_id, meta)
                if arts is None:
                    errors.append('%s/%s: قانون ناشناخته %r' % (name, item.get('id'), law_id))
                    continue
                if art not in arts:
                    errors.append('%s/%s: مادهٔ %s در %s نیست' % (name, item.get('id'), art, law_id))
    return n


def check():
    """خروجی: (خطاها، شمارش ارجاع‌ها)."""
    meta = load_meta()
    errors = []
    counts = {
        'topics': check_topic_refs(meta, errors),
        'templates': check_template_refs(meta, errors),
        'qa': check_qa_refs(meta, errors),
    }
    return errors, counts


def main(argv):
    errors, counts = check()
    total = sum(counts.values())
    if '--count' in argv:
        print('ارجاع‌ها: %s' % counts)
    for e in errors:
        print('خطا:', e)
    if errors:
        print('نتیجه: %d ارجاع شکسته از %d ارجاع.' % (len(errors), total))
        return 1
    print('نتیجه: هر %d ارجاع قانونی به متن واقعی می‌رسد.' % total)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
