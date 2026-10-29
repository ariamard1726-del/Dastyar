# tools/patch_bm25.py
# پارامترهای رتبه‌بندی را از (k1=1.2, b=0.4) به (k1=0.9, b=0.7) می‌برد:
# موادِ بلند کمتر بر موادِ کوتاه و دقیق غلبه می‌کنند.
# اگر ریپو با انتظار نخواند، هیچ چیز نوشته نمی‌شود.
import sys

P = 'lib/engine.dart'
s = open(P, encoding='utf-8').read()

if 'static const double _k1 = 0.9;' in s:
    print('قبلاً اعمال شده است.')
    sys.exit(0)

OLD = [
    ('  static const double _k1 = 1.2;\n', '  static const double _k1 = 0.9;\n'),
    ('  static const double _b = 0.4;\n', '  static const double _b = 0.7;\n'),
]
for old, _ in OLD:
    if s.count(old) != 1:
        print('خطا: خط مورد انتظار پیدا نشد یا تکراری است:\n' + old)
        sys.exit(1)
for old, new in OLD:
    s = s.replace(old, new, 1)
open(P, 'w', encoding='utf-8').write(s)
print('انجام شد: k1=0.9 و b=0.7 اعمال شد.')
