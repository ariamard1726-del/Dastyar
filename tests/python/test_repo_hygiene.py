"""مرزِ اپ و ابزار آفلاین: سرانجام تک پوشه برای ورودی و خروجی سنجش."""

import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _tracked_text_files():
    names = subprocess.check_output(['git', 'ls-files'], cwd=ROOT, text=True).splitlines()
    return [ROOT / n for n in names if n.endswith(
        ('.py', '.dart', '.md', '.txt', '.yml', '.yaml', '.json', '.sh', '.tsv'))]


class RepoHygieneTests(unittest.TestCase):
    def test_twin_directories_are_gone(self):
        self.assertFalse((ROOT / 'brain').exists(), 'پوشهٔ قدیمی brain هنوز هست')
        self.assertFalse((ROOT / 'tools').exists(), 'پوشهٔ قدیمی tools هنوز هست')
        self.assertTrue((ROOT / 'dev' / 'brain').is_dir())
        self.assertTrue((ROOT / 'dev' / 'tools').is_dir())
        for name in ('eval.txt', 'intent_eval.txt', 'eval_none.txt'):
            self.assertTrue((ROOT / 'eval' / name).is_file(), name)
        for name in ('last_test.txt', 'intent_holdout.md', 'near_miss.txt'):
            self.assertTrue((ROOT / 'reports' / name).is_file(), name)

    def test_no_reference_to_old_paths(self):
        bad = []
        for path in _tracked_text_files():
            # مستندات حق دارند از مسیر قدیمی برای توضیحِ ادغام حرف بزنند.
            if (not path.exists() or path.suffix == '.md'
                    or path.name == 'test_repo_hygiene.py'):
                continue
            text = path.read_text(encoding='utf-8')
            if 'dev/brain/eval' in text or 'dev/brain/reports' in text:
                bad.append(str(path.relative_to(ROOT)))
        self.assertEqual(bad, [], 'مسیر دوقلوی قدیمی باقی مانده: %s' % bad)

    def test_app_package_excludes_offline_tooling(self):
        pubspec = (ROOT / 'pubspec.yaml').read_text(encoding='utf-8')
        assets = [l.strip() for l in pubspec.splitlines()
                  if l.strip().startswith('- assets/')]
        self.assertTrue(assets)
        for entry in assets:
            self.assertTrue(entry.startswith('- assets/'), entry)
        dart = list((ROOT / 'lib').rglob('*.dart'))
        bad = [str(p.relative_to(ROOT)) for p in dart
               if "'dev/brain/eval" in p.read_text(encoding='utf-8')
               or "'dev/brain/reports" in p.read_text(encoding='utf-8')
               or "'dev/tools/" in p.read_text(encoding='utf-8')]
        self.assertEqual(bad, [], 'کد اپ به ابزار آفلاین وابسته شد: %s' % bad)


if __name__ == '__main__':
    unittest.main()
