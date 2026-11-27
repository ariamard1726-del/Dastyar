"""مستندِ معماری باید به فایل‌هایی اشاره کند که وجود دارند.

`docs/ARCHITECTURE.md` نقشهٔ `lib/` است و ارزشش به همین است که تازه بماند.
یک بار از کد عقب افتاد: `topics/rent.dart` را «شش تکه» می‌گفت در حالی که
سیزده تکه بود، `case_file.dart` را صاحبِ مدل‌ها می‌دانست در حالی که مدل‌ها در
`case_model.dart` رفته بودند، و شکستنِ `advocate_reply` را اصلاً نمی‌شناخت.

این آزمون سه چیز را می‌سنجد:

1. هر نامِ `*.dart` که در سند با بک‌تیک آمده، در `lib/` هست (خطی که خودش
   می‌گوید «حذف شد» یا «بازگشت» استثناست — تاریخِ آگاهانه، نه نقشهٔ کهنه).
2. فهرستِ تکه‌های `topics/rent.dart` در سند **همان** فهرستِ `part`های واقعی است.
3. شمارِ خط‌هایی که سند برای فایل‌های `lib/` می‌آورد با `dev/tools/lines.py` جور است.
"""

import glob
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))
from library import dart_files, line_count, parts_of  # noqa: E402

DOC = os.path.join(ROOT, 'docs', 'ARCHITECTURE.md')
RENT = os.path.join(ROOT, 'lib', 'domain', 'advocate', 'topics', 'rent.dart')
FA = {ord(c): str(i) for i, c in enumerate('۰۱۲۳۴۵۶۷۸۹')}

# خطی که خودش می‌گوید «این فایل دیگر نیست» تاریخ است، نه نقشهٔ کهنه.
HISTORY = ('حذف شد', 'بازگشت', 'تاریخی')


def _fa(text):
    return int(text.translate(FA))


class ArchitectureDocTests(unittest.TestCase):
    def setUp(self):
        with open(DOC, encoding='utf-8') as f:
            self.text = f.read()
        self.lines = self.text.split('\n')
        self.lib = {os.path.basename(rel) for rel in dart_files(ROOT)}

    def test_every_mentioned_file_exists(self):
        missing = []
        for no, line in enumerate(self.lines, 1):
            if any(word in line for word in HISTORY):
                continue
            for name in re.findall(r'`([\w/]+\.dart)`', line):
                # مسیرهای `test/…` و `flutter/services` فایلِ `lib/` نیستند؛
                # ادعای این آزمون فقط دربارهٔ نقشهٔ `lib/` است.
                if '/' in name or name.endswith('_test.dart'):
                    continue
                if name not in self.lib:
                    missing.append((no, name))
        self.assertEqual(missing, [],
                         'سند به فایلی اشاره می‌کند که نیست: %s' % missing)

    def test_rent_parts_match_reality(self):
        parts = parts_of(ROOT, os.path.relpath(RENT, ROOT))
        self.assertGreaterEqual(len(parts), 10, parts)
        for name in parts:
            self.assertTrue('`%s`' % name in self.text,
                            'تکهٔ %s در سندِ معماری نیست' % name)
        # و ادعای شمار («در **سیزده** تکه») باید عددِ فارسیِ همان تعداد باشد.
        claim = re.search(r'خودِ موضوع در \*\*([۰-۹]+)\*\* تکه', self.text)
        self.assertIsNotNone(claim, 'جملهٔ شمارِ تکه‌های rent پیدا نشد')
        self.assertEqual(_fa(claim.group(1)), len(parts),
                         'سند می‌گوید %s تکه، واقعیت %d تکه'
                         % (claim.group(1), len(parts)))

    def test_quoted_line_counts_are_current(self):
        # `name.dart` (۳۳۴، …) — عددِ داخلِ پرانتزِ بلافاصله بعد از نام.
        pattern = re.compile(r'`([\w/]+\.dart)`\s*\(([۰-۹]+)[،,)]')
        checked = 0
        for name, num in pattern.findall(self.text):
            base = os.path.basename(name)
            if base not in self.lib:
                continue
            rel = next(r for r in dart_files(ROOT)
                       if os.path.basename(r) == base)
            checked += 1
            self.assertEqual(line_count(ROOT, rel), _fa(num),
                             'سند برای %s نوشته %s خط' % (base, num))
        self.assertGreaterEqual(checked, 8,
                                'شمارِ خطِ کافی در سند پیدا نشد: %d' % checked)


if __name__ == '__main__':
    unittest.main()
