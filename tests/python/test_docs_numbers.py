"""عددهای مستندات باید عددهای واقعیِ کد باشند.

قاعدهٔ این مخزن («عددِ کهنه در مستندات، دروغِ آرام است») تا امروز فقط با
انضباطِ دستی رعایت می‌شد. سه سند در همان کامیتِ تغییر به‌روز می‌شوند و همین
آزمون می‌سنجد که واقعاً به‌روز شده‌اند:

1. هر ردیفِ جدولی که `` `file.dart` | **N** `` دارد: فایل زیرِ `lib/` باشد و
   شمارِ خطش دقیقاً `N` باشد.
2. هر جملهٔ «بزرگ‌ترین … `file.dart` N»: هم اندازه درست باشد، هم واقعاً
   بزرگ‌ترین فایلِ `lib/` باشد.
3. جملهٔ «هیچ فایل… بالای ۴۲۰ خط نیست»: بزرگ‌ترین فایل از سقف نگذرد.

عددها در مستندات فارسی نوشته می‌شوند؛ پس ارقامِ فارسی هم خوانده می‌شوند.
"""

import glob
import os
import re
import sys
import unittest

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'tools'))
from library import dart_files, line_count  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOCS = [
    os.path.join(ROOT, 'docs', 'GOD_OBJECTS.md'),
    os.path.join(ROOT, 'docs', 'CODE_REVIEW.md'),
    os.path.join(ROOT, 'README.md'),
    os.path.join(ROOT, 'docs', 'PHASES.md'),
]
LIMIT = 420

FA = {ord(c): str(i) for i, c in enumerate('۰۱۲۳۴۵۶۷۸۹')}


def _fa_to_int(text):
    return int(text.translate(FA))


def _lines(path):
    return line_count(path)


def _doc_lines():
    for path in DOCS:
        with open(path, encoding='utf-8') as f:
            for no, line in enumerate(f, 1):
                yield path, no, line


class DocsNumberTests(unittest.TestCase):
    def setUp(self):
        # ادعاهای مستندات با نامِ فایل نوشته می‌شوند، نه مسیر.
        self.sizes = {os.path.basename(rel): line_count(ROOT, rel)
                      for rel in dart_files(ROOT)}
        self.largest = max(self.sizes.items(), key=lambda kv: kv[1])

    def _size(self, name):
        self.assertIn(name, self.sizes,
                      'مستندات از فایلی حرف می‌زنند که در `lib/` نیست: %s' % name)
        return self.sizes[name]

    def test_table_rows_quote_real_sizes(self):
        """`| `x.dart` | **N** |` یعنی «این فایل الان N خط است»."""
        row = re.compile(r'\|\s*`([\w/]+\.dart)`\s*\|\s*\*\*([۰-۹]+)\*\*\s*\|')
        checked = 0
        for path, no, line in _doc_lines():
            m = row.search(line)
            if not m:
                continue
            name = os.path.basename(m.group(1))
            want = _fa_to_int(m.group(2))
            got = self._size(name)
            checked += 1
            self.assertEqual(
                got, want,
                '%s:%d می‌گوید %s برابرِ %d خط است، ولی %d خط است'
                % (os.path.relpath(path, ROOT), no, name, want, got))
        self.assertGreaterEqual(checked, 12, 'ردیفِ عدددارِ کافی پیدا نشد')

    def test_largest_file_claim_is_true(self):
        """«بزرگ‌ترین فایل `x.dart` N است» باید هم درست باشد هم واقعاً بزرگ‌ترین."""
        claim = re.compile(r'بزرگ‌ترین[^\n`]*`([\w/]+\.dart)`\s*([۰-۹]+)')
        checked = 0
        for path, no, line in _doc_lines():
            for m in claim.finditer(line):
                name = os.path.basename(m.group(1))
                want = _fa_to_int(m.group(2))
                checked += 1
                self.assertEqual(
                    self._size(name), want,
                    '%s:%d اندازهٔ %s را %d نوشته، ولی %d است'
                    % (os.path.relpath(path, ROOT), no, name, want,
                       self._size(name)))
                self.assertEqual(
                    name, self.largest[0],
                    '%s:%d می‌گوید بزرگ‌ترین %s است، ولی بزرگ‌ترین %s با %d خط است'
                    % (os.path.relpath(path, ROOT), no, name, self.largest[0],
                       self.largest[1]))
        self.assertGreater(checked, 0, 'ادعای «بزرگ‌ترین» پیدا نشد')

    def test_ceiling_claim_matches_reality(self):
        """«هیچ فایل… بالای ۴۲۰ خط نیست» یک ادعای عددی است، نه آرزو."""
        over = {k: v for k, v in self.sizes.items() if v > LIMIT}
        self.assertEqual(over, {},
                         'مستندات می‌گویند هیچ فایلی بالای %d نیست' % LIMIT)
        self.assertLessEqual(self.largest[1], LIMIT)


if __name__ == '__main__':
    unittest.main()
