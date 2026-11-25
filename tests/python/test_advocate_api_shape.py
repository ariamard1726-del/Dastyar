"""شکلِ `advocate.dart`: سیم‌کشی یک فایل، API فایلِ دیگر.

آخرین گاد-آبجکتِ `lib/`: ۴۰۳ خط که در آن سه چیزِ متفاوت بود —

1. **سیم‌کشی**: بیست همکارِ `late final` و پرونده و صدا و وضعیتِ گفتگو؛
2. **API عمومی**: `respond`، `reset`، `replay`، `restoreCase`، `filings`،
   `draftIds`، `fillFor`، `hasCase`، `idleChips` و هم‌نوع‌هایشان؛
3. **اعضای `static`**: `topics`، `wantsDraft`، `topicOf`، `_correctionPattern`،
   `_afterCorrection` — این‌ها **نمی‌توانند** به `extension` بروند.

این آزمون عددی می‌گوید: فایلِ کلاس فقط سیم‌کشی و `static`ها باشد، API در
`advocate_api.dart`، و هیچ‌کدام دو جا تعریف نشوند.
"""

import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADVOCATE_DIR = os.path.join(ROOT, 'lib', 'domain', 'advocate')
HEAD = 'advocate.dart'
API = 'advocate_api.dart'

# سقف‌های امروز؛ عبور یعنی API و سیم‌کشی دوباره یکی شده‌اند.
MAX_LINES = {HEAD: 260, API: 200}

# متد یا گترِ عمومی/خصوصیِ API → صاحبش.
API_MEMBERS = [
    'respond', 'wantsGuess', 'reset', 'replay', 'restoreCase', 'fillFor',
    'filingFor', 'clearOffer', '_withLeave', '_out',
]
API_GETTERS = ['hasCase', 'hasMore', 'offeredDraft', 'draftIds', 'filings',
               'idleChips']

# اعضایی که باید در فایلِ کلاس بمانند (static در extension نمی‌آید).
STATICS = ['topics', 'wantsDraft', 'topicOf', '_correctionPattern',
           '_afterCorrection']


def _read(directory, name):
    path = os.path.join(directory, name)
    with open(path, encoding='utf-8') as f:
        return f.read()


def _method(name):
    return re.compile(r'^  [\w<>?, ]+ %s\(' % re.escape(name), re.M)


def _getter(name):
    return re.compile(r'^  [\w<>?, ]+ get %s\b' % re.escape(name), re.M)


def _library():
    """همهٔ فایل‌های کتابخانهٔ وکیل: سر + `part`ها."""
    head = _read(ADVOCATE_DIR, HEAD)
    parts = re.findall(r"^part '([^']+)'", head, re.M)
    return {HEAD: head, **{p: _read(ADVOCATE_DIR, p) for p in parts}}


class AdvocateApiShapeTests(unittest.TestCase):
    def test_api_has_its_own_file(self):
        path = os.path.join(ADVOCATE_DIR, API)
        self.assertTrue(os.path.exists(path), 'advocate_api.dart ساخته نشده')
        api = _read(ADVOCATE_DIR, API)
        self.assertLessEqual(len(api.split('\n')), MAX_LINES[API],
                             'advocate_api از سقفِ ثبت‌شده گذشت')
        # نامِ extension باید عمومی باشد: نامِ خصوصی، اعضا را از بیرونِ
        # کتابخانه پنهان می‌کند و `advocate.respond` در UI ناشناخته می‌شود.
        self.assertIn('extension AdvocateApi on Advocate {', api)
        self.assertNotIn('extension _AdvocateApi', api)

    def test_class_file_is_wiring_only(self):
        head = _read(ADVOCATE_DIR, HEAD)
        self.assertLessEqual(len(head.split('\n')), MAX_LINES[HEAD],
                             'advocate.dart دوباره پر شد: %d خط'
                             % len(head.split('\n')))
        self.assertIn("part '%s';" % API, head)

    def test_each_api_member_has_one_home(self):
        # مرز روی دو فایلی سنجیده می‌شود که عضوِ خودِ `Advocate` را دارند.
        # فایل‌های دیگر کلاس‌های خودشان را دارند و هم‌نامی با آن‌ها عیب نیست
        # (مثلاً `CaseFlow.clearOffer`).
        api = _read(ADVOCATE_DIR, API)
        head = _read(ADVOCATE_DIR, HEAD)
        for name in API_MEMBERS:
            pattern = _method(name)
            self.assertRegex(api, pattern, '%s باید در %s باشد' % (name, API))
            self.assertNotRegex(head, pattern,
                                '%s در فایلِ کلاس مانده' % name)
        for name in API_GETTERS:
            pattern = _getter(name)
            self.assertRegex(api, pattern, '%s باید در %s باشد' % (name, API))
            self.assertNotRegex(head, pattern,
                                '%s در فایلِ کلاس مانده' % name)

    def test_statics_stay_on_the_class(self):
        """`static` در `extension` معنا ندارد؛ این‌ها باید در فایلِ کلاس بمانند."""
        head = _read(ADVOCATE_DIR, HEAD)
        self.assertIn('static final List<Topic> topics = allTopics;', head)
        self.assertIn('static bool wantsDraft(String raw) {', head)
        self.assertIn('static String? topicOf(String raw) {', head)
        self.assertIn('static String _afterCorrection(String n) {', head)
        api = _read(ADVOCATE_DIR, API)
        code = [l for l in api.split('\n') if not l.lstrip().startswith('//')]
        self.assertNotRegex('\n'.join(code), r'^\s+static ',
                            'static در %s نباید باشد' % API)

    def test_wiring_is_not_an_extensions_business(self):
        """همکاران `late final` بخشی از سیم‌کشی‌اند و نباید به API بروند."""
        api = _read(ADVOCATE_DIR, API)
        for collaborator in ('late final ReplyRoutes', 'late final CaseFlow',
                             'late final ReplyVoice', 'late final TalkReply',
                             'late final GuideReply', 'late final TopicPicker'):
            self.assertNotIn(collaborator, api,
                             '%s به فایلِ API رفت؛ سیم‌کشی جای خودش است'
                             % collaborator)


if __name__ == '__main__':
    unittest.main()
