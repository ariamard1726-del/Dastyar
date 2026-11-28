"""تولید فایل‌های قاعدهٔ موتور بازیابی از قرارداد `dev/tools/contracts/engine_rules.json`.

چرا: الگوهای جست‌وجوی ماده، ضرایب BM25F، قواعد تعریف/منسوخ‌بودن، نام قانون،
پایش حوزه‌های خارج از پوشش و عمق زنجیرهٔ تضادها پیش‌تر در کلاس‌های
`lib/core/*` و ابزارهای `dev/tools/{eval_py,eval_none}.py` و `dev/brain/{common,engine}.py`
دستی تکرار می‌شدند. حالا یک مرجع داده‌ای است و دو خروجی تولیدشده.

اجرا:
  python3 dev/tools/gen_engine_rules.py --check   # تازه است؟ (کد خروج ۱ اگر نه)
  python3 dev/tools/gen_engine_rules.py --write   # تولید دوباره
"""

import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CONTRACT = os.path.join(ROOT, 'dev', 'tools', 'contracts', 'engine_rules.json')
DART_OUT = os.path.join(ROOT, 'lib', 'core', 'engine_rules.dart')
PY_OUT = os.path.join(ROOT, 'dev', 'brain', 'engine_rules.py')

DART_HEADER = '''// تولیدشده از dev/tools/contracts/engine_rules.json — دستی ویرایش نکنید.
// تولید دوباره: python3 dev/tools/gen_engine_rules.py --write
// بررسی تازگی:  python3 dev/tools/gen_engine_rules.py --check
'''

PY_HEADER = '''"""تولیدشده از dev/tools/contracts/engine_rules.json — دستی ویرایش نکنید.

تولید دوباره: python3 dev/tools/gen_engine_rules.py --write
بررسی تازگی:  python3 dev/tools/gen_engine_rules.py --check
"""
'''


def load(path=CONTRACT):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def _dart_str(s):
    if "'" in s:
        raise ValueError('نویسهٔ نقل‌قول در رشتهٔ قاعده: %r' % s)
    return "'%s'" % s


def _dart_raw(s):
    if "'" in s:
        raise ValueError('نویسهٔ نقل‌قول در الگوی قاعده: %r' % s)
    if s.endswith('\\'):
        raise ValueError('الگوی قاعده به بک‌اسلش ختم می‌شود: %r' % s)
    return "r'%s'" % s


def _dart_double(v):
    s = ('%f' % float(v)).rstrip('0')
    return s + '0' if s.endswith('.') else s


def _py_str(s):
    return repr(s)


def _py_raw(s):
    if "'" in s and '"' in s:
        raise ValueError('الگوی قاعده هم نقل‌قول تک و هم دوتایی دارد: %r' % s)
    if "'" in s:
        return 'r"%s"' % s
    return "r'%s'" % s


def _py_tuple(items):
    if not items:
        return '()'
    if len(items) == 1:
        return '%s,' % items[0]
    return ', '.join(items)


def _dart_list(lines, name, items, indent='  '):
    lines.append('%sstatic const List<String> %s = <String>[' % (indent, name))
    for i in range(0, len(items), 6):
        chunk = items[i:i + 6]
        lines.append('%s  %s,' % (indent, ', '.join(_dart_str(x) for x in chunk)))
    lines.append('%s];' % indent)


def _dart_set(lines, name, items, indent='  '):
    lines.append('%sstatic const Set<String> %s = <String>{' % (indent, name))
    for i in range(0, len(items), 6):
        chunk = items[i:i + 6]
        lines.append('%s  %s,' % (indent, ', '.join(_dart_str(x) for x in chunk)))
    lines.append('%s};' % indent)


def render_dart(c):
    aq = c['articleQuery']
    bm = c['bm25f']
    ob = c['obsolete']
    df = c['definitionPromotion']
    lm = c['lawMention']
    ud = c['unloadedDomain']
    cf = c['conflicts']

    out = [DART_HEADER, '', '''/// قاعده‌های یکتای موتور بازیابی — تنها مرجع، `dev/tools/contracts/engine_rules.json`.
///
/// آینهٔ پایتونی‌اش `dev/brain/engine_rules.py` است و از همین قرارداد تولید
/// می‌شود؛ `python3 dev/tools/check.py enginerules` کهنه‌بودن هر دو را خطا می‌دهد.
class EngineRules {
  EngineRules._();
''']

    out.append('  // ---- الگوی «ماده/اصل N» ----')
    out.append('  static const String articleQueryPattern = %s;' % _dart_raw(aq['pattern']))
    out.append('')

    out.append('  // ---- ضرایب BM25F و آستانه‌های پاسخ‌سازی ----')
    out.append('  static const double bm25K1 = %s;' % _dart_double(bm['k1']))
    out.append('  static const double bm25B = %s;' % _dart_double(bm['b']))
    out.append('  static const double bm25WT = %s;' % _dart_double(bm['wTitle']))
    out.append('  static const double bm25WB = %s;' % _dart_double(bm['wBody']))
    out.append('  static const double bm25WC = %s;' % _dart_double(bm['wContext']))
    out.append('  static const double obsoletePenalty = %s;' % _dart_double(bm['obsoletePenalty']))
    out.append('  static const double explicitScore = %s;' % _dart_double(bm['explicitScore']))
    out.append('  static const int prefixMinLen = %d;' % bm['prefixMinLen'])
    out.append('  static const double prefixWeight = %s;' % _dart_double(bm['prefixWeight']))
    out.append('  static const double minHitScore = %s;' % _dart_double(bm['minScore']))
    out.append('  static const double lowCover = %s;' % _dart_double(bm['lowCover']))
    out.append('  static const double coverageMargin = %s;' % _dart_double(bm['coverageMargin']))
    out.append('  static const double nearAlternativeFactor = %s;' % _dart_double(bm['nearAlternativeFactor']))
    out.append('  static const int maxNearAlternatives = %d;' % bm['maxNearAlternatives'])
    out.append('  static const double altMinScoreRatio = %s;' % _dart_double(bm['altMinScoreRatio']))
    out.append('  static const double topicRerankEps = %s;' % _dart_double(bm['topicRerankEps']))
    out.append('')

    out.append('  // ---- تشخیص مادهٔ منسوخ و پاک‌سازی سرِ متن ----')
    out.append('  static const int obsoleteMaxLen = %d;' % ob['maxLen'])
    out.append('  static const String obsoleteTrimPattern = %s;' % _dart_raw(ob['trimPattern']))
    out.append('  static const String cleanBodyPattern = %s;' % _dart_raw(ob['cleanBodyPattern']))
    _dart_list(out, 'obsoletePrefixes', ob['prefixes'])
    out.append('')

    out.append('  // ---- ارتقای مواد تعریفی («X چیست / یعنی چه») ----')
    out.append('  static const String defQuestionPattern = %s;' % _dart_raw(df['questionPattern']))
    _dart_set(out, 'defWords', df['words'])
    _dart_set(out, 'defMetaPrefixes', df['metaPrefixes'])
    out.append('  static const String defMarkPattern = %s;' % _dart_raw(df['markPattern']))
    out.append('  static const String defStrongPattern = %s;' % _dart_raw(df['strongPattern']))
    out.append('  static const int defTailWindow = %d;' % df['tailWindow'])
    out.append('  static const int defMaxPicked = %d;' % df['maxPicked'])
    out.append('')

    out.append('  // ---- شناسایی نام قانون در متن ----')
    _dart_list(out, 'lawPrefixes', lm['requiredPrefixes'])
    out.append('  static const String shortLawPrefix = %s;' % _dart_str(lm['shortLawPrefix']))
    out.append('  static const int shortLawMinLen = %d;' % lm['shortLawMinLen'])
    out.append('')

    out.append('  // ---- نگهبان حوزه‌های خارج از پوشش ----')
    _dart_list(out, 'unloadedPenalTerms', ud['penalTerms'])
    _dart_list(out, 'penalContextMarkers', ud['penalContextMarkers'])
    _dart_list(out, 'loadedCriminalExceptions', ud['loadedCriminalExceptions'])
    _dart_list(out, 'taxTriggers', ud['taxTriggers'])
    _dart_list(out, 'socialSecurityTriggers', ud['socialSecurityTriggers'])
    out.append('  static const List<(String, List<String>)> anchorGroups = <(')
    out.append('      String, List<String>)>[')
    for trigger, reqs in ud['anchorGroups']:
        req_str = ', '.join(_dart_str(r) for r in reqs)
        out.append('    (%s, <String>[%s]),' % (_dart_str(trigger), req_str))
    out.append('  ];')
    out.append('')

    out.append('  // ---- زنجیرهٔ تضاد مواد ----')
    out.append('  static const int conflictsMaxDepth = %d;' % cf['maxDepth'])
    out.append('  static const String conflictsCycleSuffix = %s;' % _dart_str(cf['cycleSuffix']))
    out.append('}')
    out.append('')
    return '\n'.join(out)


def render_py(c):
    aq = c['articleQuery']
    bm = c['bm25f']
    ob = c['obsolete']
    df = c['definitionPromotion']
    lm = c['lawMention']
    ud = c['unloadedDomain']
    cf = c['conflicts']

    out = [PY_HEADER, '']
    out.append('ARTICLE_QUERY_PATTERN = %s' % _py_raw(aq['pattern']))
    out.append('')
    out.append('BM25_K1 = %s' % repr(float(bm['k1'])))
    out.append('BM25_B = %s' % repr(float(bm['b'])))
    out.append('BM25_WT = %s' % repr(float(bm['wTitle'])))
    out.append('BM25_WB = %s' % repr(float(bm['wBody'])))
    out.append('BM25_WC = %s' % repr(float(bm['wContext'])))
    out.append('OBSOLETE_PENALTY = %s' % repr(float(bm['obsoletePenalty'])))
    out.append('EXPLICIT_SCORE = %s' % repr(float(bm['explicitScore'])))
    out.append('PREFIX_MIN_LEN = %d' % bm['prefixMinLen'])
    out.append('PREFIX_WEIGHT = %s' % repr(float(bm['prefixWeight'])))
    out.append('MIN_SCORE = %s' % repr(float(bm['minScore'])))
    out.append('LOW_COVER = %s' % repr(float(bm['lowCover'])))
    out.append('COVERAGE_MARGIN = %s' % repr(float(bm['coverageMargin'])))
    out.append('NEAR_ALTERNATIVE_FACTOR = %s' % repr(float(bm['nearAlternativeFactor'])))
    out.append('MAX_NEAR_ALTERNATIVES = %d' % bm['maxNearAlternatives'])
    out.append('ALT_MIN_SCORE_RATIO = %s' % repr(float(bm['altMinScoreRatio'])))
    out.append('TOPIC_RERANK_EPS = %s' % repr(float(bm['topicRerankEps'])))
    out.append('')
    out.append('OBSOLETE_MAX_LEN = %d' % ob['maxLen'])
    out.append('OBSOLETE_TRIM_PATTERN = %s' % _py_raw(ob['trimPattern']))
    out.append('CLEAN_BODY_PATTERN = %s' % _py_raw(ob['cleanBodyPattern']))
    out.append('OBSOLETE_PREFIXES = (%s)' % _py_tuple([_py_str(p) for p in ob['prefixes']]))
    out.append('')
    out.append('DEF_QUESTION_PATTERN = %s' % _py_raw(df['questionPattern']))
    out.append('DEF_WORDS = frozenset({%s})' % ', '.join(_py_str(w) for w in df['words']))
    out.append('DEF_META_PREFIXES = frozenset({%s})' % ', '.join(_py_str(w) for w in df['metaPrefixes']))
    out.append('DEF_MARK_PATTERN = %s' % _py_raw(df['markPattern']))
    out.append('DEF_STRONG_PATTERN = %s' % _py_raw(df['strongPattern']))
    out.append('DEF_TAIL_WINDOW = %d' % df['tailWindow'])
    out.append('DEF_MAX_PICKED = %d' % df['maxPicked'])
    out.append('')
    out.append('LAW_PREFIXES = (%s)' % _py_tuple([_py_str(p) for p in lm['requiredPrefixes']]))
    out.append('SHORT_LAW_PREFIX = %s' % _py_str(lm['shortLawPrefix']))
    out.append('SHORT_LAW_MIN_LEN = %d' % lm['shortLawMinLen'])
    out.append('')
    out.append('UNLOADED_PENAL_TERMS = (')
    for x in ud['penalTerms']:
        out.append('    %s,' % _py_str(x))
    out.append(')')
    out.append('PENAL_CONTEXT_MARKERS = (%s)' % _py_tuple([_py_str(x) for x in ud['penalContextMarkers']]))
    out.append('LOADED_CRIMINAL_EXCEPTIONS = (')
    for x in ud['loadedCriminalExceptions']:
        out.append('    %s,' % _py_str(x))
    out.append(')')
    out.append('TAX_TRIGGERS = (%s)' % _py_tuple([_py_str(x) for x in ud['taxTriggers']]))
    out.append('SOCIAL_SECURITY_TRIGGERS = (%s)' % _py_tuple([_py_str(x) for x in ud['socialSecurityTriggers']]))
    out.append('ANCHOR_GROUPS = (')
    for trigger, reqs in ud['anchorGroups']:
        out.append('    (%s, (%s)),' % (_py_str(trigger), _py_tuple([_py_str(r) for r in reqs])))
    out.append(')')
    out.append('')
    out.append('CONFLICTS_MAX_DEPTH = %d' % cf['maxDepth'])
    out.append('CONFLICTS_CYCLE_SUFFIX = %s' % _py_str(cf['cycleSuffix']))
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
            print('کهنه است: %s — python3 dev/tools/gen_engine_rules.py --write' %
                  os.path.relpath(path, ROOT))
        elif write:
            with open(path, 'w', encoding='utf-8') as f:
                f.write(text)
            print('نوشته شد: %s' % os.path.relpath(path, ROOT))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
