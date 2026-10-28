# -*- coding: utf-8 -*-
"""مرحلهٔ ۴ اسکلت: پاسخ‌های ثابت از engine.dart به assets/replies.json می‌روند.
متن‌ها دقیقاً همان‌هایی‌اند که الان در engine.dart هست (از خود فایل خوانده می‌شوند)،
پس رفتار برنامه تغییر نمی‌کند. اجرا: python tools/split_replies.py
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENGINE = os.path.join(ROOT, 'lib', 'engine.dart')
REPLIES_DART = os.path.join(ROOT, 'lib', 'replies.dart')
REPLIES_JSON = os.path.join(ROOT, 'assets', 'replies.json')
PUBSPEC = os.path.join(ROOT, 'pubspec.yaml')

if os.path.exists(REPLIES_DART) or os.path.exists(REPLIES_JSON):
    print('replies از قبل هست؛ کاری نشد.')
    sys.exit(1)

src = open(ENGINE, encoding='utf-8').read()
pub = open(PUBSPEC, encoding='utf-8').read()

# (کلید، الگو با گروه‌های pre / text / post، عبارت جایگزین Dart)
ITEMS = [
    ('capabilities',
     r"(?P<pre>String _assistantCapabilitiesText\(\) \{\n    return )'(?P<text>[^']*)'(?P<post>;)",
     "replies.get('capabilities')"),
    ('outcome_prediction',
     r"(?P<pre>String _outcomePredictionText\(\) \{\n    return )'(?P<text>[^']*)'(?P<post>;)",
     "replies.get('outcome_prediction')"),
    ('greeting',
     r"(?P<pre>if \(n\.contains\('سلام'\)\) return )'(?P<text>سلام![^']*)'(?P<post>;)",
     "replies.get('greeting')"),
    ('ask_more',
     r"(?P<pre>return )'(?P<text>لطفاً پرسش خود را[^']*)'(?P<post>;)",
     "replies.get('ask_more')"),
    ('no_knowledge',
     r"(?P<pre>return )'(?P<text>هنوز دانشی در برنامه نیست\.)'(?P<post>;)",
     "replies.get('no_knowledge')"),
    ('no_laws',
     r"(?P<pre>return )'(?P<text>هنوز متن هیچ قانونی در برنامه نیست\.)'(?P<post>;)",
     "replies.get('no_laws')"),
    ('not_found',
     r"(?P<pre>String _notFound\(\) \{\n    return )'(?P<text>[^']*)'(?P<post>;)",
     "replies.get('not_found')"),
    ('low_confidence',
     r"(?P<pre>res =\n          )'(?P<text>توجه: مطمئن نیستم[^']*?)\\n\\n\$res'(?P<post>;)",
     "'${replies.get('low_confidence')}\\n\\n$res'"),
    ('missing_law',
     r"(?P<pre>: )'(?P<text>توجه: متن «\$\{missing\.first\.title\}» هنوز در برنامه نیست\.)'(?P<post>;)",
     "replies.get('missing_law', {'law': missing.first.title})"),
]

values = {}
new = src
for key, pat, expr in ITEMS:
    ms = list(re.finditer(pat, new))
    if len(ms) != 1:
        print('خطا: «%s» در engine.dart %d بار پیدا شد (باید ۱ بار)؛ چیزی تغییر نکرد.' % (key, len(ms)))
        sys.exit(1)
    m = ms[0]
    text = m.group('text')
    if key == 'missing_law':
        text = text.replace('${missing.first.title}', '{law}')
    if any(c in text for c in ("'", '$', '\\')):
        print('خطا: متن «%s» نویسهٔ ممنوع دارد؛ چیزی تغییر نکرد.' % key)
        sys.exit(1)
    values[key] = text
    new = new[:m.start()] + m.group('pre') + expr + m.group('post') + new[m.end():]

# import، فیلد و بارگذاری
imp = "import 'templates.dart' show TemplateRenderer;"
if new.count(imp) != 1:
    print('خطا: خط import پیدا نشد؛ چیزی تغییر نکرد.')
    sys.exit(1)
new = new.replace(imp, "import 'replies.dart';\n" + imp)

fld = "  final List<Chunk> _chunks = [];"
if new.count(fld) != 1:
    print('خطا: جای فیلد پیدا نشد؛ چیزی تغییر نکرد.')
    sys.exit(1)
new = new.replace(fld, "  /// پاسخ‌های ثابت؛ از assets/replies.json خوانده می‌شوند.\n  final Replies replies = Replies();\n" + fld)

mark = "    // ۱. لود فایل دانش عمومی"
if new.count(mark) != 1:
    print('خطا: جای بارگذاری پیدا نشد؛ چیزی تغییر نکرد.')
    sys.exit(1)
loader = """    try {
      final t = await rootBundle.loadString('assets/replies.json');
      final m = jsonDecode(t) as Map<String, dynamic>;
      replies.setOverrides(m.map((k, v) => MapEntry(k, v.toString())));
    } catch (e) {
      warnings.add('replies.json: $e');
    }

"""
new = new.replace(mark, loader + mark)

pk = "    - assets/knowledge.txt\n"
if pub.count(pk) != 1:
    print('خطا: خط knowledge.txt در pubspec.yaml پیدا نشد؛ چیزی تغییر نکرد.')
    sys.exit(1)
pub = pub.replace(pk, pk + "    - assets/replies.json\n")

# نوشتن فایل‌ها
dart = ["/// پاسخ‌های ثابت برنامه. متن‌ها در assets/replies.json ویرایش می‌شوند؛",
        "/// مقدارهای زیر پیش‌فرض‌اند تا اگر فایل خراب بود برنامه ساکت نماند.",
        "class Replies {",
        "  static const Map<String, String> defaults = {"]
for k, v in values.items():
    dart.append("    '%s':\n        '%s'," % (k, v))
dart += ["  };", "",
         "  Map<String, String> _over = {};", "",
         "  void setOverrides(Map<String, String> m) => _over = m;", "",
         "  /// جای‌نگهدار {name} با مقدار vars جایگزین می‌شود.",
         "  String get(String key, [Map<String, String> vars = const {}]) {",
         "    var t = _over[key] ?? defaults[key] ?? '';",
         "    vars.forEach((k, v) => t = t.replaceAll('{$k}', v));",
         "    return t;",
         "  }",
         "}", ""]
open(REPLIES_DART, 'w', encoding='utf-8').write('\n'.join(dart))
with open(REPLIES_JSON, 'w', encoding='utf-8') as f:
    json.dump(values, f, ensure_ascii=False, indent=2)
    f.write('\n')
open(ENGINE, 'w', encoding='utf-8').write(new)
open(PUBSPEC, 'w', encoding='utf-8').write(pub)
print('انجام شد: %d پاسخ ثابت به assets/replies.json رفت؛ engine.dart %d → %d خط.'
      % (len(values), src.count('\n'), new.count('\n')))
