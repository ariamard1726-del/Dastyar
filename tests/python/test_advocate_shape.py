"""شکلِ `Advocate`: گاد-آبجکت نباید بی‌صدا برگردد.

معیارِ «رفع شد» این نیست که فایل کوچک شود؛ این است که:

۱. وضعیتِ ساختِ پاسخ (متنِ مانده، سقفِ تکرارِ پرسش، دکمهٔ مرتبط، استنادهای
   آخر) صاحبِ جدا داشته باشد و روی `Advocate` برنگردد؛
۲. مسیرهای یک‌نوبتیِ `_reply` نام داشته باشند (`_route*`) و دوباره داخلِ خودِ
   تابع چپانده نشوند؛
۳. تعداد فیلدهای حالتی و درازای `_reply` از سقفِ همین امروز بالاتر نرود.

این آزمون عمداً عددی است: تغییرِ معماری بدونِ عدد، در بازبینی بعدی دوباره
«متنِ خوب» می‌شود.
"""

import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADVOCATE_DIR = os.path.join(ROOT, 'lib', 'domain', 'advocate')
ADVOCATE = os.path.join(ADVOCATE_DIR, 'advocate.dart')
VOICE = os.path.join(ADVOCATE_DIR, 'reply_voice.dart')
DIALOGUE = os.path.join(ADVOCATE_DIR, 'dialogue_state.dart')
ROUTES = os.path.join(ADVOCATE_DIR, 'advocate_routes.dart')
TOPIC_SCORE = os.path.join(ADVOCATE_DIR, 'topic_score.dart')
CASE_PLAN = os.path.join(ADVOCATE_DIR, 'case_plan.dart')
ISOLATION_TEST = os.path.join(ROOT, 'test', 'advocate', 'isolation_test.dart')
CONTROLLER = os.path.join(ROOT, 'lib', 'ui', 'chat_controller.dart')
DRAFT_FLOW = os.path.join(ROOT, 'lib', 'ui', 'draft_flow.dart')

# سقف‌های امروز؛ عبور از آن‌ها یعنی بازگشت به عقب.
MAX_STATE_FIELDS = 13
MAX_REPLY_LINES = 345
MIN_ROUTES = 12


def _read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def _class_body(src, name='Advocate'):
    lines = src.split('\n')
    start = next(i for i, l in enumerate(lines) if l.startswith('class %s {' % name))
    end = next(i for i in range(start + 1, len(lines)) if lines[i] == '}')
    return lines[start:end]


def _method(src, signature):
    """متنِ کامل یک متد (با شمارش آکولاد)."""
    lines = src.split('\n')
    start = next(i for i, l in enumerate(lines) if signature in l)
    depth = 0
    started = False
    for k in range(start, len(lines)):
        depth += lines[k].count('{') - lines[k].count('}')
        if '{' in lines[k]:
            started = True
        # متدِ فلش‌دار (`=> ...;`) در خطِ امضا بسته نمی‌شود؛ تا `;` ادامه می‌دهیم.
        if started and depth == 0 and lines[k].rstrip().endswith((';', '}')):
            return '\n'.join(lines[start:k + 1])
    raise AssertionError('بسته نشد: %s' % signature)


# فقط اعلانِ فیلد: خطی که پرانتز ندارد (یعنی متد/گتر نیست) و به `;` یا مقدار
# ختم می‌شود.
STATE_FIELD = re.compile(
    r'^  (?:final|late final|late)\s+[\w<>?, ]+\s+\w+\s*(?:=|;)'
    r'|^  (?:bool|int|double|String|List<[^>]*>|Map<[^>]*>|Set<[^>]*>|Topic\?)\s+\w+\s*(?:=|;)')

MOVED_FIELDS = ['_rest', '_offeredMore', '_lastAsk', '_askRepeats',
                '_relevantChip', '_vary', '_said', '_lastBody', '_lastLaws']


class ShapeTests(unittest.TestCase):
    def setUp(self):
        self.src = _read(ADVOCATE)

    def test_state_fields_do_not_grow(self):
        fields = [l for l in _class_body(self.src) if STATE_FIELD.match(l)]
        self.assertLessEqual(
            len(fields), MAX_STATE_FIELDS,
            'فیلد حالتیِ Advocate زیاد شد (%d):\n%s' % (len(fields), '\n'.join(fields)))

    def test_reply_does_not_grow(self):
        body = _method(self.src, 'AdvocateReply _reply(String raw')
        n = len(body.split('\n'))
        self.assertLessEqual(n, MAX_REPLY_LINES,
                             '_reply دوباره بزرگ شد: %d خط' % n)

    def test_output_state_has_its_own_owner(self):
        voice = _read(VOICE)
        for name in ['rest', 'offeredMore', 'lastAsk', 'askRepeats',
                     'relevantChip', 'lastLaws', 'lastBody', 'said']:
            self.assertRegex(voice, r'\n  [^(\n]*\b%s\b[^(\n]*=' % name,
                             '%s باید صاحبش ReplyVoice باشد' % name)
        for old in MOVED_FIELDS:
            self.assertNotIn('  String %s =' % old, self.src, old)
            self.assertNotIn('  int %s =' % old, self.src, old)
            self.assertNotIn('  bool %s =' % old, self.src, old)

    def test_out_is_a_delegate(self):
        body = _method(self.src, 'AdvocateReply _out(')
        self.assertIn('voice.out', body)
        # منطقِ استناد و برش نباید داخلِ Advocate برگردد.
        for moved in ['replaceAllMapped', 'refOne', 'askRepeats', 'cutText(']:
            self.assertNotIn(moved, body, moved)

    def test_single_turn_routes_are_named(self):
        routes = _read(ROUTES)
        handlers = re.findall(r'AdvocateReply\? (_route\w+)\(', routes)
        self.assertGreaterEqual(len(handlers), MIN_ROUTES, handlers)
        for h in handlers:
            self.assertIn('%s(' % h, self.src, 'مسیر %s از _reply صدا زده نمی‌شود' % h)
        # دوباره‌چپاندنِ همین بلوک‌ها در `_reply` نباید ممکن باشد.
        reply = _method(self.src, 'AdvocateReply _reply(String raw')
        for marker in ['isComplaintNoOption', 'wrongChip', 'فقط حرف بود']:
            self.assertNotIn(marker, reply, marker)

    def test_dialogue_state_has_its_own_owner(self):
        """«چه چیزی روی میز است» نباید دوباره فیلدهای Advocate شود."""
        dialog = _read(DIALOGUE)
        moved = ['askText', 'askChips', 'offer', 'offerDraft', 'choices',
                 'choiceText', 'guessed', 'pendingTopic', 'pendingText', 'side',
                 'sideText', 'branchAsked', 'guide', 'guideAsked',
                 'guideStepped', 'deferred', 'lastServed', 'arguedOn', 'heard',
                 'roomy', 'unclearPhrase', 'unclearTurn', 'safetyCarry',
                 'safetyShown', 'loose']
        body = '\n'.join(_class_body(self.src))
        for name in moved:
            self.assertRegex(dialog, r'\n  [^(\n]*\b%s\b[^(\n]*[=;]' % name,
                             '%s باید در DialogueState باشد' % name)
            self.assertNotRegex(
                body, r'\n  (?:final|late final|bool|int|String|List<[^>]*>|'
                      r'Topic\??)\s+_%s\b\s*[=;]' % name,
                '%s نباید به Advocate برگردد' % name)
        self.assertIn('final DialogueState dialog', self.src)

    def test_interpolations_are_braced(self):
        """`'$dialog.x'` در دارت «Instance of 'DialogueState'.x» چاپ می‌کند.

        دارت `$name` را تا نویسهٔ غیرِنام ادامه می‌دهد؛ پس `$dialog.x` یعنی
        `${dialog}.x`. همین یک اشتباه در بازچینشِ وضعیت رخ داد و متنِ پاسخ
        شد «Instance of 'DialogueState'.unclearPhrase»؛ فقط سناریوی گفتگو
        آن را گرفت. حالا پیش از CI گرفته می‌شود.
        """
        bad = []
        holders = ('dialog', 'voice', 'file', 'engine')
        pattern = re.compile(r'\$(?:%s)\.[A-Za-z_]' % '|'.join(holders))
        for base, _dirs, files in os.walk(os.path.join(ROOT, 'lib')):
            for f in files:
                if not f.endswith('.dart'):
                    continue
                path = os.path.join(base, f)
                for i, line in enumerate(_read(path).split('\n'), 1):
                    if re.search(r'//.*$', line):
                        line = re.sub(r'//.*$', '', line)
                    if pattern.search(line):
                        bad.append('%s:%d %s' % (os.path.relpath(path, ROOT), i,
                                                 line.strip()[:90]))
        self.assertEqual(bad, [], '\n'.join(bad))

    def test_rent_topic_is_not_one_wall_of_text(self):
        """موضوعِ اجاره ۲٬۶۷۹ خط بود در یک فایل؛ این خودش گاد-فایل بود."""
        topics = os.path.join(ROOT, 'lib', 'domain', 'advocate', 'topics')
        rent = _read(os.path.join(topics, 'rent.dart'))
        self.assertLess(len(rent.split('\n')), 40, 'rent.dart دوباره پر شد')
        parts = re.findall(r"part '([^']+)';", rent)
        self.assertGreaterEqual(len(parts), 6)
        for name in parts:
            path = os.path.join(topics, name)
            self.assertTrue(os.path.exists(path), name)
            body = _read(path)
            self.assertTrue(body.startswith("part of 'rent.dart';"), name)
            self.assertLess(len(body.split('\n')), 900, '%s دوباره غول شد' % name)

    def test_chat_controller_is_not_the_draft_form(self):
        """جریانِ نوشتنِ سند نباید دوباره داخلِ کنترلرِ گفتگو برگردد."""
        controller = _read(CONTROLLER)
        flow = _read(DRAFT_FLOW)
        self.assertLess(len(controller.split('\n')), 340,
                        'chat_controller.dart دوباره بزرگ شد')
        self.assertIn('DraftFlow(', controller)
        for moved in ('_withCaseHelp', '_botFromReply',
                      'void start(String userText, LegalTemplate t)',
                      'void step(String text)', 'DraftSession(t)'):
            self.assertIn(moved, flow, 'منطقِ پیش‌نویس به %s برنگشته' % moved)
        for gone in ('_withCaseHelp', '_botFromReply', '_startDraft',
                     '_draftStep', 'DraftSession(t)'):
            self.assertNotIn(gone, controller,
                             'کنترلر دوباره %s را خودش دارد' % gone)
        # رابطِ عمومیِ کنترلر برای صفحه و آزمون‌ها باید سر جایش باشد.
        for keep in ('bool get isDrafting', 'DraftSession? get draft',
                     'List<LegalTemplate> get pendingChoices'):
            self.assertIn(keep, controller)

    def test_argument_is_its_own_class(self):
        """استدلال باید کلاسِ خودش را داشته باشد، نه متدهای `Advocate`."""
        argue = _read(os.path.join(ADVOCATE_DIR, 'advocate_argue.dart'))
        self.assertIn('class CaseArgument {', argue)
        self.assertNotIn('extension _Arguing on Advocate', argue)
        self.assertIn('final CaseFile file;', argue)
        self.assertIn('final ReplyVoice voice;', argue)
        advocate = _read(ADVOCATE)
        self.assertIn('CaseArgument(file, voice,', advocate)
        # صداگذارنده نباید دوباره متدهای استدلال را خودش داشته باشد.
        for gone in ('String _argueOne(', 'String _verdict(ClaimView v)',
                     'ClaimView? _askedClaim('):
            self.assertNotIn(gone, advocate)

    def test_engine_only_orchestrates(self):
        """موتور باید بارگذاری + پاسخ‌سازی باشد؛ نوشتن و امتیازدهی همکار دارد."""
        engine = _read(os.path.join(ROOT, 'lib', 'core', 'engine.dart'))
        text = _read(os.path.join(ROOT, 'lib', 'core', 'law_text.dart'))
        for owned in ('String format(Chunk c)', 'String lawList()',
                      'String notFound()'):
            self.assertIn(owned, text)
        for gone in ('String _lawListText(', 'String _notFound('):
            self.assertNotIn(gone, engine)
        self.assertIn('String format(Chunk c) => _text.format(c);', engine)

    def test_engine_does_not_own_law_names(self):
        """نامِ قانون و ایندکس باید همکارِ موتور باشند، نه عضوِ آن."""
        engine = _read(os.path.join(ROOT, 'lib', 'core', 'engine.dart'))
        self.assertLess(len(engine.split('\n')), 650,
                        'engine.dart دوباره بزرگ شد')
        self.assertIn('LawMention(catalog: catalog', engine)
        self.assertNotIn('final short = full.startsWith', engine)
        ranker = _read(os.path.join(ROOT, 'lib', 'core', 'law_ranker.dart'))
        for owned in ('RankResult rankInternal(', 'double coverage(',
                      'static int _lowerBound(', 'void _addPrefixTerms('):
            self.assertIn(owned, ranker)
        for gone in ('_rankInternal', '_defQ', '_addPrefixTerms', '_promoteDefinitions'):
            self.assertNotIn(gone, engine, 'موتور دوباره %s را دارد' % gone)
        self.assertTrue(os.path.exists(
            os.path.join(ROOT, 'test', 'core', 'law_ranker_test.dart')))
        index = _read(os.path.join(ROOT, 'lib', 'core', 'law_index.dart'))
        for owned in ('void parseInto', 'static IndexBuild build(',
                      'void adopt(IndexBuild b)'):
            self.assertIn(owned, index)
            self.assertNotIn(owned, engine,
                             'موتور دوباره %s را خودش دارد' % owned)
        # `chunkOf` رابطِ عمومیِ موتور است؛ فقط باید پاس‌دهنده باشد.
        self.assertIn('=> _index.chunkOf(', engine)
        for test in ('law_mention_test.dart', 'law_index_test.dart'):
            self.assertTrue(os.path.exists(
                os.path.join(ROOT, 'test', 'core', test)), test)

    def test_detection_and_plan_stand_alone(self):
        """«کدام موضوع؟» و «چه بپرسم؟» باید بیرون از `Advocate` زندگی کنند.

        تا وقتی این دو متدِ `_`دارِ کلاس بودند، آزمودنشان یعنی ساختنِ یک
        `Advocate` و اجرای یک گفتگو؛ یعنی هیچ‌وقت مستقیم آزموده نمی‌شدند.
        """
        self.assertIn('static int of(Topic t, String n)', _read(TOPIC_SCORE))
        self.assertIn('static Slot? nextSlot(Topic t, CaseFile f)',
                      _read(CASE_PLAN))
        self.assertTrue(os.path.exists(ISOLATION_TEST),
                        'آزمونِ مستقلِ تشخیص/پرسش نیست')
        # منطق نباید دوباره داخلِ کلاس برگردد.
        self.assertNotIn('t.cues.entries', _read(os.path.join(ADVOCATE_DIR, 'advocate_topic.dart')))
        for name in ('advocate.dart', 'advocate_case.dart'):
            src = _read(os.path.join(ADVOCATE_DIR, name))
            self.assertNotIn('Reasoner.nextQuestion', src,
                             '%s دوباره نقشهٔ پرسش را خودش می‌چیند' % name)

    def test_turn_count_is_not_rewound(self):
        """`respond` نباید خودش را با ترفندِ `file.turns--` صدا بزند.

        پیامی که وکیل خودش می‌سازد («بگو» ← «استدلالت چیه؟») با
        `again: true` رد می‌شود؛ شمارشِ نوبت دستکاری نمی‌شود.
        """
        code = '\n'.join(l for l in _read(ADVOCATE).split('\n')
                         if not l.strip().startswith('///'))
        self.assertNotIn('turns--', code)
        self.assertIn('bool again = false', code)
        self.assertIn('again: true', _read(ROUTES))

    def test_part_files_exist(self):
        for part in re.findall(r"^part '([^']+)'", self.src, re.M):
            self.assertTrue(os.path.exists(os.path.join(ADVOCATE_DIR, part)), part)


if __name__ == '__main__':
    unittest.main()
