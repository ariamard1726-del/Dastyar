"""گزارشگر آمادگی انتشار (فاز ۲۱): فهرست دقیق کارهای انجام‌شده و دروازه‌های انسانی باقی‌مانده.

بدون دست‌کاری وضعیت‌ها نشان می‌دهد:
  ۱. چند قانون با منبع رسمی تطبیق داده شده‌اند (`_meta.json`)؛
  ۲. چند قالب سند دارای ارجاع مادهٔ معتبرند (`lawRefs`) و چند مورد بازبینی انسانی دارند (`reviewed`)؛
  ۳. آیا پیکربندی غیرمخفی امضای انتشار اندروید سالم است؛
  ۴. آیا `check.py trust` اجازهٔ ساخت انتشار را می‌دهد یا هنوز مسدود است.
"""

import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import check  # noqa: E402
import setup_release_signing  # noqa: E402


def collect_status():
    meta = check.load_meta()
    total_laws = len(meta)
    verified_laws = sum(1 for v in meta.values() if v.get('status') == 'verified')

    tpl_paths = sorted(glob.glob(os.path.join(ROOT, 'assets', 'templates', '*.json')))
    total_templates = len(tpl_paths)
    with_refs = 0
    reviewed = 0
    unreviewed_names = []
    for p in tpl_paths:
        with open(p, encoding='utf-8') as f:
            t = json.load(f)
        if t.get('lawRefs'):
            with_refs += 1
        if t.get('reviewed'):
            reviewed += 1
        else:
            unreviewed_names.append(os.path.basename(p))

    signing_errors = setup_release_signing.check_release_signing()
    return {
        'total_laws': total_laws,
        'verified_laws': verified_laws,
        'total_templates': total_templates,
        'templates_with_refs': with_refs,
        'reviewed_templates': reviewed,
        'unreviewed_templates': unreviewed_names,
        'signing_errors': signing_errors,
        'trust_blocked': (verified_laws < total_laws or reviewed < total_templates),
    }


def main():
    st = collect_status()
    print('=== آمادگی انتشار (فاز ۲۱) ===')
    print(f"قوانین تطبیق‌یافته با منبع رسمی: {st['verified_laws']}/{st['total_laws']}")
    print(f"قالب‌های دارای ارجاع ماده (lawRefs): {st['templates_with_refs']}/{st['total_templates']}")
    print(f"قالب‌های بازبینی‌شده توسط کارشناس: {st['reviewed_templates']}/{st['total_templates']}")
    if st['unreviewed_templates']:
        print('قالب‌های منتظر بازبینی حقوقی: ' + '، '.join(st['unreviewed_templates']))
    print(
        'امضای انتشار اندروید: '
        + ('آماده (fail-closed)' if not st['signing_errors'] else 'ناقص: ' + '; '.join(st['signing_errors']))
    )
    print('وضعیت دروازهٔ trust: ' + ('مسدود (عمدی تا تأیید رسمی و انسانی)' if st['trust_blocked'] else 'آزاد'))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
