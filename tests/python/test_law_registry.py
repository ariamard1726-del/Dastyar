"""آزمون شناسنامهٔ منبع قوانین: فیلدهای لازم، اثر انگشت، وضعیت و مقایسهٔ متن."""

import contextlib
import copy
import datetime
import io
import json
import os
from pathlib import Path
import tempfile
import unittest

from tools import law_registry as registry

ROOT = Path(__file__).resolve().parents[2]

BUNDLED = """# قانون نمونه

## فصل اول - کلیات

ماده 1
هر کس مالک چیزی باشد می‌تواند در آن تصرف کند.
تبصره - این حکم استثنا دارد.

ماده 2
مهلت اعتراض بیست روز است.

ماده 2 مکرر
حکم این ماده موقت است.
"""

OFFICIAL_SAME = """قانون نمونه
فصل اول - کليات
ماده ۱ ـ هر كس مالك چيزي باشد مي تواند در آن تصرف كند.
تبصره ـ اين حكم استثنا دارد.
ماده ۲ ) مهلت اعتراض بيست روز است.
ماده ۲ مکرر - حكم اين ماده موقت است.
"""


def entry(path, **over):
    e = {
        'title': 'قانون نمونه',
        'source': 'سامانه ملی قوانین و مقررات جمهوری اسلامی ایران',
        'url': 'https://qavanin.ir/Law/TreeText/1',
        'date': '۱۴۰۵/۰۸/۱۰',
        'amended': '۱۴۰۳/۰۳/۳۰',
        'articles': 3,
        'path': os.path.basename(path),
        'sha256': registry.sha256_of(path),
        'status': 'verified',
    }
    e.update(over)
    return e


class CompareTest(unittest.TestCase):
    def test_reads_both_layouts(self):
        ours = registry.parse_articles(BUNDLED)
        theirs = registry.parse_articles(OFFICIAL_SAME)
        self.assertEqual([k for k, _ in ours], ['ماده 1', 'ماده 2', 'ماده 2 مکرر'])
        self.assertEqual([k for k, _ in ours], [k for k, _ in theirs])

    def test_orthography_is_ignored_but_words_are_not(self):
        self.assertTrue(registry.is_identical(registry.compare(BUNDLED, OFFICIAL_SAME)))
        changed = OFFICIAL_SAME.replace('بيست روز', 'ده روز')
        result = registry.compare(BUNDLED, changed)
        self.assertFalse(registry.is_identical(result))
        self.assertEqual([d['key'] for d in result['different']], ['ماده 2'])

    def test_missing_and_extra_articles_are_reported(self):
        shorter = OFFICIAL_SAME.split('ماده ۲ مکرر')[0]
        result = registry.compare(BUNDLED, shorter)
        self.assertEqual(result['extra'], ['ماده 2 مکرر'])
        longer = OFFICIAL_SAME + 'ماده ۳ - حکم تازه.\n'
        result = registry.compare(BUNDLED, longer)
        self.assertEqual(result['missing'], ['ماده 3'])
        self.assertFalse(registry.is_identical(result))

    def test_empty_official_text_never_passes(self):
        self.assertFalse(registry.is_identical(registry.compare(BUNDLED, 'متن بی‌ماده')))

    def test_repeated_numbering_gets_distinct_keys(self):
        keys = [k for k, _ in registry.parse_articles('ماده 1 - الف\nماده 1 - ب\n')]
        self.assertEqual(keys, ['ماده 1', 'ماده 1 #2'])

    def test_glued_article_is_detected(self):
        text = '# ق\n\nماده 71\nمتن.\nماده ۷۲ (اصلاحی) - متن دیگر.\n\nماده 73\nمتن.\n'
        self.assertEqual(registry.glued_articles(text), [('ماده 71', 'ماده 72')])


class ValidateTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.path = os.path.join(self.dir.name, 'law.txt')
        Path(self.path).write_text(BUNDLED, encoding='utf-8')

    def errors(self, **over):
        meta = {'law': entry(self.path, **over)}
        return registry.validate(meta, self.dir.name)[0]

    def test_complete_verified_entry_passes(self):
        self.assertEqual(self.errors(), [])

    def test_every_required_field_is_enforced(self):
        for key in registry.REQUIRED:
            meta = {'law': entry(self.path)}
            del meta['law'][key]
            errors = registry.validate(meta, self.dir.name)[0]
            self.assertTrue(errors, 'نبود %s باید خطا باشد' % key)
            self.assertIn(key, errors[0])

    def test_changed_text_breaks_the_fingerprint(self):
        meta = {'law': entry(self.path)}
        Path(self.path).write_text(BUNDLED + '\nماده 3\nتازه.\n', encoding='utf-8')
        errors = registry.validate(meta, self.dir.name)[0]
        self.assertTrue(any('sha256' in e for e in errors))

    def test_latin_digit_dates_are_rejected(self):
        self.assertTrue(any('date' in e for e in self.errors(date='1405/08/10')))
        self.assertTrue(any('amended' in e for e in self.errors(amended='1403/03/30')))

    def test_verified_needs_an_official_https_url(self):
        self.assertTrue(self.errors(url=''))
        self.assertTrue(self.errors(url='http://qavanin.ir/Law/TreeText/1'))
        self.assertTrue(self.errors(url='https://www.ekhtebar.ir/x'))
        self.assertTrue(self.errors(url='https://qavanin.ir.example.com/x'))
        self.assertEqual(self.errors(url='https://www.qavanin.ir/Law/TreeText/1'), [])

    def test_ekhtebar_can_never_be_verified(self):
        self.assertTrue(self.errors(source='پایگاه قوانین و مقررات اختبار'))

    def test_unverified_is_a_warning_unless_required(self):
        meta = {'law': entry(self.path, status='unverified', url='')}
        errors, warnings, verified = registry.validate(meta, self.dir.name)
        self.assertEqual((errors, len(warnings), verified), ([], 1, 0))
        errors = registry.validate(meta, self.dir.name, require_verified=True)[0]
        self.assertEqual(len(errors), 1)

    def test_unknown_status_is_rejected(self):
        self.assertTrue(self.errors(status='ok'))


class VerifyCommandTest(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.law = os.path.join(self.dir.name, 'law.txt')
        Path(self.law).write_text(BUNDLED, encoding='utf-8')
        self.meta = os.path.join(self.dir.name, '_meta.json')
        start = {'law': entry(self.law, status='unverified', url='',
                              source='روزنامه رسمی / پایگاه قوانین و مقررات اختبار',
                              note='ثبت دسته‌ای')}
        Path(self.meta).write_text(json.dumps(start, ensure_ascii=False), encoding='utf-8')
        self.raw = os.path.join(self.dir.name, 'raw.txt')
        self.saved = (registry.LAWS_DIR, registry.META)
        registry.LAWS_DIR, registry.META = self.dir.name, self.meta
        self.addCleanup(self.restore)

    def restore(self):
        registry.LAWS_DIR, registry.META = self.saved

    def run_verify(self, raw_text, url='https://qavanin.ir/Law/TreeText/1'):
        Path(self.raw).write_text(raw_text, encoding='utf-8')
        with contextlib.redirect_stdout(io.StringIO()):
            code = registry.main(['verify', 'law', '--url', url, '--raw', self.raw,
                                  '--amended', '1403/03/30', '--date', '1405/08/22'])
        return code, json.loads(Path(self.meta).read_text(encoding='utf-8'))['law']

    def test_identical_text_becomes_verified(self):
        code, info = self.run_verify(OFFICIAL_SAME)
        self.assertEqual(code, 0)
        self.assertEqual(info['status'], 'verified')
        self.assertEqual(info['source'], registry.OFFICIAL_HOSTS['qavanin.ir'])
        self.assertEqual(info['url'], 'https://qavanin.ir/Law/TreeText/1')
        self.assertEqual(info['date'], '۱۴۰۵/۰۸/۲۲')
        self.assertEqual(info['amended'], '۱۴۰۳/۰۳/۳۰')
        self.assertNotIn('note', info)
        self.assertEqual(registry.validate({'law': info}, self.dir.name)[0], [])

    def test_different_text_changes_nothing(self):
        before = json.loads(Path(self.meta).read_text(encoding='utf-8'))['law']
        code, info = self.run_verify(OFFICIAL_SAME.replace('بيست', 'سی'))
        self.assertEqual(code, 1)
        self.assertEqual(info, before)

    def test_unofficial_url_is_refused(self):
        code, info = self.run_verify(OFFICIAL_SAME, url='https://www.ekhtebar.ir/x')
        self.assertEqual(code, 1)
        self.assertEqual(info['status'], 'unverified')

    def test_stamp_downgrades_a_verified_law_whose_text_changed(self):
        self.run_verify(OFFICIAL_SAME)
        Path(self.law).write_text(BUNDLED + '\nماده 3\nتازه.\n', encoding='utf-8')
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(registry.main(['stamp']), 0)
        info = json.loads(Path(self.meta).read_text(encoding='utf-8'))['law']
        self.assertEqual(info['status'], 'unverified')
        self.assertEqual(info['sha256'], registry.sha256_of(self.law))


class RepositoryMetaTest(unittest.TestCase):
    """وضعیت واقعی مخزن: هیچ ادعای تأییدی بدون نشانی رسمی نیست."""

    def setUp(self):
        self.meta = json.loads(
            (ROOT / 'assets' / 'laws' / '_meta.json').read_text(encoding='utf-8'))

    def test_repository_meta_is_valid(self):
        errors = registry.validate(copy.deepcopy(self.meta))[0]
        self.assertEqual(errors, [])

    def test_no_batch_entry_claims_to_be_verified(self):
        for lid, info in self.meta.items():
            if 'اختبار' in info['source'] or not info['url']:
                self.assertEqual(info['status'], 'unverified', lid)

    def test_known_structural_defects_do_not_grow(self):
        known = {
            'direct_taxes': [('ماده 40 مکرر', 'ماده 41'), ('ماده 41 مکرر', 'ماده 42')],
        }
        for lid, info in self.meta.items():
            text = (ROOT / 'assets' / 'laws' / info['path']).read_text(encoding='utf-8')
            self.assertEqual(registry.glued_articles(text), known.get(lid, []), lid)


class JalaliTest(unittest.TestCase):
    def test_known_dates(self):
        self.assertEqual(registry.jalali(datetime.date(2024, 3, 20)), (1403, 1, 1))
        self.assertEqual(registry.jalali(datetime.date(2025, 3, 21)), (1404, 1, 1))
        self.assertEqual(registry.jalali(datetime.date(2026, 11, 13)), (1405, 8, 22))


if __name__ == '__main__':
    unittest.main()
