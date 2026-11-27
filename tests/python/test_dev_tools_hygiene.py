"""نگهبانِ فاز ۷: جمع‌وجورکردن و یکپارچه‌سازی ابزارهای توسعه (`dev/tools/`).

تضمین می‌کند:
۱. گزارش‌گرهای CI (`ci_summary.py` و `ci_annotate.py`) یک پارس لاگ دارند؛
۲. `lawtext.py` تک‌منبعِ ارقام فارسی/عربی، خواندن `_meta.json` و `AI_MARKERS`
   در `dev/tools/` است؛
۳. اسکریپت‌های `dev/tools/synonyms/` از `lawtext` و `with open` استفاده می‌کنند؛
۴. اجرای تست‌های پایتون هیچ `ResourceWarning` (فایلِ بازِ رهاشده) تولید نمی‌کند؛
۵. `README.md` و `docs/PHASES.md` با وضعیت فعلی فازها هم‌خوان‌اند.
"""

import os
import re
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / 'dev' / 'tools'


def _read(path):
    return Path(path).read_text(encoding='utf-8')


class DevToolsHygieneTests(unittest.TestCase):
    def test_ci_reporters_share_log_parser(self):
        summary = _read(TOOLS / 'ci_summary.py')
        self.assertIn('from ci_annotate import', summary)
        self.assertNotIn('status_re = re.compile', summary)
        self.assertNotIn("if ' [E]' in lines", summary)
        self.assertNotIn("if '❌' in lines", summary)

    def test_lawtext_is_single_source_for_digits_meta_and_ai_markers(self):
        lt = _read(TOOLS / 'lawtext.py')
        self.assertIn('AI_MARKERS', lt)
        self.assertIn('def digits(', lt)
        self.assertIn('def to_fa(', lt)
        self.assertIn('def load_meta(', lt)
        self.assertIn('def law_files(', lt)

        for name in ('check.py', 'doctor.py', 'sync_meta.py', 'data_refs.py',
                     'check_refs.py', 'convert.py', 'law_diff.py', 'law_registry.py'):
            src = _read(TOOLS / name)
            self.assertIn('lawtext', src, f'{name} باید از lawtext بخواند')
            self.assertNotRegex(
                src, r'^(?:_?FA_DIGITS|PERSIAN)\s*=\s*str\.maketrans',
                f'{name} جدول ارقام تکراری دارد')
            self.assertNotIn('۰۱۲۳۴۵۶۷۸۹', src,
                             f'{name} هنوز رشتهٔ خام ارقام فارسی را کپی کرده است')
            if name != 'lawtext.py':
                self.assertNotRegex(src, r'^AI_MARKERS\s*=',
                                    f'{name} نباید AI_MARKERS را دوباره تعریف کند')

    def test_synonyms_tools_use_lawtext_and_context_managers(self):
        syn_dir = TOOLS / 'synonyms'
        for name in ('coverage_report.py', 'distinct_words.py', 'validate_synonyms.py'):
            src = _read(syn_dir / name)
            self.assertIn('lawtext', src, f'synonyms/{name} باید از lawtext بخواند')
            self.assertNotIn("BASE = 'assets/laws'", src)
            self.assertNotIn("BASE='assets/laws'", src)
            self.assertNotRegex(src, r'(?<!with )open\(',
                                f'synonyms/{name} فایل باز را با with نبسته است')

    def test_python_suite_emits_zero_resource_warnings(self):
        code = (
            "import pathlib, sys, unittest; "
            "loader = unittest.TestLoader(); "
            "suite = unittest.TestSuite(); "
            "sys.path.insert(0, 'tests/python'); "
            "[suite.addTests(loader.loadTestsFromName(p.stem)) "
            "for p in sorted(pathlib.Path('tests/python').glob('test_*.py')) "
            "if p.name != 'test_dev_tools_hygiene.py']; "
            "res = unittest.TextTestRunner(warnings=None, verbosity=0).run(suite); "
            "sys.exit(0 if res.wasSuccessful() else 1)"
        )
        res = subprocess.run(
            [sys.executable, '-W', 'error::ResourceWarning', '-c', code],
            cwd=ROOT, capture_output=True, text=True,
        )
        self.assertEqual(res.returncode, 0, f'{res.stdout}\n{res.stderr}')
        self.assertNotIn('ResourceWarning', res.stderr)
        self.assertNotIn('Exception ignored', res.stderr)

    def test_readme_and_phases_reflect_completed_phases(self):
        phases = _read(ROOT / 'docs' / 'PHASES.md')
        self.assertIn('## فاز ۷ — یکپارچه‌سازی و زدودن تکرار در ابزارهای توسعه (انجام شد)', phases)
        self.assertIn('فاز ۶', phases)
        readme = _read(ROOT / 'README.md')
        self.assertNotIn('۵۶۸ آزمون سبز', readme)
        self.assertNotIn('۳۱۱ آزمون پایتون', readme)
        self.assertNotIn('نثرِ ثابت در فایلهای غیرموضوعی', readme)
        self.assertIn('۷۰۱', readme)
        self.assertIn('reports/startup.txt', readme)


if __name__ == '__main__':
    unittest.main()
