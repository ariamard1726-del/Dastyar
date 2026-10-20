import json
import sys
import urllib.error
import urllib.request

REPO = 'ariamard1726-del/Dastyar'


def get(url):
    req = urllib.request.Request(
        url,
        headers={
            'Accept': 'application/vnd.github+json',
            'User-Agent': 'dastyar-ci-status',
        },
    )
    with urllib.request.urlopen(req, timeout=25) as r:
        return json.load(r)


try:
    data = get('https://api.github.com/repos/%s/actions/runs?per_page=3' % REPO)
except urllib.error.HTTPError as e:
    print('خطا از گیت‌هاب: %s' % e.code)
    print('اگر مخزن خصوصی است این ابزار کار نمی‌کند؛ نتیجه را از صفحهٔ Actions بفرست.')
    sys.exit(1)
except Exception as e:
    print('اتصال برقرار نشد:', e)
    sys.exit(1)

runs = data.get('workflow_runs', [])
if not runs:
    print('هنوز هیچ اجرایی ثبت نشده. در Actions، Build APK را اجرا کن.')
    sys.exit(0)

for run in runs:
    msg = (run.get('head_commit') or {}).get('message', '').split('\n')[0]
    print('=' * 36)
    print('اجرا %s | %s | %s' % (run['id'], run.get('status'), run.get('conclusion')))
    print('زمان:', run.get('created_at'))
    print('کامیت:', msg[:60])
    try:
        jobs = get(run['jobs_url']).get('jobs', [])
    except Exception as e:
        print('  مراحل خوانده نشد:', e)
        continue
    for j in jobs:
        for s in j.get('steps', []):
            print('  %2d. %-38s %s' % (s['number'], s['name'][:38], s.get('conclusion')))
