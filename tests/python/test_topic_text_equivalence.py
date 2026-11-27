"""متنِ منتقلشدهٔ موضوعهای غیرِاجاره نویسهبهنویسه همان متنِ پیش از جابهجایی است.

این آزمون معادلِ `test_rent_text_equivalence.py` برای موضوعهای مشترک،
کار و خانواده در `assets/brain/topic_texts.json` است: هشِ هر جدول پیش از
حذف از کد قفل شده و نبودِ متنِ آزادِ فارسی در فایلهای Dart مهاجرتیافته،
مصرف کامل کلیدها، نصب در `main` و `flutter_test_config.dart` و صحت
همهٔ استنادهای `[[کلید:شماره]]` در داده را وارسی میکند.
"""

import hashlib
import json
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))
import check_refs  # noqa: E402
from library import read  # noqa: E402

ASSET = os.path.join(ROOT, 'assets', 'brain', 'topic_texts.json')
RENT_ASSET = os.path.join(ROOT, 'assets', 'brain', 'topics', 'rent_texts.json')

SECTIONS = {
    'shared': (9, '5ccecb9456e17db0d686680ca3963adaf54d92a2b7a4706227b78369c68c3e79', [
        'lib/domain/advocate/topics/shared.dart',
    ]),
    'labor': (182, '193f1fe70541c09df6208ec5ffa86d02140d915beb1fddad4ed1ac1ee770f5e6', [
        'lib/domain/advocate/topics/labor_patterns.dart',
        'lib/domain/advocate/topics/labor_claims.dart',
        'lib/domain/advocate/topics/labor_bodies.dart',
        'lib/domain/advocate/topics/labor_issues.dart',
    ]),
    'family': (99, 'caf0e4258cd27baf2debc786c66204978927e77d243588fb226fa4e62fa04e50', [
        'lib/domain/advocate/topics/family_patterns.dart',
        'lib/domain/advocate/topics/family_claims.dart',
        'lib/domain/advocate/topics/family_bodies.dart',
        'lib/domain/advocate/topics/family_issues.dart',
    ]),
    'accused': (65, '640ddd3422c0ddb1bb04f7c0990969fc7c926c73bb049a5760b26978535ef37f', ['lib/domain/advocate/topics/accused.dart']),
    'admin': (17, '3d2dd59bf43f229cb33a088b32ebec29fb6fbcef18e9160eefb484ed83b316ce', ['lib/domain/advocate/topics/admin.dart']),
    'cheque': (76, '321275df2fb71caae05ffe49c17ef3fa8a95a12eeb1bc4f85999adc83be4857c', ['lib/domain/advocate/topics/cheque.dart']),
    'child': (42, '704dd86723b94edb523ff4e9af235257b6ee19769ec2ca5cf7d794a8370da68c', ['lib/domain/advocate/topics/child.dart']),
    'company': (42, 'f0b476f2524a45919b07cbdb1469ebb259ce6c919916829a11553a3e671d0991', ['lib/domain/advocate/topics/company.dart']),
    'consumer': (47, '9d01aee8562360e288f11b1d54574ee6ca519429332c929951118c6bb269f808', ['lib/domain/advocate/topics/consumer.dart']),
    'cyber': (56, '49ff6697fea744f0100b67902527eba06da8e144ec2381e930eec0dd2dced7ce', ['lib/domain/advocate/topics/cyber.dart']),
    'debt': (66, '54a6c710de7ead141a7eb3c02a65c0f68be5023bcfd79a79c6ebf7b8a4b212a5', ['lib/domain/advocate/topics/debt.dart']),
    'enforce': (48, '7785ece7ae4163355ed38a5f5b1da4759024a88366dec02552de469403b47f3a', ['lib/domain/advocate/topics/enforce.dart']),
    'fight': (21, '736e45afdfd783d0d1f172e0e4890377c69b4a8d7eb4cf2df269c374b193a5bd', ['lib/domain/advocate/topics/fight.dart']),
    'foreign_contract': (16, '333a957a114a1b5d8b9209acaf86357c6adbd2f1546ade17a86a8a412876eac8', ['lib/domain/advocate/topics/foreign_contract.dart']),
    'guarantee': (33, '7ce828f390a1822938ebeb6e0ba46323f961dc2c545fed73c59ebfbf2b666078', ['lib/domain/advocate/topics/guarantee.dart']),
    'inherit': (51, '603e2009044a81bd27820ab89f6d63001cb0480b6ba2b1a6ccb920c4dad7814f', ['lib/domain/advocate/topics/inherit.dart']),
    'injury': (57, '4590918c2511323f8351905c533ca34865467bb904211c7e996c150fad4dd86e', ['lib/domain/advocate/topics/injury.dart']),
    'marriage': (16, 'd42a41e6893addbc5c3e975c7cefb7e05e6c47626d3887e55dc2f473651ab9f8', ['lib/domain/advocate/topics/marriage.dart']),
    'minor_sale': (14, '4232329a9f9bf35eb2ee040563744f5add1282d76b95d73897cab7f3e78fd2ce', ['lib/domain/advocate/topics/minor_sale.dart']),
    'neighbor': (23, '67d8d8b32a96726d51a9c1853ea81716258c9c40ee825bb247cda297bcb7a3d6', ['lib/domain/advocate/topics/neighbor.dart']),
    'partner': (42, 'e7248b797d8851eeda2bbc8b82eafbe26edae00ef38712b09c6d97466184a271', ['lib/domain/advocate/topics/partner.dart']),
    'property': (56, '6fee2b0a8984e9370458469d982ede3df4ce3ab08bf996f35ddfd0c5ac67606d', ['lib/domain/advocate/topics/property.dart']),
    'sale': (14, 'f8a6565628d7556aaa2c6701512f35a999ea54a72a544401628eb466573b1ad7', ['lib/domain/advocate/topics/sale.dart']),
    'theft': (14, 'e0705a645f3422f01d7686ae45ca0662bd026559c021050bdfb87b4580ba6072', ['lib/domain/advocate/topics/theft.dart']),
}


def digest(texts):
    blob = json.dumps(texts, sort_keys=True, ensure_ascii=False,
                      separators=(',', ':'))
    return hashlib.sha256(blob.encode('utf-8')).hexdigest()


def _is_regex_line(line):
    if any(tok in line for tok in ('|', '(?:', '(?!', '(?=', '[^', '[0-9')):
        return True
    if re.search(r'\b(cues|anti)\s*:', line):
        return True
    if re.search(r'\bSense\.(has|yn|rx|numberBefore|words)\b', line):
        return True
    if re.search(r'^\s*const String _\w+(?:Re|Unpaid)\b', line):
        return True
    if re.search(r"^\s*'[^{}\n]+':\s*\d", line):
        return True
    return False


class TopicTextEquivalenceTest(unittest.TestCase):
    def setUp(self):
        with open(ASSET, encoding='utf-8') as f:
            self.data = json.load(f)

    def test_sections_match_pre_move_hashes_and_counts(self):
        self.assertEqual(self.data.get('v'), 1)
        seen = set()
        for sec, (want_n, want_sha, _) in SECTIONS.items():
            tbl = self.data[sec]
            self.assertEqual(len(tbl), want_n, sec)
            self.assertEqual(digest(tbl), want_sha,
                             'یک نویسه از جدول %s عوض شده است' % sec)
            self.assertTrue(all(isinstance(v, str) and v for v in tbl.values()),
                            'متن خالی در جدول %s نیست' % sec)
            self.assertFalse(seen & set(tbl), 'تداخل کلید در %s' % sec)
            seen |= set(tbl)

    def test_dart_files_keep_no_prose_and_use_every_key(self):
        for sec, (_, _, files) in SECTIONS.items():
            used = []
            for rel in files:
                src = read(ROOT, rel)
                code_lines = [re.sub(r'//.*$', '', ln) for ln in src.split('\n')]
                for ln in code_lines:
                    for lit in re.findall(r"'((?:\\.|[^'])*)'", ln):
                        if any('\u0600' <= c <= '\u06FF' for c in lit):
                            self.assertTrue(
                                _is_regex_line(ln),
                                'متن آزاد فارسی در %s باقی مانده است: %s' % (rel, ln.strip()),
                            )
                used.extend(re.findall(r"topicText\('([^']+)'\)", '\n'.join(code_lines)))
            self.assertEqual(set(used), set(self.data[sec]),
                             'کلید بدون استفاده یا گمشده در بخش %s' % sec)

    def test_loader_is_installed_before_any_reply(self):
        main = read(ROOT, 'lib/main.dart')
        cfg = read(ROOT, 'test/flutter_test_config.dart')
        self.assertIn('await loadTopicTexts()', main)
        self.assertIn('await loadTopicTexts()', cfg)

    def test_asset_is_hashed_by_the_text_guard(self):
        with open(os.path.join(ROOT, 'assets', 'brain', 'text_manifest.json'),
                  encoding='utf-8') as f:
            manifest = json.load(f)
        self.assertIn('assets/brain/topic_texts.json', manifest['files'])

    def test_law_citations_inside_text_assets_resolve(self):
        files = check_refs.law_files()
        ref_re = re.compile(r'\[\[([a-z_0-9]+):([0-9]+)(m?)\]\]')
        problems = []
        for path in (ASSET, RENT_ASSET):
            with open(path, encoding='utf-8') as f:
                data = json.load(f)
            for sec, tbl in data.items():
                if sec == 'v' or not isinstance(tbl, dict):
                    continue
                for k, v in tbl.items():
                    for law_key, art, mok in ref_re.findall(str(v)):
                        if law_key not in files:
                            problems.append(f'{sec}.{k}: کلید ناشناخته {law_key}')
                            continue
                        word = 'اصل' if law_key == 'constitution' else 'ماده'
                        num = f'{art} مکرر' if mok == 'm' else art
                        text = files[law_key].read_text(encoding='utf-8')
                        if not check_refs.article_exists(text, num, word):
                            problems.append(f'{sec}.{k}: {word} {num} در {law_key}')
        self.assertEqual(problems, [])


if __name__ == '__main__':
    unittest.main()
