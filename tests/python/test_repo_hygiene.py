"""مرزِ اپ و ابزار آفلاین: سرانجام تک پوشه برای ورودی و خروجی سنجش."""

import re
import subprocess
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _tracked_text_files():
    names = subprocess.check_output(['git', 'ls-files'], cwd=ROOT, text=True).splitlines()
    return [ROOT / n for n in names if n.endswith(
        ('.py', '.dart', '.md', '.txt', '.yml', '.yaml', '.json', '.sh', '.tsv'))]


# نمونههایی که واقعاً توسط `topic_flow.py --check` و `test_topic_flow.py` خوانده
# میشوند. بقیهٔ عکسهای توسعه (test5..7، fresh، dev5..7 و heldout2..6) یتیماند.
LIVE_TOPIC_FIXTURES = {
    'cheque_gold.json', 'cheque_heldout.json',
    'rent_gold.json', 'labor_wages_gold.json',
}
ORPHAN_TOPIC_FIXTURES = {
    'cheque_heldout2.json', 'cheque_heldout3.json', 'cheque_heldout4.json',
    'cheque_heldout5.json', 'cheque_heldout6.json',
    'labor_wages_dev5.json', 'labor_wages_dev6.json', 'labor_wages_dev7.json',
    'labor_wages_fresh.json', 'labor_wages_fresh3.json',
    'labor_wages_fresh4.json', 'labor_wages_heldout.json',
    'labor_wages_test5.json', 'labor_wages_test6.json',
    'labor_wages_test7.json', 'misfiled_labor_in_rent_test6.json',
    'rent_dev5.json', 'rent_dev6.json', 'rent_dev7.json',
    'rent_fresh.json', 'rent_fresh3.json', 'rent_fresh4.json',
    'rent_heldout.json', 'rent_test5.json', 'rent_test6.json',
    'rent_test7.json',
}
ORPHAN_FILES = (
    'dev/tools/holdout_intent.py', 'dev/tools/set_meta.py',
    'reports/intent_holdout_netcompare.txt', 'reports/ngram.txt',
)


def _dart_graph():
    """گراف واردات/part از `lib/main.dart`؛ این یک قرارداد است."""
    files = {p.relative_to(ROOT).as_posix() for p in (ROOT / 'lib').rglob('*.dart')}
    edges = {}
    for rel in files:
        text = (ROOT / rel).read_text(encoding='utf-8')
        targets = set()
        for spec in re.findall(
                r"^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]", text, re.M):
            if spec.startswith('dart:') or spec.startswith('package:') \
                    and not spec.startswith('package:dastyar/'):
                continue
            if spec.startswith('package:dastyar/'):
                target = 'lib/' + spec[len('package:dastyar/'):]
            else:
                target = (ROOT / rel).parent.joinpath(spec).resolve().relative_to(ROOT).as_posix()
            if target in files:
                targets.add(target)
        edges[rel] = targets
    seen, stack = set(), ['lib/main.dart']
    while stack:
        cur = stack.pop()
        if cur in seen:
            continue
        seen.add(cur)
        stack.extend(edges[cur] - seen)
    return files, seen


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

    def test_every_lib_file_is_reachable_from_main(self):
        files, seen = _dart_graph()
        self.assertEqual(files - seen, set(), 'فایل Dart یتیم: %s' % sorted(files - seen))

    def test_topic_fixtures_are_only_the_ones_actually_read(self):
        here = {p.name for p in (ROOT / 'tests' / 'topics').glob('*.json')}
        self.assertTrue(LIVE_TOPIC_FIXTURES <= here,
                        'نمونهٔ زنده حذف شد: %s' % sorted(LIVE_TOPIC_FIXTURES - here))
        self.assertEqual(here & ORPHAN_TOPIC_FIXTURES, set(),
                         'عکس توسعهٔ یتیم بازگشت: %s'
                         % sorted(here & ORPHAN_TOPIC_FIXTURES))

    def test_orphan_manual_tools_are_gone(self):
        for rel in ORPHAN_FILES:
            self.assertFalse((ROOT / rel).exists(), rel)


if __name__ == '__main__':
    unittest.main()
