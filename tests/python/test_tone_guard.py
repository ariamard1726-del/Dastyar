"""لحنِ پاسخ‌ها روی خودِ سورسِ دارت سنجیده می‌شود، نه روی خروجیِ اجرا.

چرا: کاربری که پولش را نگه داشته‌اند با «خوشبختانه» دلداریِ دروغ می‌گیرد و
کاربری که پیش از این همان پرسش را جواب داده با تکرارِ پرسش سرگردان می‌شود.
این دو قاعده در چند فایل پخش بودند و هر بار یکی جا می‌ماند؛ این آزمون همهٔ
`lib/**.dart` را می‌گردد، پس فایل تازه هم خودکار پوشیده می‌شود.

کامنت‌ها کنار گذاشته می‌شوند: کامنتِ توضیحی اجازه دارد عبارت را نقل کند.
"""

import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LIB = os.path.join(ROOT, 'lib')

# عبارت‌هایی که هیچ‌جا در متنِ پاسخ نباید بیایند.
BANNED = {
    'خوشبختانه': 'دلداریِ دروغ؛ جای «خوشبختانه» نتیجه و شرطش گفته می‌شود',
    'این حرف را زیاد می‌شنوم': 'ادعای تجربهٔ زیسته؛ دستیار تجربهٔ زیسته ندارد',
    'موقعیت شما معمولاً قوی است': 'ارزیابیِ بی‌مدرک از پرونده',
}


def _dart_files():
    for base, _dirs, files in os.walk(LIB):
        for f in files:
            if f.endswith('.dart'):
                yield os.path.join(base, f)


def _code_only(path):
    """سورس بدون کامنت: هم `//` و هم `///` و هم بلوک `/* */`."""
    with open(path, encoding='utf-8') as f:
        src = f.read()
    src = re.sub(r'/\*.*?\*/', '', src, flags=re.S)
    return '\n'.join(re.sub(r'//.*$', '', line) for line in src.split('\n'))


class ToneTests(unittest.TestCase):
    def test_no_flattery_phrase_in_reply_text(self):
        bad = []
        for path in _dart_files():
            body = _code_only(path)
            for phrase, why in BANNED.items():
                if phrase in body:
                    bad.append('%s → «%s» (%s)' %
                               (os.path.relpath(path, ROOT), phrase, why))
        self.assertEqual(bad, [], '\n'.join(bad))

    def test_guard_would_catch_a_relapse(self):
        # اگر کسی عبارت را برگرداند، _code_only باید ببیندش.
        here = os.path.abspath(__file__)
        sample = os.path.join(os.path.dirname(here), '_tone_probe.dart')
        try:
            with open(sample, 'w', encoding='utf-8') as f:
                f.write("// خوشبختانه این‌جا کامنت است و ایراد ندارد\n"
                        "const s = 'خوشبختانه راهی هست';\n")
            body = _code_only(sample)
            self.assertIn('خوشبختانه', body)
        finally:
            if os.path.exists(sample):
                os.remove(sample)


if __name__ == '__main__':
    unittest.main()
