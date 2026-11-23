"""نگهبان معماری و هم‌خوانی داده‌ها: وابستگی‌های مجاز بین لایه‌ها، دارایی‌های اعلام‌شده،
و هم‌خوانی پاسخ‌های ثابت میان JSON و Dart.

این آزمون‌ها بدون Flutter SDK اجرا می‌شوند تا هر شکستن قاعده‌ها در همان مرحلهٔ
`unittest` دیده شود، نه فقط در CI فلاتر.
"""

import json
import os
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / 'lib'
IMPORT_RE = re.compile(r"^import\s+'([^']+)'", re.M)

# بدهی شناخته‌شده: این فایل‌های domain به ThemeMode/ChangeNotifier فلاتر وابسته‌اند.
# هر فایل جدیدی که بیاید باید از اینجا اجازه بگیرد؛ آزمون عمداً سخت‌گیر است.
DOMAIN_FLUTTER_ALLOWLIST = {'lib/domain/settings.dart'}


def _imports(path):
    return IMPORT_RE.findall(path.read_text(encoding='utf-8'))


def _layer(rel):
    parts = rel.split('/')
    return parts[1] if len(parts) > 2 else ''


class LayerRulesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = sorted(p for p in LIB.rglob('*.dart'))

    def rel(self, p):
        return p.relative_to(ROOT).as_posix()

    def test_core_never_imports_domain_or_ui(self):
        for p in self.files:
            rel = self.rel(p)
            if _layer(rel) != 'core':
                continue
            for imp in _imports(p):
                self.assertFalse(
                    imp.startswith(('package:dastyar/domain/', 'package:dastyar/ui/')),
                    f'{rel} وابستگی رو به بالا دارد: {imp}')

    def test_core_only_uses_flutter_services_not_widgets(self):
        for p in self.files:
            rel = self.rel(p)
            if _layer(rel) != 'core':
                continue
            for imp in _imports(p):
                if imp.startswith('package:flutter/'):
                    self.assertEqual(imp, 'package:flutter/services.dart',
                                     f'{rel} از ویجت‌های فلاتر استفاده می‌کند: {imp}')

    def test_domain_never_imports_ui(self):
        for p in self.files:
            rel = self.rel(p)
            if _layer(rel) != 'domain':
                continue
            for imp in _imports(p):
                self.assertFalse(imp.startswith('package:dastyar/ui/'),
                                 f'{rel} به ui وابسته است: {imp}')

    def test_domain_has_no_new_widget_or_share_dependencies(self):
        for p in self.files:
            rel = self.rel(p)
            if _layer(rel) != 'domain' or rel in DOMAIN_FLUTTER_ALLOWLIST:
                continue
            for imp in _imports(p):
                self.assertNotIn(imp, ('package:flutter/material.dart',
                                       'package:flutter/widgets.dart',
                                       'package:share_plus/share_plus.dart'),
                                 f'{rel} وابستگی UI دارد: {imp}')

    def test_allowlisted_domain_files_exist(self):
        for rel in DOMAIN_FLUTTER_ALLOWLIST:
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_ui_widgets_do_not_depend_on_ui_pages(self):
        # ویجت‌ها باید مستقل از صفحه‌ها باشند تا چرخهٔ وابستگی پیش نیاید.
        for p in self.files:
            rel = self.rel(p)
            if not rel.startswith('lib/ui/widgets/'):
                continue
            for imp in _imports(p):
                self.assertNotIn(imp, ('package:dastyar/ui/chat_page.dart',
                                       'package:dastyar/ui/settings_page.dart'), rel)

    def test_every_package_import_resolves_to_a_file(self):
        for p in list(self.files) + sorted((ROOT / 'test').rglob('*.dart')):
            for imp in _imports(p):
                if imp.startswith('package:dastyar/'):
                    target = ROOT / 'lib' / imp[len('package:dastyar/'):]
                    self.assertTrue(target.is_file(), f'{self.rel(p)} → {imp}')


class AssetConsistencyTest(unittest.TestCase):
    def _pubspec_assets(self):
        out = []
        in_assets = False
        for line in (ROOT / 'pubspec.yaml').read_text(encoding='utf-8').splitlines():
            if line.strip() == 'assets:':
                in_assets = True
                continue
            if in_assets:
                m = re.match(r'^\s+-\s+(\S+)\s*$', line)
                if m:
                    out.append(m.group(1))
                elif line.strip() and not line.startswith(' ' * 4):
                    in_assets = False
        return out

    def test_every_declared_asset_exists(self):
        for a in self._pubspec_assets():
            self.assertTrue((ROOT / a).exists(), f'دارایی اعلام‌شده نیست: {a}')

    def test_lease_qa_is_declared_as_asset(self):
        self.assertIn('assets/qa/', self._pubspec_assets())

    def test_replies_json_matches_dart_defaults_one_to_one(self):
        data = json.loads((ROOT / 'assets/replies.json').read_text(encoding='utf-8'))
        dart = (LIB / 'core/replies.dart').read_text(encoding='utf-8')
        block = re.search(r'defaults\s*=\s*\{(.*?)\n  \};', dart, re.S)
        self.assertIsNotNone(block, 'بلوک defaults پیدا نشد')
        dart_keys = set(re.findall(r"^\s+'([a-z0-9_]+)':", block.group(1), re.M))
        self.assertEqual(set(data), dart_keys)
        for k, v in data.items():
            self.assertTrue(str(v).strip(), k)

    def test_no_legacy_counselor_reply_keys_remain(self):
        data = json.loads((ROOT / 'assets/replies.json').read_text(encoding='utf-8'))
        legacy = [k for k in data if re.match(r'^(counselor_|ci_|cq_|counsel_)', k)]
        self.assertEqual(legacy, [], 'کلیدهای مشاورهٔ حذف‌شده هنوز هستند')

    def test_lease_qa_refs_point_to_known_laws(self):
        data = json.loads((ROOT / 'assets/qa/lease_qa.json').read_text(encoding='utf-8'))
        for it in data['items']:
            for ref in it['refs']:
                law = ref.split(':')[0]
                self.assertIn(law, data['law_titles'], it['id'])

    def test_architecture_docs_and_diagrams_exist(self):
        for rel in ('docs/ARCHITECTURE.md', 'docs/diagrams/layers.mmd',
                    'docs/diagrams/message_flow.mmd'):
            self.assertTrue((ROOT / rel).is_file(), rel)

    def test_gitignore_covers_local_properties(self):
        lines = (ROOT / '.gitignore').read_text(encoding='utf-8').splitlines()
        self.assertIn('local.properties', [l.strip() for l in lines])


if __name__ == '__main__':
    unittest.main()
