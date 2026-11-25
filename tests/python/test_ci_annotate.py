import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))

import ci_annotate  # noqa: E402

LOG = '''00:01 +10: loading
00:02 +12 -1: /w/Dastyar/test/advocate/meta_and_tone_test.dart: پیام کوتاه [E]
  Expected: no matching text
  Actual: 'منظورتان از ...'
   Which: did match
00:03 +13: next test
'''


class AnnotateTests(unittest.TestCase):
    def test_emits_header_and_reason(self):
        out = ci_annotate.annotate(LOG.splitlines())
        joined = '\n'.join(out)
        self.assertIn('meta_and_tone_test.dart', joined)
        self.assertIn('Expected:', joined)
        self.assertTrue(all(l.startswith('::error::') for l in out))

    def test_strips_workspace_prefix_and_keeps_limit(self):
        lines = ['00:02 +1 -1: /home/runner/work/Dastyar/Dastyar/test/x_test.dart: a [E]']
        for i in range(20):
            lines.append('00:0%d +%d -1: /home/runner/work/Dastyar/Dastyar/test/y_test.dart: t%d [E]'
                         % (i % 10, i, i))
        out = ci_annotate.annotate(lines)
        self.assertLessEqual(len(out), 8)
        self.assertNotIn('/home/runner', '\n'.join(out))

    def test_cross_marker_reporter_is_understood(self):
        log = ['00:01 +10: a',
               '❌ test/advocate/meta_and_tone_test.dart: پیام کوتاه',
               '   Expected: no matching text',
               '   Actual: x',
               '✅ test/x_test.dart: y']
        out = ci_annotate.annotate(log)
        self.assertIn('meta_and_tone_test.dart', out[0])
        self.assertIn('Expected:', '\n'.join(out))

    def test_without_marker_reports_tail(self):
        out = ci_annotate.annotate(['Some tests failed.', 'ok'])
        self.assertTrue(out)
        self.assertIn('بدون بلوکِ', out[0])


if __name__ == '__main__':
    unittest.main()
