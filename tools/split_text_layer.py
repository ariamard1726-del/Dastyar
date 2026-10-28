# -*- coding: utf-8 -*-
"""مرحلهٔ ۲ اسکلت: لایهٔ متن فارسی از engine.dart به lib/persian_text.dart می‌رود.
رفتار برنامه تغییر نمی‌کند؛ KnowledgeEngine.normalize/tokenize/tokenizeIndex همان‌طور کار می‌کنند.
اجرا: python tools/split_text_layer.py
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ENGINE = os.path.join(ROOT, 'lib', 'engine.dart')
OUT = os.path.join(ROOT, 'lib', 'persian_text.dart')
START = "  static const Set<String> _stop = {"
END = "  static bool _isObsolete(String body) {"

if os.path.exists(OUT):
    print('persian_text.dart از قبل هست؛ کاری نشد.')
    sys.exit(1)
src = open(ENGINE, encoding='utf-8').read()
a, b = src.find(START), src.find(END)
if a < 0 or b < 0 or b < a or src.count(START) != 1 or src.count(END) != 1:
    print('خطا: جای بلوک در engine.dart همان نیست که انتظار می‌رفت؛ چیزی تغییر نکرد.')
    sys.exit(1)

block = src[a:b].rstrip() + '\n'
if block.count('_collapse') != 1:
    print('خطا: ساختار بلوک متفاوت است؛ چیزی تغییر نکرد.')
    sys.exit(1)
block = block.replace('static String _collapse(String s)', 'static String collapse(String s)')
block += """
  /// عبارت یکدست‌شده: نرمال، بدون نشانه، با فاصلهٔ تک.
  static String phrase(String s) =>
      collapse(normalize(s).replaceAll(_nonWord, ' '));
"""

head = """/// لایهٔ متن فارسی: یکدست‌سازی نویسه‌ها، ریشه‌یابی سبک و واژه‌بندی.
/// موتور جست‌وجو و بخش‌های دیگر فقط از اینجا استفاده می‌کنند،
/// تا هر بهبود زبانی (ریشه‌یاب بهتر، نیم‌فاصله، ...) در یک جا انجام شود.
class PersianText {
  PersianText._();

"""
open(OUT, 'w', encoding='utf-8').write(head + block + '}\n')

delegates = """  // لایهٔ متن به persian_text.dart رفته؛ اینجا فقط نام‌های قدیمی نگه داشته شده‌اند.
  static String normalize(String s) => PersianText.normalize(s);

  static String _collapse(String s) => PersianText.collapse(s);

  static List<String> tokenizeIndex(String s) => PersianText.tokenizeIndex(s);

  static List<String> tokenize(String s) => PersianText.tokenize(s);

"""
new = src[:a] + delegates + src[b:]

old_phrase = """  static String _phrase(String s) =>
      _collapse(normalize(s).replaceAll(_nonWord, ' '));"""
if new.count(old_phrase) != 1:
    print('خطا: _phrase پیدا نشد؛ چیزی تغییر نکرد.')
    os.remove(OUT)
    sys.exit(1)
new = new.replace(old_phrase, "  static String _phrase(String s) => PersianText.phrase(s);")

imp = "import 'templates.dart' show TemplateRenderer;"
if new.count(imp) != 1:
    print('خطا: خط import پیدا نشد؛ چیزی تغییر نکرد.')
    os.remove(OUT)
    sys.exit(1)
new = new.replace(imp, "import 'persian_text.dart';\n" + imp)

for leftover in ('_stop', '_nonWord', '_stemIndex', '_suffixes'):
    if re.search(r'\b%s\b' % leftover, new):
        print('خطا: %s هنوز در engine.dart استفاده می‌شود؛ بازگردانی.' % leftover)
        os.remove(OUT)
        sys.exit(1)

open(ENGINE, 'w', encoding='utf-8').write(new)
print('انجام شد: lib/persian_text.dart ساخته شد، engine.dart %d → %d خط.'
      % (src.count('\n'), new.count('\n')))
