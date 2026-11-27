"""دروازهٔ زمان استارت و حافظه بر اساس `reports/startup.txt`.

استفاده:
    python dev/tools/startup_gate.py reports/startup.txt --max-load-ms 15000 --max-worker-ms 15000 --max-query-ms 5000

خروجی `test/engine/load_budget_test.dart` را می‌خواند و از نبود معیارها یا
گذشتن از سقف زمانیِ ثبت‌شده جلوگیری می‌کند.
"""

import argparse
import re
import sys
from pathlib import Path

REQUIRED = (
    'load_ms',
    'assets_ms',
    'index_ms',
    'worker_load_ms',
    'first_query_ms',
    'laws',
    'chunks',
    'vocab',
    'rss_mb',
)
PAIR_RE = re.compile(r'([a-z_]+)=([0-9]+(?:\.[0-9]+)?)')


def parse_startup(path):
    metrics = {}
    with open(path, encoding='utf-8') as f:
        for line in f:
            if not line.startswith('STARTUP-BASELINE '):
                continue
            for key, raw in PAIR_RE.findall(line):
                metrics[key] = float(raw) if '.' in raw else int(raw)
    missing = [k for k in REQUIRED if k not in metrics]
    if missing:
        raise ValueError('گزارش استارت معیار کم دارد: %s' % ', '.join(missing))
    return metrics


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument('report', type=Path)
    ap.add_argument('--max-load-ms', type=int, default=15000)
    ap.add_argument('--max-worker-ms', type=int, default=15000)
    ap.add_argument('--max-query-ms', type=int, default=5000)
    args = ap.parse_args(argv)
    try:
        m = parse_startup(args.report)
    except (OSError, ValueError) as e:
        print('startup: %s' % e, file=sys.stderr)
        return 2
    print(
        'startup: load=%dms (assets=%dms, index=%dms) worker=%dms '
        'query=%dms laws=%d chunks=%d vocab=%d rss=%.1fMB | '
        'budget<=%dms'
        % (
            m['load_ms'], m['assets_ms'], m['index_ms'], m['worker_load_ms'],
            m['first_query_ms'], m['laws'], m['chunks'], m['vocab'],
            m['rss_mb'], args.max_load_ms,
        )
    )
    if (
        m['load_ms'] > args.max_load_ms
        or m['worker_load_ms'] > args.max_worker_ms
        or m['first_query_ms'] > args.max_query_ms
    ):
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
