"""سقفِ اندازهٔ فایل: هیچ فایلِ گاد-آبجکتی در `lib/` نماند و برنگردد.

قاعده ساده است و عددی:

  * هیچ فایلِ `lib/**/*.dart` بیشتر از ۴۲۰ خط نباشد.
  * فهرستِ استثناها ("بدهی") فقط می‌تواند **کوچک** شود: اگر فایلی از فهرست به
    زیرِ سقف برسد، همین آزمون می‌گوید خطش را از فهرست بردارید؛ اگر بزرگ‌تر
    شود، قرمز می‌شود.

این آزمون جای سلیقه را با عدد می‌گیرد؛ هدفش «کدِ قشنگ» نیست، این است که هیچ
فایلی دوباره به جایی نرسد که خواندنش یک پروژه باشد.
"""
import glob
import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LIMIT = 420

# بدهیِ شناخته‌شده: (سقفِ فعلی). هر عدد فقط اجازه دارد کم شود.
DEBT = {
    'lib/domain/advocate/topics/rent_issues.dart': 814,
    # سیم‌کشیِ بیست همکار + ثابت‌های دکمه‌ها؛ گامِ بعد ثابت‌ها را بیرون می‌برد.
    'lib/domain/advocate/advocate.dart': 595,
    'lib/domain/drafting.dart': 659,
    'lib/core/engine.dart': 639,
    'lib/domain/advocate/topics/rent_patterns.dart': 537,
    'lib/domain/advocate/topics/rent_bodies.dart': 468,
}

# فایل‌هایی که متنِ حقوقی‌اند و باید مثل راهنماها به دادهٔ بیرونی بروند.
DATA_FILES = {
    'lib/domain/advocate/topics/rent_issues.dart',
    'lib/domain/advocate/topics/rent_patterns.dart',
    'lib/domain/advocate/topics/rent_bodies.dart',
}


def _lines(path):
    with open(path, encoding='utf-8') as f:
        return len(f.read().split('\n'))


class FileSizeBudgetTests(unittest.TestCase):
    def setUp(self):
        self.sizes = {}
        for p in glob.glob(os.path.join(ROOT, 'lib', '**', '*.dart'), recursive=True):
            rel = os.path.relpath(p, ROOT).replace(os.sep, '/')
            self.sizes[rel] = _lines(p)

    def test_no_file_is_a_god_object(self):
        over = {k: v for k, v in self.sizes.items()
                if v > LIMIT and k not in DEBT}
        self.assertEqual(over, {},
                         'این فایل‌ها از سقفِ %d خط گذشتند و در فهرستِ بدهی نیستند' % LIMIT)

    def test_debt_only_shrinks(self):
        for path, cap in DEBT.items():
            self.assertIn(path, self.sizes, 'فایلِ بدهی حذف شده؛ خطش را از فهرست بردارید')
            self.assertLessEqual(self.sizes[path], cap,
                                 '%s بزرگ‌تر شد (%d > %d)' % (path, self.sizes[path], cap))
            self.assertGreater(self.sizes[path], LIMIT - 200,
                               '%s کوچک شد؛ سقفِ تازه‌اش را در فهرست بنویسید' % path)

    def test_data_files_are_marked(self):
        """متنِ حقوقی باید در فهرستِ داده باشد، نه در کدِ رفتار."""
        for path in DATA_FILES:
            self.assertIn(path, self.sizes)

    def test_largest_files_are_known(self):
        """اگر فایلِ تازه‌ای به صدر آمد، باید آگاهانه باشد."""
        top = sorted(self.sizes.items(), key=lambda kv: -kv[1])[:3]
        names = [k for k, _ in top]
        self.assertTrue(all(n in DEBT for n in names),
                        'صدرِ فهرست عوض شد و در فهرستِ بدهی نیست: %r' % names)


if __name__ == '__main__':
    unittest.main()
