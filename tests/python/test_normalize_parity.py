import json
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'brain'))

import common  # noqa: E402

FIXTURE = os.path.join(ROOT, 'tests', 'normalize_cases.json')
# نگاشت دیگر در `persian_text.dart` دستی نوشته نمی‌شود؛ از قرارداد تولید
# می‌شود. این آزمون نگهبانِ لایهٔ پایه است، نه نگهبانِ محلِ نگاشت.
DART = os.path.join(ROOT, 'lib', 'core', 'text_norm_rules.dart')


def cases():
    with open(FIXTURE, encoding='utf-8') as f:
        return json.load(f)['cases']


def dart_map():
    """نگاشت نویسه‌ها را از سورس دارت می‌خواند."""
    with open(DART, encoding='utf-8') as f:
        s = f.read()
    start = s.index('charMap = <String, String>{')
    end = s.index('};', start)
    pairs = re.findall(r"'([^'])'\s*:\s*'([^'])'", s[start:end])
    return {a: b for a, b in pairs}


class NormalizeParityTests(unittest.TestCase):
    def test_fixture_outputs_match_python(self):
        for c in cases():
            self.assertEqual(common.normalize(c['in']), c['out'], c['in'])

    def test_dart_character_map_matches_python(self):
        # اگر کسی یک نگاشت را فقط در دارت عوض کند، این آزمون می‌گیردش.
        self.assertEqual(dart_map(), common._MAP)

    def test_zwnj_and_digits_rules(self):
        f = {c['in']: c['out'] for c in cases()}
        self.assertEqual(f['مدرسه\u200cام'], 'مدرسه ام')
        self.assertEqual(f['ماده ١٢٣'], 'ماده 123')
        self.assertEqual(f['مـاده ۱۰'], 'ماده 10')
        self.assertNotIn('\u200c', ''.join(f.values()))


if __name__ == '__main__':
    unittest.main()
