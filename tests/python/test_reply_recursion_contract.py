"""قرارداد فاز ۳: سقفِ بازگشت در گرهِ مرکزی، قفلِ شمارندهٔ نوبت و ایندکس قواعد.

`Advocate` یک گرهِ بازگشتی دارد (`_routes.offer` می‌تواند دوباره `_reply`
را با `again: true` صدا بزند). بدون سقفِ بازگشت در کد، یک چرخهٔ ناخواسته
(`routes → _reply → routes`) به‌جای شکستِ فوری می‌تواند وارد حلقهٔ بی‌نهایت
یا شمارشِ دوبرابرِ `file.turns` شود. این نگهبان قفل می‌کند که:

1. `ReplyLoopGuard` سقفِ عمق (`Advocate.maxReplyDepth = 1`) و شرطِ
   `again: true` برای فراخوانی بازگشتی را در زمانِ اجرا اعمال کند.
2. تنها مسیرِ صدا زدنِ `_reply`، نگهبانِ `_guardedReply` است (چه از
   `respond`، چه از `ReplyRoutes`).
3. `file.turns` فقط با `if (!again) file.turns++;` در `_reply` بالا می‌رود و
   فقط در `reset()` صفر می‌شود.
4. آزمونِ Dart برای شکستنِ حلقه و شمارشِ دقیق نوبت وجود دارد و
   `docs/ARCHITECTURE.md` ایندکسِ صریح «کدام قاعده کدام‌جاست» را دارد.
"""

import os
import re
import sys
import unittest

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'dev', 'tools'))
from library import DartLibrary, dart_files, read as lib_read  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADVOCATE = os.path.join(ROOT, 'lib', 'domain', 'advocate', 'advocate.dart')
CANDIDATE = os.path.join(ROOT, 'lib', 'domain', 'advocate', 'answer_candidate.dart')
GUARDS = os.path.join(ROOT, 'lib', 'domain', 'advocate', 'advocate_reply_guard.dart')
DART_TEST = os.path.join(ROOT, 'test', 'advocate', 'reply_recursion_test.dart')
ARCH_DOC = os.path.join(ROOT, 'docs', 'ARCHITECTURE.md')


class ReplyRecursionContractTests(unittest.TestCase):
    def setUp(self):
        self.advocate_src = lib_read(ADVOCATE)
        self.library = DartLibrary(ROOT, ADVOCATE)
        self.candidate_src = lib_read(CANDIDATE)
        self.guards_src = lib_read(GUARDS)

    def test_reply_loop_guard_exists_and_caps_recursion(self):
        for needle in (
                'class ReplyLoopGuard {',
                'final int maxDepth;',
                'int lastDepth =',
                'int lastEntries =',
                'T run<T>({required bool again, required T Function() body})',
                '_depth > 0 && !again',
                '_depth > maxDepth',
                'throw StateError(',
                '_depth--;',
        ):
            self.assertIn(needle, self.candidate_src, needle)

    def test_advocate_enforces_max_reply_depth(self):
        m = re.search(r'static const int maxReplyDepth = (\d+);', self.advocate_src)
        self.assertIsNotNone(m, 'Advocate.maxReplyDepth تعریف نشده')
        cap = int(m.group(1))
        self.assertGreaterEqual(cap, 1)
        self.assertLessEqual(cap, 2)

        for needle in (
                'ReplyLoopGuard _loopGuard = ReplyLoopGuard(maxDepth: maxReplyDepth);',
                'int get lastReplyDepth => _loopGuard.lastDepth;',
                'int get lastReplyEntries => _loopGuard.lastEntries;',
                '_guardedReply(raw, again: again)',
                '_guardedReply(raw, guess: guess)',
        ):
            self.assertIn(needle, self.advocate_src, needle)

        self.assertIn('AdvocateReply _guardedReply(', self.guards_src)
        self.assertIn('_loopGuard.run(', self.guards_src)

    def test_no_unguarded_direct_calls_to_reply(self):
        """هیچ کدی در `lib/` نباید بی‌واسطهٔ `_guardedReply` به `_reply(` برود."""
        callers = []
        for rel in dart_files(ROOT):
            src = lib_read(ROOT, rel)
            for no, line in enumerate(src.split('\n'), 1):
                stripped = line.strip()
                if stripped.startswith('//') or stripped.startswith('///'):
                    continue
                if '_reply(' not in stripped:
                    continue
                if stripped.startswith('AdvocateReply _reply('):
                    continue
                if rel == 'lib/domain/advocate/advocate_reply_guard.dart' and \
                        'body: () => _reply(raw, guess: guess, again: again)' in stripped:
                    continue
                callers.append('%s:%d %s' % (rel, no, stripped))
        self.assertEqual(callers, [],
                         'فراخوانی مستقیم `_reply` بدون نگهبانِ بازگشت: %s' % callers)

    def test_turn_counter_increments_once_and_ignores_self_calls(self):
        mutations = []
        for no, line in enumerate(self.library.text.split('\n'), 1):
            stripped = line.strip()
            if stripped.startswith('//'):
                continue
            if re.search(r'file\.turns\s*(?:\+\+|--|\+=|-=|=)', stripped):
                mutations.append((no, stripped))
        self.assertEqual(
            [m[1] for m in mutations],
            ['file.turns = 0;', 'if (!again) file.turns++;'],
            'تغییرِ غیرمنتظره در file.turns: %s' % mutations,
        )

    def test_dart_recursion_and_turn_tests_exist(self):
        self.assertTrue(os.path.exists(DART_TEST),
                        'آزمون Dart برای بازگشت و نوبت وجود ندارد')
        src = lib_read(DART_TEST)
        for needle in (
                'throwsStateError',
                'ReplyLoopGuard',
                'ReplyRoutes',
                'file.turns',
                'lastReplyDepth',
                'Advocate.maxReplyDepth',
        ):
            self.assertIn(needle, src, needle)

    def test_architecture_has_explicit_rule_index(self):
        doc = lib_read(ARCH_DOC)
        self.assertIn('## ایندکس صریح قواعد', doc)
        idx = doc[doc.index('## ایندکس صریح قواعد'):]
        for filename in (
                'advocate_reply.dart',
                'advocate_reply_guard.dart',
                'advocate_reply_case.dart',
                'reply_routes.dart',
                'answer_candidate.dart',
                'reasoner.dart',
                'text_sense.dart',
                'law_terms.dart',
                'safety_reply.dart',
                'topic_score.dart',
                'case_plan.dart',
                'all.dart',
                'rent.dart',
                'engine.dart',
                'drafting.dart',
        ):
            self.assertIn('`%s`' % filename, idx,
                          'ایندکس قواعد %s را نیاورده' % filename)


if __name__ == '__main__':
    unittest.main()
