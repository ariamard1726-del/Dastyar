"""خواندنِ کتابخانهٔ Dart از یک جا، برای همهٔ نگهبان‌ها.

دو بار در همین بازآرایی، نگهبانی که یک **فایل** را می‌خواند با یک تقسیمِ
**درست** قرمز شد و مجبور شدم نگهبان را عوض کنم، نه کد را:

* `test_out_is_a_delegate` که `_out` را فقط در `advocate.dart` می‌جست؛
* `test_reply_pipeline_shape` که تکه‌های `advocate_reply.dart` را تک‌تک می‌شناخت.

درسش ساده است: نگهبان باید از **کتابخانه** بخواند، نه از نامِ فایل. این ماژول
همان کار را یک بار انجام می‌دهد: سرِ کتابخانه و همهٔ `part`ها را می‌خواند،
بدنهٔ کلاس و `extension`ها را جدا می‌کند، و «این نام کجا تعریف شده؟» را جواب
می‌دهد. هیچ نگهبانی نباید دوباره `_read` یا شمارشِ آکولادِ دستی بنویسد.

API عمداً کوچک است:

    lib = DartLibrary(root, 'lib/domain/advocate/advocate.dart')
    lib.text                  # سر + همهٔ بخش‌ها
    lib.parts                 # [(نام, متن), …]
    lib.class_body('Advocate')
    lib.extensions_on('Advocate')
    lib.definition_of('respond')     # [(نامِ فایل, خط)] یا []

و برای فایل‌های تنها: `read(root, rel)`، `line_count(root, rel)`، `dart_files(root)`.
"""

import glob
import os
import re


def read(root, rel=None):
    """متنِ یک فایل؛ `read(مسیرِ کامل)` یا `read(root, مسیرِ نسبی)`."""
    path = rel if rel is not None else root
    if rel is not None:
        path = os.path.join(root, rel)
    with open(path, encoding='utf-8') as f:
        return f.read()


def line_count(root, rel):
    """یک تعریف برای «شمارِ خط» در کلِ مخزن (`wc -l`)."""
    return read(root, rel).count('\n')


def dart_files(root, sub='lib'):
    return sorted(
        os.path.relpath(p, root).replace(os.sep, '/')
        for p in glob.glob(os.path.join(root, sub, '**', '*.dart'),
                           recursive=True))


class DartLibrary:
    """سرِ کتابخانه به‌علاوهٔ همهٔ `part`هایش، به‌مثابهٔ یک متن."""

    def __init__(self, root, head):
        self.root = root
        self.head_rel = head.replace(os.sep, '/')
        self.head = read(root, self.head_rel)
        base = os.path.dirname(os.path.join(root, head))
        names = re.findall(r"^part '([^']+)'", self.head, re.M)
        self.parts = [(name, read(os.path.join(base, name))) for name in names]
        self.text = '\n'.join([self.head] + [text for _, text in self.parts])

    def sources(self):
        """(نام, متن) برای سر و هر بخش — برای ادعاهای «این تعریف یک بار»."""
        yield os.path.basename(self.head_rel), self.head
        for name, text in self.parts:
            yield name, text

    def class_body(self, name):
        """خطوطِ داخلِ `class name { … }` از سرِ کتابخانه."""
        return class_body_of(self.head, name)

    def class_body_text(self, name):
        return '\n'.join(self.class_body(name))

    def extensions_on(self, type_name, source=None):
        """متنِ هر `extension … on <type> { … }` (در سر یا در بخش‌ها)."""
        found = []
        for _, text in self.sources():
            found.extend(_extensions_on(type_name, text))
        if source is not None:
            found.extend(_extensions_on(type_name, source))
        return found

    def definition_of(self, name, source=None):
        """فایل‌هایی که `name` را در آن‌ها تعریف می‌کنند (نه صدا می‌زنند)."""
        pattern = re.compile(r'^  [\w<>?, ]+ (?:get )?%s\b' % re.escape(name), re.M)
        hits = [fname for fname, text in self.sources() if pattern.search(text)]
        if source is not None:
            hits = [fname for fname in hits]
        return hits


def class_body_of(src, name):
    """خطوطِ داخلِ `class name { … }` در یک متنِ داده‌شده."""
    lines = src.split('\n')
    try:
        start = next(i for i, l in enumerate(lines)
                     if l.startswith('class %s {' % name))
    except StopIteration:
        raise AssertionError('کلاس پیدا نشد: %s' % name)
    end = next(i for i in range(start + 1, len(lines)) if lines[i] == '}')
    return lines[start:end + 1]


def extensions_on(type_name, src):
    """متنِ هر `extension … on <type> { … }` در یک متنِ داده‌شده."""
    return _extensions_on(type_name, src)


def _extensions_on(type_name, src):
    out = []
    lines = src.split('\n')
    marker = ' on %s {' % type_name
    for i, line in enumerate(lines):
        if line.startswith('extension ') and marker in line:
            depth = 0
            for k in range(i, len(lines)):
                depth += lines[k].count('{') - lines[k].count('}')
                if k > i and depth == 0:
                    out.append('\n'.join(lines[i:k + 1]))
                    break
    return out


def parts_of(root, head):
    """نامِ `part`های یک کتابخانه، به ترتیب."""
    return re.findall(r"^part '([^']+)'", read(root, head), re.M)
