"""آزمون‌های `dev/tools/sync_meta.py` و اتصال آن به گردش‌کارهای CI."""

from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dev' / 'tools'))

import sync_meta  # noqa: E402


class SyncMetaTests(unittest.TestCase):
    def test_check_flag_succeeds_on_current_repo(self):
        self.assertEqual(sync_meta.main(['--check']), 0)

    def test_check_detects_stale_derived_file_and_write_repairs_it(self):
        with tempfile.TemporaryDirectory() as tmp:
            cat = Path(tmp) / 'laws_catalog.json'
            info = Path(tmp) / 'data_info.json'
            cat.write_text('{"stale": true}\n', encoding='utf-8')
            info.write_text('{"stale": true}\n', encoding='utf-8')

            with mock.patch.object(sync_meta, 'CATALOG', str(cat)), \
                 mock.patch.object(sync_meta, 'INFO', str(info)), \
                 mock.patch.object(sync_meta, 'build', return_value=('{"ok": 1}\n', '{"ok": 2}\n')):
                self.assertEqual(sync_meta.main(['--check']), 1)
                self.assertEqual(sync_meta.main(['--write']), 0)
                self.assertEqual(cat.read_text(encoding='utf-8'), '{"ok": 1}\n')
                self.assertEqual(info.read_text(encoding='utf-8'), '{"ok": 2}\n')
                self.assertEqual(sync_meta.main(['--check']), 0)

    def test_ci_workflows_wire_sync_meta(self):
        test_wf = (ROOT / '.github' / 'workflows' / 'test.yml').read_text(encoding='utf-8')
        build_wf = (ROOT / '.github' / 'workflows' / 'build.yml').read_text(encoding='utf-8')
        self.assertIn('dev/tools/sync_meta.py --check', test_wf)
        self.assertIn('dev/tools/sync_meta.py --check', build_wf)
        self.assertIn('dev/tools/sync_meta.py --write', build_wf)


if __name__ == '__main__':
    unittest.main()
