"""دروازهٔ پوشش: خواندن lcov و بستن آستانه در CI."""

import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
from coverage_gate import coverage, main  # noqa: E402


class CoverageGateTests(unittest.TestCase):
    def test_parses_lcov_and_applies_threshold(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / 'lcov.info'
            p.write_text('SF:lib/a.dart\nLF:10\nLH:7\nend_of_record\n',
                         encoding='utf-8')
            hit, found, pct = coverage(p)
            self.assertEqual((hit, found), (7, 10))
            self.assertAlmostEqual(pct, 70.0)
            self.assertEqual(main([str(p), '--min', '50']), 0)
            self.assertEqual(main([str(p), '--min', '80']), 1)
            p.write_text('SF:lib/a.dart\nend_of_record\n', encoding='utf-8')
            self.assertEqual(main([str(p), '--min', '40']), 2)

    def test_ci_runs_coverage(self):
        wf = (ROOT / '.github' / 'workflows' / 'test.yml').read_text(encoding='utf-8')
        self.assertIn('flutter test --coverage', wf)
        self.assertIn('tools/coverage_gate.py coverage/lcov.info --min', wf)
        self.assertIn('reports/coverage.txt', wf)
        self.assertIn('run-id: ${{ github.run_id }}', wf)
        self.assertIn('test-reports-${{ github.run_id }}', wf)
        self.assertIn('${GITHUB_SHA:0:7}', wf)


if __name__ == '__main__':
    unittest.main()
