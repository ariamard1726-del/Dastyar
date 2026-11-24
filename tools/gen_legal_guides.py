"""تبدیلِ دادهٔ `legal_guides.dart` به JSON، بدونِ دست‌زدن به متن.

این ابزار **ترجمه‌گرِ ساختاری** است، نه نویسنده: هیچ حرفی به متن اضافه یا کم
نمی‌کند و خروجی چند بار اجرا شود یکی است. ترتیبِ راهنماها و ترتیبِ کلیدها حفظ
می‌شود تا مقایسهٔ فایل و کد ساده باشد.

قاعده‌ها:
- رشته‌های `'...'` و `r'...'` خوانده می‌شوند؛ `\\n` به خطِ تازه تبدیل می‌شود.
- `LegalGuide(...)`، `LegalRef(...)` و `GuideNote(...)` به شکلِ صریحِ JSON درمی‌آیند.
- فیلدهایی که در کد نیامده‌اند (مقدارِ پیش‌فرضِ سازنده) در JSON هم نمی‌آیند.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, 'lib', 'domain', 'lawyer', 'legal_guides.dart')
OUT = os.path.join(ROOT, 'tools', 'data', 'legal_guides.json')


class Reader:
    def __init__(self, text):
        self.s = text
        self.i = 0

    def fail(self, msg):
        line = self.s.count('\n', 0, self.i) + 1
        raise ValueError('%s (خط %d)' % (msg, line))

    def ws(self):
        while self.i < len(self.s):
            c = self.s[self.i]
            if c in ' \t\r\n,':
                self.i += 1
            elif self.s.startswith('//', self.i):
                j = self.s.find('\n', self.i)
                self.i = len(self.s) if j < 0 else j + 1
            else:
                return

    def peek(self):
        self.ws()
        return self.s[self.i] if self.i < len(self.s) else ''

    def string(self):
        raw = False
        if self.s.startswith("r'", self.i):
            raw = True
            self.i += 1
        if self.s[self.i] != "'":
            self.fail('رشتهٔ ناشناخته')
        self.i += 1
        out = []
        while True:
            c = self.s[self.i]
            if c == '\\' and not raw:
                nxt = self.s[self.i + 1]
                out.append({'n': '\n', 't': '\t', "'": "'", '\\': '\\', '"': '"',
                            '$': '$', 'r': '\r'}.get(nxt, '\\' + nxt))
                self.i += 2
                continue
            if c == "'":
                self.i += 1
                return ''.join(out)
            out.append(c)
            self.i += 1

    def value(self):
        self.ws()
        c = self.s[self.i]
        if c == "'" or self.s.startswith("r'", self.i):
            return self.string()
        if c == '[':
            self.i += 1
            items = []
            while self.peek() != ']':
                items.append(self.value())
            self.i += 1
            return items
        if c.isdigit() or c == '-':
            j = self.i
            while self.i < len(self.s) and (self.s[self.i].isdigit() or self.s[self.i] in '-.'):
                self.i += 1
            return float(self.s[j:self.i]) if '.' in self.s[j:self.i] else int(self.s[j:self.i])
        if c.isalpha() or c == '_':
            j = self.i
            while self.i < len(self.s) and (self.s[self.i].isalnum() or self.s[self.i] == '_'):
                self.i += 1
            name = self.s[j:self.i]
            if self.peek() == '(':
                return self.call(name)
            return {'true': True, 'false': False, 'null': None}.get(name, name)
        self.fail('مقدارِ ناشناخته: %r' % c)

    def call(self, name):
        self.i += 1  # '('
        args, named = [], {}
        while self.peek() != ')':
            # arg: نام‌دار یا مکانی
            save = self.i
            self.ws()
            j = self.i
            while self.i < len(self.s) and (self.s[self.i].isalnum() or self.s[self.i] == '_'):
                self.i += 1
            label = self.s[j:self.i]
            self.ws()
            if label and self.s[self.i] == ':':
                self.i += 1
                named[label] = self.value()
            else:
                self.i = save
                args.append(self.value())
        self.i += 1  # ')'
        return {'__call__': name, 'args': args, 'named': named}


def convert(node):
    """درختِ خوانده‌شده → شکلِ صریحِ JSON."""
    if isinstance(node, list):
        return [convert(x) for x in node]
    if not isinstance(node, dict) or '__call__' not in node:
        return node
    name, args, named = node['__call__'], node['args'], node['named']
    if name == 'LegalRef':
        return {'law': args[0], 'article': str(args[1])}
    if name == 'GuideNote':
        return {'cues': convert(args[0]), 'text': args[1]}
    if name == 'LegalGuide':
        out = {}
        for key, val in named.items():
            out[key] = convert(val)
        return out
    raise ValueError('سازندهٔ ناشناخته: %s' % name)


def parse(source):
    """فهرستِ راهنماها را از متنِ Dart می‌خواند."""
    marker = 'const List<LegalGuide> legalGuides = ['
    i = source.index(marker) + len(marker)
    r = Reader(source)
    r.i = i
    guides = []
    while r.peek() != ']':
        node = r.value()
        if not (isinstance(node, dict) and node.get('__call__') == 'LegalGuide'):
            raise ValueError('عضوِ ناشناخته در فهرستِ راهنماها')
        guides.append(convert(node))
    return guides


def load_dart():
    with open(SOURCE, encoding='utf-8') as f:
        return parse(f.read())


def load_json():
    with open(OUT, encoding='utf-8') as f:
        return json.load(f)


def build():
    return {'generated_by': 'tools/gen_legal_guides.py', 'guides': load_dart()}


def main(argv):
    data = build()
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
        f.write('\n')
    print('نوشته شد: %s (%d راهنما)' % (os.path.relpath(OUT, ROOT), len(data['guides'])))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
