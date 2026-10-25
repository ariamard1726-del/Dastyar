import hashlib
import json
import os

DIR = os.path.join('assets', 'templates')
POS = ['چک برگشت', 'چکم برگشت', 'برگشت خورد']
NEG = ['-چک دادم', '-چک کشیدم', '-چک صادر کردم']
PLAN = {
    'cheque_complaint': ('pos', 'c719821bdfc46b3bc2c8e94ba67d509d4f9691c3'),
    'cheque_execution': ('pos', 'cb976ddcfa943bfb72a86f59ff9279be5969907e'),
    'demand_money': ('neg', '416c18186c3b9d174dcdf22a6ceaab53468f2d3b'),
}


def patch(t, kind):
    kws = t['keywords']
    if kind == 'pos':
        for k in POS:
            if k not in kws:
                kws.insert(len(kws) - sum(1 for x in kws if x.startswith('-')), k)
    else:
        for k in NEG:
            if k not in kws:
                kws.append(k)


ok = True
for tid, (kind, want) in PLAN.items():
    p = os.path.join(DIR, tid + '.json')
    t = json.load(open(p, encoding='utf-8'))
    patch(t, kind)
    raw = (json.dumps(t, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    h = hashlib.sha1(raw).hexdigest()
    if h == want:
        open(p, 'wb').write(raw)
        print(tid, 'به‌روز شد.')
    else:
        ok = False
        print(tid, 'sha1 متفاوت:', h, '(چیزی نوشته نشد)')
print('نتیجه:', 'همه چیز درست است.' if ok else 'مشکل؛ خروجی را بفرست.')
