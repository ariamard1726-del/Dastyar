"""قاعده‌های تطبیق واژه‌ها یک‌جا هستند و دو فایل تولیدشده تازه‌اند.

پیش‌تر فهرست ۱۵۳ واژه‌ای و آستانه‌ها در `law_terms.dart` و `law_terms.py`
دستی نگه داشته می‌شد و این آزمون فقط «واگرایی نکنند» را می‌سنجید؛ خودِ
دوتا‌بودن رفع نشده بود. حالا مرجع `dev/tools/contracts/law_terms.json` است.
"""

import json
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'brain'))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))

import gen_law_terms  # noqa: E402
import law_terms_rules  # noqa: E402
from library import read  # noqa: E402

DART_REL = 'lib/domain/advocate/law_terms.dart'
DART_RULES_REL = 'lib/domain/advocate/law_terms_rules.dart'
CONTRACT = os.path.join(ROOT, 'dev', 'tools', 'contracts', 'law_terms.json')


def _read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def _contract():
    return json.loads(_read(CONTRACT))


def _dart_generic():
    s = read(ROOT, DART_RULES_REL)
    start = s.index('static const Set<String> generic = <String>{')
    end = s.index('};', start)
    return set(re.findall(r"'([^']+)'", s[start:end]))


def _dart_number(name):
    m = re.search(
        r'static const (?:int|double) %s = ([0-9.]+);' % name,
        read(ROOT, DART_RULES_REL),
    )
    return float(m.group(1)) if m else None


class GeneratedTests(unittest.TestCase):
    def test_files_are_fresh(self):
        for path, text in gen_law_terms.targets().items():
            self.assertEqual(_read(path), text,
                             'کهنه است: %s — python3 dev/tools/gen_law_terms.py --write'
                             % os.path.relpath(path, ROOT))

    def test_word_lists_are_one(self):
        contract = set(_contract()['generic'])
        self.assertEqual(len(contract), 153)
        self.assertEqual(_dart_generic(), contract)
        self.assertEqual(set(law_terms_rules.GENERIC), contract)

    def test_thresholds_match(self):
        th = _contract()['thresholds']
        self.assertEqual(law_terms_rules.MIN_LEN, th['minLen'])
        self.assertEqual(law_terms_rules.TOP, th['top'])
        self.assertEqual(law_terms_rules.MIN_COVER, th['minCover'])
        self.assertEqual(law_terms_rules.RARE_DF, th['rareDf'])
        self.assertEqual(law_terms_rules.MAX_SPAN, th['maxSpan'])
        self.assertEqual(law_terms_rules.PHRASE_MIN_IDF, th['phraseMinIdf'])
        self.assertEqual(_dart_number('minLen'), th['minLen'])
        self.assertEqual(_dart_number('topCount'), th['top'])
        self.assertEqual(_dart_number('rareDf'), th['rareDf'])
        self.assertEqual(_dart_number('minCover'), th['minCover'])
        self.assertEqual(_dart_number('maxSpan'), th['maxSpan'])
        self.assertEqual(_dart_number('phraseMinIdf'), th['phraseMinIdf'])

    def test_ranking_and_source_match(self):
        c = _contract()
        rk = c['ranking']
        self.assertEqual(law_terms_rules.DEFAULT_PRIORITY, rk['defaultPriority'])
        self.assertEqual(law_terms_rules.MISSING_SPAN, rk['missingSpan'])
        self.assertEqual(law_terms_rules.COVER_DIGITS, rk['coverDigits'])
        self.assertEqual(law_terms_rules.RANK_COVER_DIGITS, rk['rankCoverDigits'])
        self.assertEqual(law_terms_rules.RANK_DENSITY_DIGITS, rk['rankDensityDigits'])
        self.assertEqual(law_terms_rules.MIN_PHRASE_WORDS, rk['minPhraseWords'])
        self.assertEqual(law_terms_rules.MIN_RARE_HITS, rk['minRareHits'])
        self.assertEqual(law_terms_rules.GENERAL_SOURCE, c['generalSource'])
        self.assertEqual(_dart_number('defaultPriority'), rk['defaultPriority'])
        self.assertEqual(_dart_number('missingSpan'), rk['missingSpan'])
        self.assertEqual(_dart_number('coverDigits'), rk['coverDigits'])
        self.assertEqual(_dart_number('rankCoverDigits'), rk['rankCoverDigits'])
        self.assertEqual(_dart_number('rankDensityDigits'), rk['rankDensityDigits'])
        self.assertEqual(_dart_number('minPhraseWords'), rk['minPhraseWords'])
        self.assertEqual(_dart_number('minRareHits'), rk['minRareHits'])
        self.assertIn(
            "static const String generalSource = '%s';" % c['generalSource'],
            read(ROOT, DART_RULES_REL),
        )

    def test_alias_match(self):
        alias = _contract()['alias']
        self.assertEqual(law_terms_rules.ALIAS, alias)
        dart = read(ROOT, DART_RULES_REL)
        for k, v in alias.items():
            self.assertIn("'%s': '%s'" % (k, v), dart,
                          'نگاشت %s→%s در فایل تولیدشدهٔ دارت نیست' % (k, v))

    def test_no_second_hand_written_list(self):
        # اگر کسی فهرست را دستی به law_terms.dart یا law_terms.py برگرداند، این آزمون می‌گیرد.
        dart = read(ROOT, DART_REL)
        self.assertNotIn('static const Set<String> generic = {', dart)
        self.assertNotIn('static const Map<String, String> alias = {', dart)
        self.assertNotIn('1000000', dart)
        self.assertNotIn("'دانش عمومی'", dart)

        py = read(ROOT, 'dev/tools/law_terms.py')
        self.assertNotIn("'دانش عمومی'", py)
        self.assertNotIn('return best if best is not None else 1000000', py)


if __name__ == '__main__':
    unittest.main()
