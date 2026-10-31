import os, re, sys

test_f, data_f, dst, sha = sys.argv[1:5]


def read(p):
    try:
        return open(p, encoding='utf-8', errors='replace').read().splitlines()
    except OSError:
        return []


def cut(s):
    return s.replace('/home/runner/work/Dastyar/Dastyar/', '').strip()[:300]


lines = read(test_f)
out = ['commit: ' + sha[:7]]
summ = [cut(l) for l in lines
        if re.search(r'\d+ tests? passed|All tests passed', l)]
out += summ[-1:] or ['(خلاصهٔ تست پیدا نشد)']

if os.environ.get('DATA_FAILED') == '1':
    out.append('--- بررسی داده‌ها شکست خورد (آخرین خط‌ها) ---')
    out += [cut(l) for l in read(data_f)[-15:]]

i = 0
while i < len(lines):
    if '❌' in lines[i]:
        out.append(cut(lines[i]))
        j, k = i + 1, 0
        while (j < len(lines) and k < 8
               and '❌' not in lines[j] and '✅' not in lines[j]):
            t = cut(lines[j])
            if t and not t.startswith(('package:', 'dart:')):
                out.append('   ' + t)
                k += 1
            j += 1
        i = j
    else:
        i += 1

errs = [cut(l) for l in lines
        if re.search(r': Error:|Compilation failed|Failed to load', l)]
if errs:
    out.append('--- خطای کامپایل ---')
    out += errs[:15]

os.makedirs(os.path.dirname(dst) or '.', exist_ok=True)
open(dst, 'w', encoding='utf-8').write('\n'.join(out[:140]) + '\n')
