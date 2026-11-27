import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))

import term_audit as T  # noqa: E402


class TermAuditTests(unittest.TestCase):
    def test_dart_turns_extracted(self):
        turns = T.dart_turns()
        self.assertGreater(len(turns), 100)
        self.assertEqual(len(turns), len(set(turns)))

    def test_every_ok_item_passes(self):
        with open(T.AUDIT, encoding='utf-8') as f:
            audit = json.load(f)
        for item in audit:
            if item['status'] == 'ok':
                ok, why, _ = T.check_audit(item)
                self.assertTrue(ok, '%s: %s' % (item['q'], why))

    def test_open_items_have_expectation_fields(self):
        with open(T.AUDIT, encoding='utf-8') as f:
            audit = json.load(f)
        for item in audit:
            self.assertIn(item['status'], ('ok', 'open'))
            self.assertIn('accepted', item)

    def test_glossary_targets_exist_and_mention_term(self):
        import law_terms as LT
        e = LT.engine()
        with open(LT.GLOSSARY, encoding='utf-8') as f:
            entries = json.load(f)['entries']
        for entry in entries:
            hits = [c for c in e.chunks if c['law'] == entry['law'] and c['title'] == entry['title']]
            self.assertEqual(len(hits), 1, entry)
            body = hits[0]['body']
            # واژهٔ لنگر (anchor) باید در متن رسمی ماده باشد.
            self.assertIn(entry['anchor'], body, entry)

    def test_no_regression_in_cases(self):
        _, fails = T.LT.run_cases()
        self.assertEqual(fails, [])


if __name__ == '__main__':
    unittest.main()
