"""نگهبانِ محلِ نوشتنِ گزارشِ مدلهای جایگزین.

کارگر Benchmark گزارش را در ریشهٔ مخزن commit میکند؛ اگر اسکریپت آن را در
زیرشاخهٔ `dev/brain` بنویسد، نتیجهٔ واقعی هرگز دیده نمیشود و.report قدیمی سرِ
جای خود میماند.
"""
import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPT = os.path.join(ROOT, 'dev', 'brain', 'alt_bench.py')
WORKFLOW = os.path.join(ROOT, '.github', 'workflows', 'alt-bench.yml')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


class AltBenchReportPathTests(unittest.TestCase):
    def test_report_goes_to_committed_path(self):
        src = read(SCRIPT)
        self.assertIn("OUT = os.path.join(ROOT, 'reports', 'alt_bench.md')", src)
        self.assertNotIn("OUT = os.path.join(HERE, 'reports'", src)
        workflow = read(WORKFLOW)
        self.assertIn('git add reports/alt_bench.md', workflow)

    def test_root_constant_points_to_repository_root(self):
        src = read(SCRIPT)
        self.assertIn("HERE = os.path.dirname(os.path.abspath(__file__))", src)
        self.assertIn("BRAIN = os.path.dirname(HERE)", src)
        self.assertIn("ROOT = os.path.dirname(BRAIN)", src)


if __name__ == '__main__':
    unittest.main()
