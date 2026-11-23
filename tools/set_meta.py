"""یک فیلد توصیفی از شناسنامهٔ یک قانون را عوض می‌کند.

فقط فیلدهای توصیفی اینجا قابل تغییرند. وضعیت تطبیق (status) و اثر انگشت
(sha256) را فقط tools/law_registry.py می‌نویسد؛ و چون منبع، نشانی و تاریخ
دریافت بخشی از همان تأییدند، تغییر هر کدام وضعیت را به unverified برمی‌گرداند.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import law_registry  # noqa: E402

KEYS = ('title', 'source', 'url', 'date', 'amended')
PROVENANCE = ('source', 'url', 'date')


def main(argv):
    if len(argv) != 4 or argv[2] not in KEYS:
        print('استفاده: python tools/set_meta.py ID KEY "مقدار"')
        print('KEY یکی از: ' + ', '.join(KEYS))
        print('date = تاریخ دریافت متن توسط شما؛ amended = آخرین اصلاحیه طبق منبع')
        return 1
    law, key, value = argv[1], argv[2], argv[3].strip()
    meta = law_registry.load_meta()
    if law not in meta:
        print('قانونی با شناسهٔ %s در _meta.json نیست.' % law)
        return 1
    if key in ('date', 'amended'):
        value = law_registry.to_fa(value)
    meta[law][key] = value
    if key in PROVENANCE and meta[law].get('status') == 'verified':
        meta[law]['status'] = 'unverified'
        print('توجه: با تغییر %s، وضعیت به unverified برگشت؛ دوباره verify کنید.' % key)
    law_registry.save_meta(meta)
    print(meta[law])
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
