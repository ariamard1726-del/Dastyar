import json
import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'brain'))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))

import common  # noqa: E402
import gen_text_norm  # noqa: E402
from library import read  # noqa: E402
import text_norm_rules  # noqa: E402

GOLDEN = os.path.join(ROOT, 'tests', 'text_norm_golden.json')
NORM_CASES = os.path.join(ROOT, 'tests', 'text_norm_norm_cases.json')


def _json(path):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


class ContractTests(unittest.TestCase):
    """قاعده‌ها یک‌جا هستند و فایل‌های تولیدشده تازه‌اند."""

    def test_generated_files_are_fresh(self):
        for path, text in gen_text_norm.targets().items():
            with open(path, encoding='utf-8') as f:
                self.assertEqual(f.read(), text,
                                 'کهنه است: %s — python3 dev/tools/gen_text_norm.py --write'
                                 % os.path.relpath(path, ROOT))

    def test_dart_rules_carry_the_same_values(self):
        dart = read(ROOT, 'lib/core/text_norm_rules.dart')
        contract = gen_text_norm.load()
        for ch, rep in contract['chars']['map'].items():
            self.assertIn("'%s': '%s'" % (ch, rep), dart, ch)
        for pattern in (contract['norm']['punct'], contract['norm']['dot'],
                        contract['norm']['joinMi']):
            self.assertIn("r'%s'" % pattern, dart, pattern)
        for pattern, rep in contract['norm']['canon']:
            self.assertIn("r'%s', '%s'" % (pattern, rep), dart, pattern)
        self.assertEqual(contract['chars']['lowercase'], text_norm_rules.LOWERCASE)
        self.assertEqual(len(contract['norm']['canon']), len(text_norm_rules.CANON))

        tok = contract['tokenize']
        self.assertEqual(text_norm_rules.NONWORD_PATTERN, tok['nonWord'])
        self.assertIn("r'%s'" % tok['nonWord'], dart)
        self.assertEqual(text_norm_rules.STEM_MIN_STEM, tok['stemMinStem'])
        self.assertEqual(list(text_norm_rules.SUFFIXES), tok['suffixes'])
        self.assertEqual(list(text_norm_rules.SUFFIXES_INDEX), tok['suffixesIndex'])
        self.assertEqual(text_norm_rules.STOP, frozenset(tok['stop']))

        for key in ('tools', 'terms'):
            sp = contract['spaced'][key]
            self.assertEqual(text_norm_rules.SPACED[key]['map'], sp['map'])
            self.assertEqual(text_norm_rules.SPACED[key]['punct'], sp['punct'])
            self.assertEqual(text_norm_rules.SPACED[key]['pad'], sp['pad'])

    def test_consumers_do_not_duplicate_tokenize_or_spaced_tables(self):
        for rel in (
            'lib/core/persian_text.dart',
            'lib/domain/advocate/topic_flow.dart',
            'lib/domain/advocate/law_terms.dart',
            'lib/domain/intent_net.dart',
        ):
            self.assertIn('text_norm_rules.dart', read(ROOT, rel), rel)

        pt = read(ROOT, 'lib/core/persian_text.dart')
        self.assertNotIn("static const Set<String> _stop = {", pt)
        self.assertNotIn("static const List<String> _suffixes = [", pt)

        inet = read(ROOT, 'lib/domain/intent_net.dart')
        self.assertNotIn("RegExp(r'[^\\u0621", inet)

        for rel in ('dev/tools/eval_py.py', 'dev/tools/check.py', 'dev/brain/train_intent.py'):
            src = read(ROOT, rel)
            self.assertIn('text_norm_rules', src, rel)
            self.assertNotIn("'ترین', 'هایی', 'های', 'ها'", src, rel)


class GoldenTests(unittest.TestCase):
    """رفتار پیش و پس از یکسان‌سازی باید یکی بماند."""

    def test_normalize(self):
        for row in _json(GOLDEN)['normalize']:
            self.assertEqual(common.normalize(row['in']), row['out'], row['in'])

    def test_spaced_variants(self):
        golden = _json(GOLDEN)
        for name, key in (('tools', 'spaced'), ('terms', 'spaced_terms')):
            for row in golden[key]:
                self.assertEqual(common.spaced(row['in'], name), row['out'],
                                 '%s: %s' % (name, row['in']))

    def test_norm_matches_pinned_cases(self):
        for row in _json(NORM_CASES)['cases']:
            self.assertEqual(common.norm(row['in']), row['out'], row['in'])

    def test_norm_basics(self):
        self.assertEqual(common.norm('می خواهم'), ' میخواهم ')
        self.assertEqual(common.norm('چکار کنم؟'), ' چه کار کنم ؟ ')
        self.assertEqual(common.norm('خانه'), ' خونه ')


if __name__ == '__main__':
    unittest.main()
