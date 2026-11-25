"""ابزارِ مشترکِ خواندن، خودش آزمون دارد.

اگر این ماژول اشتباه بخواند، همهٔ نگهبان‌هایی که رویش سوارند سبزِ دروغ می‌دهند.
پس این‌جا خودش سنجیده می‌شود: سر + `part`ها، بدنهٔ کلاس، `extension`ها و
«چه کسی این نام را تعریف می‌کند».
"""

import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))

from library import DartLibrary, dart_files, line_count, parts_of, read  # noqa: E402
from lines import line_count as lines_count  # noqa: E402

ADVOCATE = 'lib/domain/advocate/advocate.dart'


class LibraryToolTests(unittest.TestCase):
    def setUp(self):
        self.lib = DartLibrary(ROOT, ADVOCATE)

    def test_head_and_parts_are_one_text(self):
        self.assertIn('class Advocate {', self.lib.text)
        self.assertGreaterEqual(len(self.lib.parts), 25,
                                'کتابخانهٔ وکیل باید ده‌ها بخش داشته باشد')
        for name, text in self.lib.parts:
            self.assertTrue(text.strip(), 'بخشِ خالی: %s' % name)
            self.assertIn("part of 'advocate.dart';", text,
                          '%s باید `part of advocate.dart` باشد' % name)

    def test_class_body_stops_at_class_end(self):
        body = self.lib.class_body('Advocate')
        self.assertEqual(body[0], 'class Advocate {')
        self.assertEqual(body[-1], '}')
        text = '\n'.join(body)
        self.assertIn('final CaseFile file = CaseFile();', text)
        # متدها در `extension`ها هستند، نه در بدنهٔ کلاس.
        self.assertNotIn('AdvocateReply _reply(', text)

    def test_extensions_are_found_by_type(self):
        guarded = self.lib.extensions_on('Advocate')
        self.assertGreaterEqual(len(guarded), 5, guarded)
        self.assertTrue(any('_ReplyPipeline' in e for e in guarded))
        self.assertTrue(any('_ReplyGuards' in e for e in guarded))
        # نوعِ دیگری هم extension دارد، ولی از این خانواده نیست.
        flow = self.lib.extensions_on('CaseFlow')
        self.assertTrue(any('_CaseFacts' in e for e in flow))
        self.assertFalse(any('_ReplyPipeline' in e for e in flow))

    def test_definition_of_separates_definition_from_call(self):
        self.assertEqual(self.lib.definition_of('_reply'),
                         ['advocate_reply.dart'])
        # `_out` صدا زده می‌شود ولی در `advocate.dart` تعریف شده است.
        # `CaseFlow` هم `_out` خودش را دارد؛ ادعا «کجاست» است، نه «یکتاست».
        self.assertIn('advocate.dart', self.lib.definition_of('_out'))

    def test_line_count_is_shared(self):
        rel = 'lib/domain/advocate/advocate.dart'
        self.assertEqual(line_count(ROOT, rel), lines_count(os.path.join(ROOT, rel)))
        self.assertEqual(line_count(ROOT, ADVOCATE), read(ROOT, ADVOCATE).count('\n'))

    def test_every_dart_file_is_reachable(self):
        files = dart_files(ROOT)
        self.assertGreaterEqual(len(files), 140, len(files))
        self.assertIn(ADVOCATE, files)
        self.assertTrue(all(f.startswith('lib/') for f in files))

    def test_parts_are_listed_in_order(self):
        parts = parts_of(ROOT, ADVOCATE)
        self.assertEqual(parts[0], 'advocate_topic.dart')
        self.assertIn('advocate_reply_guard.dart', parts)
        self.assertLess(parts.index('advocate_reply.dart'),
                        parts.index('advocate_reply_guard.dart'))


if __name__ == '__main__':
    unittest.main()
