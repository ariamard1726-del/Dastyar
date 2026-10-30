# tools/patch_router_fix.py
# ترمیم patch_router: دو متن پاسخ در ریپوی شما از replies.get(...) می‌آید و
# در router.dart دیده نمی‌شود. این دو متد را از router.dart برمی‌دارد و
# فراخوانی‌شان را در engine.dart مستقیم به replies.get(...) برمی‌گرداند.
# اگر ریپو با انتظار نخواند، هیچ فایلی نوشته نمی‌شود.
import re
import sys

E = 'lib/engine.dart'
R = 'lib/router.dart'
e = open(E, encoding='utf-8').read()
r = open(R, encoding='utf-8').read()

if 'static String capabilitiesText' not in r:
    print('قبلاً اعمال شده است.')
    sys.exit(0)

JOBS = [
    ('capabilitiesText', 'capabilities', 'QueryRouter.capabilitiesText()'),
    ('outcomeText', 'outcome_prediction', 'QueryRouter.outcomeText()'),
]

for name, key, call in JOBS:
    pat = re.compile(r'\n  static String %s\(\) \{.*?\n  \}\n' % name, re.S)
    ms = pat.findall(r)
    if len(ms) != 1 or ("replies.get('%s')" % key) not in ms[0]:
        print('خطا: متد %s در router.dart با انتظار نمی‌خواند.' % name)
        sys.exit(1)
    if e.count(call) != 1:
        print('خطا: فراخوانی %s در engine.dart پیدا نشد.' % call)
        sys.exit(1)

for name, key, call in JOBS:
    pat = re.compile(r'\n  static String %s\(\) \{.*?\n  \}\n' % name, re.S)
    r = pat.sub('\n', r, count=1)
    e = e.replace(call, "replies.get('%s')" % key, 1)

r = re.sub(r'\n{3,}', '\n\n', r)
open(R, 'w', encoding='utf-8').write(r)
open(E, 'w', encoding='utf-8').write(e)
print('انجام شد: router.dart دیگر به replies نیاز ندارد.')
