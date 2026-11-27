import copy
import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))

import data_refs as RC  # noqa: E402


def load_cheque():
    with open(os.path.join(ROOT, 'assets', 'brain', 'topics', 'cheque.json'), encoding='utf-8') as f:
        return json.load(f)


class RefCheckTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.meta = RC.load_meta()

    def test_current_repo_has_no_broken_refs(self):
        errors, counts = RC.check()
        self.assertEqual(errors, [])
        self.assertGreater(counts['topics'], 0)
        self.assertGreater(counts['templates'], 0)
        self.assertGreater(counts['qa'], 0)

    def test_articles_are_parsed_from_corpus(self):
        arts = RC.articles('cheque', self.meta)
        self.assertIsNotNone(arts)
        self.assertIn('3', arts)

    def test_unknown_law_has_no_articles(self):
        self.assertIsNone(RC.articles('no_such_law', self.meta))

    def test_digits_are_normalized(self):
        self.assertEqual(RC.norm_digits('۱۲۳'), '123')
        self.assertEqual(RC.norm_digits(' 45 '), '45')


class RefMutationTests(unittest.TestCase):
    """تغییر داده باید خطای صریح بدهد، نه سکوتِ زمان اجرا."""

    @classmethod
    def setUpClass(cls):
        cls.meta = RC.load_meta()

    def test_broken_article_number_is_reported(self):
        flow = copy.deepcopy(load_cheque())
        flow['leaves']['partial_payment']['articles'] = [
            {'law': 'cheque', 'title': 'ماده 9999'}]
        errors = []
        RC.check_flow_refs('cheque.json', flow, self.meta, errors)
        self.assertTrue(any('9999' in e for e in errors), errors)

    def test_unknown_law_is_reported(self):
        flow = copy.deepcopy(load_cheque())
        flow['leaves']['partial_payment']['articles'] = [
            {'law': 'ghost_law', 'title': 'ماده 1'}]
        errors = []
        RC.check_flow_refs('cheque.json', flow, self.meta, errors)
        self.assertTrue(any('ghost_law' in e for e in errors), errors)

    def test_persian_digits_in_ref_match(self):
        flow = copy.deepcopy(load_cheque())
        flow['leaves']['partial_payment']['articles'] = [
            {'law': 'cheque', 'title': 'ماده ۵'}]
        errors = []
        RC.check_flow_refs('cheque.json', flow, self.meta, errors)
        self.assertEqual(errors, [])

    def test_clean_flow_passes(self):
        errors = []
        n = RC.check_flow_refs('cheque.json', load_cheque(), self.meta, errors)
        self.assertEqual(errors, [])
        self.assertEqual(n, 13)


if __name__ == '__main__':
    unittest.main()
