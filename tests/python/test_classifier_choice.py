"""تصمیمِ تک طبقهبند در اجرای واقعی: Noql مقدم است، IntentNet فقط ابزار سنجش.

شواهد تصمیم در `reports/intent_holdout.md` نگه داشته شده است: در چهار مجموعهٔ
تازه، نتیجهٔ «با IntentNet» و «بدون IntentNet» دقیقاً یکسان بود (۵/۱۱، ۶/۹،
۵/۹ و ۴/۸). پس بارگذاری ۳۴۴ کیلوبایت مدلِ دوم در هر اجرای برنامه هزای بیفایده
است. کد و مدل IntentNet حذف نشدهاند تا سنجش قابلتکرار بماند، ولی هیچ مسیرِ
اجرایی نباید آن را بار کند.
"""

import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MAIN = os.path.join(ROOT, 'lib', 'main.dart')
HOLDOUT = os.path.join(ROOT, 'reports', 'intent_holdout.md')
MODEL = os.path.join(ROOT, 'assets', 'brain', 'intent_model.json')


def _read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


class ClassifierChoiceTests(unittest.TestCase):
    def test_app_never_loads_the_second_classifier(self):
        src = _read(MAIN)
        self.assertNotIn('IntentNet.load', src,
                         'برنامه نباید مدل دوم را هنگام شروع بار کند')
        self.assertNotIn('_intentNet', src,
                         'رابط و وکیل نباید نظر دومِ طبقهبند را حمل کنند')

    def test_eval_evidence_is_kept(self):
        self.assertTrue(os.path.exists(MODEL), 'مدل سنجش حذف شد')
        report = _read(HOLDOUT)
        result = re.compile(r'\*\*نتیجه: (\d+) از (\d+) درست\.?\*\*')
        chunks = report.split('### با IntentNet')
        self.assertGreaterEqual(len(chunks), 4, 'گزارش مقایسه ناکامل است')
        pairs = []
        for before, after in zip(chunks, chunks[1:]):
            plain = result.findall(before)
            hinted = result.findall(after)
            self.assertTrue(plain and hinted, 'یکی از جفتها ناقص است')
            pairs.append((plain[-1], hinted[0]))
        self.assertGreaterEqual(len(pairs), 3)
        for plain, hinted in pairs:
            self.assertEqual(plain, hinted,
                             'مدل دوم بر نتیجهٔ سنجش اثر داشته؛ تصمیم بازبینی شود')


if __name__ == '__main__':
    unittest.main()
