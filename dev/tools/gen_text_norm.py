"""تولید فایل‌های قاعدهٔ متن از قرارداد `dev/tools/contracts/text_norm.json`.

چرا تولید و نه نوشتنِ دستی: همان قاعده‌ها (نگاشت نویسه، اعراب، نشانه‌ها،
بازنویسی‌ها) در دارت و پایتون تکرار می‌شدند و هر تغییر، دو جای ویرایش
می‌خواست. حالا یک فایل مرجع است و دو فایل تولیدشده.

اجرا:
  python3 dev/tools/gen_text_norm.py --check   # تازه است؟ (کدِ خروج ۱ اگر نه)
  python3 dev/tools/gen_text_norm.py --write   # تولید دوباره
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONTRACT = os.path.join(ROOT, 'dev', 'tools', 'contracts', 'text_norm.json')
DART_OUT = os.path.join(ROOT, 'lib', 'core', 'text_norm_rules.dart')
PY_OUT = os.path.join(ROOT, 'dev', 'brain', 'text_norm_rules.py')

DART_HEADER = '''// تولیدشده از dev/tools/contracts/text_norm.json — دستی ویرایش نکنید.
// تولید دوباره: python3 dev/tools/gen_text_norm.py --write
// بررسی تازگی:  python3 dev/tools/gen_text_norm.py --check
'''

PY_HEADER = '''"""تولیدشده از dev/tools/contracts/text_norm.json — دستی ویرایش نکنید.

تولید دوباره: python3 dev/tools/gen_text_norm.py --write
بررسی تازگی:  python3 dev/tools/gen_text_norm.py --check
"""
'''


def load(path=CONTRACT):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def _sorted_items(mapping):
    return sorted(mapping.items(), key=lambda kv: ord(kv[0]))


def _dart_str(s):
    if "'" in s:
        raise ValueError('نویسهٔ نقل‌قول در رشتهٔ قاعده: %r' % s)
    escaped = ''.join(
        '\\u%04x' % ord(ch) if 0x200B <= ord(ch) <= 0x200F else ch
        for ch in s
    )
    return "'%s'" % escaped


def _dart_raw(s):
    if "'" in s:
        raise ValueError('نویسهٔ نقل‌قول در الگوی قاعده: %r' % s)
    if s.endswith('\\'):
        raise ValueError('الگوی قاعده به بک‌اسلش ختم می‌شود: %r' % s)
    return "r'%s'" % s


def _py_str(s):
    return repr(s)


def _py_tuple(items):
    """تاپلِ پایتون با کامای پایانی برای تک‌عضو (وگرنه `(1600)` عدد است، نه تاپل)."""
    if not items:
        return '()'
    if len(items) == 1:
        return '%s,' % items[0]
    return ', '.join(items)


def _py_raw(s):
    if "'" in s and '"' in s:
        raise ValueError('الگوی قاعده هم نقل‌قول تک و هم دوتایی دارد: %r' % s)
    if "'" in s:
        return 'r"%s"' % s
    return "r'%s'" % s


def render_dart(c):
    ch = c['chars']
    nm = c['norm']
    sp = c['spaced']
    tk = c['tokenize']
    out = [DART_HEADER, '', '''/// قاعده‌های یکدست‌سازی متن — تنها مرجع، `dev/tools/contracts/text_norm.json`.
///
/// پیش‌تر همین نگاشت‌ها و مجموعه‌ها در `persian_text.dart`، `text_sense.dart`
/// و سه ابزار پایتون جدا نوشته شده بودند؛ تغییرِ یک قاعده یعنی ویرایشِ پنج
/// جا و ریسکِ واگراییِ خاموش. حالا قاعده یک‌جاست.
class TextNormRules {
  TextNormRules._();
''']
    out.append('  /// نگاشت نویسه‌های عربی به فارسی.')
    out.append('  static const Map<String, String> charMap = <String, String>{')
    for k, v in _sorted_items(ch['map']):
        out.append('    %s: %s, // U+%04X' % (
            _dart_str(k), _dart_str(v), ord(k)))
    out.append('  };')
    out.append('')
    out.append('  /// نویسه‌هایی که کامل حذف می‌شوند (کشیدگی).')
    out.append('  static const List<int> dropCodepoints = <int>[%s];' % ', '.join(
        str(n) for n in ch['dropCodepoints']))  # noqa: E501
    out.append('')
    out.append('  /// بازه‌های حذف (اعراب).')
    out.append('  static const List<List<int>> dropRanges = <List<int>>[')
    for lo, hi in ch['dropRanges']:
        out.append('    <int>[%d, %d],' % (lo, hi))
    out.append('  ];')
    out.append('')
    out.append('  /// نویسه‌هایی که به فاصله تبدیل می‌شوند (نیم‌فاصله، پیوند و جهت).')
    out.append('  static const List<int> toSpaceCodepoints = <int>[%s];' % ', '.join(
        str(n) for n in ch['toSpaceCodepoints']))
    out.append('')
    out.append('  /// [از، تا، پایه] → رقم لاتین (فارسی و عربی).')
    out.append('  static const List<List<int>> digitRanges = <List<int>>[')
    for lo, hi, base in ch['digitRanges']:
        out.append('    <int>[%d, %d, %d],' % (lo, hi, base))
    out.append('  ];')
    out.append('')
    out.append('  static const bool lowercase = %s;' %
               ('true' if ch['lowercase'] else 'false'))
    out.append('')
    out.append('  // ---- لایهٔ دوم (`Sense.norm`) ----')
    out.append('')
    out.append('  static const String questionMarkFrom = %s;' % _dart_str(nm['questionMarkFrom']))
    out.append('  static const String questionMarkTo = %s;' % _dart_str(nm['questionMarkTo']))
    out.append('  static const bool questionMarkPad = %s;' %
               ('true' if nm['questionMarkPad'] else 'false'))
    out.append('  static const String normPunct = %s;' % _dart_raw(nm['punct']))
    out.append('  static const String normDot = %s;' % _dart_raw(nm['dot']))
    out.append('  static const String normJoinMi = %s;' % _dart_raw(nm['joinMi']))
    out.append('  static const bool normPad = %s;' %
               ('true' if nm['pad'] else 'false'))
    out.append('')
    out.append('  /// بازنویسی‌های محاوره، به ترتیب؛ اولی زودتر اجرا می‌شود.')
    out.append('  static const List<List<String>> canon = <List<String>>[')
    for pat, rep in nm['canon']:
        out.append('    <String>[%s, %s],' % (_dart_raw(pat), _dart_str(rep)))
    out.append('  ];')
    out.append('')
    out.append('  // ---- لایهٔ واژه‌بندی و ریشه‌یابی (`PersianText` / `eval_py`) ----')
    out.append('')
    out.append('  static const String nonWord = %s;' % _dart_raw(tk['nonWord']))
    out.append('  static const int stemMinStem = %d;' % tk['stemMinStem'])
    out.append('  static const List<String> suffixes = <String>[%s];' % ', '.join(
        _dart_str(s) for s in tk['suffixes']))
    out.append('  static const List<String> suffixesIndex = <String>[%s];' % ', '.join(
        _dart_str(s) for s in tk['suffixesIndex']))
    out.append('  static const Set<String> stop = <String>{')
    stop_words = sorted(tk['stop'])
    for i in range(0, len(stop_words), 8):
        out.append('    %s,' % ', '.join(_dart_str(w) for w in stop_words[i:i + 8]))
    out.append('  };')
    out.append('')
    out.append('  // ---- نسخه‌های فاصله‌دار (`TopicFlow` و `LawTerms`) ----')
    for key, label in (('tools', 'Tools'), ('terms', 'Terms')):
        v = sp[key]
        out.append('')
        out.append('  static const Map<String, String> spaced%sMap = <String, String>{' % label)
        for k, rep in _sorted_items(v['map']):
            out.append('    %s: %s, // U+%04X' % (
                _dart_str(k), _dart_str(rep), ord(k)))
        out.append('  };')
        if v['dropRanges']:
            out.append('  static const List<List<int>> spaced%sDropRanges = <List<int>>[' % label)
            for lo, hi in v['dropRanges']:
                out.append('    <int>[%d, %d],' % (lo, hi))
            out.append('  ];')
        else:
            out.append('  static const List<List<int>> spaced%sDropRanges = <List<int>>[];' % label)
        out.append('  static const String spaced%sPunct = %s;' % (label, _dart_raw(v['punct'])))
        out.append('  static const bool spaced%sPad = %s;' % (
            label, 'true' if v['pad'] else 'false'))
    out.append('}')
    out.append('')
    return '\n'.join(out)


def render_py(c):
    ch = c['chars']
    nm = c['norm']
    tk = c['tokenize']
    out = [PY_HEADER, '']
    out.append('CHAR_MAP = {')
    for k, v in _sorted_items(ch['map']):
        out.append('    %s: %s,  # U+%04X' % (_py_str(k), _py_str(v), ord(k)))
    out.append('}')
    out.append('')
    out.append('DROP_CODEPOINTS = (%s)' % _py_tuple(
        [str(n) for n in ch['dropCodepoints']]))
    out.append('DROP_RANGES = (%s)' % _py_tuple(
        ['(%d, %d)' % (lo, hi) for lo, hi in ch['dropRanges']]))
    out.append('TO_SPACE_CODEPOINTS = (%s)' % _py_tuple(
        [str(n) for n in ch['toSpaceCodepoints']]))
    out.append('DIGIT_RANGES = (%s)' % _py_tuple(
        ['(%d, %d, %d)' % (lo, hi, base) for lo, hi, base in ch['digitRanges']]))
    out.append('LOWERCASE = %s' % ('True' if ch['lowercase'] else 'False'))
    out.append('')
    out.append('QUESTION_MARK_FROM = %s' % _py_str(nm['questionMarkFrom']))
    out.append('QUESTION_MARK_TO = %s' % _py_str(nm['questionMarkTo']))
    out.append('QUESTION_MARK_PAD = %s' % ('True' if nm['questionMarkPad'] else 'False'))
    out.append('NORM_PUNCT = %s' % _py_raw(nm['punct']))
    out.append('NORM_DOT = %s' % _py_raw(nm['dot']))
    out.append('NORM_JOIN_MI = %s' % _py_raw(nm['joinMi']))
    out.append('NORM_PAD = %s' % ('True' if nm['pad'] else 'False'))
    out.append('CANON = (')
    for pat, rep in nm['canon']:
        out.append('    (%s, %s),' % (_py_raw(pat), _py_str(rep)))
    out.append(')')
    out.append('')
    out.append('NONWORD_PATTERN = %s' % _py_raw(tk['nonWord']))
    out.append('STEM_MIN_STEM = %d' % tk['stemMinStem'])
    out.append('SUFFIXES = (%s)' % _py_tuple([_py_str(s) for s in tk['suffixes']]))
    out.append('SUFFIXES_INDEX = (%s)' % _py_tuple([_py_str(s) for s in tk['suffixesIndex']]))
    out.append('STOP = frozenset({')
    for w in sorted(tk['stop']):
        out.append('    %s,' % _py_str(w))
    out.append('})')
    out.append('')
    out.append('# نسخه‌های ابزارها: تفاوت‌ها یک‌جا اینجاست، نه در پیاده‌سازی‌های جدا.')
    out.append('SPACED = {')
    for name in sorted(c['spaced']):
        if name == 'description':
            continue
        v = c['spaced'][name]
        out.append("    '%s': {" % name)
        out.append("        'usedBy': %s," % _py_str(v['usedBy']))
        out.append("        'map': {")
        for k, rep in _sorted_items(v['map']):
            out.append('            %s: %s,  # U+%04X' % (
                _py_str(k), _py_str(rep), ord(k)))
        out.append('        },')
        out.append("        'drop': (%s)," % _py_tuple(
            ['(%d, %d)' % (lo, hi) for lo, hi in v['dropRanges']]))
        out.append("        'punct': %s," % _py_raw(v['punct']))
        out.append("        'pad': %s," % ('True' if v['pad'] else 'False'))
        out.append('    },')
    out.append('}')
    out.append('')
    return '\n'.join(out)


def targets():
    c = load()
    return {DART_OUT: render_dart(c), PY_OUT: render_py(c)}


def main(argv):
    check = '--check' in argv
    write = '--write' in argv or not check
    bad = []
    for path, text in targets().items():
        old = None
        if os.path.exists(path):
            with open(path, encoding='utf-8') as f:
                old = f.read()
        if old == text:
            if check:
                print('تازه است: %s' % os.path.relpath(path, ROOT))
            continue
        if check:
            bad.append(path)
            print('کهنه است: %s — python3 dev/tools/gen_text_norm.py --write' %
                  os.path.relpath(path, ROOT))
        elif write:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(text)
            print('نوشته شد: %s' % os.path.relpath(path, ROOT))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
