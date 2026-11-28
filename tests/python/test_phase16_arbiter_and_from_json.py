"""نگهبان فاز ۱۶: یکپارچه‌سازی کامل داور پاسخ (`AnswerArbiter`)، اتصال زندهٔ `pipeline.json` و `Topic.fromJson`.
"""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _read(rel):
    return (ROOT / rel).read_text(encoding='utf-8')


class Phase16Tests(unittest.TestCase):
    def test_reply_routes_all_decisions_through_arbiter(self):
        src = _read('lib/domain/advocate/advocate_reply.dart')
        m = re.search(r'AdvocateReply _reply\([^)]*\)\s*\{(.*)\n  \}\n', src, re.S)
        self.assertIsNotNone(m)
        body = m.group(1)
        self.assertIn('return tailDecision!.reply;', body)
        self.assertNotIn('_correctionReply(n, topic);\n', body)
        self.assertNotIn('_meta(n, topic', body.split('tailDecision')[1])
        self.assertEqual(len(re.findall(r"AnswerCandidate\(\s*'[^']+'", src)), 26)

    def test_pipeline_json_is_loaded_at_runtime_and_resolved(self):
        models = _read('lib/core/models.dart')
        load = _read('lib/core/engine_load.dart')
        data = _read('lib/domain/advocate/advocate_data.dart')
        self.assertIn('class PipelineConfig', models)
        self.assertIn("rootBundle.loadString('assets/pipeline.json'", load)
        for fn in (
            'resolvePipelineOrder(',
            'resolveNetMin(',
            'resolveTopicOpenMin(',
            'resolveTopicStrongMin(',
            'resolveTopicDominantMin(',
        ):
            self.assertIn(fn, data, fn)

    def test_topic_from_json_and_all_dsl_ops_present(self):
        model = _read('lib/domain/advocate/case_model.dart')
        from_json = _read('lib/domain/advocate/rule_dsl_from_json.dart')
        topic_from_json = _read('lib/domain/advocate/rule_dsl_topic_from_json.dart')
        self.assertIn('factory Topic.fromJson(', model)
        self.assertIn('FactExpr factExprFromJson(', from_json)
        self.assertIn('ReadRule readRuleFromJson(', from_json)
        self.assertIn('GateRule gateRuleFromJson(', from_json)
        self.assertIn('TextExpr textExprFromJson(', from_json)
        self.assertIn('Topic topicFromJson(', topic_from_json)
        # همهٔ اپراتورهای سریال‌شده در rule_dsl*.dart باید در fromJson پشتیبانی شوند.
        for src_rel in (
            'lib/domain/advocate/rule_dsl.dart',
            'lib/domain/advocate/rule_dsl_read.dart',
            'lib/domain/advocate/rule_dsl_text.dart',
            'lib/domain/advocate/rule_dsl_topic.dart',
        ):
            ops = re.findall(r"'op':\s*'([^']+)'", _read(src_rel))
            combined = from_json + '\n' + topic_from_json
            for op in ops:
                self.assertIn(f"'{op}' =>", combined, f'{op} در {src_rel} پارس نشده')


if __name__ == '__main__':
    unittest.main()
