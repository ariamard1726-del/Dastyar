"""الگوهای فارسیِ `advocate_meta.dart` روی رشتهٔ خودِ سورس سنجیده می‌شوند.

چرا: این الگوها با `Sense.has` روی متنِ یکسان‌شده اجرا می‌شوند و بدون
Flutter/Dart در این مخزن قابل اجرا نیستند تا وقتی که CI بالا بیاید. نسخهٔ
اولِ `_lossWords` یک فاصلهٔ اضافه داشت و «سگم مرده» را نمی‌گرفت؛ همین آزمون
آن را می‌گرفت. معنای این الگوها در پایتون و دارت یکی است (بدون پرچم‌های
ویژه)، پس سنجشِ متنشان اینجا معتبر است.
"""

import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, 'lib', 'domain', 'advocate', 'advocate_meta.dart')

LB = r'(?<![\u0600-\u06FF])'
RB = r'(?![\u0600-\u06FF])'


def dart_const(name):
    """رشتهٔ یک `const String` از سورس دارت (چند تکه‌ای هم باشد)."""
    with open(SRC, encoding='utf-8') as f:
        src = f.read()
    start = src.index('const String %s =' % name)
    chunk = src[start:src.index(';', start)]
    return ''.join(re.findall(r"'([^']*)'", chunk))


class PatternTests(unittest.TestCase):
    def test_loss_words(self):
        p = dart_const('_lossWords')
        yes = [' سگم مرده ', ' پدرش فوت کرد ', ' دوستم از دست رفت ', ' سگم مرد ']
        no = [' یک مرد به من حمله کرد ', ' مردم شکایت کردند ',
              ' دارم مردد می‌شوم ', ' مرداد ماه است ']
        for t in yes:
            self.assertTrue(re.search(p, t), t)
        for t in no:
            self.assertFalse(re.search(p, t), t)

    def test_app_meta_needs_word_and_action(self):
        words = dart_const('_appWords')
        acts = dart_const('_appActs')
        history = dart_const('_historyWords')

        def is_meta(t):
            return bool(re.search(LB + '(?:' + words + ')' + RB, t)
                        and re.search(acts, t)) or bool(re.search(history, t))

        self.assertTrue(is_meta(' از برنامه خارج شدم و دوباره برگشتم '))
        self.assertTrue(is_meta(' برنامه رو بستم '))
        self.assertTrue(is_meta(' پیام‌های قبلی را نمی‌بینم '))
        # «برنامهٔ اقساط» وام است، نه برنامهٔ گوشی.
        self.assertFalse(is_meta(' برنامه اقساط وام را پرداخت نکردم '))

    def test_legal_cues_protect_real_cases(self):
        p = dart_const('_legalCues')
        for t in [' پدرم مرده و ارث داریم ', ' مستاجر پول پیش نمی‌دهد ',
                  ' کارفرما حقوق نداد ', ' چکم برگشت خورد ']:
            self.assertTrue(re.search(p, t), t)


if __name__ == '__main__':
    unittest.main()
