"""تولید فایل‌های قاعدهٔ تطبیق واژه‌ها از `dev/tools/contracts/law_terms.json`.

چرا: فهرستِ ۱۵۳ واژه‌ایِ ایست‌واژه و آستانه‌ها در `law_terms.dart` و
`law_terms.py` دستی نگه داشته می‌شد؛ یک واژهٔ تازه یعنی دو ویرایش و ریسکِ
واگراییِ خاموش. آزمون آینه فقط از واگرایی جلوگیری می‌کرد، رفعش نمی‌کرد.

اجرا:
  python3 dev/tools/gen_law_terms.py --check
  python3 dev/tools/gen_law_terms.py --write
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONTRACT = os.path.join(ROOT, 'dev', 'tools', 'contracts', 'law_terms.json')
DART_OUT = os.path.join(ROOT, 'lib', 'domain', 'advocate', 'law_terms_rules.dart')
PY_OUT = os.path.join(ROOT, 'dev', 'brain', 'law_terms_rules.py')

DART_HEADER = '''// تولیدشده از dev/tools/contracts/law_terms.json — دستی ویرایش نکنید.
// تولید دوباره: python3 dev/tools/gen_law_terms.py --write
// بررسی تازگی:  python3 dev/tools/gen_law_terms.py --check
'''

PY_HEADER = '''"""تولیدشده از dev/tools/contracts/law_terms.json — دستی ویرایش نکنید.

تولید دوباره: python3 dev/tools/gen_law_terms.py --write
بررسی تازگی:  python3 dev/tools/gen_law_terms.py --check
"""
'''

# در دارت هر خط چند واژه؛ فهرستِ ۱۵۳ واژه‌ای یک‌خطی خواندنی نیست.
PER_LINE = 6


def load(path=CONTRACT):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def _sorted_words(words):
    return sorted(words)


def _dart_str(s):
    if "'" in s:
        raise ValueError('نویسهٔ نقل‌قول در قاعده: %r' % s)
    return "'%s'" % s


def _py_str(s):
    return repr(s)


def render_dart(c):
    out = [DART_HEADER, '', '''/// قاعده‌های تطبیق واژه‌ها — تنها مرجع، `dev/tools/contracts/law_terms.json`.
///
/// آینهٔ پایتونی‌اش `dev/brain/law_terms_rules.py` است و از همین قرارداد تولید
/// می‌شود؛ `python3 dev/tools/check.py lawterms` کهنه‌بودن هر دو را خطا می‌دهد.
class LawTermsRules {
  LawTermsRules._();
''']
    out.append('  /// املای محاوره‌ای یا عربیِ رایج که در متن قوانین جور دیگری است.')
    out.append('  static const Map<String, String> alias = <String, String>{')
    for k in sorted(c['alias']):
        out.append('    %s: %s,' % (_dart_str(k), _dart_str(c['alias'][k])))
    out.append('  };')
    out.append('')
    out.append('  /// واژه‌های گفتاری یا عمومیِ بی‌بار که در تطبیق شرکت نمی‌کنند.')
    out.append('  static const Set<String> generic = <String>{')
    words = _sorted_words(c['generic'])
    for i in range(0, len(words), PER_LINE):
        chunk = words[i:i + PER_LINE]
        out.append('    %s,' % ', '.join(_dart_str(w) for w in chunk))
    out.append('  };')
    out.append('')
    th = c['thresholds']
    out.append('  /// کوتاه‌تر از این تعداد نویسه، واژهٔ معنادار حساب نمی‌شود.')
    out.append('  static const int minLen = %d;' % th['minLen'])
    out.append('')
    out.append('  /// تعداد نامزدهای برتر که عبارت‌ها روی آن‌ها سنجیده می‌شود.')
    out.append('  static const int topCount = %d;' % th['top'])
    out.append('')
    out.append('  /// کمترین پوشش برای پذیرش همراه با دو واژه.')
    out.append('  static const double minCover = %s;' % _dart_double(th['minCover']))
    out.append('')
    out.append('  /// واژه‌ای که در بیش از این تعداد ماده آمده، «نادر» نیست.')
    out.append('  static const int rareDf = %d;' % th['rareDf'])
    out.append('')
    out.append('  /// بیشترین فاصلهٔ واژه‌های یک عبارت در متن ماده.')
    out.append('  static const int maxSpan = %d;' % th['maxSpan'])
    out.append('')
    out.append('  /// کمترین مجموع idf برای اینکه دو واژه «عبارت» حساب شود.')
    out.append('  static const double phraseMinIdf = %s;' %
               _dart_double(th['phraseMinIdf']))
    out.append('')
    out.append('  /// برچسب متنی که از بانک قوانین نیست.')
    out.append('  static const String generalSource = %s;' %
               _dart_str(c['generalSource']))
    out.append('}')
    out.append('')
    return '\n'.join(out)


def _dart_double(v):
    """`4.0` بمانَد؛ در دارت `4` برای double خطاست."""
    s = ('%f' % v).rstrip('0')
    return s + '0' if s.endswith('.') else s


def render_py(c):
    out = [PY_HEADER, '']
    out.append('ALIAS = {')
    for k in sorted(c['alias']):
        out.append('    %s: %s,' % (_py_str(k), _py_str(c['alias'][k])))
    out.append('}')
    out.append('')
    out.append('GENERIC = frozenset({')
    for w in _sorted_words(c['generic']):
        out.append('    %s,' % _py_str(w))
    out.append('})')
    out.append('')
    th = c['thresholds']
    out.append('MIN_LEN = %d' % th['minLen'])
    out.append('TOP = %d' % th['top'])
    out.append('MIN_COVER = %s' % repr(float(th['minCover'])))
    out.append('RARE_DF = %d' % th['rareDf'])
    out.append('MAX_SPAN = %d' % th['maxSpan'])
    out.append('PHRASE_MIN_IDF = %s' % repr(float(th['phraseMinIdf'])))
    out.append('GENERAL_SOURCE = %s' % _py_str(c['generalSource']))
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
            print('کهنه است: %s — python3 dev/tools/gen_law_terms.py --write' %
                  os.path.relpath(path, ROOT))
        elif write:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(text)
            print('نوشته شد: %s' % os.path.relpath(path, ROOT))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
