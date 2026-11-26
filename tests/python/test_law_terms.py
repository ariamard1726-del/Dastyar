"""آزمون تطبیق واژه‌های پرسش با متن قوانین (dev/tools/law_terms.py).

نمونه‌ها در tests/law_terms/cases.json است. هر نمونه یک پرسش واقعی یا گزارش‌شده
است با پاسخ مورد انتظار: آیا ماده‌ای پذیرفته شود، کدام قانون و ماده، و کدام
واژه‌ها در آن ماده نیستند. برای افزودن رگرسیون، نمونه را به همان فایل اضافه کنید.
"""

import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))

import law_terms  # noqa: E402


class LawTermsTest(unittest.TestCase):
    def test_all_cases(self):
        cases, fails = law_terms.run_cases()
        self.assertGreaterEqual(len(cases), 30)
        self.assertEqual([f[0] for f in fails], [], fails[:3])

    def test_adjacent_words_break_on_stopwords(self):
        runs = law_terms.query_runs('مبلغ و تاریخ')
        self.assertEqual(len(runs), 2)
        self.assertEqual(law_terms._pairs(runs), [])

    def test_alias_افحش_is_fahish(self):
        runs = law_terms.query_runs('غبن افحش')
        self.assertEqual(runs[0][-1], law_terms.query_terms('فاحش')[0])

    def test_span_is_minimal_window(self):
        self.assertEqual(law_terms._span(['a', 'x', 'x', 'b', 'a'], ['a', 'b']), 2)
        self.assertEqual(law_terms._span(['a', 'x'], ['a', 'b']), 10 ** 6)

    def test_single_common_greeting_is_not_a_law_match(self):
        self.assertFalse(law_terms.match('سلام')['accepted'])

    def test_unknown_word_is_reported(self):
        r = law_terms.match('لاکپشت بنفش')
        self.assertIn('لاکپشت', r['unknown'])
        self.assertFalse(r['accepted'])


if __name__ == '__main__':
    unittest.main()
