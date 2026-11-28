import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))

import topic_flow as TF  # noqa: E402
import law_terms as LT  # noqa: E402


class TopicFlowTests(unittest.TestCase):
    def test_dev_gold_all_correct(self):
        gold, bad = TF.check()
        self.assertEqual(bad, [])
        self.assertGreater(len(gold), 20)

    def test_heldout_majority_correct(self):
        # مجموعهٔ کنترل: نتیجه گزارش می‌شود؛ حداقل نیمی از آن باید درست باشد.
        flow = TF.load()
        with open(os.path.join(ROOT, 'tests', 'topics', 'cheque_heldout.json'), encoding='utf-8') as f:
            g = json.load(f)
        ok = sum(1 for x in g if TF.route(x['q'], flow) == x['leaf'])
        self.assertGreaterEqual(ok, len(g) // 2)

    def test_every_leaf_cites_existing_article(self):
        flow = TF.load()
        e = LT.engine()
        have = {(c['law'], c['title']) for c in e.chunks}
        for leaf_id, leaf in flow['leaves'].items():
            self.assertTrue(leaf['text'].strip(), leaf_id)
            for a in leaf['articles']:
                self.assertIn((a['law'], a['title']), have, (leaf_id, a))

    def test_fallback_asks(self):
        self.assertEqual(TF.route('سلام'), 'ask')

    def test_malformed_flow_falls_back_to_ask(self):
        bad_flow = {
            'gate': [123, None],
            'rules': [
                'not_a_dict',
                {'any': ['چک']},
                {'any': [42], 'leaf': 'x'},
                {'all_groups': ['bad'], 'leaf': 'x'},
            ],
        }
        self.assertEqual(TF.route('چکم برگشت خورد', bad_flow), 'ask')
        self.assertEqual(TF.route('چکم برگشت خورد', {}), 'ask')

    def test_answer_has_disclaimer_and_refs(self):
        a = TF.answer('چکم برگشت خورد')
        self.assertEqual(a['leaf'], 'returned_holder')
        self.assertIn('cheque ماده 4', a['articles'])
        self.assertTrue(a['disclaimer'])


if __name__ == '__main__':
    unittest.main()
