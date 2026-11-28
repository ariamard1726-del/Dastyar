"""نگهبان فاز ۱۹: جداسازی بارگذاری دارایی و انبار ذخیره از فلاتر و SharedPreferences."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class Phase19DecouplingTests(unittest.TestCase):
    def test_core_abstractions_exist(self):
        for rel in (
            'lib/core/asset_loader.dart',
            'lib/core/local_store.dart',
            'lib/core/storage_migration.dart',
        ):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_knowledge_engine_supports_injected_asset_loader(self):
        engine = (ROOT / 'lib' / 'core' / 'engine.dart').read_text(encoding='utf-8')
        loader = (ROOT / 'lib' / 'core' / 'engine_load.dart').read_text(encoding='utf-8')
        main_src = (ROOT / 'lib' / 'main.dart').read_text(encoding='utf-8')
        self.assertIn('AssetTextLoader', engine)
        self.assertIn('KnowledgeEngine({AssetTextLoader? assetLoader})', engine)
        self.assertIn('_readAsset(', loader)
        self.assertIn('assetLoader:', main_src)

    def test_domain_and_history_do_not_import_shared_preferences_directly(self):
        for path in sorted((ROOT / 'lib' / 'domain').rglob('*.dart')):
            src = path.read_text(encoding='utf-8')
            self.assertNotIn(
                'package:shared_preferences/shared_preferences.dart',
                src,
                f'{path.relative_to(ROOT)} نباید مستقیم به shared_preferences وابسته باشد',
            )
        for rel in ('lib/core/history.dart', 'lib/core/history_store.dart'):
            src = (ROOT / rel).read_text(encoding='utf-8')
            self.assertNotIn('package:shared_preferences/shared_preferences.dart', src, rel)
            self.assertIn('KeyValueStore', (ROOT / 'lib' / 'core' / 'history_store.dart').read_text(encoding='utf-8'))

    def test_storage_migration_covers_all_sensitive_store_keys(self):
        mig = (ROOT / 'lib' / 'core' / 'storage_migration.dart').read_text(encoding='utf-8')
        for key in ('history_v1', 'history_v1:m:', 'active_draft_v1', 'feedback_v1'):
            self.assertIn(key, mig)


if __name__ == '__main__':
    unittest.main()
