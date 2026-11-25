"""مسیر تصمیم موضوعی (پایلوت: چک) با پاسخ‌های مبتنی بر متن ماده.

هیچ مدل زبانی یا یادگیری ماشین در زمان اجرا نیست. هر پرسش با قاعده‌های
ساده (زیررشته روی متن نرمال‌شده) به یک «برگ» تصمیم می‌رسد؛ اگر هیچ قاعده‌ای
نخورد، برگ «ask» پرسش روشنگر می‌دهد. متن هر برگ دست‌نویس و نسخهٔ قانون است؛
شماره مادهٔ هر برگ با داده‌های assets/laws بررسی می‌شود (tests/python).

اجرا:
  python3 tools/topic_flow.py "چک من برگشت خورده"
  python3 tools/topic_flow.py --check      # همهٔ نمونه‌های tests/topics/cheque_gold.json
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOPIC_DIR = os.path.join(ROOT, 'assets', 'brain', 'topics')
# مسیرهای در دست ساخت: در APK بسته‌بندی نمی‌شوند (در pubspec نیستند) ولی
# نمونه‌های آزمونشان باید همچنان اجرا شود تا کار نیمه‌کاره از دست نرود.
LAB_DIR = os.path.join(ROOT, 'lab', 'topics')
TEST_DIR = os.path.join(ROOT, 'tests', 'topics')

sys.path.insert(0, os.path.join(ROOT, 'brain'))
from common import spaced as _spaced  # noqa: E402  (قاعده‌ها: tools/contracts/text_norm.json)


def spaced(s):
    """یکدست‌سازی متن برای تطبیق قاعده‌ها.

    پیش‌تر جدول و الگوی جداگانهٔ خودش را داشت (نسخهٔ سومِ همان قاعده در مخزن)؛
    حالا از قرارداد `tools/contracts/text_norm.json` می‌آید و رفتارش با
    `tests/text_norm_golden.json` قفل است.
    """
    return _spaced(s, 'tools')


def _has(text, words):
    # پیشوندِ واژه: «برگشتی» و «برگشت» هر دو با «برگشت» تطبیق می‌یابند.
    return any((' ' + spaced(w).strip()) in text for w in words)


def route(q, flow=None):
    """برگ تصمیم را برمی‌گرداند؛ ترتیب قاعده‌ها مهم است (اولین تطابق)."""
    flow = flow or load()
    text = spaced(q)
    # مسیر فقط برای پیام‌هایی است که واژهٔ دروازه (مثلاً «چک») دارند.
    if flow.get('gate') and not _has(text, flow['gate']):
        return 'ask'
    for rule in flow['rules']:
        if 'any' in rule and _has(text, rule['any']):
            return rule['leaf']
        if 'all_groups' in rule and all(_has(text, g) for g in rule['all_groups']):
            return rule['leaf']
    return 'ask'


def topic_names():
    with open(os.path.join(TOPIC_DIR, 'index.json'), encoding='utf-8') as f:
        return [os.path.splitext(n)[0] for n in json.load(f)['topics']]


def topic_path(topic):
    """مسیر فایل یک موضوع: اول بستهٔ برنامه، بعد آزمایشگاه."""
    shipped = os.path.join(TOPIC_DIR, topic + '.json')
    if os.path.isfile(shipped):
        return shipped
    return os.path.join(LAB_DIR, topic + '.json')


def lab_names():
    if not os.path.isdir(LAB_DIR):
        return []
    return sorted(os.path.splitext(n)[0] for n in os.listdir(LAB_DIR) if n.endswith('.json'))


def all_names():
    """همهٔ موضوع‌ها: هم آن‌هایی که در APK هستند، هم آن‌هایی که در آزمایشگاه‌اند."""
    out = list(topic_names())
    for n in lab_names():
        if n not in out:
            out.append(n)
    return out


def load(topic='cheque'):
    with open(topic_path(topic), encoding='utf-8') as f:
        return json.load(f)


def route_all(q):
    """اولین موضوعی که پاسخ غیر از ask بدهد؛ (نام موضوع، برگ) یا (None، 'ask')."""
    for name in topic_names():
        flow = load(name)
        leaf = route(q, flow)
        if leaf != 'ask':
            return name, leaf
    return None, 'ask'


def answer(q, flow=None):
    if flow is None:
        name, leaf_id = route_all(q)
        if name is None:
            flow, name = load('cheque'), 'cheque'
        flow = load(name)
    leaf_id = route(q, flow)
    leaf = flow['leaves'][leaf_id]
    refs = ['%s %s' % (a['law'], a['title']) for a in leaf['articles']]
    return {'leaf': leaf_id, 'title': leaf['title'], 'text': leaf['text'],
            'articles': refs, 'disclaimer': flow['disclaimer']}


def check():
    """بررسی هر موضوع با نمونه‌های خودش؛ خروجی: (همه، ناموفق‌ها)."""
    gold_all, bad = [], []
    for name in all_names():
        flow = load(name)
        path = os.path.join(TEST_DIR, name + '_gold.json')
        if not os.path.isfile(path):
            continue
        gold = json.load(open(path, encoding='utf-8'))
        for g in gold:
            gold_all.append(g)
            got = route(g['q'], flow)
            if got != g['leaf']:
                bad.append((name, g['q'], g['leaf'], got))
    return gold_all, bad


def main(argv):
    if argv and argv[0] == '--check':
        gold, bad = check()
        print('%d از %d نمونه درست است.' % (len(gold) - len(bad), len(gold)))
        for name, q, want, got in bad:
            print('  ✗ [%s] %s: انتظار %s، گرفت %s' % (name, q, want, got))
        return 1 if bad else 0
    if not argv:
        print(__doc__)
        return 0
    a = answer(' '.join(argv))
    print(json.dumps(a, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
