"""نگهبانِ فاز ۱۰: تکمیل موتور RuleDSL و مهاجرت ۴ موضوع بزرگ (cheque، family، labor، rent).

تضمین می‌کند:
۱. ماژول‌های `RuleDSL` (از جمله `rule_dsl_topic.dart`) عملگرها و قواعد پیشرفتهٔ
   مورد نیاز ۴ موضوع بزرگ (`FactTouched`، `FactCovered`، `FactNumMax`، `TxRent`،
   `TxNumOffset`، `TxScaleMul`، `TxListJoin`، `TxAssessDemands`، `ReadGuard`،
   `ReadBeforeMatch`، `ReadMonths`، `RankRule`، `FilingRule`، `PromptRule`،
   `FillRule`) و سریال‌سازی `toJson()` را دارند؛
۲. `case_model.dart` سازنده‌های `Issue.dsl` (`RankRule`) و `Topic.dsl`
   (`FilingRule`، `FillRule`، `PromptRule`) را ارائه می‌دهد؛
۳. هر ۲۴ موضوع در `lib/domain/advocate/topics/` (شامل `cheque`، `family`،
   `labor` و تمام ۱۳ تکهٔ `rent`) به `Topic.dsl` مهاجرت کرده‌اند و صفر عملگر
   `=>`، صفر کلوژر بی‌نام و صفر سازندهٔ غیر-DSL در آن‌ها باقی مانده است؛
۴. آزمون واحد `test/advocate/phase10_rule_dsl_test.dart` هم‌ارزی رفتاری و
   اعتبار `toJson()` را برای هر چهار موضوع بزرگ می‌سنجد.
"""

import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dev' / 'tools'))
from library import dart_files, read  # noqa: E402

INFRA_TOPIC_FILES = {
    'all.dart',
    'shared.dart',
    'topic_texts_loader.dart',
    'rent_texts_loader.dart',
}


def _strip_comments(src):
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    return '\n'.join(re.sub(r'//.*$', '', ln) for ln in src.split('\n'))


class Phase10RuleDslTests(unittest.TestCase):
    def test_rule_dsl_supports_phase10_constructs_and_topic_rules(self):
        expected = {
            'rule_dsl.dart': ('FactTouched', 'FactCovered', 'FactNumMax'),
            'rule_dsl_text.dart': ('TxRent', 'TxNumOffset', 'TxScaleMul', 'TxListJoin'),
            'rule_dsl_read.dart': ('ReadGuard', 'ReadBeforeMatch', 'ReadMonths'),
            'rule_dsl_topic.dart': (
                'class RankRule',
                'class FilingRule',
                'class PromptRule',
                'class FillRule',
                'class TxAssessDemands',
            ),
            'rule_dsl_json.dart': ('extension TopicRuleJson on Topic',),
        }
        for name, tokens in expected.items():
            rel = f'lib/domain/advocate/{name}'
            self.assertTrue((ROOT / rel).is_file(), f'{name} باید وجود داشته باشد')
            src = read(str(ROOT), rel)
            for tok in tokens:
                self.assertIn(tok, src, f'{tok} در {name} نیست')
            self.assertIn('Map<String, dynamic> toJson()', src)

        model = read(str(ROOT), 'lib/domain/advocate/case_model.dart')
        for tok in ('RankRule?', 'FilingRule?', 'FillRule?', 'PromptRule?'):
            self.assertIn(tok, model, f'{tok} در case_model.dart نیست')

    def test_all_24_topics_are_declarative_dsl_with_zero_closures(self):
        all_src = read(str(ROOT), 'lib/domain/advocate/topics/all.dart')
        all_topics = re.findall(r'\b(\w+Topic)\b', all_src)
        self.assertEqual(len(all_topics), 24)

        topic_rels = [
            rel for rel in dart_files(str(ROOT))
            if rel.startswith('lib/domain/advocate/topics/')
            and rel.rsplit('/', 1)[-1] not in INFRA_TOPIC_FILES
        ]

        dsl_topics = set()
        bad = []
        fn_decl_re = re.compile(
            r'^(?:bool\??|String\??|int\??|List<[^>]+>|Map<[^>]+>|Filing\??|Prompt\??)\s+[_a-zA-Z]\w*\s*\(',
            re.M,
        )
        closure_re = re.compile(
            r'\(\s*(?:CaseFile\s+\w+|String\s+\w+|f|n)\s*(?:,\s*(?:String\s+\w+|\w+))?\s*\)\s*\{'
        )
        for rel in sorted(topic_rels):
            name = rel.rsplit('/', 1)[-1]
            code = _strip_comments(read(str(ROOT), rel))
            m = re.search(r'\bfinal Topic (\w+)Topic =', code)
            if m:
                if 'Topic.dsl(' in code:
                    dsl_topics.add(m.group(1))
                else:
                    bad.append(f'{name}: Topic غیر-DSL دارد')
            if '=>' in code:
                bad.append(f'{name}: هنوز عملگر => دارد')
            if closure_re.search(code):
                bad.append(f'{name}: هنوز کلوژر بی‌نام دارد')
            if fn_decl_re.search(code):
                bad.append(f'{name}: هنوز تابع کمکی دارد')
            for ctor in ('Slot', 'Issue', 'Claim', 'Element', 'Topic'):
                if re.search(rf'\b{ctor}\s*\(', code):
                    bad.append(f'{name}: هنوز {ctor}() غیر-DSL دارد')

        self.assertEqual(bad, [], '\n'.join(bad))
        self.assertEqual(len(dsl_topics), 24, f'تنها {len(dsl_topics)} موضوع DSL است')

    def test_phase10_dart_unit_test_exists_and_covers_all_4_topics(self):
        p = ROOT / 'test' / 'advocate' / 'phase10_rule_dsl_test.dart'
        self.assertTrue(p.is_file(), 'test/advocate/phase10_rule_dsl_test.dart باید وجود داشته باشد')
        src = p.read_text(encoding='utf-8')
        for tok in ('cheque', 'family', 'labor', 'rent', 'toJson()', 'isDeclarative'):
            self.assertIn(tok, src)


if __name__ == '__main__':
    unittest.main()
