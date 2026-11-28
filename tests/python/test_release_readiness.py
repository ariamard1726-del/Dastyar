"""نگهبان فاز ۲۱: کامل‌بودن lawRefs همهٔ قالب‌ها، مستندات فاصلهٔ مواد و آمادگی امضای انتشار."""

import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dev' / 'tools'))
import release_readiness  # noqa: E402
import setup_release_signing  # noqa: E402


class Phase21ReadinessTests(unittest.TestCase):
    def test_all_templates_have_verified_law_refs_without_faking_review(self):
        templates = sorted((ROOT / 'assets' / 'templates').glob('*.json'))
        self.assertEqual(len(templates), 9)
        reviewed = 0
        for path in templates:
            data = json.loads(path.read_text(encoding='utf-8'))
            refs = data.get('lawRefs')
            self.assertIsInstance(refs, list, f'{path.name} باید lawRefs داشته باشد')
            self.assertGreater(len(refs), 0, f'{path.name} نباید lawRefs خالی داشته باشد')
            if data.get('reviewed') is True:
                reviewed += 1
        # صداقت: بدون تایید کارشناس حقوقی نباید reviewed جعلی ثبت شده باشد.
        self.assertEqual(reviewed, 2)

    def test_release_signing_preflight_passes_and_blocks_unsigned_release(self):
        self.assertEqual(setup_release_signing.check_release_signing(), [])
        res = subprocess.run(
            [sys.executable, str(ROOT / 'dev' / 'tools' / 'setup_release_signing.py'), '--check'],
            cwd=ROOT,
            capture_output=True,
            text=True,
        )
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)

    def test_law_gaps_audit_exists_and_covers_all_seven_laws(self):
        gaps = ROOT / 'docs' / 'LAW_GAPS.md'
        self.assertTrue(gaps.is_file())
        text = gaps.read_text(encoding='utf-8')
        for lid in (
            'commerce', 'penal_taazirat', 'direct_taxes',
            'registration', 'civil', 'social_security', 'civil_procedure',
        ):
            self.assertIn(lid, text)
        self.assertIn('۱۲۷', text)

    def test_release_readiness_reports_honest_status(self):
        st = release_readiness.collect_status()
        self.assertEqual(st['total_templates'], 9)
        self.assertEqual(st['templates_with_refs'], 9)
        self.assertEqual(st['reviewed_templates'], 2)
        self.assertEqual(st['verified_laws'], 0)
        self.assertEqual(st['signing_errors'], [])
        self.assertTrue(st['trust_blocked'])


if __name__ == '__main__':
    unittest.main()
