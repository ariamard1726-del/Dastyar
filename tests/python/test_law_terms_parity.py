"""آینهٔ پایتون و دارتِ تطبیق واژه‌ها باید یکی بماند.

`lib/domain/advocate/law_terms.dart` و `tools/law_terms.py` دو پیاده‌سازی از
یک قاعده‌اند. اگر فهرست ایست‌واژه‌ها یا آستانه‌ها فقط در یکی عوض شود،
ارزیابی پایتون نتیجهٔ دیگری از برنامه می‌دهد و آزمون‌های سبز، دروغ می‌شوند.
"""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DART = os.path.join(ROOT, 'lib', 'domain', 'advocate', 'law_terms.dart')
PY = os.path.join(ROOT, 'tools', 'law_terms.py')


def _read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def _dart_generic():
    s = _read(DART)
    start = s.index('static const Set<String> generic = {')
    end = s.index('};', start)
    return set(re.findall(r"'([^']+)'", s[start:end]))


def _py_generic():
    s = _read(PY)
    start = s.index('GENERIC = {')
    end = s.index('\n}', start)
    return set(re.findall(r"'([^']+)'", s[start:end]))


def _dart_number(name):
    s = _read(DART)
    m = re.search(r'static const (?:int|double) %s = ([0-9.]+);' % name, s)
    return float(m.group(1)) if m else None


def _py_number(name):
    s = _read(PY)
    m = re.search(r'^%s = ([0-9.]+)$' % name, s, re.M)
    return float(m.group(1)) if m else None


class LawTermsParityTests(unittest.TestCase):
    def test_generic_sets_are_identical(self):
        dart, py = _dart_generic(), _py_generic()
        self.assertTrue(dart)
        self.assertEqual(sorted(dart - py), [], 'فقط در دارت')
        self.assertEqual(sorted(py - dart), [], 'فقط در پایتون')

    def test_thresholds_match(self):
        pairs = [
            ('minLen', 'MIN_LEN'),
            ('topCount', 'TOP'),
            ('rareDf', 'RARE_DF'),
            ('minCover', 'MIN_COVER'),
            ('phraseMinIdf', 'PHRASE_MIN_IDF'),
            ('maxSpan', 'MAX_SPAN'),
        ]
        for dart_name, py_name in pairs:
            self.assertEqual(_dart_number(dart_name), _py_number(py_name),
                             '%s/%s' % (dart_name, py_name))

    def test_everyday_words_are_not_offered_as_legal_terms(self):
        # این واژه‌ها در گفتار روزمره‌اند و نباید در پاسخ بیایند که
        # «در قوانین من نیست»; فقط وقتی واژهٔ حقوقی باشند معنا دارند.
        for w in ('توانم', 'اگر', 'کاری', 'انجام', 'باشد', 'برای'):
            self.assertIn(w, _dart_generic(), w)
            self.assertIn(w, _py_generic(), w)


if __name__ == '__main__':
    unittest.main()
