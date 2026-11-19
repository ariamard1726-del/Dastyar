"""سنجش IntentNet (assets/brain/intent_model.json) روی جمله‌های مجموعه‌های نگه‌داشتهٔ
test/advocate/intent_scenarios_test.dart. فقط گزارش می‌دهد؛ چیزی را تغییر نمی‌دهد.

اجرا:  python3 tools/holdout_intent.py   (به numpy نیاز ندارد؛ فقط json و base64)
"""
import importlib.util
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
spec = importlib.util.spec_from_file_location('check', os.path.join(ROOT, 'tools', 'check.py'))
c = importlib.util.module_from_spec(spec)
spec.loader.exec_module(c)
m=c.IntentModel()
src=open(os.path.join(ROOT,'test/advocate/intent_scenarios_test.dart'),encoding='utf-8').read()
cases=[]
for name in ('_holdout','_holdout2','_holdout3','_holdout4'):
    i=src.index('const List<_Case> %s = [' % name)
    j=src.index('];',i)
    cases+=re.findall(r"_Case\('([^']*)', \['([^']*)'\]", src[i:j])
for name,text in cases:
    s=m.scores(text)
    ranked=sorted(zip(s,m.labels),reverse=True)[:3]
    print(f"{name[:28]:28} | {text[:45]:45} | "+", ".join(f"{l}:{v:.2f}" for v,l in ranked))
