"""نگهبان بودجهٔ رابط کاربری: نمایش تدریجی نباید دوباره طولانی شود."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVEAL = ROOT / 'lib' / 'ui' / 'widgets' / 'reveal_text.dart'


def _constant(src, name):
    m = re.search(r'static const int %s = (\d+);' % name, src)
    assert m, '%s پیدا نشد' % name
    return int(m.group(1))


class UiBudgetTest(unittest.TestCase):
    def test_reveal_animation_has_a_short_cap(self):
        src = REVEAL.read_text(encoding='utf-8')
        self.assertLessEqual(_constant(src, 'maxMs'), 6000,
                             'سقف نگارش دوباره طولانی شد')
        self.assertLessEqual(_constant(src, 'msPerChar'), 8)
        self.assertLessEqual(_constant(src, 'msPerCharLong'), 5)
        # `setState` در میانهٔ build ممنوع است؛ حالت تمامشده به فریم بعد موکول
        # میشود.
        self.assertIn('addPostFrameCallback', src)


if __name__ == '__main__':
    unittest.main()
