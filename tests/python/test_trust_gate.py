"""دروازهٔ انتشار نباید بیصدا رد شود: محتوای تأییدنشده باید release را متوقف کند."""

import contextlib
import io
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))
import check  # noqa: E402


class TrustGateTest(unittest.TestCase):
    def test_trust_is_excluded_from_development_check(self):
        self.assertIn('trust', check.COMMANDS)
        self.assertIn('trust', check.RELEASE_ONLY)
        self.assertNotIn('trust', [n for n in check.COMMANDS
                                   if n not in check.RELEASE_ONLY])

    def test_release_gate_is_actually_enforced_in_build_workflow(self):
        with open(os.path.join(ROOT, '.github', 'workflows', 'build.yml'),
                  encoding='utf-8') as f:
            workflow = f.read()
        self.assertIn('python dev/tools/check.py trust', workflow)
        self.assertLess(workflow.index('check.py trust'),
                        workflow.index('Build release APK'))

    def test_readme_does_not_hide_the_release_blocker(self):
        with open(os.path.join(ROOT, 'README.md'), encoding='utf-8') as f:
            readme = f.read()
        self.assertIn('وضعیت انتشار: مسدود است', readme)
        self.assertIn('check.py trust', readme)
        self.assertIn('۰/۲۴', readme)
        # صداقتی که از README حذف شود، دوباره به ادعای قدیمی برمیگردد.
        self.assertIn('نصب نبودند', readme)

    def test_current_unreviewed_content_blocks_release(self):
        # وضعیت امروز صادقانه ثبت شود: تا زمانی که منبع رسمی تأیید نشده،
        # دروازه باید قرمز بماند. اگر روزی سبز شد، همین آزمون یادآوری میکند
        # که باید انتظارِ تازهاش را در README بنویسید.
        with contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(check.cmd_trust(), 1)
        self.assertIn('انتشار مسدود است', out.getvalue())


if __name__ == '__main__':
    unittest.main()
