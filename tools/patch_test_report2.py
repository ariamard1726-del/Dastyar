# tools/patch_test_report2.py
# مرحلهٔ قدیمی «Near-miss report» در test.yml را با نسخه‌ای عوض می‌کند که
# گزارش را در brain/reports/near_miss.txt می‌نویسد و روی همان شاخه commit می‌کند.
# اگر ساختار فایل با انتظار نخواند، چیزی نوشته نمی‌شود.
import sys

P = '.github/workflows/test.yml'
s = open(P, encoding='utf-8').read()

if 'Commit near-miss report' in s:
    print('قبلاً اعمال شده است.')
    sys.exit(0)

MARK = '\n      - name: Near-miss report\n'
if s.count(MARK) != 1:
    print('خطا: مرحلهٔ قدیمی Near-miss report پیدا نشد. این ۴ خط آخر را بفرستید:')
    print('\n'.join(s.rstrip().split('\n')[-4:]))
    sys.exit(1)

head = s[:s.index(MARK)].rstrip()
old = s[s.index(MARK):]
if 'near_miss_test' not in old or old.count('- name:') != 1:
    print('خطا: بخش آخر فایل با انتظار نمی‌خواند.')
    sys.exit(1)
if not head.endswith('      - run: flutter test'):
    print('خطا: قبل از مرحلهٔ Near-miss باید flutter test باشد.')
    sys.exit(1)
if head.count('\njobs:\n') != 1 or 'permissions:' in head:
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
head = head.replace('\njobs:\n', '\npermissions:\n  contents: write\n\njobs:\n', 1)
open(P, 'w', encoding='utf-8').write(head + '\n' + STEPS)
print('انجام شد: test.yml حالا گزارش NEAR را می‌نویسد.')
