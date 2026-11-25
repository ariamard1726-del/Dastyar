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
import sys
import unittest

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'tools'))
from library import (DartLibrary, class_body_of,  # noqa: E402
                     extensions_on, read as lib_read)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADVOCATE_DIR = os.path.join(ROOT, 'lib', 'domain', 'advocate')
ADVOCATE = os.path.join(ADVOCATE_DIR, 'advocate.dart')
VOICE = os.path.join(ADVOCATE_DIR, 'reply_voice.dart')
DIALOGUE = os.path.join(ADVOCATE_DIR, 'dialogue_state.dart')
ROUTES = os.path.join(ADVOCATE_DIR, 'reply_routes.dart')
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
    """همهٔ خواندن‌ها از ابزارِ مشترکِ `tools/library.py`."""
    return lib_read(path)


def _class_body(src, name='Advocate'):
    return class_body_of(src, name)


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

# همکارها نه وضعیت‌اند نه گاد-آبجکت: خودشان صاحبِ داده‌اند. اگر فیلدی از این
# نوع‌ها روی Advocate باشد، یعنی وکیل فقط آن‌ها را به هم وصل می‌کند.
COLLABORATORS = ['DialogueState', 'ReplyVoice', 'CaseArgument', 'ChipPlan',
                 'MetaReply', 'LawTerms', 'KnowledgeEngine', 'IntentNet',
                 'LawAnswer', 'TalkReply', 'TopicPicker', 'CaseFlow',
                 'TalkRoute', 'ReplyRoutes', 'GuideReply', 'TermReply', 'SafetyReply']
COLLABORATOR_FIELD = re.compile(
    r'^  (?:late final|final|late)\s+(?:%s)\b' % '|'.join(COLLABORATORS))

# API عمومی: این‌ها باید عضوِ خودِ کلاس باشند. عضوِ `extension` نیاز به
# `import` کتابخانه در همان فایل دارد و از راهِ نوع (مثلاً `Advocate` که از
# `ChatController` گرفته می‌شود) دیده نمی‌شود.
PUBLIC_API = ['respond', 'reset', 'replay', 'restoreCase', 'filings',
              'draftIds', 'fillFor', 'filingFor', 'hasCase', 'hasMore',
              'offeredDraft', 'clearOffer', 'idleChips', 'wantsGuess']

MOVED_FIELDS = ['_rest', '_offeredMore', '_lastAsk', '_askRepeats',
                '_relevantChip', '_vary', '_said', '_lastBody', '_lastLaws']


def _extensions_on_advocate(src):
    """متنِ همهٔ `extension … on Advocate { … }` در یک فایل."""
    return extensions_on('Advocate', src)


class ShapeTests(unittest.TestCase):
    def setUp(self):
        self.src = _read(ADVOCATE)
        # کتابخانهٔ وکیل از چند بخش ساخته می‌شود؛ `self.src` فقط فایلِ کلاس است
        # و `self.lib` همهٔ بخش‌ها. ادعاهای ساختاری روی `src` و ادعاهای
        # «کجا صدا زده می‌شود» روی `lib` نوشته می‌شوند.
        self.library = DartLibrary(ROOT, ADVOCATE)
        self.parts = self.library.parts
        self.lib = self.library.text

    def test_state_fields_do_not_grow(self):
        fields = [l for l in _class_body(self.src)
                  if STATE_FIELD.match(l) and not COLLABORATOR_FIELD.match(l)]
        self.assertLessEqual(
            len(fields), MAX_STATE_FIELDS,
            'فیلد حالتیِ Advocate زیاد شد (%d):\n%s' % (len(fields), '\n'.join(fields)))

    def test_talk_lives_in_talk_reply(self):
        """خلاصه/احوال‌پرسی/«منظورتان چیست» نباید دوباره متدِ Advocate شود."""
        talk = _read(os.path.join(ADVOCATE_DIR, 'talk_reply.dart'))
        part = _read(os.path.join(ADVOCATE_DIR, 'advocate_talk.dart'))
        self.assertIn('class TalkReply {', talk)
        for sig in ('AdvocateReply summary(Topic? topic) {',
                    'AdvocateReply? social(String n, Topic? topic) {',
                    'AdvocateReply unclearReply(String raw',
                    'bool anyTopicCue(String n) {'):
            self.assertIn(sig, talk, sig)
            self.assertNotIn(sig.replace(' {', ''), part)
        self.assertLess(len(part.split('\n')), 420, 'advocate_talk دوباره پر شد')
        self.assertIn('TalkReply _talk', self.src)

    def test_topic_picking_is_its_own_class(self):
        """تشخیصِ موضوع نباید دوباره متدهای Advocate شود."""
        pick = _read(os.path.join(ADVOCATE_DIR, 'topic_picker.dart'))
        part = _read(os.path.join(ADVOCATE_DIR, 'advocate_topic.dart'))
        self.assertIn('class TopicPicker {', pick)
        for sig in ('Topic? current() {', 'bool answers(Topic t, String n) {',
                    'Topic? secondOpinion(String raw, String n) {',
                    'LegalGuide? matchGuide(String raw, String n) {'):
            self.assertIn(sig, pick, sig)
        self.assertNotIn('Topic? _secondOpinion(String raw, String n) {', part)
        self.assertLess(len(part.split('\n')), 90, 'advocate_topic دوباره پر شد')
        self.assertIn('TopicPicker _picker', self.src)
        self.assertTrue(os.path.exists(
            os.path.join(ROOT, 'test', 'advocate', 'topic_picker_test.dart')))

    def test_guides_stay_data(self):
        """راهنمای آماده در کد نیست: مدل و ثبت، نه متن و نه رفتار."""
        path = os.path.join(ROOT, 'lib', 'domain', 'lawyer', 'legal_guides.dart')
        self.assertTrue(os.path.exists(path))
        guides = _read(path)
        methods = re.findall(r'^  (?:static\s+)?[\w<>?,\[\] ]+?\s+\w+\([^)]*\)\s*'
                             r'(?:async\s*)?(?:\{|=>)', guides, re.M)
        self.assertEqual(methods, [], 'legal_guides.dart متد گرفت: %r' % methods[:3])
        self.assertLess(len(guides.split('\n')), 140,
                        'داده دوباره داخلِ کد نوشته شد (%d خط)' % len(guides.split('\n')))
        self.assertEqual(guides.count("    id: '"), 0, 'رکوردِ راهنما در کد ماند')
        self.assertIn('List<LegalGuide> get legalGuides', guides)
        self.assertIn('void installLegalGuides(', guides)

    def test_topics_are_split(self):
        """موضوع‌های بزرگ نباید یک فایلِ هزارخطی باشند."""
        topics = os.path.join(ADVOCATE_DIR, 'topics')
        for main in ('rent.dart', 'labor.dart', 'family.dart'):
            src = _read(os.path.join(topics, main))
            parts = re.findall(r"part '([^']+)';", src)
            self.assertGreaterEqual(len(parts), 3, main)
            for p in parts:
                path = os.path.join(topics, p)
                self.assertTrue(os.path.exists(path), path)
                self.assertIn("part of '%s';" % main, _read(path), path)
        # هیچ فایلی در topics نباید دوباره غول شود
        for f in sorted(os.listdir(topics)):
            if not f.endswith('.dart'):
                continue
            n = len(_read(os.path.join(topics, f)).split('\n'))
            self.assertLessEqual(n, 820, '%s دوباره بزرگ شد (%d خط)' % (f, n))

    def test_talk_route_is_its_own_class(self):
        """مسیرِ گفت‌وگوی عمومی (سلام/سوگ/خلاصه/دستهٔ مشکل) نباید متدِ Advocate باشد."""
        route = _read(os.path.join(ADVOCATE_DIR, 'talk_route.dart'))
        part = _read(os.path.join(ADVOCATE_DIR, 'advocate_talk.dart'))
        self.assertIn('class TalkRoute {', route)
        for sig in ('AdvocateReply? meta(String n, Topic? topic',
                    'List<String> branchStart() {',
                    'AdvocateReply? branchReply(String raw, String n',
                    'AdvocateReply intake(String raw) =>'):
            self.assertIn(sig, route, sig)
        # پوستهٔ talk نباید دوباره بدنه داشته باشد
        self.assertLess(len(part.split('\n')), 130, 'advocate_talk دوباره پر شد')
        self.assertIn('_talkRoute.meta(', part)
        self.assertNotIn('_idleChips()', part)
        self.assertIn('TalkRoute _talkRoute', self.src)

    def test_safety_reply_is_its_own_class(self):
        """ایمنی باید یک واحدِ آزمون‌پذیر باشد، نه متدِ خصوصیِ وکیل."""
        sr = _read(os.path.join(ADVOCATE_DIR, 'safety_reply.dart'))
        self.assertIn('class SafetyReply {', sr)
        self.assertIn('AdvocateReply? reply(String n) {', sr)
        self.assertIn('bool asksDanger(String n) =>', sr)
        self.assertIn('source: AnswerSource.safety', sr)
        self.assertIn('SafetyReply _safetyBot', self.src)
        # قاعدهٔ خشونت نباید دوباره داخلِ Advocate بنشیند.
        self.assertNotIn('چاقو', self.src)
        self.assertNotIn('AdvocateReply? _safety(String n)', self.src)
        self.assertTrue(os.path.exists(
            os.path.join(ROOT, 'test', 'domain', 'safety_reply_test.dart')))

    def test_reply_is_one_ordered_list(self):
        """ترتیبِ پاسخ‌ها باید خواندنی باشد، نه زنجیرهٔ `if`های پشتِ‌سرِهم."""
        ac = _read(os.path.join(ADVOCATE_DIR, 'answer_candidate.dart'))
        self.assertIn('class AnswerCandidate {', ac)
        self.assertIn('class AnswerArbiter {', ac)
        self.assertIn('_arbiter.pick(', self.lib)
        names = re.findall(r"AnswerCandidate\('([^']+)'", self.lib)
        self.assertGreaterEqual(len(names), 15, names)
        self.assertEqual(names[0], 'موضوعِ تازه', names[:2])
        # سبکِ پیشین: هر مسیر با `if` جدا و پراکنده در `_reply` — برنگردد.
        self.assertNotIn('if (_routes.', self.lib)
        self.assertNotIn('final branch = _branchReply(', self.lib)
        # ایمنی و انصراف هم کاندید شدند، نه بلوکِ درون‌خطی.
        self.assertIn('_leaveReply(', self.lib)
        self.assertIn('_safetyReply(', self.lib)

    def test_reply_no_longer_mixes_counting_with_deciding(self):
        """محاسبهٔ موضوع باید از تصمیمِ `_reply` جدا بماند و `_reply` کوتاه بماند."""
        tr = _read(os.path.join(ADVOCATE_DIR, 'topic_read.dart'))
        self.assertIn('class TopicRead {', tr)
        self.assertIn('final Topic? best;', tr)
        self.assertIn('final Map<String, int> scores;', tr)
        reply = _method(self.lib, 'AdvocateReply _reply(String raw')
        self.assertLess(reply.count('\n'), 140, '_reply دوباره پر شد: %d خط' % reply.count('\n'))
        self.assertIn('_readTopics(n)', reply)
        # حلقه‌های امتیازدهی و اصلاحِ کاربر نباید دوباره در `_reply` نوشته شوند.
        self.assertNotIn('for (final t in topics)', reply)
        self.assertNotIn('_afterCorrection(', reply)
        self.assertIn('_noCaseReply(raw, n, read, guess)', reply)
        self.assertIn('_inCaseReply(raw, n, topic, read)', reply)
        self.assertIn('TopicRead _readTopics(String n)', self.lib)

    def test_term_reply_is_its_own_class(self):
        """پاسخ‌های واژه‌محور نباید دوباره متدِ Advocate شوند."""
        tr = _read(os.path.join(ADVOCATE_DIR, 'term_reply.dart'))
        self.assertIn('class TermReply {', tr)
        for sig in ('AdvocateReply? lawTerms(String raw, String n)',
                    'AdvocateReply? topicFlow(String raw, String n)',
                    'AdvocateReply? _topicLeaf(Map<String, dynamic> flow'):
            self.assertIn(sig, tr, sig)
        self.assertIn('TermReply _termReply', self.src)
        self.assertIn('_termReply.lawTerms(', self.lib)
        self.assertIn('_termReply.topicFlow(', self.lib)
        # فایلِ پوسته حذف شد؛ اگر کسی پاسخِ واژه‌محور را برگرداند، این می‌گیردش.
        self.assertFalse(
            os.path.exists(os.path.join(ADVOCATE_DIR, 'advocate_guides.dart')),
            'advocate_guides دوباره ساخته شد')
        self.assertNotIn('_lawTermsReply(', self.lib)

    def test_guide_reply_is_its_own_class(self):
        """راهنما و واژه‌نامه نباید دوباره متدِ Advocate شوند."""
        bg = _read(os.path.join(ADVOCATE_DIR, 'guide_reply.dart'))
        self.assertIn('class GuideReply {', bg)
        for sig in ('AdvocateReply lookup(String raw, String n)',
                    'String? glossary(String n)',
                    'AdvocateReply openGuide(LegalGuide g, String raw, String n',
                    'AdvocateReply? follow(LegalGuide g, String n)'):
            self.assertIn(sig, bg, sig)
        self.assertIn('GuideReply _guides', self.src)
        self.assertIn('_guides.lookup(', self.lib)
        self.assertNotIn('AdvocateReply? _guideFollow(', self.src)

    def test_case_flow_is_its_own_class(self):
        """روندِ پرونده نباید دوباره ۱۳ متدِ خصوصیِ Advocate شود.

        روند در چهار فایلِ هم‌کتابخانه است (کلاس + سه `extension`)، پس متنِ هر
        چهار با هم خوانده می‌شود؛ وگرنه جابه‌جا شدنِ یک متد به بخشِ دیگر، آزمون
        را بی‌سبب قرمز می‌کند.
        """
        flow = '\n'.join(
            _read(os.path.join(ADVOCATE_DIR, name))
            for name in ('case_flow.dart', 'case_facts.dart',
                         'case_answer.dart', 'case_text.dart'))
        shell = _read(os.path.join(ADVOCATE_DIR, 'advocate_case.dart'))
        self.assertIn('class CaseFlow {', flow)
        for sig in ('AdvocateReply inCase(Topic t, String raw, String n, Issue? issue) {',
                    'AdvocateReply open(Topic t, String n,',
                    'AdvocateReply finish(Topic t, List<String> parts',
                    'List<Slot> absorb(Topic t, String n, {bool live = true}) {'):
            self.assertIn(sig, flow, sig)
        # پوسته نباید دوباره منطق داشته باشد
        self.assertLess(len(shell.split('\n')), 90, 'advocate_case دوباره پر شد')
        for bad in ('file.pending', 'dialog.loose', 'voice.said'):
            self.assertNotIn(bad, shell)
        self.assertIn('CaseFlow _case', self.src)

    def test_the_reply_model_has_its_own_part(self):
        """مدلِ پاسخ (`AnswerSource`، `AdvocateReply`، `_Ask`) در فایلِ خودش.

        این‌ها داده‌اند، نه رفتار: بردنشان از `advocate.dart` هیچ امضایی را
        عوض نمی‌کند (بخش‌های یک کتابخانه‌اند) و فقط حجمِ فایلِ سیم‌کشی را کم
        می‌کند. آزمون، هم نبودشان در فایلِ اصلی و هم دست‌نخورده بودنِ میدان‌های
        `AdvocateReply` را می‌سنجد.
        """
        model = _read(os.path.join(ADVOCATE_DIR, 'advocate_model.dart'))
        for decl in ('enum AnswerSource {', 'class AdvocateReply {', 'class _Ask {'):
            self.assertIn(decl, model, decl)
            self.assertNotIn(decl, self.src, '%s دوباره در advocate.dart است' % decl)
        for field in ('final String text;', 'final List<String> chips;',
                      'final List<LawText> laws;', 'final AnswerSource source;'):
            self.assertIn(field, model, field)
        self.assertIn("part 'advocate_model.dart';", self.src)

    def test_chip_labels_are_data_not_class_members(self):
        """متنِ دکمه‌ها داده است: یک فایلِ خودش، با همان کلمه‌ها.

        دکمه‌ها چیزی هستند که کاربر می‌بیند؛ جابه‌جا کردنشان نباید یک حرف را
        عوض کند. آزمون هم محل را می‌سنجد (نه عضوِ کلاسِ سیم‌کشی) و هم خودِ
        یازده برچسب را، حرف‌به‌حرف.
        """
        chips = _read(os.path.join(ADVOCATE_DIR, 'chip_texts.dart'))
        self.assertIn('class ChipTexts {', chips)
        labels = ('ادامه بده', 'متن قانون را ببینم', 'موضوع تازه‌ای دارم',
                  'این یک موضوع جداست', 'به همین ماجرای قبلی مربوط است',
                  'بله، موضوع تازه است', 'خیر، به همان ماجرا مربوط است',
                  'انصراف', 'هیچ‌کدام', 'موضوعم این نیست', 'حقوقی', 'کیفری',
                  'اداری', 'نمی‌دانم')
        missing = [l for l in labels if "'%s'" % l not in chips]
        self.assertEqual(missing, [], 'برچسبِ دکمه عوض شد یا گم شد: %s' % missing)
        self.assertNotIn('static const String moreChip', self.src,
                         'ثابت‌های دکمه دوباره عضوِ Advocate شدند')
        self.assertIn("part 'chip_texts.dart';", self.src)

    def test_the_data_tables_live_outside_the_class(self):
        """جدول‌های داده (ترتیبِ مسیرها، نگاشتِ شبکهٔ نیت) عضوِ کلاس نباشند.

        `pipelineOrder` فقط یک فهرست نیست؛ **ترتیبش رفتار است**: ایمنی پیش از
        موضوع، و شبکهٔ نیت پس از راهنما. آزمون، هم محل را می‌سنجد و هم ترتیب را
        حرف‌به‌حرف، تا جابه‌جاییِ جدول، رفتار را عوض نکند.
        """
        data = _read(os.path.join(ADVOCATE_DIR, 'advocate_data.dart'))
        for name in ('netTopics', 'netMin', 'pipelineOrder', 'guessTopics'):
            self.assertRegex(data, r'(?m)^const .*\b%s\b' % name,
                             'جدولِ %s در advocate_data.dart نیست' % name)
            self.assertNotIn('static const %s' % name, self.src)
        order = ['safety', 'topic', 'lawTerms', 'glossary', 'guide',
                 'topicFlow', 'guess', 'intentNet', 'qaBank', 'engine']
        self.assertIn("part 'advocate_data.dart';", self.src)
        seen = [l.strip().split('.')[-1].rstrip(',') for l in data.split('\n')
                if l.strip().startswith('AnswerSource.')]
        self.assertEqual(seen, order, 'ترتیبِ مسیرهای پاسخ عوض شد')

    def test_collaborators_are_wired(self):
        """هر کارِ جدا باید همکارِ خودش را داشته باشد، نه فیلدِ حالتی."""
        for name in ('DialogueState dialog', 'ReplyVoice voice',
                     'CaseArgument _argument', 'MetaReply _metaReplyBot',
                     'LawAnswer _lawAnswer', 'TalkReply _talk',
                     'TopicPicker _picker', 'CaseFlow _case',
                     'TalkRoute _talkRoute'):
            self.assertIn(name, self.src, name)

    def test_reply_does_not_grow(self):
        body = _method(self.lib, 'AdvocateReply _reply(String raw')
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
        self.assertIn('class ReplyRoutes {', routes)
        handlers = re.findall(r'^  AdvocateReply\? (\w+)\(', routes, re.M)
        self.assertGreaterEqual(len(handlers), MIN_ROUTES, handlers)
        for h in handlers:
            self.assertIn('_routes.%s(' % h, self.lib,
                          'مسیر %s از _reply صدا زده نمی‌شود' % h)
        # دوباره‌چپاندنِ همین بلوک‌ها در `_reply` نباید ممکن باشد.
        reply = _method(self.lib, 'AdvocateReply _reply(String raw')
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

    def test_public_api_stays_on_the_class(self):
        """API عمومی روی خودِ کلاس بماند، نه در `extension`.

        دلیلش رفتاری است، نه سلیقه: عضوِ `extension` فقط در فایلی دیده می‌شود
        که کتابخانه را `import` کرده باشد. هر مصرف‌کننده‌ای که `Advocate` را از
        راهِ دیگری بگیرد (مثل `ChatController.advocate`) `hasCase` و `respond`
        را نمی‌بیند. این یک بار در گام ۳۲ انجام شد: فایل از ۴۰۳ به ۲۴۵ رسید و
        `test/app/chat_controller_test.dart` قرمز شد. پس این نگهبان همان
        وسوسه را می‌بندد.
        """
        body = '\n'.join(_class_body(self.src))
        for name in PUBLIC_API:
            self.assertRegex(
                body, r'\n  [\w<>?, ]+ (?:get )?%s\b' % re.escape(name),
                '%s از کلاس بیرون رفت؛ API عمومی در `extension` دیده نمی‌شود'
                % name)
        for path in self.parts:
            for ext in _extensions_on_advocate(path[1]):
                for name in PUBLIC_API:
                    self.assertNotRegex(
                        ext, r'^(?!\s*//).*\b%s\b' % re.escape(name),
                        '%s در extensionِ %s تعریف شده' % (name, path[0]))

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
            self.assertLessEqual(len(body.split('\n')), 420,
                                 '%s از سقفِ خط گذشت' % name)

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

    def test_chips_and_recap_stand_alone(self):
        """دکمه‌ها و خلاصه باید تابع/کلاسِ خودشان را داشته باشند."""
        chips = _read(os.path.join(ADVOCATE_DIR, 'advocate_chips.dart'))
        plan = _read(os.path.join(ADVOCATE_DIR, 'chip_plan.dart'))
        recap = _read(os.path.join(ADVOCATE_DIR, 'case_recap.dart'))
        self.assertIn('class ChipPlan {', plan)
        self.assertIn('List<String> recapOf(Topic t, CaseFile f)', recap)
        self.assertLess(len(chips.split('\n')), 40, 'advocate_chips دوباره پر شد')
        self.assertNotIn('final near = <String, int>{};', chips)
        self.assertTrue(os.path.exists(
            os.path.join(ROOT, 'test', 'advocate', 'chip_plan_test.dart')))

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
        # موتور سه بخش است (کلاس + بارگذار + پاسخ‌ساز)؛ کلِ کتابخانه خوانده
        # می‌شود تا جابه‌جا شدنِ یک متد به بخشِ دیگر آزمون را بی‌سبب قرمز نکند.
        engine = '\n'.join(
            _read(os.path.join(ROOT, 'lib', 'core', name))
            for name in ('engine.dart', 'engine_load.dart', 'engine_query.dart'))
        self.assertLess(len(engine.split('\n')), 760,
                        'کتابخانهٔ موتور دوباره بزرگ شد')
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
        code = '\n'.join(l for l in self.lib.split('\n')
                         if not l.strip().startswith('///'))
        self.assertNotIn('turns--', code)
        self.assertIn('bool again = false', code)
        self.assertIn('again: true', _read(ROUTES))

    def test_part_files_exist(self):
        for part in re.findall(r"^part '([^']+)'", self.src, re.M):
            self.assertTrue(os.path.exists(os.path.join(ADVOCATE_DIR, part)), part)


if __name__ == '__main__':
    unittest.main()
