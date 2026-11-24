"""شکلِ `Advocate`: گاد-آبجکت نباید بی‌صدا برگردد.

معیارِ «رفع شد» این نیست که فایل کوچک شود؛ این است که:

۱. وضعیتِ ساختِ پاسخ (متنِ مانده، سقفِ تکرارِ پرسش، دکمهٔ مرتبط، استنادهای
   آخر) صاحبِ جدا داشته باشد و روی `Advocate` برنگردد؛
۲. مسیرهای یک‌نوبتیِ `_reply` نام داشته باشند (`_route*`) و دوباره داخلِ خودِ
   تابع چپانده نشوند؛
۳. تعداد فیلدهای حالتی و درازای `_reply` از سقفِ همین امروز بالاتر نرود.

این آزمون عمداً عددی است: تغییرِ معماری بدونِ عدد، در بازبینی بعدی دوباره
«متنِ خوب» می‌شود.
"""

import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADVOCATE_DIR = os.path.join(ROOT, 'lib', 'domain', 'advocate')
ADVOCATE = os.path.join(ADVOCATE_DIR, 'advocate.dart')
VOICE = os.path.join(ADVOCATE_DIR, 'reply_voice.dart')
ROUTES = os.path.join(ADVOCATE_DIR, 'advocate_routes.dart')

# سقف‌های امروز؛ عبور از آن‌ها یعنی بازگشت به عقب.
MAX_STATE_FIELDS = 42
MAX_REPLY_LINES = 345
MIN_ROUTES = 12


def _read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def _class_body(src, name='Advocate'):
    lines = src.split('\n')
    start = next(i for i, l in enumerate(lines) if l.startswith('class %s {' % name))
    end = next(i for i in range(start + 1, len(lines)) if lines[i] == '}')
    return lines[start:end]


def _method(src, signature):
    """متنِ کامل یک متد (با شمارش آکولاد)."""
    lines = src.split('\n')
    start = next(i for i, l in enumerate(lines) if signature in l)
    depth = 0
    started = False
    for k in range(start, len(lines)):
        depth += lines[k].count('{') - lines[k].count('}')
        if '{' in lines[k]:
            started = True
        # متدِ فلش‌دار (`=> ...;`) در خطِ امضا بسته نمی‌شود؛ تا `;` ادامه می‌دهیم.
        if started and depth == 0 and lines[k].rstrip().endswith((';', '}')):
            return '\n'.join(lines[start:k + 1])
    raise AssertionError('بسته نشد: %s' % signature)


# فقط اعلانِ فیلد: خطی که پرانتز ندارد (یعنی متد/گتر نیست) و به `;` یا مقدار
# ختم می‌شود.
STATE_FIELD = re.compile(
    r'^  (?:final|late final|late)\s+[\w<>?, ]+\s+\w+\s*(?:=|;)'
    r'|^  (?:bool|int|double|String|List<[^>]*>|Map<[^>]*>|Set<[^>]*>|Topic\?)\s+\w+\s*(?:=|;)')

MOVED_FIELDS = ['_rest', '_offeredMore', '_lastAsk', '_askRepeats',
                '_relevantChip', '_vary', '_said', '_lastBody', '_lastLaws']


class ShapeTests(unittest.TestCase):
    def setUp(self):
        self.src = _read(ADVOCATE)

    def test_state_fields_do_not_grow(self):
        fields = [l for l in _class_body(self.src) if STATE_FIELD.match(l)]
        self.assertLessEqual(
            len(fields), MAX_STATE_FIELDS,
            'فیلد حالتیِ Advocate زیاد شد (%d):\n%s' % (len(fields), '\n'.join(fields)))

    def test_reply_does_not_grow(self):
        body = _method(self.src, 'AdvocateReply _reply(String raw')
        n = len(body.split('\n'))
        self.assertLessEqual(n, MAX_REPLY_LINES,
                             '_reply دوباره بزرگ شد: %d خط' % n)

    def test_output_state_has_its_own_owner(self):
        voice = _read(VOICE)
        for name in ['rest', 'offeredMore', 'lastAsk', 'askRepeats',
                     'relevantChip', 'lastLaws', 'lastBody', 'said']:
            self.assertRegex(voice, r'\n  [^(\n]*\b%s\b[^(\n]*=' % name,
                             '%s باید صاحبش ReplyVoice باشد' % name)
        for old in MOVED_FIELDS:
            self.assertNotIn('  String %s =' % old, self.src, old)
            self.assertNotIn('  int %s =' % old, self.src, old)
            self.assertNotIn('  bool %s =' % old, self.src, old)

    def test_out_is_a_delegate(self):
        body = _method(self.src, 'AdvocateReply _out(')
        self.assertIn('voice.out', body)
        # منطقِ استناد و برش نباید داخلِ Advocate برگردد.
        for moved in ['replaceAllMapped', 'refOne', 'askRepeats', 'cutText(']:
            self.assertNotIn(moved, body, moved)

    def test_single_turn_routes_are_named(self):
        routes = _read(ROUTES)
        handlers = re.findall(r'AdvocateReply\? (_route\w+)\(', routes)
        self.assertGreaterEqual(len(handlers), MIN_ROUTES, handlers)
        for h in handlers:
            self.assertIn('%s(' % h, self.src, 'مسیر %s از _reply صدا زده نمی‌شود' % h)
        # دوباره‌چپاندنِ همین بلوک‌ها در `_reply` نباید ممکن باشد.
        reply = _method(self.src, 'AdvocateReply _reply(String raw')
        for marker in ['isComplaintNoOption', 'wrongChip', 'فقط حرف بود']:
            self.assertNotIn(marker, reply, marker)

    def test_part_files_exist(self):
        for part in re.findall(r"^part '([^']+)'", self.src, re.M):
            self.assertTrue(os.path.exists(os.path.join(ADVOCATE_DIR, part)), part)


if __name__ == '__main__':
    unittest.main()
