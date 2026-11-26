"""متنِ منتقلشدهٔ اجاره نویسهبهنویسه همان متنِ پیش از جابهجایی است.

پیش از این گام ۴۲ رشتهٔ بلند بهصورت `const String` در دو فایلِ دارت بود.
هشِ زیر از همان رشتهها **قبل** از حذفشان از کد گرفته شده است؛ هر تغییر در
فایلِ JSON یا تلاش برای برگرداندن متن به دارت، قرمز میشود مگر اینکه آگاهانه
هشِ تازه در این آزمون نوشته شود.
"""

import glob
import hashlib
import json
import os
import re
import unittest

import sys
sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'dev', 'tools'))
from library import read  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ASSET = os.path.join(ROOT, 'assets', 'brain', 'topics', 'rent_texts.json')
BEFORE_SHA256 = '60f7d07b5579bb669fd1faef1824a3c68a2ba8139ef6fe06716b328646248f2e'
BEFORE_COUNT = 42
DART_FILES = [
    'lib/domain/advocate/topics/rent_bodies.dart',
    'lib/domain/advocate/topics/rent_bodies_landlord.dart',
]


def digest(texts):
    blob = json.dumps(texts, sort_keys=True, ensure_ascii=False,
                      separators=(',', ':'))
    return hashlib.sha256(blob.encode('utf-8')).hexdigest()


class RentTextEquivalenceTest(unittest.TestCase):
    def setUp(self):
        with open(ASSET, encoding='utf-8') as f:
            self.data = json.load(f)

    def test_texts_are_identical_to_the_pre_move_source(self):
        self.assertEqual(self.data.get('v'), 1)
        texts = self.data['texts']
        self.assertEqual(len(texts), BEFORE_COUNT)
        self.assertEqual(digest(texts), BEFORE_SHA256,
                         'یک نویسه از متنِ اجاره عوض شده است')

    def test_dart_keeps_only_delegates_not_a_second_copy(self):
        all_src = ''
        for rel in DART_FILES:
            with open(os.path.join(ROOT, rel), encoding='utf-8') as f:
                src = f.read()
            self.assertNotRegex(src, r'^const String\s+_rent\w+\s*=',
                                '%s دوباره متن را به خود گرفته است' % rel)
            all_src += src
        for key in self.data['texts']:
            self.assertIn("String _%s() => rentText('%s');" % (key, key), all_src,
                          'پوستهٔ متنِ %s در Dart نیست' % key)

    def test_loader_is_installed_before_any_reply(self):
        main = read(ROOT, 'lib/main.dart')
        with open(os.path.join(ROOT, 'test', 'flutter_test_config.dart'),
                  encoding='utf-8') as f:
            config = f.read()
        self.assertIn('await loadRentTexts()', main)
        self.assertIn('await loadRentTexts()', config)

    def test_topic_assets_have_exactly_two_contracts(self):
        # تصمیمِ نهایی فاز ۱: دو قراردار جدا، نه حالتِ میانه. `index.json`
        # فقط مسیرهای تصمیم (topic flow) را فهرست میکند و متنِ ثابت اجاره
        # قراردادِ خودش را دارد. هیچ فایلِ یتیمی در این فهرست نماند.
        with open(os.path.join(ROOT, 'assets', 'brain', 'topics', 'index.json'),
                  encoding='utf-8') as f:
            flows = set(json.load(f)['topics'])
        files = {os.path.basename(p)
                 for p in glob.glob(os.path.join(ROOT, 'assets', 'brain',
                                                 'topics', '*.json'))}
        expected = flows | {'index.json', 'rent_texts.json'}
        self.assertEqual(files, expected,
                         'فایلِ_topic ناشناخته: %s' % sorted(files - expected))
        self.assertNotIn('rent_texts.json', flows,
                         'متنِ ثابت نباید در فهرستِ تصمیمگیرها باشد')

    def test_asset_is_hashed_by_the_text_guard(self):
        with open(os.path.join(ROOT, 'assets', 'brain', 'text_manifest.json'),
                  encoding='utf-8') as f:
            manifest = json.load(f)
        self.assertIn('assets/brain/topics/rent_texts.json',
                      manifest['files'])


if __name__ == '__main__':
    unittest.main()
