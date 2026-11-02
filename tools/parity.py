"""تولید استاندارد طلایی برابری (parity) بین آینهٔ پایتون و موتور دارت.

خروجی: brain/parity_expected.json — فایل ثبت‌شده در ریپو که تست دارت
(test/core/parity_test.dart) خروجی سمت دارت را با آن مقایسه می‌کند.
هر دو سمت از یک داده می‌خوانند، پس اگر آینهٔ پایتون یا موتور دارت
بدون به‌روزرسانی دیگری تغییر کند، CI شکست می‌خورد.

بخش‌ها:
  normalize/collapse/phrase/tokenize — لایهٔ متن (brain/common.py + tools/eval_py.py ↔ lib/core/persian_text.dart)
  conflicts — زنجیرهٔ تضادها (brain/engine.py ↔ ConflictsService)
  rank — top-3 بازیابی برای پرسش‌های brain/eval/eval.txt (tools/eval_py.py ↔ KnowledgeEngine)

اجرا:
  python3 tools/parity.py           # بررسی تازگی (خروج ۱ اگر کهنه است)
  python3 tools/parity.py --write   # بازتولید استاندارد طلایی
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'brain'))
sys.path.insert(0, os.path.join(ROOT, 'tools'))

import engine as brain_engine  # noqa: E402
from common import normalize  # noqa: E402
from eval_py import Engine, collapse, phrase, tok  # noqa: E402

OUT = os.path.join(ROOT, 'brain', 'parity_expected.json')

# نمونه‌هایی که لایهٔ متن هر دو زبان باید دقیقاً یکسان پردازند.
TEXT_SAMPLES = [
    'ماده ۱۰ قانون مدنی',
    'مادهٔ 13 قانون صدور چک',
    'قرارداد اجاره با دو شاهد',
    'مي‌توانم وكالت بگيرم؟',
    'كِتاب‌ها و دفترهاي قديمي',
    'حکم غیابی علیه من صادر شده چه کار کنم؟',
    'چک برگشتی ۰۲۱-۸۸۷۷۶۶۵۵',
    'اصل ۳۵ قانون اساسی',
    'ماده 21 مکرر قانون صدور چک',
    'مهریه‌ام را نمی‌دهد',
    'کارفرما اخراجم کرده و بیمه رد نکرده',
    'تخلیهٔ فوری خانهٔ اجاره‌ای',
    '  فاصله‌های   اضافه\t و نیم‌فاصله‌ی  مستمر  ',
    'طلاق توافقی چقدر طول می‌کشد',
    'دية و ارش و تعزیرات',
    'پیش‌قرارداد فروش آپارتمان (کد رهگیری ۱۲۳۴۵۶)',
    'English mixed متن 42 با عدد',
    'نيم‌فاصله: مي‌شود يا نمي‌شود؟',
    'مواد ۱ تا ۳ قانون تجارت',
    'لایحه اصلاحی قسمتی از قانون تجارت',
]


def text_section():
    out = []
    for s in TEXT_SAMPLES:
        out.append({
            'in': s,
            'normalize': normalize(s),
            'collapse': collapse(normalize(s)),
            'phrase': phrase(s),
            'tok': tok(s),
        })
    return out


def conflicts_section():
    data = brain_engine.load_data()
    if data is None:
        raise SystemExit('خطا: relationships.json خوانده نشد')
    out = {}
    for aid in sorted(data.get('articles', {}), key=lambda x: str(x)):
        out[str(aid)] = brain_engine.find_conflicts(str(aid), data)
    return out


def rank_section():
    eng = Engine()
    path = os.path.join(ROOT, 'brain', 'eval', 'eval.txt')
    queries = []
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            queries.append(line.split('|')[0].strip())
    out = []
    for q in queries:
        hits = eng.rank(q)
        top = [[h[0]['law'], h[0]['title']] for h in hits[:3]]
        out.append({'q': q, 'top': top})
    return out


def build():
    doc = {
        'version': 1,
        'text': text_section(),
        'conflicts': conflicts_section(),
        'rank': rank_section(),
    }
    return json.dumps(doc, ensure_ascii=False, indent=1, sort_keys=True) + '\n'


def main():
    want = build()
    have = ''
    if os.path.isfile(OUT):
        with open(OUT, encoding='utf-8') as f:
            have = f.read()
    if have == want:
        n = json.loads(want)
        print('parity: استاندارد طلایی تازه است (text=%d conflicts=%d rank=%d).'
              % (len(n['text']), len(n['conflicts']), len(n['rank'])))
        return 0
    if '--write' not in sys.argv:
        print('خطا: brain/parity_expected.json با خروجی آینهٔ پایتون نمی‌خواند.')
        print('اگر تغییر آینهٔ پایتون عمدی است: python3 tools/parity.py --write')
        print('و سپس test/core/parity_test.dart را در CI بررسی کنید (سمت دارت باید هم‌تراز شود).')
        return 1
    with open(OUT, 'w', encoding='utf-8') as f:
        f.write(want)
    print('parity: brain/parity_expected.json بازنویسی شد.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
