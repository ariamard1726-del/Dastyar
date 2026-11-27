"""نگهبانِ فاز ۹: موتور RuleDSL و مهاجرت ۲۰ موضوع ساده/میانی از کلوژر به قانون داده‌ای.

تضمین می‌کند:
۱. `lib/domain/advocate/rule_dsl.dart` هستهٔ قانون‌پذیر (`FactExpr`، `TextExpr`،
   `ReadRule`، `GateRule`، `RecapItem`، `DraftRule`) و `toJson()` را دارد؛
۲. `case_model.dart` سازنده‌های `.dsl` و `toJson()` را روی `Topic`/`Slot`/`Issue`/
   `Claim`/`Element` ارائه می‌دهد؛
۳. تمام ۲۰ موضوعِ تک‌فایلی به `Topic.dsl` مهاجرت کرده‌اند و صفر عملگر `=>`
   یا تابعِ بی‌نام در آن‌ها باقی نمانده است؛
۴. تنها ۴ موضوعِ بزرگ (`cheque`، `family`، `labor`، `rent`) برای فاز ۱۰
   باقی مانده‌اند (فهرست استثنا هرگز بزرگ نمی‌شود).
"""

import re
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dev' / 'tools'))
from library import read  # noqa: E402

TOPICS_DIR = ROOT / 'lib' / 'domain' / 'advocate' / 'topics'

PHASE9_TOPICS = (
    'accused.dart',
    'admin.dart',
    'child.dart',
    'company.dart',
    'consumer.dart',
    'cyber.dart',
    'debt.dart',
    'enforce.dart',
    'fight.dart',
    'foreign_contract.dart',
    'guarantee.dart',
    'inherit.dart',
    'injury.dart',
    'marriage.dart',
    'minor_sale.dart',
    'neighbor.dart',
    'partner.dart',
    'property.dart',
    'sale.dart',
    'theft.dart',
)

PHASE10_COMPLEX_TOPICS = {'cheque', 'family', 'labor', 'rent'}


def _strip_comments(src):
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    return '\n'.join(re.sub(r'//.*$', '', ln) for ln in src.split('\n'))


class Phase9RuleDslTests(unittest.TestCase):
    def test_rule_dsl_module_exists_with_json_support(self):
        files = {
            'rule_dsl.dart': ('class FactExpr',),
            'rule_dsl_text.dart': ('class TextExpr', 'class RecapItem', 'class DraftRule'),
            'rule_dsl_read.dart': ('class ReadRule', 'class GateRule'),
            'rule_dsl_json.dart': ('extension TopicRuleJson on Topic',),
        }
        for name, classes in files.items():
            p = ROOT / 'lib' / 'domain' / 'advocate' / name
            self.assertTrue(p.is_file(), f'{name} باید وجود داشته باشد')
            src = read(str(ROOT), f'lib/domain/advocate/{name}')
            for cls in classes:
                self.assertIn(cls, src)
            self.assertIn('Map<String, dynamic> toJson()', src)

    def test_case_model_exposes_dsl_constructors_and_to_json(self):
        src = read(str(ROOT), 'lib/domain/advocate/case_model.dart')
        for ctor in ('Element.dsl(', 'Claim.dsl(', 'Slot.dsl(', 'Issue.dsl(',
                     'Topic.dsl('):
            self.assertIn(ctor, src, f'سازندهٔ {ctor} در case_model.dart نیست')
        j_src = read(str(ROOT), 'lib/domain/advocate/rule_dsl_json.dart')
        self.assertIn('extension TopicRuleJson on Topic', j_src)

    def test_twenty_topics_migrated_with_zero_closures(self):
        self.assertEqual(len(PHASE9_TOPICS), 20)
        bad = []
        for name in PHASE9_TOPICS:
            rel = f'lib/domain/advocate/topics/{name}'
            code = _strip_comments(read(str(ROOT), rel))
            if 'Topic.dsl(' not in code:
                bad.append(f'{name}: بدون Topic.dsl(')
            if '=>' in code:
                bad.append(f'{name}: هنوز عملگر => دارد')
            if re.search(r'\(\s*(?:CaseFile\s+\w+|String\s+\w+|f|n)\s*(?:,\s*(?:String\s+\w+|\w+))?\s*\)\s*\{', code):
                bad.append(f'{name}: هنوز تابعِ بی‌نام کلوژر دارد')
            if re.search(r'\bSlot\s*\(', code):
                bad.append(f'{name}: هنوز Slot() غیر-DSL دارد')
            if re.search(r'\bIssue\s*\(', code):
                bad.append(f'{name}: هنوز Issue() غیر-DSL دارد')
            if re.search(r'\bClaim\s*\(', code):
                bad.append(f'{name}: هنوز Claim() غیر-DSL دارد')
            if re.search(r'\bElement\s*\(', code):
                bad.append(f'{name}: هنوز Element() غیر-DSL دارد')
        self.assertEqual(bad, [], '\n'.join(bad))

    def test_only_four_complex_topics_left_for_phase10(self):
        all_src = read(str(ROOT), 'lib/domain/advocate/topics/all.dart')
        all_topics = re.findall(r'\b(\w+Topic)\b', all_src)
        self.assertEqual(len(all_topics), 24)
        non_dsl = set()
        for f in TOPICS_DIR.glob('*.dart'):
            src = read(str(ROOT), f'lib/domain/advocate/topics/{f.name}')
            m = re.search(r'\bfinal Topic (\w+)Topic =', src)
            if not m:
                continue
            code = _strip_comments(src)
            if 'Topic.dsl(' not in code:
                tid = m.group(1)
                non_dsl.add('cheque' if tid == 'cheque' else tid)
        self.assertLessEqual(non_dsl, PHASE10_COMPLEX_TOPICS)

    def test_rule_dsl_dart_unit_test_exists(self):
        self.assertTrue(
            (ROOT / 'test' / 'advocate' / 'rule_dsl_test.dart').is_file(),
            'test/advocate/rule_dsl_test.dart باید وجود داشته باشد',
        )


if __name__ == '__main__':
    unittest.main()
