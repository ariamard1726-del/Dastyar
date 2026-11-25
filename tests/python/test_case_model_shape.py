"""شکلِ پروندهٔ وکیل: وضعیت یک فایل، مدل‌ها فایلِ دیگر.

`case_file.dart` ۴۰۱ خط بود و **نُه** چیزِ متفاوت در آن زندگی می‌کرد:
خودِ پروندهٔ گفتگو (وضعیت + JSON) و هشت مدلِ زبانِ موضوع (`Element`، `Claim`،
`Slot`، `Issue`، `Filing`، `Prompt`، `Topic` و typedefهایشان). هر کسی که فقط
`CaseFile` می‌خواست، هشت مدل را هم می‌خواند و برعکس.

این آزمون عددی سه چیز را می‌سنجد: سقفِ خطِ هر فایل، صاحبِ هر نام (و یک‌بار
تعریف شدنش)، و اینکه `case_file.dart` فقط **دروازه** باشد — چون ۴۰ فایل در
`lib/` و آزمون‌ها همان مسیرِ پیشین را `import` می‌کنند و نباید عوض شود.
"""

import os
import re
import sys
import unittest

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'tools'))
from lines import line_count  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADVOCATE_DIR = os.path.join(ROOT, 'lib', 'domain', 'advocate')

GATE = 'case_file.dart'
STATE = 'case_state.dart'
MODEL = 'case_model.dart'

# سقف‌ها اندازهٔ واقعیِ امروز است، نه آرزو: ۲۸۳ خط برای هفت مدلِ کوچک که یک
# واژگان‌اند (شکستنِ دوباره‌شان، یک زبان را تکه‌تکه می‌کند). عبور از سقف یعنی
# مدلِ تازه‌ای به همین فایل اضافه شده است.
MAX_LINES = {GATE: 40, STATE: 200, MODEL: 300}

# هر نام یک صاحب دارد.
OWNER = {
    'CaseFile': STATE,
    'Element': MODEL,
    'Claim': MODEL,
    'Slot': MODEL,
    'Issue': MODEL,
    'Filing': MODEL,
    'Prompt': MODEL,
    'Topic': MODEL,
}

TYPEDEFS = ['Body', 'Reader', 'Cond', 'Tri']


def _read(name):
    path = os.path.join(ADVOCATE_DIR, name)
    with open(path, encoding='utf-8') as f:
        return f.read()


def _lines(src):
    """«شمارِ خط» با همان تعریفِ `tools/lines.py` (همان `wc -l`)."""
    return src.count('\n')


def _exists(name):
    return os.path.exists(os.path.join(ADVOCATE_DIR, name))


class CaseFileShapeTests(unittest.TestCase):
    def test_the_gate_is_only_a_gate(self):
        """`case_file.dart` باید فقط دو export داشته باشد، نه کد."""
        self.assertTrue(_exists(GATE))
        src = _read(GATE)
        self.assertLessEqual(_lines(src), MAX_LINES[GATE],
                             'case_file دوباره کد شد: %d خط' % _lines(src))
        self.assertNotIn('class ', src, 'کلاس نباید در فایلِ دروازه تعریف شود')
        exports = re.findall(r"^export '([^']+)'", src, re.M)
        self.assertEqual(sorted(exports), sorted([STATE, MODEL]),
                         'دروازه باید هر دو صاحب را export کند')
        # آنچه export می‌شود باید وجود داشته باشد.
        for name in exports:
            self.assertTrue(_exists(name), 'exportِ فایلِ ناموجود: %s' % name)

    def test_every_name_has_one_owner(self):
        """هر مدل در یک فایل و فقط یک بار تعریف شده است."""
        for name in (STATE, MODEL):
            self.assertTrue(_exists(name), 'بخش گم شده: %s' % name)
        sources = {name: _read(name) for name in (GATE, STATE, MODEL)}
        for type_name, owner in OWNER.items():
            decl = re.compile(r'^class %s\b' % type_name, re.M)
            self.assertRegex(sources[owner], decl,
                             '%s باید در %s باشد' % (type_name, owner))
            for other, src in sources.items():
                if other == owner:
                    continue
                self.assertNotRegex(src, decl,
                                    '%s در %s هم تعریف شده' % (type_name, other))
        for typedef in TYPEDEFS:
            decl = re.compile(r'^typedef %s =' % typedef, re.M)
            self.assertRegex(sources[MODEL], decl, 'typedef %s باید در %s باشد' % (typedef, MODEL))
            self.assertNotRegex(sources[STATE], decl, 'typedef %s از مدل جدا شد' % typedef)

    def test_state_is_the_only_writer_of_facts(self):
        """وضعیتِ گفتگو در یک فایل است: پرونده، واقعیت‌ها، JSON."""
        state = _read(STATE)
        for member in ('final Map<String, String> facts = {}',
                       'Map<String, dynamic> toJson()',
                       'factory CaseFile.fromJson(',
                       'static const int schemaVersion = 1'):
            self.assertIn(member, state, member)

    def test_model_files_stay_under_the_ceiling(self):
        for name, cap in MAX_LINES.items():
            self.assertLessEqual(_lines(_read(name)), cap,
                                 '%s از سقفِ ثبت‌شده گذشت' % name)

    def test_the_file_that_owns_case_file_does_not_own_topics(self):
        """مرزِ اصلی: وضعیتِ گفتگو نباید به زبانِ موضوع‌ها آلوده شود."""
        state = _read(STATE)
        self.assertNotIn('class Slot', state)
        self.assertNotIn('class Topic', state)
        self.assertNotIn('class Claim', state)


if __name__ == '__main__':
    unittest.main()
