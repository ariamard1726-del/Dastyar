import copy
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))

import topic_schema as TS  # noqa: E402


class TopicSchemaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.meta = TS.load_meta()

    def test_current_topics_have_no_errors(self):
        errors, _ = TS.check()
        self.assertEqual(errors, [])

    def test_cheque_is_clean(self):
        flow = TS.load_topic('cheque.json')
        errors, _ = TS.validate_topic(flow, self.meta, 'cheque.json')
        self.assertEqual(errors, [])

    def test_missing_key_fails(self):
        flow = copy.deepcopy(TS.load_topic('cheque.json'))
        del flow['disclaimer']
        errors, _ = TS.validate_topic(flow, self.meta, 'cheque.json')
        self.assertTrue(any('disclaimer' in e for e in errors))

    def test_unknown_law_fails(self):
        flow = copy.deepcopy(TS.load_topic('cheque.json'))
        flow['leaves']['returned_holder']['articles'][0]['law'] = 'no_such_law'
        errors, _ = TS.validate_topic(flow, self.meta, 'cheque.json')
        self.assertTrue(any('no_such_law' in e for e in errors))

    def test_rule_without_condition_fails(self):
        flow = copy.deepcopy(TS.load_topic('cheque.json'))
        flow['rules'].append({'leaf': 'returned_holder'})
        errors, _ = TS.validate_topic(flow, self.meta, 'cheque.json')
        self.assertTrue(any('any' in e or 'all_groups' in e for e in errors))

    def test_missing_ask_leaf_fails(self):
        flow = copy.deepcopy(TS.load_topic('cheque.json'))
        del flow['leaves']['ask']
        errors, _ = TS.validate_topic(flow, self.meta, 'cheque.json')
        self.assertTrue(any('ask' in e for e in errors))

    def test_generic_gate_is_warning_not_error(self):
        flow = copy.deepcopy(TS.load_topic('cheque.json'))
        flow['gate'] = ['خانه']
        errors, warnings = TS.validate_topic(flow, self.meta, 'cheque.json')
        self.assertEqual(errors, [])
        self.assertTrue(any('خانه' in w for w in warnings))

    def test_dead_topic_warns(self):
        flow = copy.deepcopy(TS.load_topic('cheque.json'))
        flow['live'] = False
        _, warnings = TS.validate_topic(flow, self.meta, 'cheque.json')
        self.assertTrue(any('live' in w for w in warnings))


if __name__ == '__main__':
    unittest.main()
