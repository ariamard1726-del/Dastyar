"""نگهبان‌ها باید از کتابخانه بخوانند، نه از نامِ فایل.

دو بار در همین بازآرایی، یک نگهبان که فقط **یک فایل** را می‌شناخت با یک
تقسیمِ **درست** قرمز شد (`test_out_is_a_delegate` و تکه‌های `advocate_reply`).
دفعهٔ بعد هم می‌شود، مگر اینکه قاعده آزمون داشته باشد: خواندن از
`tools/library.py`، شمردنِ خط با `tools/lines.py`، و هیچ نگهبانی `open()` روی
`lib/` نزند.
"""

import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
GUARDS_DIR = os.path.join(ROOT, 'tests', 'python')

# نگهبان‌هایی که مستقیم با `lib/` کار می‌کنند.
SKIP = {'test_guards_use_library.py'}


def _guard_files():
    for name in sorted(os.listdir(GUARDS_DIR)):
        if not name.endswith('.py') or name in SKIP:
            continue
        with open(os.path.join(GUARDS_DIR, name), encoding='utf-8') as f:
            yield name, f.read()


class LawTextReaderTests(unittest.TestCase):
    """تعریفِ «ماده» یک‌جا در `tools/lawtext.py` است، نه در هر ابزار."""

    TOOLS = os.path.join(ROOT, 'tools')

    def test_only_lawtext_defines_the_article_pattern(self):
        bad = []
        for name in sorted(os.listdir(self.TOOLS)):
            if not name.endswith('.py') or name == 'lawtext.py':
                continue
            with open(os.path.join(self.TOOLS, name), encoding='utf-8') as f:
                src = f.read()
            if re.search(r'^ARTICLE\s*=', src, re.M):
                bad.append(name)
        self.assertEqual(bad, [], 'این ابزارها الگوی ماده را دوباره ساخته‌اند')

    def test_doctor_and_law_diff_read_from_lawtext(self):
        # import_law.py استثناست: متنِ خامِ چسبانده‌شده را با نشانهٔ «-» می‌خواند،
        # نه فایلِ نهایی را؛ کارش درون‌ریزی است نه بخش‌بندی.
        for name in ('doctor.py', 'law_diff.py'):
            path = os.path.join(self.TOOLS, name)
            with open(path, encoding='utf-8') as f:
                src = f.read()
            self.assertIn('from lawtext import', src,
                          '%s از خوانندهٔ مشترک استفاده نمی‌کند' % name)


class GuardHygieneTests(unittest.TestCase):
    def test_no_guard_opens_a_lib_file(self):
        """مسیرِ فایل‌های `lib/` فقط در ابزارِ مشترک باز می‌شود."""
        bad = []
        for name, src in _guard_files():
            for line in src.split('\n'):
                if 'open(' not in line:
                    continue
                # ادعا فقط دربارهٔ `lib/` است: فایل‌های داده آزادند.
                if "'lib'" in line or 'ADVOCATE_DIR' in line or \
                        "'lib/" in line:
                    bad.append('%s: %s' % (name, line.strip()[:60]))
        self.assertEqual(bad, [], 'این نگهبان‌ها خودشان فایل باز می‌کنند: %s' % bad)

    def test_part_parsing_uses_the_shared_tool(self):
        """نگهبانی که `part`ها را می‌شمارد، باید از `library` بخواند."""
        without = []
        for name, src in _guard_files():
            if "part '" not in src:
                continue
            if not re.search(r'^from library import ', src, re.M):
                without.append(name)
        self.assertEqual(without, [],
                         'این نگهبان‌ها `part` را دستی می‌خوانند: %s' % without)

    def test_class_and_extension_parsing_is_delegated(self):
        """اگر نگهبانی `class_body`/`extensions_on` دارد، باید وام‌بگیر باشد."""
        bad = []
        for name, src in _guard_files():
            for helper, target in (('_class_body', 'class_body_of('),
                                   ('_extensions_on_advocate', 'extensions_on(')):
                if 'def %s(' % helper not in src:
                    continue
                body = src[src.index('def %s(' % helper):]
                body = body[:body.index('\n\ndef ')] if '\n\ndef ' in body else body
                if target not in body:
                    bad.append('%s:%s' % (name, helper))
        self.assertEqual(bad, [], 'این کمک‌تابع‌ها منطقِ خودشان را دارند: %s' % bad)


if __name__ == '__main__':
    unittest.main()
