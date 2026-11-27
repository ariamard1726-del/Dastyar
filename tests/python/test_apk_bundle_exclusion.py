"""چکهٔ بستهبندی: ابزارهای آفلاین نباید وارد APK شوند.

اپ فقط `assets/` را بستهبندی میکند. این آزمون قراردادِ `check.py bundle` را
میسنجد و سپس همان بررسی را روی درخت واقعی اجرا میکند؛ CI نیازی به ابزار
اندروید ندارد تا بفهمد `dev/` وارد بسته نشده است.
"""

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dev' / 'tools'))
import check as repo_check  # noqa: E402


class ApkBundleTests(unittest.TestCase):
    def test_helper_rejects_tooling_paths(self):
        self.assertEqual(repo_check.bundle_problems(['assets/laws/'], []), [])
        for bad in ('dev/tools/check.py', 'tools/check.py', 'brain/train.py',
                    'eval/intent_eval.txt', 'reports/last_test.txt'):
            with self.subTest(bad=bad):
                self.assertTrue(repo_check.bundle_problems([bad], []), bad)
        self.assertTrue(repo_check.bundle_problems(
            ['assets/laws/'], ["final x = 'dev/tools/secret';"]))

    def test_current_bundle_is_clean(self):
        pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
        dart = [p.read_text(encoding='utf-8') for p in (ROOT / 'lib').rglob('*.dart')]
        self.assertEqual(repo_check.bundle_problems(
            repo_check.bundle_entries(pubspec), dart), [])

    def test_check_command_is_registered_and_green(self):
        self.assertIn('bundle', repo_check.COMMANDS)
        done = subprocess.run([sys.executable, 'dev/tools/check.py', 'bundle'],
                              cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        self.assertIn('bundle', done.stdout)


if __name__ == '__main__':
    unittest.main()
