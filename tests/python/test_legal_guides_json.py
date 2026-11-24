"""قفلِ دادهٔ راهنماها: JSON باید دقیقاً همان چیزی باشد که در Dart نوشته شده.

این آزمون دو کار می‌کند:
  ۱. نمی‌گذارد JSON از کد جدا بیفتد (هر تغییر در یکی، دیگری را قرمز می‌کند).
  ۲. ثابت می‌کند هیچ حرفی از متنِ حقوقی در ترجمه عوض نشده: هر رشته، بی‌کم‌وکاست،
     در فایلِ Dart پیدا می‌شود.

ترجمه با `tools/gen_legal_guides.py` انجام می‌شود؛ همان ابزار هم این‌جا اجرا
می‌شود، پس اگر کسی JSON را دستی ویرایش کند یا متنِ کد را عوض کند، قرمز می‌شود.
"""
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))

import gen_legal_guides  # noqa: E402

SOURCE = os.path.join(ROOT, 'lib', 'domain', 'lawyer', 'legal_guides.dart')

ALLOWED = {'id', 'title', 'triggers', 'excludes', 'priority', 'empathy', 'brief',
           'answer', 'steps', 'cautions', 'refs', 'followUp', 'templateIds', 'notes'}
REQUIRED = ('id', 'title', 'triggers', 'empathy', 'brief', 'answer', 'followUp')


def _dart():
    with open(SOURCE, encoding='utf-8') as f:
        return f.read()


def _escaped(text):
    """همان شکلی که متن در فایلِ Dart نوشته شده است."""
    return (text.replace('\\', '\\\\').replace("'", "\\'")
            .replace('\n', '\\n').replace('\t', '\\t'))


class LegalGuidesJsonTests(unittest.TestCase):
    def setUp(self):
        self.src = _dart()
        self.file = gen_legal_guides.load_json()
        self.guides = self.file['guides']

    def test_json_is_what_the_generator_makes(self):
        """JSON نباید دستی ویرایش شده باشد."""
        self.assertEqual(gen_legal_guides.build(), self.file)

    def test_every_guide_of_the_code_is_in_json(self):
        ids = re.findall(r"^    id: '([^']+)',", self.src, re.M)
        self.assertGreaterEqual(len(ids), 30, ids)
        self.assertEqual(ids, [g['id'] for g in self.guides])
        self.assertEqual(len(set(ids)), len(ids), 'شناسهٔ تکراری')

    def test_no_legal_text_was_altered(self):
        """هر رشتهٔ متنیِ JSON باید عیناً در فایلِ Dart باشد."""
        for g in self.guides:
            for key in ('title', 'empathy', 'brief', 'answer', 'followUp'):
                text = g.get(key)
                self.assertTrue(text, '%s.%s خالی است' % (g['id'], key))
                self.assertIn(_escaped(text), self.src, '%s.%s' % (g['id'], key))
            for text in g.get('steps', []) + g.get('cautions', []):
                self.assertIn(_escaped(text), self.src, '%s: %s' % (g['id'], text[:30]))
            for note in g.get('notes', []):
                self.assertIn(_escaped(note['text']), self.src, '%s note' % g['id'])

    def test_refs_and_notes_are_all_there(self):
        # یکی از هر کدام، خودِ سازنده در فایل است.
        self.assertEqual(len(self.src.split('LegalRef(')) - 2,
                         sum(len(g.get('refs', [])) for g in self.guides))
        self.assertEqual(len(self.src.split('GuideNote(')) - 2,
                         sum(len(g.get('notes', [])) for g in self.guides))

    def test_schema_is_explicit_and_closed(self):
        for g in self.guides:
            self.assertLessEqual(set(g), ALLOWED, g['id'])
            for key in REQUIRED:
                self.assertIn(key, g, g['id'])
            self.assertTrue(g['triggers'], '%s: بی‌نشانه' % g['id'])
            for group in g['triggers']:
                self.assertTrue(group, '%s: گروهِ خالی' % g['id'])
                for word in group:
                    self.assertIsInstance(word, str)
            for ref in g.get('refs', []):
                self.assertEqual(set(ref), {'law', 'article'})
                self.assertTrue(re.fullmatch(r'[0-9]+', ref['article']),
                                '%s: شمارهٔ مادهٔ نامعتبر %r' % (g['id'], ref['article']))
            for note in g.get('notes', []):
                self.assertEqual(set(note), {'cues', 'text'})
                self.assertTrue(note['cues'])
            self.assertIsInstance(g.get('priority', 0), int)

    def test_json_is_not_bundled_in_the_app(self):
        """تا وقتی بارگذار عوض نشده، این فایل نباید داخلِ APK برود."""
        self.assertFalse(os.path.exists(os.path.join(ROOT, 'assets', 'brain', 'guides')),
                         'JSON بدونِ بارگذار به assets رفت')


if __name__ == '__main__':
    unittest.main()
