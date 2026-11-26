"""نگهبان بودجهٔ رابط کاربری: پاسخ بدون نگارش تدریجی و بدون setState در هر فریم."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVEAL = ROOT / 'lib' / 'ui' / 'widgets' / 'reveal_text.dart'
BUBBLES = ROOT / 'lib' / 'ui' / 'widgets' / 'chat_bubbles.dart'
BOT_VIEW = ROOT / 'lib' / 'ui' / 'widgets' / 'bot_message_view.dart'
PAGE = ROOT / 'lib' / 'ui' / 'chat_page.dart'


class UiBudgetTest(unittest.TestCase):
    def test_reveal_animation_is_gone(self):
        src = '\n'.join(l for l in REVEAL.read_text(encoding='utf-8').splitlines()
                        if not l.strip().startswith('///'))
        for banned in ('AnimationController', 'setState', 'msPerChar', 'maxMs',
                       'onTick', 'SchedulerBinding', 'GestureDetector'):
            self.assertNotIn(banned, src,
                             'نگارش تدریجی دوباره برگشت: %s' % banned)
        self.assertIn("'...'", src, 'حالت «در حال نوشتن» باید بماند')
        self.assertIn('TypingDots', src)
        self.assertIn('SelectableText', src)

    def test_no_per_frame_scroll_hook_is_left(self):
        for path in (BUBBLES, BOT_VIEW, PAGE):
            self.assertNotIn('onRevealTick', path.read_text(encoding='utf-8'),
                             '%s هنوز دنبالهٔ انیمیشن را حمل میکند' % path.name)


if __name__ == '__main__':
    unittest.main()
