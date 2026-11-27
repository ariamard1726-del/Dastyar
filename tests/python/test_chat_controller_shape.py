"""قرارداد فاز ۴: کنترلرِ لاغر (`chat_controller.dart` < ۱۵۰ خط) و یک منبع برای هر داده.

`ChatController` پیش‌تر سه مسئولیتِ جدا را با هم داشت: فرمِ پیش‌نویس
(`DraftFlow`)، حدسِ موضوع با مدل (`GuessFlow`) و خطِ پردازش و ذخیرهٔ پاسخ
(`ReplyFlow`). این نگهبان قفل می‌کند که:

1. `lib/ui/chat_controller.dart` زیرِ ۱۵۰ خط بماند؛
2. کنترلر فقط سیم‌کشی بین `DraftFlow`، `GuessFlow` و `ReplyFlow` باشد و
   منطق پردازش/ذخیره/حدس دوباره به آن برنگردد؛
3. هیچ فایل داده‌ای دو نسخهٔ تکراری (هم‌نام یا هم‌محتوا) در مسیرهای داده
   نداشته باشد؛
4. آزمون واحدِ جریان‌های جداشده و مستنداتِ به‌روزشدهٔ معماری/فازها وجود دارد.
"""

import hashlib
import os
import sys
import unittest
from collections import defaultdict

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'dev', 'tools'))
from library import line_count, read as lib_read  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONTROLLER_REL = 'lib/ui/chat_controller.dart'
FLOWS = (
    ('lib/ui/draft_flow.dart', 'DraftFlow'),
    ('lib/ui/guess_flow.dart', 'GuessFlow'),
    ('lib/ui/reply_flow.dart', 'ReplyFlow'),
)
DART_TEST = os.path.join(ROOT, 'test', 'app', 'chat_flows_test.dart')
ARCH_DOC = os.path.join(ROOT, 'docs', 'ARCHITECTURE.md')
MAX_CONTROLLER_LINES = 149


class ChatControllerShapeTests(unittest.TestCase):
    def test_chat_controller_is_under_150_lines(self):
        lines = line_count(ROOT, CONTROLLER_REL)
        self.assertLessEqual(
            lines, MAX_CONTROLLER_LINES,
            'chat_controller.dart از سقف ۱۵۰ خط گذشت: %d خط' % lines,
        )

    def test_chat_controller_delegates_to_three_flows(self):
        ctrl = lib_read(ROOT, CONTROLLER_REL)
        for rel, cls in FLOWS:
            path = os.path.join(ROOT, rel)
            self.assertTrue(os.path.exists(path), 'همکار گم شده: %s' % rel)
            self.assertIn('class %s {' % cls, lib_read(ROOT, rel))
            self.assertIn('%s(' % cls, ctrl, 'کنترلر %s را نساخته' % cls)
        for gone in ('_process(', '_saveSession(', '_reportFailure(',
                     'StoredMsg(', 'DraftCheckpointStore.clear('):
            self.assertNotIn(gone, ctrl,
                             'منطق پردازش/ذخیره دوباره داخل کنترلر برگشت: %s' % gone)

    def test_no_duplicate_data_files(self):
        """هیچ فایل داده‌ای نباید دو نسخه در مخزن داشته باشد."""
        by_hash = defaultdict(list)
        by_name = defaultdict(list)
        for top in ('assets', 'eval', 'tests', 'dev'):
            base = os.path.join(ROOT, top)
            for dirpath, _dirs, filenames in os.walk(base):
                for fn in sorted(filenames):
                    if not fn.endswith(('.json', '.txt', '.tsv')):
                        continue
                    full = os.path.join(dirpath, fn)
                    rel = os.path.relpath(full, ROOT)
                    by_name[fn].append(rel)
                    digest = hashlib.sha256(
                        lib_read(full).encode('utf-8')).hexdigest()
                    by_hash[digest].append(rel)
        dup_names = {k: v for k, v in by_name.items() if len(v) > 1}
        dup_hashes = [v for v in by_hash.values() if len(v) > 1]
        self.assertEqual(dup_names, {}, 'فایل دادهٔ هم‌نام تکراری: %s' % dup_names)
        self.assertEqual(dup_hashes, [], 'فایل دادهٔ هم‌محتوای تکراری: %s' % dup_hashes)

    def test_dart_flow_tests_and_docs_exist(self):
        self.assertTrue(os.path.exists(DART_TEST),
                        'آزمون واحد جریان‌های کنترلر وجود ندارد')
        src = lib_read(DART_TEST)
        for cls in ('GuessFlow', 'ReplyFlow', 'ChatController'):
            self.assertIn(cls, src)
        arch = lib_read(ARCH_DOC)
        for token in ('guess_flow', 'reply_flow', 'draft_flow'):
            self.assertIn(token, arch)


if __name__ == '__main__':
    unittest.main()
