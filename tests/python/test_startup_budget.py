"""قرارداد فاز ۵: ثبتِ خطِ پایهٔ زمانِ استارت و حافظه در CI و جلوگیری از پس‌رفت.

این نگهبان چهار چیز را قفل می‌کند:
1. `dev/tools/startup_gate.py` خروجی `reports/startup.txt` را می‌خواند و در برابر
   سقف زمانی/نبودِ معیارها شکست می‌دهد؛
2. `lib/core/engine_load.dart` دارایی‌های خام را با `cache: false` می‌خواند
   تا رشته‌های چندمگابایتی در کش `rootBundle` دو نسخه نمانند و دادهٔ موقتِ
   worker را پس از ساخت نمایه آزاد می‌کند؛
3. `test/engine/load_budget_test.dart` زمانِ بارگذاری سرد، worker، پرسش نخست
   و مصرف حافظه/دارایی را می‌سنجد و در `reports/startup.txt` می‌نویسد؛
4. `.github/workflows/test.yml` دروازهٔ `startup_gate.py` را اجرا و
   `reports/startup.txt` را همراه `reports/last_test.txt` ذخیره می‌کند.
"""

import re
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dev' / 'tools'))
from library import read as lib_read  # noqa: E402


class StartupBudgetTests(unittest.TestCase):
    def test_startup_gate_parses_and_enforces_budgets(self):
        gate_path = ROOT / 'dev' / 'tools' / 'startup_gate.py'
        self.assertTrue(gate_path.is_file(), 'dev/tools/startup_gate.py وجود ندارد')
        import startup_gate  # noqa: E402

        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'startup.txt'
            p.write_text(
                'STARTUP-BASELINE load_ms=1250 assets_ms=320 index_ms=930 '
                'worker_load_ms=1680 first_query_ms=18 laws=24 chunks=5900 '
                'vocab=42000 assets_mb=17.5 laws_mb=3.2 lazy_noql_mb=12.9 '
                'rss_mb=185.0\n',
                encoding='utf-8',
            )
            metrics = startup_gate.parse_startup(p)
            self.assertEqual(metrics['load_ms'], 1250)
            self.assertEqual(metrics['worker_load_ms'], 1680)
            self.assertEqual(metrics['first_query_ms'], 18)
            self.assertEqual(startup_gate.main([
                str(p), '--max-load-ms', '15000', '--max-worker-ms', '15000',
                '--max-query-ms', '5000',
            ]), 0)
            self.assertEqual(startup_gate.main([
                str(p), '--max-load-ms', '1000',
            ]), 1)
            p.write_text('empty\n', encoding='utf-8')
            self.assertEqual(startup_gate.main([str(p)]), 2)

    def test_engine_loader_avoids_caching_raw_strings(self):
        loader = lib_read(str(ROOT), 'lib/core/engine_load.dart')
        calls = re.findall(r'rootBundle\.loadString\(([^)]+)\)', loader)
        self.assertGreaterEqual(len(calls), 10)
        uncached = [c for c in calls if 'cache: false' not in c]
        self.assertEqual(uncached, [],
                         'این خواندن‌های موتور هنوز در rootBundle کش می‌شوند: %s' % uncached)
        self.assertIn('_repliesRaw = const {}', loader)
        self.assertIn('_lawTopicsRaw = null', loader)
        engine = lib_read(str(ROOT), 'lib/core/engine.dart')
        self.assertIn('StartupMetrics? get startupMetrics', engine)

    def test_load_budget_test_records_startup_report(self):
        src = (ROOT / 'test' / 'engine' / 'load_budget_test.dart').read_text(
            encoding='utf-8')
        for token in ('reports/startup.txt', 'STARTUP-BASELINE',
                      'worker_load_ms=', 'first_query_ms=', 'rss_mb='):
            self.assertIn(token, src)

    def test_ci_wires_startup_gate_and_report(self):
        wf = (ROOT / '.github' / 'workflows' / 'test.yml').read_text(
            encoding='utf-8')
        self.assertIn('dev/tools/startup_gate.py reports/startup.txt', wf)
        self.assertIn('reports/startup.txt', wf)
        self.assertIn('path: reports', wf)
        phases = (ROOT / 'docs' / 'PHASES.md').read_text(encoding='utf-8')
        self.assertIn('## فاز ۵ — استارت و حافظه (انجام شد)', phases)

    def test_committed_startup_report_is_valid_when_present(self):
        report = ROOT / 'reports' / 'startup.txt'
        if not report.is_file():
            return
        import startup_gate  # noqa: E402

        metrics = startup_gate.parse_startup(report)
        for key in ('load_ms', 'assets_ms', 'index_ms', 'worker_load_ms',
                    'first_query_ms', 'laws', 'chunks', 'vocab', 'rss_mb'):
            self.assertIn(key, metrics)


if __name__ == '__main__':
    unittest.main()
