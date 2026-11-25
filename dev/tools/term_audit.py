"""بازرسی تطبیق واژه‌های پرسش با متن قوانین.

سه منبع را یک‌جا اجرا می‌کند:
  1. tests/law_terms/cases.json      نمونه‌های آزمون (رگرسیون، باید همه درست باشند)
  2. tests/law_terms/audit.json      پرسش‌های سخت با انتظار مشخص؛ مواردی که هنوز
                                     درست نیستند با status=open گزارش می‌شوند
  3. پیام‌های کاربر در test/advocate/intent_scenarios_test.dart
                                     فقط گزارش می‌شوند (بدون انتظار)

خروجی در stdout و در reports/term_audit.md نوشته می‌شود.
کد خروج ۱ یعنی رگرسیون در موارد status=ok یا در cases.json.

اجرا:
  python3 dev/tools/term_audit.py
  python3 dev/tools/term_audit.py --turns-only
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'tools'))

import law_terms as LT  # noqa: E402

AUDIT = os.path.join(ROOT, 'tests', 'law_terms', 'audit.json')
SCENARIOS = os.path.join(ROOT, 'test', 'advocate', 'intent_scenarios_test.dart')
REPORT = os.path.join(ROOT, 'reports', 'term_audit.md')

STR = r"'((?:[^'\\]|\\.)*)'"


def dart_turns():
    """همهٔ پیام‌های کاربر (لیست دوم هر _Case) را از فایل سناریو استخراج می‌کند."""
    src = open(SCENARIOS, encoding='utf-8').read()
    out = []
    for m in re.finditer(r"_Case\(\s*" + STR + r"\s*,\s*\[((?:\s*" + STR + r"\s*,?)*)\]", src):
        for t in re.findall(STR, m.group(2)):
            out.append(t.replace("\\'", "'"))
    return list(dict.fromkeys(out))


def body_of(res):
    e = LT.engine()
    for c in e.chunks:
        if c['law'] == res['law'] and c['title'] == res['title']:
            return c['body'] + ' ' + c['title']
    return ''


def check_audit(item):
    """برمی‌گرداند (ok_bool, [دلیل‌های شکست])."""
    res = LT.match(item['q'])
    why = []
    if res['accepted'] != item['accepted']:
        why.append('accepted=%s' % res['accepted'])
    if 'law' in item and res['law'] != item['law']:
        why.append('law=%s' % res['law'])
    if 'title' in item and res['title'] != item['title']:
        why.append('title=%s' % res['title'])
    if res['law'] in item.get('not_law', []):
        why.append('law در فهرست ممنوع: %s' % res['law'])
    if item.get('body_has') and res['accepted']:
        body = body_of(res)
        for w in item['body_has']:
            if w not in body:
                why.append('متن ماده «%s» را ندارد' % w)
    return (not why), why, res


def main(argv):
    turns_only = '--turns-only' in argv
    lines = ['# بازرسی تطبیق واژه‌ها', '']
    regress = 0

    if not turns_only:
        cases = json.load(open(os.path.join(ROOT, 'tests', 'law_terms', 'cases.json'), encoding='utf-8'))
        _, fails = LT.run_cases()
        lines += ['## نمونه‌های رگرسیون (cases.json)', '',
                  'شکست: %d از %d' % (len(fails) if isinstance(fails, list) else 0, len(cases)), '']
        if fails:
            regress += len(fails)
            lines += ['- شکست: ' + str(f) for f in fails]
            lines.append('')

        audit = json.load(open(AUDIT, encoding='utf-8'))
        lines += ['## پرسش‌های سخت (audit.json)', '',
                  '| وضعیت | پرسش | نتیجه | دلیل |', '|---|---|---|---|']
        open_n = ok_n = 0
        for item in audit:
            ok, why, res = check_audit(item)
            tag = 'درست' if ok else ('باز' if item['status'] == 'open' else 'رگرسیون')
            if not ok and item['status'] == 'ok':
                regress += 1
            if not ok and item['status'] == 'open':
                open_n += 1
            if ok:
                ok_n += 1
            got = ('%s — %s (%s)' % (res['law'], res['title'], res['cover'])
                   if res['accepted'] else 'پذیرفته نشد')
            lines.append('| %s | %s | %s | %s |' % (tag, item['q'], got, '؛ '.join(why) or '—'))
        lines += ['', 'درست: %d، باز: %d، رگرسیون: %d' % (ok_n, open_n, regress), '']

    turns = dart_turns()
    acc = []
    for t in turns:
        res = LT.match(t)
        if res['accepted']:
            acc.append((t, res))
    lines += ['## پیام‌های سناریوهای Dart (فقط گزارش)', '',
              'تعداد پیام: %d؛ پذیرفته‌شده: %d' % (len(turns), len(acc)), '',
              '| پیام | ماده | پوشش | واژه‌های پیدانشده |', '|---|---|---|---|']
    for t, res in acc:
        lines.append('| %s | %s — %s | %s | %s |' % (t, res['law'], res['title'], res['cover'],
                                                    '، '.join(res['unknown']) or '—'))
    text = '\n'.join(lines) + '\n'
    os.makedirs(os.path.dirname(REPORT), exist_ok=True)
    open(REPORT, 'w', encoding='utf-8').write(text)
    print(text)
    return 1 if regress else 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
