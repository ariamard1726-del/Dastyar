"""نگهبانِ جدولِ بدهی‌های موقت (`tools/contracts/duplicated_logic.json`).

سه چیزی که باید همیشه درست بمانند:

۱. قراردادِ فعلی مخزن سالم است (`check.py debt` سبز)؛
۲. اگر یک طرف خواندنِ مجموعهٔ نمونه را از دست بدهد، بررسی قرمز می‌شود؛
۳. اگر ردیفی از ROADMAP حذف شود، بررسی قرمز می‌شود — بدهی بی‌صدا از فهرست
   بیرون نمی‌رود.
"""

import json
import os
import shutil
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))

import debt_check  # noqa: E402


class CurrentRepoTests(unittest.TestCase):
    def test_contract_is_sound(self):
        self.assertEqual(debt_check.check(), [])

    def test_every_pair_has_guard_on_both_sides(self):
        c = debt_check.load()
        self.assertGreaterEqual(len(c['pairs']), 3)
        for p in c['pairs']:
            self.assertTrue(p['shared'], p['id'])
            self.assertTrue(p['fix'].strip(), p['id'])
            self.assertTrue(p['what'].strip(), p['id'])


class BrokenRepoTests(unittest.TestCase):
    """مخزنِ ساختگی در پوشهٔ موقت: هر ایراد باید همان‌جا گرفته شود."""

    def setUp(self):
        self.tmp = tempfile.mkdtemp(prefix='debt_')
        self._saved = (debt_check.ROOT, debt_check.DART_ROOTS, debt_check.PY_ROOTS)
        debt_check.ROOT = self.tmp
        debt_check.DART_ROOTS = ['dart']
        debt_check.PY_ROOTS = ['py']

    def tearDown(self):
        debt_check.ROOT, debt_check.DART_ROOTS, debt_check.PY_ROOTS = self._saved
        shutil.rmtree(self.tmp, ignore_errors=True)

    def _write(self, rel, text):
        path = os.path.join(self.tmp, rel)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as f:
            f.write(text)

    def _pair(self):
        self._write('dart/a.dart', 'void main() {}\n')
        self._write('py/a.py', 'x = 1\n')
        return {'id': 'a', 'what': 'چیز', 'dart': 'dart/a.dart', 'py': 'py/a.py',
                'shared': ['cases/x.json'], 'note': '', 'fix': 'یک منبع'}

    def _contract(self, pair, roadmap='a'):
        self._write('tools/contracts/duplicated_logic.json',
                    json.dumps({'version': 1, 'pairs': [pair]}, ensure_ascii=False))
        self._write('docs/ROADMAP.md', roadmap)

    def _healthy(self):
        self._write('cases/x.json', '[]')
        self._write('dart/t.dart', "File('cases/x.json')\n")
        self._write('py/t.py', "open('cases/x.json')\n")

    def test_missing_corpus_is_error(self):
        self._contract(self._pair())
        errs = debt_check.check()
        self.assertTrue(any('پیدا نشد' in e for e in errs), errs)

    def test_one_sided_corpus_is_error(self):
        self._write('cases/x.json', '[]')
        self._write('dart/t.dart', "File('cases/x.json')\n")
        self._contract(self._pair())
        errs = debt_check.check()
        self.assertTrue(any('سمت پایتون' in e for e in errs), errs)

    def test_missing_roadmap_row_is_error(self):
        self._healthy()
        self._contract(self._pair(), roadmap='این ردیف جایش نیست')
        errs = debt_check.check()
        self.assertTrue(any('ROADMAP' in e for e in errs), errs)

    def test_missing_source_file_is_error(self):
        self._healthy()
        pair = self._pair()
        pair['py'] = 'py/gone.py'
        self._contract(pair)
        errs = debt_check.check()
        self.assertTrue(any('وجود ندارد' in e for e in errs), errs)

    def test_healthy_pair_passes(self):
        self._healthy()
        self._contract(self._pair(), roadmap='| a | `dart/a.dart` |')
        self.assertEqual(debt_check.check(), [])


if __name__ == '__main__':
    unittest.main()
