"""نگهبانِ دارایی اصلی Noql: وزن، واژهنامه، سر و پروانه همیشه بسته شوند.

مدل ۱۲ مگابایتی Noql عمداً در اپ میماند: تنها زمان حدس موضوع است، در Isolate
اجرا میشود و دقتش در `reports/noql_finetune.md` ثبت شده است. این آزمون مانع
حذف بیصدای فایلها یا بیرون افتادنشان از `pubspec.yaml` میشود.
"""

import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dev' / 'tools'))
import check as repo_check  # noqa: E402

READER = (ROOT / 'lib' / 'domain' / 'understanding' / 'reader_service.dart')
PUBSPEC = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')


class NoqlAssetTests(unittest.TestCase):
    def test_required_files_exist_and_are_nonempty(self):
        for rel in repo_check.NOQL_REQUIRED:
            with self.subTest(rel=rel):
                path = ROOT / rel
                self.assertTrue(path.is_file(), '%s پاک شده است' % rel)
                self.assertGreater(path.stat().st_size, 0, rel)

    def test_reader_points_at_the_same_files(self):
        source = READER.read_text(encoding='utf-8')
        for name, rel in repo_check.NOQL_READER_PATHS.items():
            with self.subTest(name=name):
                self.assertIn("static const String %s = '%s';" % (name, rel),
                              source)

    def test_pubspec_bundles_every_noql_file(self):
        entries = repo_check.bundle_entries(PUBSPEC)
        self.assertEqual(repo_check.noql_bundle_problems(entries), [])

    def test_check_command_is_registered_and_green(self):
        self.assertIn('noql', repo_check.COMMANDS)
        done = subprocess.run([sys.executable, 'dev/tools/check.py', 'noql'],
                              cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(done.returncode, 0, done.stdout + done.stderr)
        self.assertIn('noql', done.stdout)


if __name__ == '__main__':
    unittest.main()
