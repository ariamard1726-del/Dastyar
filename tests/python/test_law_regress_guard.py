"""نگهبانِ رگرسیونِ ۱۰۰٪: جدولِ رگرسیونِ پایهٔ بانک قوانین.

`test/engine/law_regress_test.dart` (دنبالهٔ `law_regress_cases.dart`) برای هر
۲۴ قانون یک مادهٔ واقعی را واکشی می‌کند و از خودِ متنِ بسته واژهٔ متمایز استخراج
می‌کند. این فایل همان قرارداد را بدون نیاز به اجرای Flutter قفل می‌کند:

۱. هر شناسهٔ ثبت‌شده در `_meta.json` در جدولِ رگرسیون هست (۲۴/۲۴)؛
۲. جدول هیچ شناسهٔ اضافی/ناشناسی ندارد؛
۳. مادهٔ هر ردیف واقعاً در فایل آن قانون بسته‌بندی‌شده وجود دارد و نوعش
   («ماده»/«اصل» برای قانون اساسی) درست است.
"""

import json
import re
import unicodedata
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

HEAD = re.compile(
    r'^(ماده|اصل)\s+[0-9۰-۹٠-٩]+(\s*مکرر(\s*[0-9۰-۹٠-٩]{1,2})?)?'
    r'(\s*\([^)\n]*\))?\s*$'
)
NUM = re.compile(r'[0-9۰-۹٠-٩]+')
FA_AR_DIGITS = '۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩'


def _en_digits(text):
    return text.translate(str.maketrans(FA_AR_DIGITS, '0123456789' * 2))


def _articles(path):
    """{(kind, number)} از سربرگ‌های قانون."""
    found = set()
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.rstrip()
            m = HEAD.match(line)
            if not m:
                continue
            kind = m.group(1)
            num = int(_en_digits(NUM.search(line).group(0)))
            found.add((kind, num))
    return found


class LawRegressGuard(unittest.TestCase):
    def setUp(self):
        self.meta = json.loads(
            (ROOT / 'assets' / 'laws' / '_meta.json').read_text(encoding='utf-8'))
        self.cases_src = (ROOT / 'test' / 'engine' / 'law_regress_cases.dart').read_text(
            encoding='utf-8')
        found = re.findall(r"LawRegressCase\('([a-z0-9_]+)',\s*([0-9]+)\)", self.cases_src)
        self.cases = [(law_id, int(n)) for law_id, n in found]

    def test_every_law_is_in_the_regression_table(self):
        ids = {law_id for law_id, _ in self.cases}
        missing = set(self.meta) - ids
        self.assertEqual(missing, set(), 'قوانین جاافتاده: %s' % sorted(missing))
        self.assertEqual(len(self.cases), 24, 'جدول باید دقیقاً ۲۴ ردیف داشته باشد')

    def test_no_unknown_law_in_the_table(self):
        unknown = {law_id for law_id, _ in self.cases} - set(self.meta)
        self.assertEqual(unknown, set(), 'شناسهٔ ناشناخته در جدول: %s' % sorted(unknown))

    def test_every_case_article_exists_with_the_right_kind(self):
        for law_id, article in self.cases:
            path = ROOT / 'assets' / 'laws' / self.meta[law_id]['path']
            arts = _articles(path)
            kind = 'اصل' if law_id == 'constitution' else 'ماده'
            self.assertIn(
                (kind, article), arts,
                '%s %s %d در متنِ بسته‌بندی‌شده نیست' % (law_id, kind, article))


if __name__ == '__main__':
    unittest.main()
