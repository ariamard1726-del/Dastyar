"""صفر تحملِ assertion متنی: قرارداد پاسخ نباید به جملهٔ دقیق گره بخورد."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / 'test'

# هر `expect(...text..., contains(...))` — مستقیم یا درون `isNot` — ممنوع است.
# تنها راهِ آزمودنِ پاسخ، خواندنِ فیلدهای ساختاری (`source`, `chips`, `laws`,
# `ask`, وضعیت پرونده) است. نگهبانِ قدیمی سقفِ ۱۱۹ را مجاز میداشت؛ اکنون صفر.
PATTERN = re.compile(
    r'expect\([^\n]*\.text[^\n]*\bcontains\s*\(')


def _comment(line):
    stripped = line.lstrip()
    return stripped.startswith('//') or stripped.startswith('*')


class StructuralTestTests(unittest.TestCase):
    def test_no_text_contains_assertions(self):
        found = []
        for path in TESTS.rglob('*.dart'):
            for no, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
                if not _comment(line) and PATTERN.search(line):
                    found.append('%s:%d' % (path.relative_to(ROOT), no))
        self.assertEqual(found, [],
                         'آزمون متنمحور تازه: %s' % found[:10])

    def test_guard_catches_positive_and_negative_forms(self):
        for sample in (
                "expect(r.text, contains('سلام'));",
                "expect(reply.text, isNot(contains('خطا')));",
                "expect(r.text.trim(), contains('متن'));"):
            self.assertIsNotNone(PATTERN.search(sample), sample)
        self.assertIsNone(PATTERN.search('expect(r.laws, isNotEmpty);'))

    def test_structural_helper_exists_and_is_used(self):
        helper = TESTS / 'support' / 'reply_shape.dart'
        self.assertTrue(helper.is_file())
        src = helper.read_text(encoding='utf-8')
        for name in ('expectSource', 'expectChip', 'expectTopic', 'expectCited'):
            self.assertIn('void %s(' % name, src)
        user = (TESTS / 'advocate' / 'reply_shape_test.dart').read_text(encoding='utf-8')
        self.assertIn('expectSource(', user)
        self.assertIn('expectTopic(', user)


if __name__ == '__main__':
    unittest.main()
