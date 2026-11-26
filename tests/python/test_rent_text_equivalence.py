"""متنِ منتقلشدهٔ اجاره نویسهبهنویسه همان متنِ پیش از جابهجایی است.

پیش از این گام ۴۲ رشتهٔ بلند در دو فایلِ پاسخ، ۸۷ رشته و ۳۲ برچسبِ
سند در `rent_claims.dart` و ۱۳ متنِ طرحِ دعوا در `rent_plan.dart` بود.
هشِ هر جدول **قبل** از حذفشان از کد گرفته شده است؛ هر تغییر در فایلِ
JSON یا تلاش برای برگرداندن متن به دارت، قرمز میشود مگر اینکه آگاهانه
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
CLAIMS_BEFORE_SHA256 = 'abd7d7a17225bdf81e3df0ef3ba854dac2d0cf27b4254c02cb1871ec23b16041'
CLAIMS_BEFORE_COUNT = 87
FILINGS_BEFORE_SHA256 = '706c5beef307a43b879be402022533e21fbc949ebf37cd9dbb0a2dfd395325db'
FILINGS_BEFORE_COUNT = 32
FILING_CTOR_COUNT = 18
PLANS_BEFORE_SHA256 = '8840c2d49cab74044783cb2dda422ffd588f809e0420fec7dfdf51a6dd152555'
PLANS_BEFORE_COUNT = 19
RENT_PLAN_BODY_COUNT = 13
PLAN_SUFFIXES = {
    'plan0': 'moneyForum(sum)',
    'plan1': 'moneyForum(sum)',
    'plan8': '_rentPeace()',
    'plan12': 'moneyForum(sum)',
}
DART_FILES = [
    'lib/domain/advocate/topics/rent_bodies.dart',
    'lib/domain/advocate/topics/rent_bodies_landlord.dart',
    'lib/domain/advocate/topics/rent_claims.dart',
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

    def test_claims_are_identical_to_the_pre_move_source(self):
        claims = self.data['claims']
        self.assertEqual(CLAIMS_BEFORE_COUNT, len(claims))
        self.assertEqual(CLAIMS_BEFORE_SHA256, digest(claims),
                         'یک نویسه از متنِ ادعاها عوض شده است')
        self.assertFalse(set(claims) & set(self.data['texts']),
                         'شناسهٔ ادعا با شناسهٔ پاسخ تداخل دارد')

    def test_claims_have_one_delegate_each(self):
        src = read(ROOT, 'lib/domain/advocate/topics/rent_claims.dart')
        self.assertNotRegex(src, r'^const String\s+_rent\w+\s*=',
                            'متنِ ادعا دوباره به Dart برگشته است')
        ids = [i for i in re.findall(r"rentText\('([^']+)'\)", src)
               if i.startswith('claim')]
        self.assertEqual(len(ids), CLAIMS_BEFORE_COUNT)
        self.assertEqual(set(ids), set(self.data['claims']),
                         'هر شناسهٔ ادعا دقیقاً یک بار در Dart خوانده میشود')

    def test_filing_labels_are_identical_to_the_pre_move_source(self):
        filings = self.data['filings']
        self.assertEqual(FILINGS_BEFORE_COUNT, len(filings))
        self.assertEqual(FILINGS_BEFORE_SHA256, digest(filings),
                         'یک نویسه از برچسبِ سند عوض شده است')
        self.assertFalse(set(filings) & set(self.data['texts']))
        self.assertFalse(set(filings) & set(self.data['claims']))

    def test_filing_labels_have_delegates_and_no_const_filing(self):
        src = read(ROOT, 'lib/domain/advocate/topics/rent_claims.dart')
        self.assertNotIn('const Filing(', src,
                         'برچسبِ سند دوباره const در Dart شده است')
        self.assertNotRegex(src, r"Filing\(\s*'[^']+'\s*,\s*'",
                            'متنِ برچسبِ سند دوباره به Dart برگشته است')
        self.assertEqual(FILING_CTOR_COUNT, len(re.findall(r'\bFiling\(', src)))
        ids = re.findall(r"rentText\('(filing\d+_(?:chip|name))'\)", src)
        self.assertEqual(FILING_CTOR_COUNT * 2, len(ids))
        self.assertEqual(set(ids), set(self.data['filings']),
                         'هر برچسبِ سند دقیقاً از دارایی خوانده میشود')

    def test_plan_texts_are_identical_to_the_pre_move_source(self):
        plans = self.data['plans']
        self.assertEqual(PLANS_BEFORE_COUNT, len(plans))
        self.assertEqual(PLANS_BEFORE_SHA256, digest(plans),
                         'یک نویسه از متنِ طرحِ دعوا عوض شده است')
        for section in ('texts', 'claims', 'filings'):
            self.assertFalse(set(plans) & set(self.data[section]))

    def test_plan_bodies_keep_only_delegates_and_interpolations(self):
        src = read(ROOT, 'lib/domain/advocate/topics/rent_plan.dart')
        body = src.split('String _rentPlan(CaseFile f) {')[1].split(
            'String _rentEvidence')[0]
        ids = re.findall(r"rentText\('(plan\d+)'\)", body)
        self.assertEqual(RENT_PLAN_BODY_COUNT, len(ids))
        self.assertEqual(set(ids), set(list(self.data['plans'])[:RENT_PLAN_BODY_COUNT]))
        # شرطها و شناسهها کوتاهاند؛ متنِ بلند فقط در دارایی است.
        literals = re.findall(r"'((?:\\.|[^'])*)'", body)
        self.assertLessEqual(max(map(len, literals)), 16,
                             'متنِ بلند دوباره به بدنهٔ _rentPlan برگشته است')
        found = {key: (tail.strip() or None) for key, tail in re.findall(
            r"return rentText\('(plan\d+)'\)(?:\s*\+\s*([^;]+))?;", body)}
        expected = {key: PLAN_SUFFIXES.get(key) for key in list(self.data['plans'])[:RENT_PLAN_BODY_COUNT]}
        self.assertEqual(expected, found,
                         'درونیابیِ انتهایی دستنخورده بماند')
        # شش متنِ بعدی از `_rentDeadline` و `_rentRefuse`اند؛ شاخهای که
        # درونیابی در میانه دارد عمداً در Dart مانده است.
        for index in range(RENT_PLAN_BODY_COUNT, PLANS_BEFORE_COUNT):
            key = 'plan%d' % index
            self.assertEqual(1, src.count("rentText('%s')" % key))
            self.assertIn("return rentText('%s');" % key, src)
        self.assertEqual(1, src.count('${_rentPeace()}'))

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
