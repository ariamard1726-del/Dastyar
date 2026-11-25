"""مهاجرت تدریجی از آزمون متنمحور به آزمون ساختاری: سقف ثبتشده رشد نکند."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TESTS = ROOT / 'test'

# تعداد امروزِ `expect(x.text, contains('...'))`. هر کاهش خوب است؛ افزایش
# یعنی کسی دوباره قرارداد پاسخ را به جملهٔ دقیق گره زده است.
TEXT_CONTAINS_CAP = 50
PATTERN = re.compile(r'expect\([^,]*\.text, contains\(')


class StructuralTestTests(unittest.TestCase):
    def test_text_contains_does_not_grow(self):
        found = []
        for path in TESTS.rglob('*.dart'):
            for no, line in enumerate(path.read_text(encoding='utf-8').splitlines(), 1):
                if PATTERN.search(line):
                    found.append('%s:%d' % (path.relative_to(ROOT), no))
        self.assertLessEqual(len(found), TEXT_CONTAINS_CAP,
                             'آزمون متنمحور زیاد شد: %s' % found[:10])

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
