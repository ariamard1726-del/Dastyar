"""شکلِ خطِ تولیدِ پاسخ: یک فایلِ ۴۱۰خطی نباید دوباره برگردد.

`advocate_reply.dart` سه کارِ جدا را با هم داشت: ترتیبِ کاندیدهای پاسخ،
نگهبان‌هایی که پیش از آن ترتیب تصمیم می‌گیرند (انصراف، سند، ایمنی، مهلت،
اصلاحِ کاربر) و دو شاخهٔ «پرونده باز است / باز نیست». این آزمون عددی می‌گوید
هر کدام باید خانهٔ خودش را داشته باشد و ترتیبِ نوزده کاندید عوض نشود.

ترتیب = اولویت است، نه سلیقه: داور اولین کاندیدی را برمی‌گرداند که پاسخ
بدهد. جابه‌جا شدنِ دو نام یعنی رفتارِ وکیل عوض شده.
"""

import os
import re
import sys
import unittest

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'dev', 'tools'))
from library import read as lib_read, line_count  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADVOCATE_DIR = os.path.join(ROOT, 'lib', 'domain', 'advocate')
ADVOCATE = os.path.join(ADVOCATE_DIR, 'advocate.dart')
PIPELINE = 'advocate_reply.dart'
GUARDS = 'advocate_reply_guard.dart'
CASE = 'advocate_reply_case.dart'

# سقف‌های امروز؛ عبور از آن‌ها یعنی خطِ تولید دوباره یک‌جا جمع شده است.
MAX_LINES = {PIPELINE: 200, GUARDS: 220, CASE: 220}

# هر تصمیم یک صاحب دارد. اعلانِ متد در Dart با دو فاصله شروع می‌شود و نامِ
# متد پیش از پرانتزِ آرگومان‌ها می‌آید؛ فراخوانی‌ها این شکل را ندارند، پس
# «تعریف» از «صدا زدن» جدا می‌شود.
OWNER = {
    '_reply': PIPELINE,
    '_leaveReply': GUARDS,
    '_filingReply': GUARDS,
    '_objectionDeadline': GUARDS,
    '_safetyReply': GUARDS,
    '_readTopics': GUARDS,
    '_correctionReply': GUARDS,
    '_noCaseReply': CASE,
    '_inCaseReply': CASE,
    '_askSwitch': CASE,
}

# ترتیبِ دقیقِ کاندیدهای پاسخ در `_reply` و دُمِ آن. عوض شدنش آگاهانه است.
CANDIDATE_ORDER = [
    'موضوعِ تازه',
    '«هیچ‌کدام»',
    'تازه است یا مربوط؟',
    'دکمهٔ دستهٔ مشکل',
    'کنار گذاشتنِ موضوع',
    'ایمنی',
    'دربارهٔ برنامه',
    'دعوا و شکایت',
    'انتخابِ موضوع',
    'حدسِ اشتباه',
    'ادامهٔ حرفِ قبلی',
    'تنظیمِ سند',
    'پیشنهادِ پاسخ',
    '«باشه»',
    'موضوعِ کنارِ هم',
    'مهلت',
    'تکرارِ حرفِ قبلی',
    'قاعدهٔ ثابت',
    'مهلتِ اعتراض',
]


def _read(name):
    """یک بخشِ کتابخانهٔ وکیل، از ابزارِ مشترکِ `dev/tools/library.py`."""
    return lib_read(os.path.join(ADVOCATE_DIR, name))


def _lines(src):
    return src.count('\n')


class ReplyPipelineShapeTests(unittest.TestCase):
    def test_pipeline_file_is_only_the_order(self):
        """فایلِ خطِ تولید، فقط ترتیبِ کاندیدهاست."""
        src = _read(PIPELINE)
        self.assertLessEqual(
            _lines(src), MAX_LINES[PIPELINE],
            'advocate_reply دوباره پر شد: %d خط' % _lines(src))
        labels = re.findall(r"AnswerCandidate\('([^']+)'", src)
        self.assertEqual(labels, CANDIDATE_ORDER,
                         'ترتیبِ کاندیدهای پاسخ عوض شده')

    def test_each_decision_has_one_home(self):
        """هر تصمیم در یک فایل و فقط یک بار تعریف شده است."""
        sources = {}
        for name in MAX_LINES:
            path = os.path.join(ADVOCATE_DIR, name)
            self.assertTrue(os.path.exists(path), 'بخش گم شده: %s' % name)
            sources[name] = _read(name)
        for method, owner in OWNER.items():
            pattern = re.compile(r'^  [\w?<>]+ %s\(' % re.escape(method), re.M)
            self.assertRegex(sources[owner], pattern,
                             '%s باید در %s باشد' % (method, owner))
            for other, src in sources.items():
                if other == owner:
                    continue
                self.assertNotRegex(src, pattern,
                                    '%s در %s هم تعریف شده' % (method, other))

    def test_parts_are_declared(self):
        """بخش‌های تازه باید `part` شده باشند، وگرنه کد کامپایل نمی‌شود."""
        src = _read('advocate.dart')
        for name in (GUARDS, CASE):
            self.assertIn("part '%s';" % name, src)
        for name in MAX_LINES:
            self.assertLessEqual(
                _lines(_read(name)), MAX_LINES[name],
                '%s از سقفِ ثبت‌شده گذشت' % name)

    def test_guards_run_before_the_order(self):
        """نگهبان‌ها پیش از تصمیمِ پرونده در فهرست می‌آیند؛ ترتیب قفل است."""
        pipeline = _read(PIPELINE)
        self.assertLess(pipeline.index("'کنار گذاشتنِ موضوع'"),
                        pipeline.index("'ایمنی'"),
                        'انصراف باید پیش از ایمنی بیاید')
        self.assertLess(pipeline.index("'ایمنی'"),
                        pipeline.index("'موضوعِ کنارِ هم'"),
                        'ایمنی باید پیش از موضوعِ کنارِ هم بیاید')
        self.assertLess(pipeline.index("'تنظیمِ سند'"),
                        pipeline.index("'مهلت'"),
                        'سند باید در گامِ اول بیاید، نه در دُم')


if __name__ == '__main__':
    unittest.main()
