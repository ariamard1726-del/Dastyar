import re
import subprocess
import sys


def sh(args):
    r = subprocess.run(args, capture_output=True, text=True)
    return (r.stdout + r.stderr).strip()


def cut(s):
    return s.replace('\r', '')[:160]


def head(title, text, n=40):
    print('=== ' + title + ' ===')
    lines = [cut(l) for l in text.splitlines() if l.strip()]
    print('\n'.join(lines[:n]))
    if len(lines) > n:
        print('... (%d خط دیگر)' % (len(lines) - n))


git_summary = '\n'.join(
    part
    for part in (
        sh(['git', 'branch', '--show-current']),
        sh(['git', 'log', '--oneline', '-5']),
        sh(['git', 'status', '-sb']),
    )
    if part
)
head('git', git_summary, 15)

try:
    with open('reports/last_test.txt', encoding='utf-8') as f:
        head('آخرین گزارش تست', f.read(), 40)
except OSError:
    print('=== گزارش تست هنوز نیست ===')

for spec in sys.argv[1:]:
    if spec.startswith('g:'):
        pat = spec[2:]
        out = subprocess.run(
            ['grep', '-rn', '-E', pat, 'lib', 'test'],
            capture_output=True,
            text=True,
        ).stdout
        head('grep ' + pat, out, 30)
        continue
    m = re.match(r'^(.+?):(\d+)-(\d+)$', spec)
    if m:
        path, a, b = m.group(1), int(m.group(2)), int(m.group(3))
    else:
        path, a, b = spec, 1, 80
    b = min(b, a + 120)
    try:
        with open(path, encoding='utf-8', errors='replace') as f:
            lines = f.read().splitlines()
    except OSError:
        print('=== %s: پیدا نشد ===' % path)
        continue
    print('=== %s [%d-%d] ===' % (path, a, b))
    for i in range(a - 1, min(b, len(lines))):
        print('%d: %s' % (i + 1, cut(lines[i])))
