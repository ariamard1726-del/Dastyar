"""قفلِ دادهٔ راهنماها: از وقتی متن از کد بیرون رفت، این آزمون نگهبانِ متن است.

سه کار می‌کند:
  ۱. نمی‌گذارد متنِ حقوقی بی‌آنکه کسی متوجه شود عوض شود (اثرِ انگشتِ sha256).
  ۲. نمی‌گذارد کسی داده را دوباره داخلِ فایلِ Dart بنویسد.
  ۳. نمی‌گذارد فایل از `pubspec.yaml` بیفتد (که در APK نباشد و برنامه بی‌صدا
     راهنما نداشته باشد).
"""
import hashlib
import json
import os
import re
import sys
import unittest

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'dev', 'tools'))
from library import read  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

ASSET = os.path.join(ROOT, 'assets', 'brain', 'guides', 'legal_guides.json')
SOURCE = os.path.join(ROOT, 'lib', 'domain', 'lawyer', 'legal_guides.dart')
PUBSPEC = os.path.join(ROOT, 'pubspec.yaml')

# اثرِ انگشتِ متنِ راهنماها. تغییرِ عمدی؟ همین عدد را به‌روز کنید — و بدانید
# که دارید متنِ حقوقی را عوض می‌کنید.
GOLDEN_SHA256 = '7484c4253a629ab9323ecad6d4d51b892160137e14cbca9d627d9e3e3684d4f8'

ALLOWED = {'id', 'title', 'triggers', 'excludes', 'priority', 'empathy', 'brief',
           'answer', 'steps', 'cautions', 'refs', 'followUp', 'templateIds', 'notes'}
REQUIRED = ('id', 'title', 'triggers', 'empathy', 'brief', 'answer', 'followUp')


class LegalGuidesJsonTests(unittest.TestCase):
    def setUp(self):
        with open(ASSET, encoding='utf-8') as f:
            self.raw = f.read()
        self.guides = json.loads(self.raw)['guides']
        with open(SOURCE, encoding='utf-8') as f:
            self.dart = f.read()

    def test_text_has_not_drifted(self):
        digest = hashlib.sha256(self.raw.encode('utf-8')).hexdigest()
        self.assertEqual(digest, GOLDEN_SHA256,
                         'متنِ راهنماها عوض شده است؛ اگر عمدی بود اثرِ انگشت را به‌روز کنید')

    def test_data_no_longer_lives_in_dart(self):
        # تنها «LegalGuide(» باقی‌مانده سازندهٔ کلاس است؛ بارگذار در فایلِ دیگری است.
        self.assertEqual(self.dart.count("    id: '"), 0)
        self.assertEqual(self.dart.count('LegalGuide('), 1)  # فقط سازنده
        self.assertNotIn('const List<LegalGuide> legalGuides', self.dart)
        self.assertLess(len(self.dart.split('\n')), 220, 'داده دوباره در کد نوشته شد')

    def test_asset_is_bundled(self):
        with open(PUBSPEC, encoding='utf-8') as f:
            pubspec = f.read()
        self.assertIn('- assets/brain/guides/', pubspec)
        self.assertTrue(os.path.exists(ASSET))

    def test_guides_are_well_formed(self):
        self.assertEqual(len(self.guides), 34)
        ids = [g['id'] for g in self.guides]
        self.assertEqual(len(set(ids)), len(ids), 'شناسهٔ تکراری')
        for g in self.guides:
            self.assertLessEqual(set(g), ALLOWED, g['id'])
            for key in REQUIRED:
                self.assertTrue(g.get(key), '%s.%s خالی است' % (g['id'], key))
            self.assertTrue(g['triggers'], '%s: بی‌نشانه' % g['id'])
            for group in g['triggers']:
                self.assertTrue(group, '%s: گروهِ خالی' % g['id'])
            for ref in g.get('refs', []):
                self.assertEqual(set(ref), {'law', 'article'})
                self.assertTrue(re.fullmatch(r'[0-9]+', ref['article']),
                                '%s: شمارهٔ مادهٔ نامعتبر %r' % (g['id'], ref['article']))
            for note in g.get('notes', []):
                self.assertEqual(set(note), {'cues', 'text'})
                self.assertTrue(note['cues'] and note['text'])
            self.assertIsInstance(g.get('priority', 0), int)

    def test_the_app_actually_loads_them(self):
        """آزمون‌ها با config بار می‌شوند؛ برنامه باید جای خودش بار کند.

        اگر این سیم‌کشی بیفتد، همهٔ آزمون‌ها سبز می‌مانند و برنامه بی‌صدا
        راهنما ندارد — بدترین حالتِ ممکن. پس وجودش آزمون دارد.
        """
        main = read(ROOT, 'lib/main.dart')
        self.assertEqual(main.count('await loadLegalGuides();'), 1,
                         'بارگذاری راهنماها در main.dart یک جا و صریح باشد')
        self.assertIn("import 'package:dastyar/domain/lawyer/legal_guides_loader.dart';",
                      main)
        # و گرنه به فهرستِ مشکلاتِ بارگذاری اضافه می‌شود (نه سکوت).
        self.assertIn('راهنماهای آماده بار نشدند', main)

    def test_counts_match_what_the_app_had(self):
        self.assertEqual(sum(len(g.get('refs', [])) for g in self.guides), 89)
        self.assertEqual(sum(len(g.get('notes', [])) for g in self.guides), 19)
        self.assertEqual(sum(len(g.get('steps', [])) for g in self.guides), 115)
        self.assertEqual(sum(len(g.get('cautions', [])) for g in self.guides), 30)


if __name__ == '__main__':
    unittest.main()
