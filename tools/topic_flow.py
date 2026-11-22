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
FLOW = os.path.join(ROOT, 'assets', 'brain', 'topics', 'cheque.json')
GOLD = os.path.join(ROOT, 'tests', 'topics', 'cheque_gold.json')

_FIX = str.maketrans({'ي': 'ی', 'ك': 'ک', '\u200c': ' ', 'ۀ': 'ه', 'ؤ': 'و', 'أ': 'ا', 'ء': ''})
_PUNCT = re.compile(r'[،,.;:!?؟()\[\]«»"\-/]+')


def spaced(s):
    s = _PUNCT.sub(' ', s.translate(_FIX))
    return ' ' + re.sub(r'\s+', ' ', s).strip() + ' '


def _has(text, words):
    return any(spaced(w) in text for w in words)


def route(q, flow=None):
    """برگ تصمیم را برمی‌گرداند؛ ترتیب قاعده‌ها مهم است (اولین تطابق)."""
    flow = flow or load()
    text = spaced(q)
    for rule in flow['rules']:
        if 'any' in rule and _has(text, rule['any']):
            return rule['leaf']
        if 'all_groups' in rule and all(_has(text, g) for g in rule['all_groups']):
            return rule['leaf']
    return 'ask'


def load():
    with open(FLOW, encoding='utf-8') as f:
        return json.load(f)


def answer(q, flow=None):
    flow = flow or load()
    leaf_id = route(q, flow)
    leaf = flow['leaves'][leaf_id]
    refs = ['%s %s' % (a['law'], a['title']) for a in leaf['articles']]
    return {'leaf': leaf_id, 'title': leaf['title'], 'text': leaf['text'],
            'articles': refs, 'disclaimer': flow['disclaimer']}


def check():
    flow = load()
    gold = json.load(open(GOLD, encoding='utf-8'))
    bad = [(g['q'], g['leaf'], route(g['q'], flow)) for g in gold if route(g['q'], flow) != g['leaf']]
    return gold, bad


def main(argv):
    if argv and argv[0] == '--check':
        gold, bad = check()
        print('%d از %d نمونه درست است.' % (len(gold) - len(bad), len(gold)))
        for q, want, got in bad:
            print('  ✗ %s: انتظار %s، گرفت %s' % (q, want, got))
        return 1 if bad else 0
    if not argv:
        print(__doc__)
        return 0
    a = answer(' '.join(argv))
    print(json.dumps(a, ensure_ascii=False, indent=2))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
