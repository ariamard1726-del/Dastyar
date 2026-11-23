"""اعتبارسنج مسیرهای تصمیم موضوعی (assets/brain/topics/*.json).

قواعد ساختاری (خطا):
- کلیدهای لازم (live/gate/topic/law/disclaimer/clarify/rules/leaves) حاضر و از نوع درست.
- هر قاعده یک leaf دارد و دست‌کم یکی از any یا all_groups.
- هر برگ title و text غیرخالی دارد و articles آن به قانون موجود در
  assets/laws/_meta.json و عنوان «ماده/اصل N» اشاره می‌کند.
- برگ ask وجود دارد و هر leaf قاعده در leaves تعریف شده است.

قواعد کیفی (هشدار، نه خطا تا دادهٔ قدیمی CI را نشکند):
- واژهٔ دروازهٔ خیلی عام (خانه، پول، قرارداد و...) که هر پیامی را به این
  مسیر می‌کشد.
- موضوع live:false که در index هست ولی در گفتگو جواب نمی‌دهد (در APK می‌ماند).
- برگی که هیچ قاعده‌ای به آن نمی‌رسد (کد مردهٔ داده‌ای).

اجرا:
  python3 tools/topic_schema.py            # همهٔ موضوع‌های index.json
  python3 tools/topic_schema.py cheque     # فقط یک موضوع
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOPIC_DIR = os.path.join(ROOT, 'assets', 'brain', 'topics')
META_PATH = os.path.join(ROOT, 'assets', 'laws', '_meta.json')

REQUIRED = ('live', 'gate', 'topic', 'law', 'disclaimer', 'clarify', 'rules', 'leaves')
ARTICLE_TITLE_RE = re.compile(r'^(ماده|اصل)\s+\S+')

# واژه‌هایی که به‌تنهایی دروازهٔ خوبی نیستند: هر پیامی را به این مسیر می‌کشند.
GENERIC_GATE_WORDS = {
    'خانه', 'خونه', 'صاحب', 'مالک', 'پول', 'طلب', 'پایان', 'قرارداد',
    'واحد', 'مغازه', 'آپارتمان', 'ساکن', 'کار', 'مبلغ', 'مورد', 'متن',
}


def load_meta():
    with open(META_PATH, encoding='utf-8') as f:
        return json.load(f)


def topic_names():
    with open(os.path.join(TOPIC_DIR, 'index.json'), encoding='utf-8') as f:
        return json.load(f)['topics']


def load_topic(name):
    with open(os.path.join(TOPIC_DIR, name), encoding='utf-8') as f:
        return json.load(f)


def validate_topic(flow, meta, name='<topic>'):
    """یک موضوع را می‌سنجد؛ خروجی: (خطاها، هشدارها)."""
    errors, warnings = [], []
    if not isinstance(flow, dict):
        return ['%s: باید شیء باشد' % name], []
    for k in REQUIRED:
        if k not in flow:
            errors.append('%s: کلید لازم %s وجود ندارد' % (name, k))
    if errors:
        return errors, warnings
    if not isinstance(flow['live'], bool):
        errors.append('%s: live باید boolean باشد' % name)
    gate = flow['gate']
    if not isinstance(gate, list) or not gate or not all(isinstance(x, str) and x for x in gate):
        errors.append('%s: gate باید فهرست غیرخالی از رشته باشد' % name)
    else:
        for w in gate:
            if w in GENERIC_GATE_WORDS:
                warnings.append('%s: واژهٔ دروازهٔ عام «%s» هر پیامی را به این مسیر می‌کشد' % (name, w))
    if flow['law'] not in meta:
        errors.append('%s: قانون %s در _meta.json نیست' % (name, flow['law']))
    if not str(flow['disclaimer']).strip():
        errors.append('%s: disclaimer خالی است' % name)
    if not str(flow['clarify']).strip():
        errors.append('%s: clarify خالی است' % name)
    rules = flow['rules']
    leaves = flow['leaves']
    if not isinstance(rules, list) or not rules:
        errors.append('%s: rules باید فهرست غیرخالی باشد' % name)
        rules = []
    if not isinstance(leaves, dict) or not leaves:
        errors.append('%s: leaves باید شیء غیرخالی باشد' % name)
        leaves = {}
    if 'ask' not in leaves:
        errors.append('%s: برگ ask وجود ندارد' % name)
    reached = set()
    for i, r in enumerate(rules):
        if not isinstance(r, dict) or not r.get('leaf'):
            errors.append('%s: قاعدهٔ %d بدون leaf است' % (name, i))
            continue
        leaf = r['leaf']
        reached.add(leaf)
        if leaf not in leaves:
            errors.append('%s: قاعدهٔ %d به برگ تعریف‌نشده %s اشاره می‌کند' % (name, i, leaf))
        has_any = isinstance(r.get('any'), list) and r['any']
        has_all = isinstance(r.get('all_groups'), list) and r['all_groups']
        if not (has_any or has_all):
            errors.append('%s: قاعدهٔ %d نه any دارد نه all_groups' % (name, i))
    for leaf_id, leaf in leaves.items():
        if not isinstance(leaf, dict):
            errors.append('%s: برگ %s باید شیء باشد' % (name, leaf_id))
            continue
        if not str(leaf.get('title', '')).strip():
            errors.append('%s: برگ %s عنوان ندارد' % (name, leaf_id))
        if not str(leaf.get('text', '')).strip():
            errors.append('%s: برگ %s متن ندارد' % (name, leaf_id))
        arts = leaf.get('articles')
        if not isinstance(arts, list):
            errors.append('%s: برگ %s articles باید فهرست باشد' % (name, leaf_id))
            continue
        for a in arts:
            if not isinstance(a, dict) or not a.get('law') or not a.get('title'):
                errors.append('%s: برگ %s یک ارجاع ناقص دارد: %r' % (name, leaf_id, a))
                continue
            if a['law'] not in meta:
                errors.append('%s: برگ %s به قانون ناشناخته %s اشاره می‌کند' % (name, leaf_id, a['law']))
            if not ARTICLE_TITLE_RE.match(str(a['title'])):
                errors.append('%s: برگ %s عنوان ماده نامعتبر دارد: %r' % (name, leaf_id, a['title']))
        if leaf_id != 'ask' and leaf_id not in reached:
            warnings.append('%s: برگ %s هیچ قاعده‌ای ندارد (دادهٔ مرده)' % (name, leaf_id))
    if flow.get('live') is not True:
        warnings.append('%s: live نیست؛ در APK می‌ماند ولی در گفتگو جواب نمی‌دهد' % name)
    return errors, warnings


def check(names=None):
    meta = load_meta()
    names = names or topic_names()
    all_errors, all_warnings = [], []
    for name in names:
        try:
            flow = load_topic(name)
        except Exception as e:
            all_errors.append('%s: خوانده نشد (%s)' % (name, e))
            continue
        e, w = validate_topic(flow, meta, name)
        all_errors += e
        all_warnings += w
    return all_errors, all_warnings


def main(argv):
    names = [a for a in argv if not a.startswith('-')] or None
    errors, warnings = check(names)
    for w in warnings:
        print('هشدار:', w)
    for e in errors:
        print('خطا:', e)
    if errors:
        print('نتیجه: %d خطا در مسیرهای موضوعی.' % len(errors))
        return 1
    print('نتیجه: مسیرهای موضوعی سالم است.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
