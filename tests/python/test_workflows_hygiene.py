"""نگهبان فاز ۲۰: تفکیک CI محصول از گردش‌کارهای آزمایشی سنگین."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WF = ROOT / '.github' / 'workflows'

EXPERIMENTAL_WORKFLOWS = (
    'agent.yml',
    'alt-bench.yml',
    'build-preview.yml',
    'embed-bench.yml',
    'embed.yml',
    'eval.yml',
    'hakim-eval.yml',
    'llm-bench.yml',
    'noql-export.yml',
    'noql-finetune.yml',
    'qwen-probe.yml',
    'train.yml',
    'vex-probe.yml',
)

PRODUCT_PUSH_WORKFLOWS = (
    'test.yml',
    'lawyer-lab.yml',
    'intent-eval.yml',
)


def _on_block(path):
    text = path.read_text(encoding='utf-8')
    m = re.search(r'^on:\s*\n((?:[ \t].*\n|\s*\n)*)', text, re.M)
    return m.group(1) if m else ''


class WorkflowHygieneTests(unittest.TestCase):
    def test_experimental_workflows_are_manual_dispatch_only(self):
        for name in EXPERIMENTAL_WORKFLOWS:
            path = WF / name
            self.assertTrue(path.is_file(), name)
            on = _on_block(path)
            self.assertIn('workflow_dispatch:', on, f'{name} باید دستی باشد')
            self.assertNotRegex(
                on, r'^\s*(?:push|pull_request)\s*:',
                f'{name} نباید روی push یا pull_request به‌صورت خودکار اجرا شود',
            )

    def test_product_ci_keeps_automated_triggers_and_release_gate(self):
        for name in PRODUCT_PUSH_WORKFLOWS:
            path = WF / name
            self.assertTrue(path.is_file(), name)
            self.assertRegex(_on_block(path), r'^\s*push\s*:', name)
        build_on = _on_block(WF / 'build.yml')
        self.assertIn('workflow_dispatch:', build_on)
        self.assertNotRegex(build_on, r'^\s*push\s*:', 'build.yml')


if __name__ == '__main__':
    unittest.main()
