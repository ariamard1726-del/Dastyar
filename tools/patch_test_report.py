# tools/patch_test_report.py
# test.yml را طوری تغییر می‌دهد که بعد از هر push گزارش NEAR را در
# brain/reports/near_miss.txt بنویسد و روی همان شاخه commit کند.
# اگر ساختار فایل با انتظار نخواند، چیزی نوشته نمی‌شود.
import sys

P = '.github/workflows/test.yml'
s = open(P, encoding='utf-8').read()

if 'near_miss' in s:
    print('قبلاً اعمال شده است.')
    sys.exit(0)

LAST = '      - run: flutter test'
body = s.rstrip()
if not body.endswith(LAST):
    print('خطا: آخر test.yml با انتظار نمی‌خواند. این ۴ خط آخر را بفرستید:')
    print('\n'.join(body.split('\n')[-4:]))
    sys.exit(1)
if body.count('\njobs:\n') != 1 or 'permissions:' in body:
    print('خطا: ساختار بالای test.yml با انتظار نمی‌خواند.')
    sys.exit(1)

STEPS = '''
      - name: Near-miss report
        continue-on-error: true
        run: |
          mkdir -p brain/reports
          flutter test test/near_miss_test.dart --reporter expanded 2>&1 | grep -E "NEAR" > brain/reports/near_miss.txt || true
          head -n 60 brain/reports/near_miss.txt
      - name: Commit near-miss report
        if: github.event_name == 'push'
        continue-on-error: true
        run: |
          git config user.name "github-actions"
          git config user.email "actions@users.noreply.github.com"
          git add brain/reports/near_miss.txt
          git diff --cached --quiet || git commit -m "گزارش near-miss (خودکار)"
          git pull --rebase || true
          git push origin HEAD:"${GITHUB_REF_NAME}" || true
'''
body = body.replace('\njobs:\n', '\npermissions:\n  contents: write\n\njobs:\n', 1)
open(P, 'w', encoding='utf-8').write(body + '\n' + STEPS)
print('انجام شد: test.yml حالا گزارش NEAR را می‌نویسد.')
