"""نگهبانِ اعلامیهٔ «تائیدنشده» بودنِ کلیهٔ قوانین.

برنامه اعلام می‌کند هیچ‌کدام از ۲۴ قانون و موادشان با منبع رسمی تطبیق داده
نشده‌اند و برنامه هیچ مسئولیتی دربارهٔ صحت مفاد آن‌ها برعهده نمی‌گیرد.
این فایل آن قرارداد را به‌صورت مکانیزه نگه می‌دارد:

۱. متنِ دقیقِ اعلامیه فقط در `lib/core/legal_disclaimer.dart` تعریف می‌شود
   (منبعِ یگانه) و هر مصرف‌کنندهٔ دیگر (قانون‌متن چت، کپی ماده/کل قانون،
   دراور فهرست قوانین، صفحهٔ «دربارهٔ داده‌ها» و README) همان متن را
   استفاده/نمایش می‌کند؛
۲. همهٔ ۲۴ قانون در `_meta.json` وضعیت `unverified` دارند.
"""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DECL = ROOT / 'lib' / 'core' / 'legal_disclaimer.dart'


def _disclaimer():
    src = DECL.read_text(encoding='utf-8')
    m = re.search(r"const String legalDisclaimer =\s*'(.*?)';", src, re.S)
    if not m:
        raise AssertionError('در %s ثابت legalDisclaimer پیدا نشد' % DECL)
    return m.group(1)


class LegalDisclaimerTests(unittest.TestCase):
    def test_disclaimer_mentions_the_official_registry(self):
        text = _disclaimer()
        self.assertIn('سامانه قوانین و مقررات جمهوری اسلامی ایران', text)
        self.assertIn('تائید نمی کند', text)
        self.assertIn('تائید نشده', text)

    def test_all_laws_are_declared_unverified(self):
        meta = json.loads(
            (ROOT / 'assets' / 'laws' / '_meta.json').read_text(encoding='utf-8'))
        self.assertEqual(len(meta), 24)
        verified = [k for k, v in meta.items()
                    if str(v.get('status', '')).strip() == 'verified']
        self.assertEqual(verified, [], 'قوانین تأییدشدهٔ غیرمنتظره: %s' % verified)

    def test_law_text_in_chat_appends_it(self):
        src = (ROOT / 'lib' / 'core' / 'law_text.dart').read_text(encoding='utf-8')
        self.assertIn('legalDisclaimer', src)

    def test_copy_paths_include_it(self):
        src = (ROOT / 'lib' / 'ui' / 'laws_library.dart').read_text(encoding='utf-8')
        self.assertIn('legalDisclaimer', src)
        self.assertIn('copyText', src)
        self.assertIn('fullCopyText', src)

    def test_laws_drawer_shows_it(self):
        src = (ROOT / 'lib' / 'ui' / 'laws_drawer.dart').read_text(encoding='utf-8')
        self.assertIn('legalDisclaimer', src)

    def test_about_page_shows_it(self):
        src = (ROOT / 'lib' / 'ui' / 'about_page.dart').read_text(encoding='utf-8')
        self.assertIn('legalDisclaimer', src)

    def test_readme_announces_it(self):
        readme = (ROOT / 'README.md').read_text(encoding='utf-8')
        self.assertIn(_disclaimer(), readme)


if __name__ == '__main__':
    unittest.main()
