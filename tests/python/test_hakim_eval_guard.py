"""نگهبانِ آزمایشِ غیرمخربِ Hakim-small.

این آزمایش فقط در GitHub Actions اجرا میشود و گزارشی مینویسد. نباید حتی یک
فایلِ دارایی یا کدِ مسیر اصلی را عوض کند؛ تعویضِ Noql کاری جداگانه و با
تصمیمِ صریح است.
"""
import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCRIPT = os.path.join(ROOT, 'dev', 'brain', 'hakim_eval.py')
WORKFLOW = os.path.join(ROOT, '.github', 'workflows', 'hakim-eval.yml')
REPORT = os.path.join(ROOT, 'reports', 'hakim_eval.md')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


class HakimEvalGuardTests(unittest.TestCase):
    def test_experiment_files_exist(self):
        for path in (SCRIPT, WORKFLOW, REPORT):
            self.assertTrue(os.path.isfile(path), path)

    def test_weights_come_from_an_explicit_environment_variable(self):
        src = read(SCRIPT)
        self.assertIn('HAKIM_MODEL_REPO', src)
        self.assertIn('HAKIM_REV', src)
        # نباید بهطور ضمنی از منبع بسته وزن بگیرد: نبودِ متغیر = عدمِ اجرا.
        self.assertIn("os.environ.get('HAKIM_MODEL_REPO', '')", src)

    def test_missing_weights_is_not_a_failure(self):
        src = read(SCRIPT)
        self.assertIn('CLOSED', src)
        self.assertIn('return 0', src)
        report = read(REPORT)
        self.assertIn('HAKIM_MODEL_REPO', report)

    def test_experiment_never_writes_runtime_or_assets(self):
        src = read(SCRIPT)
        for forbidden in ('assets/brain', 'noql.bin', 'lib/domain', 'pubspec.yaml'):
            self.assertNotIn(forbidden, src, forbidden)
        workflow = read(WORKFLOW)
        self.assertIn('reports/hakim_eval.md', workflow)
        for forbidden in ('assets/brain', 'lib/', 'pubspec.yaml'):
            self.assertNotIn('git add ' + forbidden, workflow)

    def test_benchmark_uses_the_same_probe_as_noql(self):
        src = read(SCRIPT)
        for needed in ('embed_bench', 'alt_bench', 'head_scores', 'probe', 'set_b'):
            self.assertIn(needed, src)

    def test_workflow_is_dispatchable_and_repo_is_injected(self):
        workflow = read(WORKFLOW)
        self.assertIn('workflow_dispatch:', workflow)
        self.assertIn('HAKIM_MODEL_REPO:', workflow)
        self.assertIn('secrets.HF_TOKEN', workflow)
        self.assertIn('python dev/brain/hakim_eval.py', workflow)


if __name__ == '__main__':
    unittest.main()
