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
        ref_re = re.compile(r'\[\[([a-z_]+):([0-9]+)\]\]')
        problems = []
        for path in (ASSET, RENT_ASSET):
            with open(path, encoding='utf-8') as f:
                data = json.load(f)
            for sec, tbl in data.items():
                if sec == 'v' or not isinstance(tbl, dict):
                    continue
                for k, v in tbl.items():
                    for law_key, art in ref_re.findall(str(v)):
                        if law_key not in files:
                            problems.append(f'{sec}.{k}: کلید ناشناخته {law_key}')
                            continue
                        word = 'اصل' if law_key == 'constitution' else 'ماده'
                        text = files[law_key].read_text(encoding='utf-8')
                        if not check_refs.article_exists(text, art, word):
                            problems.append(f'{sec}.{k}: {word} {art} در {law_key}')
        self.assertEqual(problems, [])


if __name__ == '__main__':
    unittest.main()
