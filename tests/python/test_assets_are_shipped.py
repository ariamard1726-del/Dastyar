"""هر مسیرِ `assets/` که کد می‌خواند، باید هم روی دیسک باشد و هم در pubspec.

این آزمون یک کلاسِ خطای *زمانِ اجرا* را می‌گیرد که کامپایلر نمی‌بیند: فایلی که
در کد خوانده می‌شود ولی در `pubspec.yaml` اعلام نشده، در بستهٔ نهایی نیست و
`rootBundle` هنگامِ اجرا استثنا می‌دهد. بارگذارهای موتور آن استثنا را در
`warnings` می‌ریزند، پس برنامه «کار می‌کند» ولی بی‌صدا بی‌دانش می‌شود — بدترین
نوعِ خرابی، چون در آزمون‌های واحد دیده نمی‌شود.

پس دو چیز سنجیده می‌شود:

۱. هر مسیرِ `assets/...` که در `lib/` نوشته شده، روی دیسک وجود دارد؛
۲. همان مسیر با یکی از اعلان‌های `assets:` در `pubspec.yaml` پوشیده می‌شود
   (اعلانِ پوشه، همهٔ فایل‌های زیرش را می‌پوشاند).
"""

import glob
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PUBSPEC = os.path.join(ROOT, 'pubspec.yaml')

ASSET_RE = re.compile(r"['\"](assets/[A-Za-z0-9_./-]*)")


def _declared():
    """اعلان‌های `assets:` از pubspec، به‌صورتِ مسیرِ نسبی."""
    out = []
    in_assets = False
    with open(PUBSPEC, encoding='utf-8') as f:
        for line in f:
            if re.match(r'^\s*assets:\s*$', line):
                in_assets = True
                continue
            if in_assets:
                m = re.match(r'^\s*-\s*(\S+)\s*$', line)
                if m:
                    out.append(m.group(1))
                elif line.strip() and not line.startswith(' ' * 4):
                    in_assets = False
    return out


def _literals():
    seen = set()
    for p in glob.glob(os.path.join(ROOT, 'lib', '**', '*.dart'), recursive=True):
        with open(p, encoding='utf-8') as f:
            for m in ASSET_RE.finditer(f.read()):
                seen.add(m.group(1))
    return sorted(seen)


def _covered(literal, entries):
    """آیا این مسیر با یکی از اعلان‌ها پوشیده می‌شود؟"""
    norm = literal.rstrip('/')
    for e in entries:
        en = e.rstrip('/')
        if norm == en or norm.startswith(en + '/'):
            return True
    return False


class AssetShippingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.entries = _declared()
        cls.literals = _literals()

    def test_pubspec_declares_assets(self):
        self.assertGreater(len(self.entries), 10, 'اعلان‌های assets کم شد')

    def test_declared_entries_exist_on_disk(self):
        missing = [e for e in self.entries
                   if not os.path.exists(os.path.join(ROOT, e.rstrip('/')))]
        self.assertEqual(missing, [], 'اعلانِ assets به مسیرِ ناموجود: %s' % missing)

    def test_every_literal_exists_on_disk(self):
        missing = [a for a in self.literals
                   if not os.path.exists(os.path.join(ROOT, a))]
        self.assertEqual(missing, [], 'کد مسیرِ ناموجود را می‌خواند: %s' % missing)

    def test_every_literal_is_shipped(self):
        """مسیرِ خوانده‌شده ولی اعلام‌نشده، در بستهٔ نهایی نیست."""
        uncovered = [a for a in self.literals if not _covered(a, self.entries)]
        self.assertEqual(uncovered, [],
                         'این مسیرها در pubspec اعلام نشده‌اند: %s' % uncovered)

    def test_every_json_asset_parses(self):
        """فایلِ بریده یا خراب، هنگامِ بارگذاری استثنا می‌دهد و در `warnings`
        گم می‌شود؛ پس همان‌جا سنجیده می‌شود."""
        import json
        bad = []
        paths = glob.glob(os.path.join(ROOT, 'assets', '**', '*.json'),
                          recursive=True)
        self.assertGreater(len(paths), 15, 'داراییِ JSON کمتر از انتظار')
        for p in paths:
            try:
                with open(p, encoding='utf-8') as f:
                    data = json.load(f)
            except Exception as exc:  # noqa: BLE001
                bad.append('%s: %s' % (os.path.relpath(p, ROOT), exc))
                continue
            if data in ({}, [], None, ''):
                bad.append('%s: خالی' % os.path.relpath(p, ROOT))
        self.assertEqual(bad, [], 'داراییِ JSON خراب یا خالی: %s' % bad)

    def test_the_guard_sees_the_real_thing(self):
        """اگر اسکن هیچ چیزی نبیند، آزمونِ سبز یعنی هیچ."""
        self.assertGreaterEqual(len(self.literals), 20,
                                'مسیرهای assets کمتر از انتظار پیدا شد')


if __name__ == '__main__':
    unittest.main()
