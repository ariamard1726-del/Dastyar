"""گاد-آبجکتِ زنده نباید برگردد: معیارِ کلاس، نه فقط سقفِ فایل.

`test_file_sizes.py` فقط اندازهٔ فایل را میسنجد. یک کلاس میتواند در فایلی
کوچک، ۲۵ فیلدِ حالتی داشته باشد و هر متدی آزادانه آنها را عوض کند — همان
چیزی که در `DialogueState` رخ داده بود. این آزمون تعداد فیلدهای حالتیِ
سطحِ کلاس را میشمارد و سقف میگذارد. فیلدهای `final` و `static` جزءِ
«وضعیت قابل تغییر» نیستند؛ getter/setter هم فیلد محسوب نمیشوند.
"""

import os
import re
import sys
import unittest

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'dev', 'tools'))
from library import dart_files, read  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

MAX_STATE_FIELDS = 12
FIELD = re.compile(
    r'^  (?!(?:static|const|final|late final|get|set)\b)'
    r'(?:late\s+)?[\w<>?,\[\]\s]+?\s+(\w+)\s*(?:=|;)')


def state_fields(source, class_name):
    lines = source.split('\n')
    start = next((i for i, l in enumerate(lines)
                  if l.startswith('class %s {' % class_name)), None)
    if start is None:
        return None
    depth = 0
    fields = []
    for i in range(start, len(lines)):
        line = lines[i]
        before = depth
        depth += line.count('{') - line.count('}')
        getter = re.match(r'^  [\w<>?,\[\]\s]+\s+(get|set)\b', line)
        if before == 1 and FIELD.match(line) and not getter:
            fields.append(line.strip())
        if i > start and depth == 0:
            break
    return fields


class NoGodObjectTest(unittest.TestCase):
    def setUp(self):
        self.sources = {rel: read(ROOT, rel) for rel in dart_files(ROOT)}

    def test_no_class_owns_too_mutable_state(self):
        bad = {}
        for rel, src in self.sources.items():
            for match in re.finditer(r'^class (\w+)', src, re.M):
                fields = state_fields(src, match.group(1))
                if fields is not None and len(fields) > MAX_STATE_FIELDS:
                    bad['%s:%s' % (rel, match.group(1))] = fields
        self.assertEqual(bad, {},
                         'کلاسهایی که دوباره گاد-آبجکت شدند: %r' % bad)

    def test_dialogue_state_is_a_facade_over_sections(self):
        src = self.sources['lib/domain/advocate/dialogue_state.dart']
        for name in ('QuestionState', 'ChoiceState', 'GuideState',
                     'SafetyState', 'UnclearState'):
            self.assertIn('%s %s =' % (name, {
                'QuestionState': 'question',
                'ChoiceState': 'choice',
                'GuideState': 'guideState',
                'SafetyState': 'safety',
                'UnclearState': 'unclear',
            }[name]), src, '%s هنوز مستقیم روی DialogueState است' % name)
        for old in ('  String askText =', '  bool safetyShown =',
                    '  List<Topic> choices ='):
            self.assertNotIn(old, src, 'فیلد قدیمی برگشت: %s' % old)
        for path in ('lib/domain/advocate/dialogue_sections.dart',):
            self.assertIn(path, self.sources)


if __name__ == '__main__':
    unittest.main()
