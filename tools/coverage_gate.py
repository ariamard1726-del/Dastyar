"""دروازهٔ پوشش خطوط کد بر اساس `coverage/lcov.info`.

استفاده:
    python tools/coverage_gate.py coverage/lcov.info --min 40

گزارش سادهتر از «درصدی که کسی یادش نیست» است: آستانه در CI ثبت میشود و
هر کاهش پوشش همانجا قرمز میشود. شمارش ONLY خطوط `LF:`/`LH:` است، نه_branch.
"""

import argparse
import re
import sys
from pathlib import Path

LINE_FOUND = re.compile(r'^LF:(\d+)$')
LINE_HIT = re.compile(r'^LH:(\d+)$')


def coverage(path):
    found = hit = 0
    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            m = LINE_FOUND.match(line)
            if m:
                found += int(m.group(1))
                continue
            m = LINE_HIT.match(line)
            if m:
                hit += int(m.group(1))
    if found == 0:
        raise ValueError('lcov.info هیچ خطی را ثبت نکرده است')
    return hit, found, 100.0 * hit / found


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument('lcov', type=Path)
    ap.add_argument('--min', type=float, required=True)
    args = ap.parse_args(argv)
    try:
        hit, found, pct = coverage(args.lcov)
    except (OSError, ValueError) as e:
        print('coverage: %s' % e, file=sys.stderr)
        return 2
    print('coverage: %d/%d خط (%.1f%%) | آستانه %.1f%%' %
          (hit, found, pct, args.min))
    return 0 if pct >= args.min else 1


if __name__ == '__main__':
    sys.exit(main())
