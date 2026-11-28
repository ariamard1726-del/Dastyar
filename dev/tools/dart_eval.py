"""اجراگر و خوانندهٔ سنجش‌های واقعی Dart (`test/core/dart_eval_suite_test.dart`).

اگر ابزار `flutter` در محیط نصب باشد، مجموعهٔ `test/core/dart_eval_suite_test.dart`
را روی کد واقعی Dart (`PersianText`/`Sense`, `KnowledgeEngine`, `LawTerms`, `TopicFlow`)
اجرا می‌کند و گزارش `reports/dart_eval.txt` را می‌سازد. در محیط‌های بدون Flutter SDK
(مانند سندباکس آزمایش)، صادقانه نبود ابزار محلی را گزارش می‌دهد و در صورت وجود
`reports/dart_eval.txt` (تولیدشده در CI)، مقادیر ثبت‌شده را بازبینی و بررسی می‌کند.

اجرا:
  python3 dev/tools/dart_eval.py
  python3 dev/tools/dart_eval.py --check
  python3 dev/tools/dart_eval.py --require-flutter
"""

from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SUITE = 'test/core/dart_eval_suite_test.dart'
REPORT = ROOT / 'reports' / 'dart_eval.txt'

RANK_THRESHOLDS = {
    'eval.txt': (0.75, 0.85, 0.80),
    'eval_extra.txt': (0.70, 0.90, 0.78),
    'eval_blind.txt': (0.55, 0.80, 0.65),
    'eval_all_laws.txt': (0.75, 0.90, 0.80),
    'eval_feedback.txt': (0.45, 0.78, 0.60),
}
MAX_EVAL_NONE_FALSE_PCT = 10.0
MIN_EVERYDAY_LAW_ACC = 0.90

_RANK_RE = re.compile(
    r'^DART_EVAL (\S+): n=(\d+) recall@1=([0-9.]+) recall@5=([0-9.]+) MRR=([0-9.]+)$'
)
_EVERYDAY_RE = re.compile(r'^DART_EVAL eval_everyday_laws\.txt: n=(\d+) law@1=([0-9.]+)$')
_NONE_RE = re.compile(
    r'^DART_EVAL eval_none\.txt: n=(\d+) rejected=(\d+) false_confident=(\d+) \(([0-9.]+)%\)$'
)


def parse_report(text):
    """سطرهای `DART_EVAL` را از گزارش استخراج و ساختاری می‌کند."""
    ranks = {}
    everyday = None
    eval_none = None
    lines = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line.startswith('DART_EVAL '):
            continue
        lines.append(line)
        if m := _RANK_RE.match(line):
            ranks[m.group(1)] = {
                'n': int(m.group(2)),
                'r1': float(m.group(3)),
                'r5': float(m.group(4)),
                'mrr': float(m.group(5)),
            }
        elif m := _EVERYDAY_RE.match(line):
            everyday = {'n': int(m.group(1)), 'law1': float(m.group(2))}
        elif m := _NONE_RE.match(line):
            eval_none = {
                'n': int(m.group(1)),
                'rejected': int(m.group(2)),
                'false_confident': int(m.group(3)),
                'rate_pct': float(m.group(4)),
            }
    return {'lines': lines, 'ranks': ranks, 'everyday': everyday, 'eval_none': eval_none}


def validate_report(text):
    """مقادیر گزارش مستقیم Dart را با آستانه‌های CI می‌سنجد."""
    parsed = parse_report(text)
    errors = []
    if not parsed['lines']:
        return ['گزارش هیچ خط DART_EVAL ندارد.']
    for name, (min_r1, min_r5, min_mrr) in RANK_THRESHOLDS.items():
        if name not in parsed['ranks']:
            if name == 'eval_feedback.txt' and not (ROOT / 'eval' / name).is_file():
                continue
            errors.append(f'{name}: در گزارش Dart نیامده است')
            continue
        got = parsed['ranks'][name]
        if got['r1'] < min_r1 or got['r5'] < min_r5 or got['mrr'] < min_mrr:
            errors.append(
                f"{name}: ({got['r1']:.2f}, {got['r5']:.2f}, {got['mrr']:.3f}) < "
                f'({min_r1:.2f}, {min_r5:.2f}, {min_mrr:.3f})'
            )
    if parsed['everyday'] is None:
        errors.append('eval_everyday_laws.txt در گزارش Dart نیست')
    elif parsed['everyday']['law1'] < MIN_EVERYDAY_LAW_ACC:
        errors.append(
            f"eval_everyday_laws.txt: {parsed['everyday']['law1']:.2f} < {MIN_EVERYDAY_LAW_ACC:.2f}"
        )
    if parsed['eval_none'] is None:
        errors.append('eval_none.txt در گزارش Dart نیست')
    elif parsed['eval_none']['rate_pct'] > MAX_EVAL_NONE_FALSE_PCT:
        errors.append(
            f"eval_none.txt: false confident {parsed['eval_none']['rate_pct']:.1f}% > "
            f'{MAX_EVAL_NONE_FALSE_PCT:.1f}%'
        )
    return errors


def main(argv=None):
    args = sys.argv[1:] if argv is None else list(argv)
    check_mode = '--check' in args
    require_flutter = '--require-flutter' in args
    report_only = '--report-only' in args
    report_path = REPORT

    flutter = None if report_only else shutil.which('flutter')
    if flutter:
        res = subprocess.run(
            [flutter, 'test', SUITE, '--reporter', 'expanded'],
            cwd=ROOT,
            check=False,
        )
        if res.returncode != 0:
            return res.returncode
    elif not report_only:
        print('dart_eval: ابزار flutter در این محیط نصب نیست (راستی‌آزمایی مستقیم Dart در CI انجام می‌شود).')
        if require_flutter:
            return 1

    if not report_path.is_file():
        if check_mode and (flutter or report_only):
            print('خطا: فایل reports/dart_eval.txt ساخته نشد.')
            return 1
        print('dart_eval: هنوز reports/dart_eval.txt ثبت نشده است.')
        return 0

    text = report_path.read_text(encoding='utf-8')
    print(text.strip())
    if check_mode:
        errs = validate_report(text)
        for e in errs:
            print('FAIL dart_eval:', e)
        return 1 if errs else 0
    return 0


if __name__ == '__main__':
    sys.exit(main())
