"""نگهبان ماتریس اولویتِ کاندیدهای پاسخ (فاز ۲).

هر جفتِ ممکن از ۲۰ کاندیدِ `advocate_reply.dart` (۱۹۰ جفت = ۱۱۳ هم‌پوشان +
۷۷ جداگانه) باید در `dev/tools/contracts/priority.json` تعریف شده باشد و
مستند (`docs/PRIORITY.md`) و آزمون (`test/advocate/priority_matrix_test.dart`)
تولیدشده از آن همیشه تازه بمانند.
"""

import copy
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))
sys.path.insert(0, os.path.join(ROOT, 'tests', 'python'))

import gen_priority as GP  # noqa: E402
from test_reply_pipeline_shape import CANDIDATE_ORDER  # noqa: E402


class PriorityMatrixTests(unittest.TestCase):
    def setUp(self):
        self.contract = GP.load()

    def test_contract_has_all_325_pairs_and_passes_validation(self):
        self.assertEqual(GP.validate(self.contract), [])
        cands = self.contract['candidates']
        self.assertEqual(len(cands), 26)
        self.assertEqual([c['name'] for c in cands], CANDIDATE_ORDER)
        pairs = self.contract['pairs']
        self.assertEqual(len(pairs), 325)
        overlaps = [p for p in pairs if p['status'] == 'overlap']
        disjoints = [p for p in pairs if p['status'] == 'disjoint']
        self.assertEqual(len(overlaps) + len(disjoints), 325)
        self.assertEqual(len(overlaps), 229)
        self.assertEqual(len(disjoints), 96)

    def test_generated_doc_and_dart_test_are_fresh(self):
        self.assertEqual(GP.main(['--check']), 0,
                         'docs/PRIORITY.md یا test/advocate/priority_matrix_test.dart کهنه است')

    def test_missing_pair_fails_validation(self):
        bad = copy.deepcopy(self.contract)
        bad['pairs'].pop()
        errs = GP.validate(bad)
        self.assertTrue(any('۳۲۵' in e or '۱۹۰' in e for e in errs), errs)

    def test_reordered_candidate_fails_validation(self):
        bad = copy.deepcopy(self.contract)
        bad['candidates'][0], bad['candidates'][1] = (
            bad['candidates'][1], bad['candidates'][0])
        errs = GP.validate(bad)
        self.assertTrue(errs)

    def test_empty_overlap_input_or_unknown_setup_fails_validation(self):
        bad = copy.deepcopy(self.contract)
        first_ov = next(p for p in bad['pairs'] if p['status'] == 'overlap')
        first_ov['setup'] = 'missing_setup'
        first_ov['compound_input'] = ''
        errs = GP.validate(bad)
        self.assertGreaterEqual(len(errs), 2, errs)


if __name__ == '__main__':
    unittest.main()
