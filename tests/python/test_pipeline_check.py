import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))

import pipeline_check as PC  # noqa: E402


class PipelineCheckTests(unittest.TestCase):
    def test_current_repo_passes(self):
        errors, _ = PC.check()
        self.assertEqual(errors, [])

    def test_order_starts_with_safety(self):
        p = PC.load_pipeline()
        self.assertEqual(p['order'][0], 'safety')

    def test_order_matches_dart(self):
        p = PC.load_pipeline()
        want = [PC.DART_NAMES[s] for s in p['order']]
        self.assertEqual(PC.dart_pipeline_order(), want)

    def test_net_min_matches_dart(self):
        p = PC.load_pipeline()
        self.assertAlmostEqual(p['thresholds']['netMin'], PC.dart_net_min())

    def test_reordered_pipeline_fails(self):
        p = PC.load_pipeline()
        p['order'] = list(reversed(p['order']))
        errors, _ = PC.validate(p)
        # ترتیب معکوس با safety شروع نمی‌شود و باید خطا بدهد.
        self.assertTrue(any('safety' in e for e in errors))

    def test_unknown_source_fails(self):
        p = PC.load_pipeline()
        p['order'] = p['order'] + ['llm']
        errors, _ = PC.validate(p)
        self.assertTrue(any('llm' in e for e in errors))

    def test_bad_threshold_fails(self):
        p = PC.load_pipeline()
        p['thresholds']['netMin'] = 1.5
        errors, _ = PC.validate(p)
        self.assertTrue(errors)

    def test_pipeline_json_is_declared_asset(self):
        # اگر فایل در APK نباشد، آزمون Dart و کد نمی‌توانند به آن برسند.
        with open(os.path.join(ROOT, 'pubspec.yaml'), encoding='utf-8') as f:
            pubspec = f.read()
        self.assertIn('assets/pipeline.json', pubspec)

    def test_every_order_entry_has_a_note(self):
        p = PC.load_pipeline()
        notes = p.get('notes') or {}
        for s in p['order']:
            self.assertIn(s, notes, 'مسیر %s توضیح ندارد' % s)


if __name__ == '__main__':
    unittest.main()
