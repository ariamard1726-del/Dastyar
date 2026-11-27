import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from ci_annotate import blocks, cross_blocks, cut  # noqa: E402


def read_lines(p):
    try:
        with open(p, encoding='utf-8', errors='replace') as f:
            return f.read().splitlines()
    except OSError:
        return []


def summarize(test_f, data_f, dst, sha):
    lines = read_lines(test_f)
    out = ['commit: ' + sha[:7]]
    summ = [cut(l, 300, ellipsis=False) for l in lines
            if re.search(r'\d+ tests? passed|All tests passed', l)]
    out += summ[-1:] or ['(خلاصهٔ تست پیدا نشد)']

    if os.environ.get('DATA_FAILED') == '1':
        out.append('--- بررسی داده‌ها شکست خورد (آخرین خط‌ها) ---')
        out += [cut(l, 300, ellipsis=False) for l in read_lines(data_f)[-15:]]

    for head, detail in blocks(lines, max_detail=20, detail_only=False, limit=300, ellipsis=False):
        out.append('--- تست ناموفق ---')
        out.append(head)
        out.extend('   ' + t for t in detail)

    for head, detail in cross_blocks(lines, max_detail=8, skip_ci_prefix=False, limit=300, ellipsis=False):
        out.append(head)
        out.extend('   ' + t for t in detail)

    errs = [cut(l, 300, ellipsis=False) for l in lines
            if re.search(r': Error:|Compilation failed|Failed to load', l)]
    if errs:
        out.append('--- خطای کامپایل ---')
        out += errs[:15]

    os.makedirs(os.path.dirname(dst) or '.', exist_ok=True)
    summary_text = '\n'.join(out[:140]) + '\n'
    with open(dst, 'w', encoding='utf-8') as f:
        f.write(summary_text)
    return summary_text


if __name__ == '__main__':
    print(summarize(*sys.argv[1:5]), end='', flush=True)
