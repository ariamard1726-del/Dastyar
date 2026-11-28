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
STATUS_RE = re.compile(r'^\d{2}:\d{2} \+')

# خطوطی که علتِ شکست را می‌گویند.
_DETAIL = ('Expected:', 'Actual:', 'Which:', 'Error:', 'Exception', 'was thrown')


def cut(s, n=280, ellipsis=True):
    s = s.replace('/home/runner/work/Dastyar/Dastyar/', '').strip()
    if len(s) <= n:
        return s
    return s[:n] + ('…' if ellipsis else '')


def blocks(lines, max_detail=4, detail_only=True, limit=280, ellipsis=True):
    """(سرتیتر، جزئیات) هر آزمونِ ناموفق با نشانگر `[E]` در خروجی `flutter test`."""
    out = []
    i = 0
    while i < len(lines):
        if ' [E]' in lines[i]:
            head = cut(lines[i], limit, ellipsis)
            detail = []
            j = i + 1
            while j < len(lines) and not STATUS_RE.match(lines[j]):
                t = cut(lines[j], limit, ellipsis)
                if t and (
                    (detail_only and any(lines[j].strip().startswith(d) or d in lines[j].strip()[:40] for d in _DETAIL))
                    or (not detail_only and not t.startswith(('package:', 'dart:')))
                ):
                    detail.append(t)
                    if len(detail) >= max_detail:
                        break
                j += 1
            out.append((head, detail))
            i = j
        else:
            i += 1
    return out


def cross_blocks(lines, max_detail=4, skip_ci_prefix=True, limit=280, ellipsis=True):
    """بلوک‌های ❌ (گزارش‌گرِ داخلیِ مخزن) هم همان معنا را دارند."""
    out = []
    skip = ('package:', 'dart:', '::') if skip_ci_prefix else ('package:', 'dart:')
    i = 0
    while i < len(lines):
        if '❌' in lines[i]:
            detail = []
            j = i + 1
            while (j < len(lines) and len(detail) < max_detail
                   and '❌' not in lines[j] and '✅' not in lines[j]):
                t = cut(lines[j], limit, ellipsis)
                if t and not t.startswith(skip):
                    detail.append(t)
                j += 1
            out.append((cut(lines[i], limit, ellipsis), detail))
            i = j
        else:
            i += 1
    return out


def annotate(lines, limit=12):
    """خطوطِ آنوتیشن؛ سقفِ گیت‌هاب برای هر step حدود ده است."""
    out = []
    found = blocks(lines)
    if not found:
        # گزارش‌گرِ همین مخزن گاهی خطِ ✅/❌ می‌دهد، نه نشانگرِ [E].
        found = cross_blocks(lines)
    if found:
        # گیت­هاب حداکثر ده آنوتیشن در هر گام نشان میدهد. دو بلوکِ نخست با
        # علتِ شکست چاپ میشوند و بقیهٔ نامها در یک آنوتیشنِ خلاصه میآیند تا
        # «چند آزمون شکست خورد؟» بیپاسخ نماند.
        for head, detail in found[:2]:
            out.append('::error::' + head)
            for d in detail[:4]:
                out.append('::error::    ' + d)
        names = ' | '.join(head.replace('::group::❌ ', '')[:160] for head, _ in found)
        out.append('::error:: %d آزمون شکست خورد: %s' % (len(found), names[:6000]))
    else:
        tail = [l for l in lines
                if l.strip() and not l.strip().startswith('::')][-6:]
        for t in tail:
            out.append('::error::(بدون بلوکِ [E]) ' + cut(t))
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
