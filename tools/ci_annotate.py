"""نامِ آزمون‌های شکست‌خورده را از خروجیِ `flutter test` بیرون می‌کشد.

لاگِ اجرای CI همیشه در دسترس نیست (در محیط‌های ابری/گوشی، دانلود لاگ بسته
است) و «۴۶۵ آزمون پاس شد، ۱ شکست خورد» بدون نام، عیب‌یابی را به حدس تبدیل
می‌کند. این اسکریپت بلوکِ هر شکست را پیدا می‌کند و به‌صورت آنوتیشنِ
`::error::` چاپ می‌کند تا روی همان اجرا دیده شود.

ورودی: فایلِ خروجیِ `flutter test` (reporter متنی). خروجی: خطوطِ `::error::`.
"""

import re
import sys

# خطِ وضعیتِ گزارش‌گر: `00:12 +45 -1: ...` — مرزِ بلوک‌های شکست.
_STATUS = re.compile(r'^\d{2}:\d{2} \+')

# خطوطی که علتِ شکست را می‌گویند.
_DETAIL = ('Expected:', 'Actual:', 'Which:', 'Error:', 'Exception', 'was thrown')


def _cut(s, n=280):
    s = s.replace('/home/runner/work/Dastyar/Dastyar/', '').strip()
    return s if len(s) <= n else s[:n] + '…'


def blocks(lines):
    """(سرتیتر، جزئیات) هر آزمونِ ناموفق؛ اگر نشانگر `[E]` نبود، یک بلوکِ
    تهی برمی‌گردد تا دستِ‌کم آخرین خطوط دیده شوند."""
    out = []
    i = 0
    while i < len(lines):
        if ' [E]' in lines[i]:
            head = _cut(lines[i])
            detail = []
            j = i + 1
            while j < len(lines) and not _STATUS.match(lines[j]):
                t = lines[j].strip()
                if t and any(t.startswith(d) or d in t[:40] for d in _DETAIL):
                    detail.append(_cut(t))
                    if len(detail) >= 3:
                        break
                j += 1
            out.append((head, detail))
            i = j
        else:
            i += 1
    return out


def cross_blocks(lines):
    """بلوک‌های ❌ (گزارش‌گرِ داخلیِ مخزن) هم همان معنا را دارند."""
    out = []
    i = 0
    while i < len(lines):
        if '❌' in lines[i]:
            detail = []
            j = i + 1
            while (j < len(lines) and len(detail) < 3
                   and '❌' not in lines[j] and '✅' not in lines[j]):
                t = lines[j].strip()
                if t and not t.startswith(('package:', 'dart:', '::')):
                    detail.append(_cut(t))
                j += 1
            out.append((_cut(lines[i]), detail))
            i = j
        else:
            i += 1
    return out


def annotate(lines, limit=8):
    """خطوطِ آنوتیشن؛ سقفِ گیت‌هاب برای هر step حدود ده است."""
    out = []
    found = blocks(lines)
    if not found:
        # گزارش‌گرِ همین مخزن گاهی خطِ ✅/❌ می‌دهد، نه نشانگرِ [E].
        found = cross_blocks(lines)
    if found:
        for head, detail in found:
            out.append('::error::' + head)
            for d in detail:
                out.append('::error::    ' + d)
            if len(out) >= limit:
                break
    else:
        tail = [l for l in lines
                if l.strip() and not l.strip().startswith('::')][-6:]
        for t in tail:
            out.append('::error::(بدون بلوکِ [E]) ' + _cut(t))
    return out[:limit]


def main(argv):
    if len(argv) < 2:
        print('usage: ci_annotate.py <flutter-test-output.txt>', file=sys.stderr)
        return 2
    try:
        with open(argv[1], encoding='utf-8', errors='replace') as f:
            lines = f.read().splitlines()
    except OSError:
        return 0
    for line in annotate(lines):
        print(line)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
