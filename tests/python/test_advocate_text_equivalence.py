"""نگهبان استخراج نثر عمومی وکیل به `assets/brain/advocate_texts.json`.

این آزمون هم‌سنگِ `test_topic_text_equivalence.py` برای ۲۱ فایلِ غیرموضوعی در
`lib/domain/advocate/*.dart` است:

1. ۱۸ بخش و ۴۷۰ کلید با هشِ قفل‌شده پیش از جابه‌جایی، بی‌تداخل و بی‌رشتهٔ خالی؛
2. مصرف ۱۰۰٪ کلیدها از طریق `advocateText` / `advocateFormat` /
   `advocateTextSeq` / `_term` / `party_` / `area_` و نبودِ شناسهٔ مجهول در کد؛
3. نبودِ نثر آزاد فارسی در کدِ ۲۱ فایلِ مهاجرت‌یافته (بجز regex، برچسب‌های
   ساختاری `AnswerCandidate`، نام‌های کوتاهِ قانون و کلیدواژه‌های داخلی)؛
4. نصب `await loadAdvocateTexts()` در `lib/main.dart` و
   `test/flutter_test_config.dart` و اتصال `loadedAdvocateTexts.values` در
   `test/advocate/advocate_test.dart`؛
5. حضور در `assets/brain/text_manifest.json` و اعتبار استنادهای `[[law:art]]`.
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

ASSET = os.path.join(ROOT, 'assets', 'brain', 'advocate_texts.json')

SECTIONS = {
    'glossary': (59, '14b2597662618b05b96f175bc92c58b8a873293fc9f7b5b2e9e0e5db8d4bdc82'),
    'phrases': (73, '9befdd80e9f469842c0f377d9cf52be95d60d2285cbf7f71691508124fd41053'),
    'constants': (12, '51ae82a9c1cc8e40e504260680add737b1a1134ef5fd2eca051b06842c33ed17'),
    'voice': (3, '23952144879564a05480fd03a46b46918b2326a6d74bb5f63f293d08e68c5f16'),
    'understanding': (11, 'c6ab5e4ae7a5bd4e383e8172cfb2b8a8a64d6ceab2b388ff834ae0b32f54e091'),
    'safety': (12, '4ebd9bfc3281e914585777d24a79289c1091ca9d9044ced79b06e30ab3e3ddc3'),
    'meta': (14, '220fc54baeb8d69ebb1f95c8079335f19e66616cf1a3647c90798d0185bb9780'),
    'talk_route': (49, 'fa635c33f73330b6212a225ce5123dcfc7316792ddf87489a0d785fc07dfa3f2'),
    'talk_reply': (37, 'eb0f9ed6258add68cef47a27fda5bee668c83beb93f22188a7ee9ea226d727fc'),
    'talk_data': (30, 'd81ac41950433960122050d87b122b73cecc879925ece450a02bac18489fce28'),
    'reply_routes': (29, '2d6d0f3af23aba339f4a2076b43e126437177c3b3ea0cb0428051f2c84491344'),
    'case_text': (24, '23c7369ce4b34473dfbd972523837c8c3614e445e6139f990d68b865ab52339e'),
    'argue': (65, 'b207849b0234d562fb09215f2860cc12e817d2c93c9bfee92f5c97798599b118'),
    'law_answer': (12, '000ab64b3f3920c75c1c6e77cc851c8ba52c28d47a7890ade3c667f7cb75b254'),
    'term_reply': (6, 'bbb12a09a92bb74caccba5efe52f775371dd3cc0593f027f920e9a3290b10f4c'),
    'guide_reply': (11, 'b7b7256aab039983965dce93f5e47cfd7e301f92fa35b5f7468f434f7567bef5'),
    'case_answer': (5, 'ce7a058d692473a18ee87e35b2d25c931b68678fc2fb69191b7c86e115c31c83'),
    'reply_pipeline': (18, '1e56ae979aee230702f27caede7ef3110c871a7b7b444ef37e8ea126c8dd51e7'),
}

MIGRATED_FILES = [
    'lib/domain/advocate/glossary.dart',
    'lib/domain/advocate/phrases.dart',
    'lib/domain/advocate/advocate_constants.dart',
    'lib/domain/advocate/reply_voice.dart',
    'lib/domain/advocate/understanding.dart',
    'lib/domain/advocate/safety_reply.dart',
    'lib/domain/advocate/advocate_meta.dart',
    'lib/domain/advocate/talk_route.dart',
    'lib/domain/advocate/talk_reply.dart',
    'lib/domain/advocate/advocate_talk.dart',
    'lib/domain/advocate/topic_picker.dart',
    'lib/domain/advocate/reply_routes.dart',
    'lib/domain/advocate/case_text.dart',
    'lib/domain/advocate/advocate_argue.dart',
    'lib/domain/advocate/law_answer.dart',
    'lib/domain/advocate/term_reply.dart',
    'lib/domain/advocate/guide_reply.dart',
    'lib/domain/advocate/case_answer.dart',
    'lib/domain/advocate/advocate_reply.dart',
    'lib/domain/advocate/advocate_reply_case.dart',
    'lib/domain/advocate/advocate_reply_guard.dart',
]

# رشته‌های فارسی غیرِ نثری که عمداً در کد مانده‌اند: نام‌های ثابت قانون،
# برچسبِ کاندیدهای داور، کلیدواژه‌های داخلی و جداکننده‌ها.
ALLOWED_NON_PROSE = {
    'دانش عمومی',
    'آیین دادرسی دادگاه',
    'مدنی',
    'قانون آیین دادرسی مدنی',
    'قانون مجازات اسلامی',
    'تعزیرات',
    'قانون مجازات اسلامی (تعزیرات)',
    'اصل',
    'ماده',
    'اصول',
    'مواد',
    'قانون اساسی',
    '، ',
    '؛ ',
    'انکار',
    'استدلالت چیه؟',
    'قدم بعدی چیست؟',
    '؟ ${_pick(Say.unknown)}.',
}


def digest(texts):
    blob = json.dumps(texts, sort_keys=True, ensure_ascii=False,
                      separators=(',', ':'))
    return hashlib.sha256(blob.encode('utf-8')).hexdigest()


def _is_non_prose_line(line):
    if any(tok in line for tok in ('|', '(?:', '(?!', '(?=', '(?<', '[^', '[0-9', '[۰-۹', 'RegExp(')):
        return True
    if re.search(r'\bSense\.(has|word|words|isQuestion)\b', line):
        return True
    if re.search(r'\bAnswerCandidate\(', line) or re.search(r"\bwhy:\s*'", line):
        return True
    if re.search(r'\b(?:_term|_ChipRule)\(', line):
        return True
    if re.search(r'^\s*static const Set<String> _(?:generic|genericLegal)\b', line) or \
            re.search(r'^\s*const Set<String> _genericLegal\b', line):
        return True
    if re.search(r'^\s*const String _(?:appWords|appActs|historyWords|legalCues|lossWords|'
                 r'goalSaid|replySaid|newMatter|hopelessPattern|entitled|howAsked|legalHint|'
                 r'rudePattern)\b', line) or \
            re.search(r'^\s*static const String _rudePattern\b', line):
        return True
    return False


def _referenced_keys(all_code):
    used = {
        k
        for k in re.findall(r"advocate(?:Text|Format)\(\s*'([^']+)'", all_code)
        if '$' not in k
    }
    for prefix, cnt in re.findall(r"advocateTextSeq\(\s*'([^']+)',\s*(\d+)\s*\)", all_code):
        for i in range(int(cnt)):
            used.add(f'{prefix}_{i}')
    for tid in re.findall(r"_term\(\s*'([^']+)'", all_code):
        used.add(f'term_{tid}_title')
        used.add(f'term_{tid}_text')
    party_block = re.search(r'_partyCues\s*=\s*\[(.*?)\];', all_code, re.S)
    if party_block:
        cues = re.findall(r"'((?:\\.|[^'])*)'", party_block.group(1))
        for i in range(len(cues)):
            used.add(f'party_{i}')
    for area_id in re.findall(r"advocateText\('area_([^']+)'\)", all_code):
        used.add(f'area_{area_id}')
    return used


class AdvocateTextEquivalenceTest(unittest.TestCase):
    def setUp(self):
        with open(ASSET, encoding='utf-8') as f:
            self.data = json.load(f)

    def test_sections_match_hashes_counts_and_disjoint_keys(self):
        self.assertEqual(self.data.get('v'), 1)
        seen = set()
        for sec, (want_n, want_sha) in SECTIONS.items():
            tbl = self.data[sec]
            self.assertEqual(len(tbl), want_n, sec)
            self.assertEqual(digest(tbl), want_sha,
                             'یک نویسه از جدول %s عوض شده است' % sec)
            self.assertTrue(all(isinstance(v, str) and v for v in tbl.values()),
                            'متن خالی در جدول %s نیست' % sec)
            self.assertFalse(seen & set(tbl), 'تداخل کلید در %s' % sec)
            seen |= set(tbl)

    def test_every_key_used_and_no_prose_left_in_migrated_files(self):
        chunks = []
        in_set = False
        for rel in MIGRATED_FILES:
            src = read(ROOT, rel)
            chunks.append(src)
            code_lines = [re.sub(r'//.*$', '', ln) for ln in src.split('\n')]
            for ln in code_lines:
                if '_generic =' in ln or '_genericLegal =' in ln or '_partyCues =' in ln:
                    in_set = True
                if in_set:
                    if '};' in ln or '];' in ln:
                        in_set = False
                    continue
                for lit in re.findall(r"'((?:\\.|[^'])*)'", ln):
                    if lit in ALLOWED_NON_PROSE:
                        continue
                    if any('\u0600' <= c <= '\u06FF' for c in lit):
                        self.assertTrue(
                            _is_non_prose_line(ln) or 'const String _' in ln or "  '" in ln and '|' in ln,
                            'نثر آزاد فارسی در %s باقی مانده است: %s' % (rel, ln.strip()),
                        )
        all_code = '\n'.join(chunks)
        used = _referenced_keys(all_code)
        defined = {
            k
            for sec, tbl in self.data.items()
            if sec != 'v'
            for k in tbl
        }
        self.assertEqual(defined - used, set(), 'کلیدهای استفاده‌نشده در دارایی')
        self.assertEqual(used - defined, set(), 'شناسه‌های مجهول در کد Dart')

    def test_placeholders_match_format_calls(self):
        tbl = {
            k: v
            for sec, d in self.data.items()
            if sec != 'v'
            for k, v in d.items()
        }
        all_code = '\n'.join(read(ROOT, rel) for rel in MIGRATED_FILES)
        ph_re = re.compile(r'\{([a-zA-Z0-9_]+)\}')

        for m in re.finditer(r"advocateText\(\s*'([^']+)'\s*\)", all_code):
            k = m.group(1)
            if '$' in k:
                continue
            self.assertEqual(ph_re.findall(tbl[k]), [],
                             f'{k} جای‌نگهدار دارد و باید با advocateFormat خوانده شود')

        fmt_re = re.compile(
            r"advocateFormat\(\s*'([^']+)'\s*,\s*\{(.*?)\}\s*,?\s*\)", re.S)
        for m in fmt_re.finditer(all_code):
            k = m.group(1)
            passed = set(re.findall(r"'([a-zA-Z0-9_]+)'\s*:", m.group(2)))
            needed = set(ph_re.findall(tbl[k]))
            self.assertEqual(passed, needed, f'ناهماهنگی جای‌نگهدار در {k}')

    def test_loader_installed_and_manifest_updated(self):
        main = read(ROOT, 'lib/main.dart')
        cfg = read(ROOT, 'test/flutter_test_config.dart')
        adv_test = read(ROOT, 'test/advocate/advocate_test.dart')
        self.assertIn('await loadAdvocateTexts()', main)
        self.assertIn('await loadAdvocateTexts()', cfg)
        self.assertIn('loadedAdvocateTexts.values', adv_test)
        with open(os.path.join(ROOT, 'assets', 'brain', 'text_manifest.json'),
                  encoding='utf-8') as f:
            manifest = json.load(f)
        self.assertIn('assets/brain/advocate_texts.json', manifest['files'])

    def test_law_citations_inside_advocate_texts_resolve(self):
        files = check_refs.law_files()
        ref_re = re.compile(r'\[\[([a-z_0-9]+):([0-9]+)(m?)\]\]')
        problems = []
        for sec, tbl in self.data.items():
            if sec == 'v':
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
