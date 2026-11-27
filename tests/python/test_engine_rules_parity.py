"""قاعده‌های موتور بازیابی یک‌جا هستند و دو فایل تولیدشده تازه‌اند.

پیش‌تر ضرایب BM25F، الگوهای جست‌وجوی ماده/منسوخ/تعریف، شناسایی نام قانون،
پایش حوزه‌های خارج از پوشش و عمق تضادها بین `lib/core/*` و ابزارهای پایتونی
(`dev/tools/{eval_py,eval_none}.py` و `dev/brain/{common,engine}.py`) دستی تکرار
می‌شدند. حالا تنها مرجع `dev/tools/contracts/engine_rules.json` است.
"""

import json
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'brain'))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))

import engine_rules  # noqa: E402
import gen_engine_rules  # noqa: E402
from library import read  # noqa: E402


def _contract():
    with open(gen_engine_rules.CONTRACT, encoding='utf-8') as f:
        return json.load(f)


def _dart_number(dart_src, name):
    m = re.search(
        r'static const (?:int|double) %s = ([0-9.]+);' % re.escape(name),
        dart_src,
    )
    return float(m.group(1)) if m else None


def _dart_string(dart_src, name):
    m = re.search(
        r"static const String %s = r?'([^']*)';" % re.escape(name),
        dart_src,
    )
    return m.group(1) if m else None


def _dart_collection(dart_src, name):
    m = re.search(
        r'static const (?:List|Set)<String> %s = <[A-Za-z]+>[\[{](.*?)[\]}];'
        % re.escape(name),
        dart_src,
        re.S,
    )
    if not m:
        return None
    return re.findall(r"'([^']+)'", m.group(1))


class EngineRulesParityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.contract = _contract()
        cls.dart = read(ROOT, 'lib/core/engine_rules.dart')

    def test_generated_files_are_fresh(self):
        for path, text in gen_engine_rules.targets().items():
            rel = os.path.relpath(path, ROOT).replace(os.sep, '/')
            self.assertEqual(
                read(ROOT, rel),
                text,
                'کهنه است: %s — python3 dev/tools/gen_engine_rules.py --write' % rel,
            )

    def test_bm25f_and_thresholds_match_contract(self):
        bm = self.contract['bm25f']
        py_pairs = (
            ('BM25_K1', 'bm25K1', bm['k1']),
            ('BM25_B', 'bm25B', bm['b']),
            ('BM25_WT', 'bm25WT', bm['wTitle']),
            ('BM25_WB', 'bm25WB', bm['wBody']),
            ('BM25_WC', 'bm25WC', bm['wContext']),
            ('OBSOLETE_PENALTY', 'obsoletePenalty', bm['obsoletePenalty']),
            ('EXPLICIT_SCORE', 'explicitScore', bm['explicitScore']),
            ('PREFIX_MIN_LEN', 'prefixMinLen', bm['prefixMinLen']),
            ('PREFIX_WEIGHT', 'prefixWeight', bm['prefixWeight']),
            ('MIN_SCORE', 'minHitScore', bm['minScore']),
            ('LOW_COVER', 'lowCover', bm['lowCover']),
            ('COVERAGE_MARGIN', 'coverageMargin', bm['coverageMargin']),
            ('NEAR_ALTERNATIVE_FACTOR', 'nearAlternativeFactor', bm['nearAlternativeFactor']),
            ('MAX_NEAR_ALTERNATIVES', 'maxNearAlternatives', bm['maxNearAlternatives']),
            ('ALT_MIN_SCORE_RATIO', 'altMinScoreRatio', bm['altMinScoreRatio']),
        )
        for py_name, dart_name, val in py_pairs:
            self.assertEqual(getattr(engine_rules, py_name), val, py_name)
            self.assertEqual(_dart_number(self.dart, dart_name), float(val), dart_name)

    def test_patterns_and_lists_match_contract(self):
        c = self.contract
        self.assertEqual(engine_rules.ARTICLE_QUERY_PATTERN, c['articleQuery']['pattern'])
        self.assertEqual(_dart_string(self.dart, 'articleQueryPattern'), c['articleQuery']['pattern'])

        ob = c['obsolete']
        self.assertEqual(engine_rules.OBSOLETE_MAX_LEN, ob['maxLen'])
        self.assertEqual(_dart_number(self.dart, 'obsoleteMaxLen'), float(ob['maxLen']))
        self.assertEqual(engine_rules.OBSOLETE_TRIM_PATTERN, ob['trimPattern'])
        self.assertEqual(_dart_string(self.dart, 'obsoleteTrimPattern'), ob['trimPattern'])
        self.assertEqual(engine_rules.CLEAN_BODY_PATTERN, ob['cleanBodyPattern'])
        self.assertEqual(_dart_string(self.dart, 'cleanBodyPattern'), ob['cleanBodyPattern'])
        self.assertEqual(list(engine_rules.OBSOLETE_PREFIXES), ob['prefixes'])
        self.assertEqual(_dart_collection(self.dart, 'obsoletePrefixes'), ob['prefixes'])

        df = c['definitionPromotion']
        self.assertEqual(engine_rules.DEF_QUESTION_PATTERN, df['questionPattern'])
        self.assertEqual(_dart_string(self.dart, 'defQuestionPattern'), df['questionPattern'])
        self.assertEqual(engine_rules.DEF_WORDS, frozenset(df['words']))
        self.assertEqual(set(_dart_collection(self.dart, 'defWords')), set(df['words']))
        self.assertEqual(engine_rules.DEF_META_PREFIXES, frozenset(df['metaPrefixes']))
        self.assertEqual(set(_dart_collection(self.dart, 'defMetaPrefixes')), set(df['metaPrefixes']))
        self.assertEqual(engine_rules.DEF_MARK_PATTERN, df['markPattern'])
        self.assertEqual(_dart_string(self.dart, 'defMarkPattern'), df['markPattern'])
        self.assertEqual(engine_rules.DEF_STRONG_PATTERN, df['strongPattern'])
        self.assertEqual(_dart_string(self.dart, 'defStrongPattern'), df['strongPattern'])
        self.assertEqual(engine_rules.DEF_TAIL_WINDOW, df['tailWindow'])
        self.assertEqual(_dart_number(self.dart, 'defTailWindow'), float(df['tailWindow']))
        self.assertEqual(engine_rules.DEF_MAX_PICKED, df['maxPicked'])
        self.assertEqual(_dart_number(self.dart, 'defMaxPicked'), float(df['maxPicked']))

        lm = c['lawMention']
        self.assertEqual(list(engine_rules.LAW_PREFIXES), lm['requiredPrefixes'])
        self.assertEqual(_dart_collection(self.dart, 'lawPrefixes'), lm['requiredPrefixes'])
        self.assertEqual(engine_rules.SHORT_LAW_PREFIX, lm['shortLawPrefix'])
        self.assertEqual(_dart_string(self.dart, 'shortLawPrefix'), lm['shortLawPrefix'])
        self.assertEqual(engine_rules.SHORT_LAW_MIN_LEN, lm['shortLawMinLen'])
        self.assertEqual(_dart_number(self.dart, 'shortLawMinLen'), float(lm['shortLawMinLen']))

        ud = c['unloadedDomain']
        self.assertEqual(list(engine_rules.UNLOADED_PENAL_TERMS), ud['penalTerms'])
        self.assertEqual(_dart_collection(self.dart, 'unloadedPenalTerms'), ud['penalTerms'])
        self.assertEqual(list(engine_rules.PENAL_CONTEXT_MARKERS), ud['penalContextMarkers'])
        self.assertEqual(_dart_collection(self.dart, 'penalContextMarkers'), ud['penalContextMarkers'])
        self.assertEqual(list(engine_rules.LOADED_CRIMINAL_EXCEPTIONS), ud['loadedCriminalExceptions'])
        self.assertEqual(_dart_collection(self.dart, 'loadedCriminalExceptions'), ud['loadedCriminalExceptions'])
        self.assertEqual(list(engine_rules.TAX_TRIGGERS), ud['taxTriggers'])
        self.assertEqual(_dart_collection(self.dart, 'taxTriggers'), ud['taxTriggers'])
        self.assertEqual(list(engine_rules.SOCIAL_SECURITY_TRIGGERS), ud['socialSecurityTriggers'])
        self.assertEqual(_dart_collection(self.dart, 'socialSecurityTriggers'), ud['socialSecurityTriggers'])

        expected_anchors = [(t, tuple(reqs)) for t, reqs in ud['anchorGroups']]
        self.assertEqual(list(engine_rules.ANCHOR_GROUPS), expected_anchors)
        for trigger, _ in ud['anchorGroups']:
            self.assertIn("('%s'" % trigger, self.dart)

        cf = c['conflicts']
        self.assertEqual(engine_rules.CONFLICTS_MAX_DEPTH, cf['maxDepth'])
        self.assertEqual(_dart_number(self.dart, 'conflictsMaxDepth'), float(cf['maxDepth']))
        self.assertEqual(engine_rules.CONFLICTS_CYCLE_SUFFIX, cf['cycleSuffix'])
        self.assertEqual(_dart_string(self.dart, 'conflictsCycleSuffix'), cf['cycleSuffix'])

    def test_consumers_use_generated_rules_and_avoid_duplicates(self):
        for rel in (
            'lib/core/article_query.dart',
            'lib/core/law_index.dart',
            'lib/core/law_mention.dart',
            'lib/core/law_ranker.dart',
            'lib/core/conflicts_service.dart',
            'lib/core/engine.dart',
        ):
            self.assertIn('package:dastyar/core/engine_rules.dart', read(ROOT, rel), rel)

        ranker = read(ROOT, 'lib/core/law_ranker.dart')
        self.assertNotIn("RegExp(r'چیست|چیه", ranker)
        self.assertNotIn('final double _k1 = 0.9;', ranker)

        engine_dart = read(ROOT, 'lib/core/engine.dart')
        self.assertNotIn('_unloadedPenalTerms', engine_dart)
        self.assertNotIn('_anchorGroups', engine_dart)

        eval_py = read(ROOT, 'dev/tools/eval_py.py')
        self.assertIn('import engine_rules', eval_py)
        self.assertIn('import text_norm_rules', eval_py)
        self.assertNotIn('K1, B, WT, WB, WC = 0.9', eval_py)

        eval_none = read(ROOT, 'dev/tools/eval_none.py')
        self.assertIn('import engine_rules', eval_none)
        self.assertNotIn("('سرقت', 'دزدی'", eval_none)
        self.assertNotIn("anchor_groups = (", eval_none)

        brain_engine = read(ROOT, 'dev/brain/engine.py')
        self.assertIn('engine_rules', brain_engine)
        self.assertNotIn(' ⚠️ (حلقه)', brain_engine)

        brain_common = read(ROOT, 'dev/brain/common.py')
        self.assertIn('engine_rules', brain_common)
        self.assertNotIn("('منسوخ', 'ملغی'", brain_common)


if __name__ == '__main__':
    unittest.main()
