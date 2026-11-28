"""آزمون‌های ابزار `dev/tools/dart_eval.py` و یکپارچگی suite واقعی Dart."""

from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dev' / 'tools'))

import dart_eval  # noqa: E402


class DartEvalToolTests(unittest.TestCase):
    def test_suite_and_workflow_wiring_exist(self):
        suite = ROOT / 'test' / 'core' / 'dart_eval_suite_test.dart'
        self.assertTrue(suite.is_file(), 'فایل test/core/dart_eval_suite_test.dart وجود ندارد')
        src = suite.read_text(encoding='utf-8')
        for expected in (
            'PersianText.normalize',
            'eval_none.txt',
            'reply.answered',
            'terms.match',
            'TopicFlow.route',
            'reports/dart_eval.txt',
        ):
            self.assertIn(expected, src)

        wf = (ROOT / '.github' / 'workflows' / 'test.yml').read_text(encoding='utf-8')
        self.assertIn('dev/tools/dart_eval.py --report-only --check', wf)
        self.assertIn('reports/dart_eval.txt', wf)

    def test_parse_and_validate_passing_report(self):
        sample = '\n'.join([
            '# گزارش نمونه',
            'DART_EVAL text_norm ok: golden=32 sense=14 parity=20',
            'DART_EVAL eval.txt: n=74 recall@1=0.93 recall@5=1.00 MRR=0.961',
            'DART_EVAL eval_extra.txt: n=30 recall@1=0.80 recall@5=0.93 MRR=0.856',
            'DART_EVAL eval_blind.txt: n=31 recall@1=0.68 recall@5=0.97 MRR=0.810',
            'DART_EVAL eval_all_laws.txt: n=40 recall@1=0.90 recall@5=1.00 MRR=0.930',
            'DART_EVAL eval_feedback.txt: n=18 recall@1=0.50 recall@5=0.83 MRR=0.660',
            'DART_EVAL eval_everyday_laws.txt: n=41 law@1=0.95',
            'DART_EVAL eval_none.txt: n=28 rejected=28 false_confident=0 (0.0%)',
            'DART_EVAL law_terms: cases=38/38 audit_ok=14 audit_open=0',
            'DART_EVAL topic_flow: files=4 cases=45/45',
        ])
        parsed = dart_eval.parse_report(sample)
        self.assertEqual(parsed['ranks']['eval_blind.txt']['r1'], 0.68)
        self.assertEqual(parsed['eval_none']['false_confident'], 0)
        self.assertEqual(dart_eval.validate_report(sample), [])

    def test_validate_rejects_high_false_confident_or_low_recall(self):
        bad = '\n'.join([
            'DART_EVAL eval.txt: n=74 recall@1=0.50 recall@5=0.70 MRR=0.600',
            'DART_EVAL eval_extra.txt: n=30 recall@1=0.80 recall@5=0.93 MRR=0.856',
            'DART_EVAL eval_blind.txt: n=31 recall@1=0.68 recall@5=0.97 MRR=0.810',
            'DART_EVAL eval_all_laws.txt: n=40 recall@1=0.90 recall@5=1.00 MRR=0.930',
            'DART_EVAL eval_feedback.txt: n=18 recall@1=0.50 recall@5=0.83 MRR=0.660',
            'DART_EVAL eval_everyday_laws.txt: n=41 law@1=0.95',
            'DART_EVAL eval_none.txt: n=28 rejected=24 false_confident=4 (14.3%)',
        ])
        errs = dart_eval.validate_report(bad)
        self.assertEqual(len(errs), 2)
        self.assertTrue(any('eval.txt' in e for e in errs))
        self.assertTrue(any('eval_none.txt' in e for e in errs))

    def test_eval_py_uses_common_helpers_without_duplicate_defs(self):
        eval_py = (ROOT / 'dev' / 'tools' / 'eval_py.py').read_text(encoding='utf-8')
        for fn in ('def collapse(', 'def tok(', 'def phrase(', 'def obsolete('):
            self.assertNotIn(fn, eval_py)
        self.assertIn('from common import', eval_py)
        self.assertIn('import engine_rules', eval_py)
        self.assertIn('import text_norm_rules', eval_py)


if __name__ == '__main__':
    unittest.main()
