"""بررسی قرارداد خط لولهٔ پاسخ: assets/pipeline.json در برابر Dart.

این فایل تنها منبع حقیقت برای ترتیب مسیرهای دانش و آستانهٔ netMin است.
این ابزار می‌سنجد که `Advocate.pipelineOrder` و `Advocate.netMin` در
lib/domain/advocate/advocate.dart دقیقاً همان چیزی باشند که در JSON نوشته
شده است؛ هر واگرایی خطاست، چون تغییر ترتیب یعنی تغییر رفتار.

اجرا:
  python3 tools/pipeline_check.py          # بررسی و گزارش
  python3 tools/pipeline_check.py --check  # فقط کد خروج (برای CI)
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PIPELINE_JSON = os.path.join(ROOT, 'assets', 'pipeline.json')
ADVOCATE_DART = os.path.join(ROOT, 'lib', 'domain', 'advocate', 'advocate.dart')

# نام‌های JSON (camelCase) به نام‌های enum در Dart.
DART_NAMES = {
    'safety': 'safety',
    'topic': 'topic',
    'lawTerms': 'lawTerms',
    'glossary': 'glossary',
    'guide': 'guide',
    'topicFlow': 'topicFlow',
    'guess': 'guess',
    'intentNet': 'intentNet',
    'qaBank': 'qaBank',
    'engine': 'engine',
}


def load_pipeline(path=PIPELINE_JSON):
    with open(path, encoding='utf-8') as f:
        return json.load(f)


def dart_pipeline_order(path=ADVOCATE_DART):
    """فهرست pipelineOrder را از کد Dart می‌خواند (ترتیب واقعی)."""
    with open(path, encoding='utf-8') as f:
        text = f.read()
    m = re.search(r'pipelineOrder\s*=\s*\[(.*?)\];', text, re.S)
    if not m:
        raise ValueError('pipelineOrder در advocate.dart پیدا نشد')
    return re.findall(r'AnswerSource\.(\w+)', m.group(1))


def dart_net_min(path=ADVOCATE_DART):
    with open(path, encoding='utf-8') as f:
        text = f.read()
    m = re.search(r'netMin\s*=\s*([0-9.]+)', text)
    if not m:
        raise ValueError('netMin در advocate.dart پیدا نشد')
    return float(m.group(1))


def validate(pipeline):
    """ساختار JSON را می‌سنجد؛ خروجی: (خطاها، هشدارها)."""
    errors, warnings = [], []
    if not isinstance(pipeline, dict):
        return ['pipeline.json باید یک شیء باشد'], []
    order = pipeline.get('order')
    if not isinstance(order, list) or not order:
        errors.append('order باید فهرست غیرخالی باشد')
        return errors, warnings
    if len(set(order)) != len(order):
        errors.append('order تکراری دارد: %s' % order)
    unknown = [s for s in order if s not in DART_NAMES]
    if unknown:
        errors.append('مسیرهای ناشناخته در order: %s' % unknown)
    if order[0] != 'safety':
        errors.append('اولین مسیر باید safety باشد، نه %s' % order[0])
    if 'unknown' in order:
        errors.append('unknown نباید در order باشد')
    th = pipeline.get('thresholds')
    if not isinstance(th, dict):
        errors.append('thresholds باید شیء باشد')
    else:
        net = th.get('netMin')
        if not isinstance(net, (int, float)) or not (0 < net < 1):
            errors.append('thresholds.netMin باید عددی بین ۰ و ۱ باشد: %r' % net)
        for k in ('topicOpen', 'topicStrong', 'topicDominant'):
            v = th.get(k)
            if not isinstance(v, int) or v <= 0:
                errors.append('thresholds.%s باید عدد صحیح مثبت باشد: %r' % (k, v))
    return errors, warnings


def check(pipeline_path=PIPELINE_JSON, dart_path=ADVOCATE_DART):
    """بررسی کامل؛ خروجی: (خطاها، هشدارها)."""
    pipeline = load_pipeline(pipeline_path)
    errors, warnings = validate(pipeline)
    if errors:
        return errors, warnings
    want = [DART_NAMES[s] for s in pipeline['order']]
    got = dart_pipeline_order(dart_path)
    if got != want:
        errors.append(
            'ترتیب Dart با pipeline.json نمی‌خواند:\n  JSON: %s\n  Dart: %s'
            % (want, got))
    net_json = pipeline['thresholds']['netMin']
    net_dart = dart_net_min(dart_path)
    if abs(net_json - net_dart) > 1e-9:
        errors.append('netMin در JSON (%s) با Dart (%s) نمی‌خواند' % (net_json, net_dart))
    return errors, warnings


def main(argv):
    errors, warnings = check()
    for w in warnings:
        print('هشدار:', w)
    for e in errors:
        print('خطا:', e)
    if errors:
        print('نتیجه: %d خطا در قرارداد خط لوله.' % len(errors))
        return 1
    print('نتیجه: قرارداد خط لوله سالم است.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
