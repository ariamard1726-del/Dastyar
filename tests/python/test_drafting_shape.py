"""شکلِ `Drafting`: نام‌فضایِ ۶۵۸ خطی نباید برگردد.

قفل، پیش از تقسیم نوشته شد. معیارِ «رفع شد»:

۱. هر عملیاتِ عمومی دقیقاً یک بار در کلِ `lib/domain/` تعریف شده باشد (نه کپی،
   نه صفر) — سطحِ عمومی و امضا دست‌نخورده؛
۲. کلاسی به نامِ `Drafting` دیگر نباشد؛ نام‌فضا با پنج صاحب جایگزین شده باشد؛
۳. `drafting.dart` سرِ کتابخانه باشد (≤ ۳۰ خط، فقط `export`) تا ۱۸ فایلی که
   امروز آن را وارد می‌کنند نشکنند؛
۴. هیچ فایلِ صاحبی از سقفِ ۴۲۰ خط نگذرد.
"""

import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOMAIN = os.path.join(ROOT, 'lib', 'domain')
BARREL = os.path.join(DOMAIN, 'drafting.dart')

LIMIT = 420
BARREL_MAX = 30

OWNERS = ('draft_models.dart', 'draft_words.dart', 'draft_intent.dart',
          'draft_step.dart', 'draft_laws.dart')

# امضای امروزِ هر عملیاتِ عمومی. تغییرِ امضا تصمیمِ معماری است، نه جزئیات.
SIGNATURES = {
    'detect': 'IntentResult detect(String text, List<LegalTemplate> ts)',
    'suggest': 'IntentResult suggest(String text, List<LegalTemplate> ts)',
    'keywordScore': 'int keywordScore(String text, LegalTemplate t)',
    'pickChoice': 'LegalTemplate? pickChoice(String raw, List<LegalTemplate> ch',
    'isYes': 'bool isYes(String raw)',
    'isNo': 'bool isNo(String raw)',
    'isLeave': 'bool isLeave(String raw)',
    'isComplaintNoOption': 'bool isComplaintNoOption(String raw)',
    'start': 'DraftReply start(DraftSession s)',
    'resumePrompt': 'DraftReply resumePrompt(DraftSession s)',
    'answer': 'DraftReply answer(DraftSession s, String raw)',
    'lawTexts': 'List<LawText> lawTexts(KnowledgeEngine e, LegalTemplate t)',
    'chooseText': 'String chooseText =',
    'suggestChooseText': 'String suggestChooseText =',
}


def _read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def _draft_files():
    return [os.path.join(DOMAIN, n) for n in sorted(os.listdir(DOMAIN))
            if n.startswith('draft') and n.endswith('.dart')]


class DraftingShape(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.lib = '\n'.join(_read(p) for p in _draft_files())
        cls.barrel = _read(BARREL)

    def test_every_public_operation_is_declared_exactly_once(self):
        counts = {}
        for name, sig in SIGNATURES.items():
            n = self.lib.count(sig)
            if n != 1:
                counts[name] = n
        self.assertEqual(counts, {},
                         'عملیاتِ عمومی صفر یا چند بار تعریف شده: %s' % counts)

    def test_the_old_namespace_is_gone(self):
        self.assertNotIn('class Drafting', self.lib,
                         'نام‌فضایِ Drafting برگشت')

    def test_each_owner_has_its_own_file(self):
        names = [os.path.basename(p) for p in _draft_files()]
        missing = [n for n in OWNERS if n not in names]
        self.assertEqual(missing, [], 'فایلِ صاحب پیدا نشد: %s' % missing)

    def test_the_barrel_only_reexports(self):
        lines = [l.strip() for l in self.barrel.split('\n') if l.strip()]
        self.assertLessEqual(len(lines), BARREL_MAX, 'سرِ کتابخانه پر شد')
        exports = [l for l in lines if l.startswith('export ')]
        self.assertEqual(len(exports), len(OWNERS),
                         'هر صاحب باید یک export داشته باشد: %s' % exports)
        for n in OWNERS:
            self.assertIn("export '%s';" % n, exports)

    def test_no_owner_file_passes_the_limit(self):
        big = {}
        for p in _draft_files():
            n = len(_read(p).splitlines())
            if n > LIMIT:
                big[os.path.basename(p)] = n
        self.assertEqual(big, {}, 'از سقفِ %d خط گذشت: %s' % (LIMIT, big))


if __name__ == '__main__':
    unittest.main()
