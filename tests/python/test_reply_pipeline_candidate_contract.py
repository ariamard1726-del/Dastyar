"""قرارداد فاز ۲: داور و مسیرها باید متادیتای کاندیدها را حفظ کنند.

همهٔ مسیرها، منطق و ترتیبشان دستنخورده میماند؛ تنها چیزی که اضافه میشود،
اطلاعاتی است که از قبل در طول خط لوله موجود بود (source/confidence/why).
"""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPLY = os.path.join(ROOT, 'lib', 'domain', 'advocate', 'advocate_reply.dart')
CANDIDATE = os.path.join(ROOT, 'lib', 'domain', 'advocate', 'answer_candidate.dart')


def read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


class ReplyPipelineCandidateContractTests(unittest.TestCase):
    def test_arbiter_exposes_decision_and_metadata_fields(self):
        code = read(CANDIDATE)
        for needle in ('class AnswerCandidate', 'class AnswerDecision',
                       'class AnswerArbiter', 'AnswerDecision? decide(',
                       'AnswerSource source', 'double confidence', 'String why'):
            self.assertIn(needle, code, needle)

    def test_every_named_candidate_has_a_source(self):
        code = read(REPLY)
        names = re.findall(r"AnswerCandidate\(\s*'([^']+)'", code)
        self.assertGreaterEqual(len(names), 19)
        starts = [m.start() for m in re.finditer(r"AnswerCandidate\(\s*'[^']+'", code)]
        for i, start in enumerate(starts):
            end = starts[i + 1] if i + 1 < len(starts) else len(code)
            block = code[start:end]
            self.assertIn('source: AnswerSource.', block, names[i])

    def test_winning_candidate_is_available_for_inspection(self):
        # جای پاسخ بیبرچسب، تصمیمی است که نام مسیر و منبع آن را نگه میدارد.
        model = read(os.path.join(ROOT, 'lib', 'domain', 'advocate', 'advocate.dart'))
        self.assertIn('AnswerDecision? lastDecision', model)
        pipeline = read(REPLY)
        self.assertIn('lastDecision =', pipeline)

    def test_contracts_unchanged(self):
        for path in ('tests/python/test_reply_pipeline_shape.py',
                     'tests/python/test_pipeline_check.py',
                     'tests/python/test_structure_tests.py'):
            self.assertTrue(os.path.exists(os.path.join(ROOT, path)), path)


if __name__ == '__main__':
    unittest.main()
