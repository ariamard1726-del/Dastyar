"""شکلِ `CaseFlow`: روندِ پرونده نباید یک کلاسِ همه‌کاره بماند.

معیارِ «رفع شد» عددی است، نه توصیفی:

۱. سطحِ عمومیِ `CaseFlow` دقیقاً همان ۱۸ نامِ امروز است — تقسیم اجازه دارد
   *جای* متد را عوض کند، نه نام و نه امضا را؛
۲. هر متد دقیقاً یک بار تعریف شده باشد؛ جابه‌جایی نباید کپی بسازد؛
۳. سه مسئولیتِ جدا (واقعیت‌ها، پاسخِ نوبت، متنِ پاسخ) هر کدام صاحبِ فایلِ
   خودشان را داشته باشند و هیچ فایلی از سقفِ ۴۲۰ خط نگذرد.

این فایل عمداً *قبل* از تقسیم نوشته شد تا رفتار قفل شود و تقسیم نتواند
بی‌صدا یکی از تصمیم‌ها را حذف کند.
"""

import os
import re
import sys
import unittest

sys.path.insert(0, os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    'tools'))
from library import parts_of  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ADVOCATE_DIR = os.path.join(ROOT, 'lib', 'domain', 'advocate')
ADVOCATE = os.path.join(ADVOCATE_DIR, 'advocate.dart')

LIMIT = 420

# صاحبانِ مسئولیت در روندِ پرونده. `advocate.dart` عمداً این‌جا نیست؛ سقفِ آن
# کارِ `test_file_sizes.py` است.
OWNER = ('case_flow.dart', 'case_facts.dart', 'case_answer.dart', 'case_text.dart')

# امضای امروزِ هر متد: (نوعِ بازگشتی، نام). تغییرِ امضا تصمیمِ معماری است، نه
# جزئیاتِ تقسیم؛ پس آزمون آن را قفل می‌کند.
SIGNATURES = {
    'hasCase': 'bool get hasCase',
    '_out': 'AdvocateReply _out(',
    '_pick': 'String _pick(',
    'clearOffer': 'void clearOffer(',
    '_lookup': 'AdvocateReply? _lookup(',
    '_factsKey': 'String _factsKey(',
    'closeCase': 'void closeCase(',
    'absorb': 'List<Slot> absorb(',
    'filing': 'AdvocateReply filing(',
    'roleUnknown': 'bool roleUnknown(',
    'open': 'AdvocateReply open(',
    'addEffects': 'void addEffects(',
    'noteAmount': 'void noteAmount(',
    'inCase': 'AdvocateReply inCase(',
    'generic': 'Body? generic(',
    'leadSettled': 'Standing? leadSettled(',
    'react': 'String react(',
    'finish': 'AdvocateReply finish(',
}

# سطحِ عمومی، جدا از خصوصی‌ها؛ گم شدنِ یکی از این‌ها رفتار را عوض می‌کند.
API = {
    'hasCase', 'clearOffer', 'closeCase', 'absorb', 'filing', 'roleUnknown',
    'open', 'addEffects', 'noteAmount', 'inCase', 'generic', 'leadSettled',
    'react', 'finish',
}


def _read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def _parts():
    return [os.path.join(ADVOCATE_DIR, p)
            for p in parts_of(ROOT, os.path.relpath(ADVOCATE, ROOT))]


class CaseFlowShape(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.src = _read(ADVOCATE)
        cls.files = [ADVOCATE] + _parts()
        cls.lib = '\n'.join(_read(p) for p in cls.files)
        cls.owned = '\n'.join(
            _read(os.path.join(ADVOCATE_DIR, n))
            for n in OWNER
            if os.path.exists(os.path.join(ADVOCATE_DIR, n)))

    def test_public_api_is_unchanged(self):
        missing = [n for n in sorted(API) if SIGNATURES[n] not in self.lib]
        self.assertEqual(missing, [], 'از سطحِ عمومیِ CaseFlow گم شد: %s' % missing)

    def test_every_signature_is_declared_exactly_once(self):
        counts = {}
        for name, sig in SIGNATURES.items():
            pat = r'^  %s' % re.escape(sig).replace(r'\ ', ' ')
            n = len(re.findall(pat, self.owned, re.M))
            if n != 1:
                counts[name] = n
        self.assertEqual(counts, {}, 'امضایی صفر یا دو بار تعریف شده: %s' % counts)

    def test_no_owner_file_passes_the_limit(self):
        big = {}
        for name in OWNER:
            path = os.path.join(ADVOCATE_DIR, name)
            if not os.path.exists(path):
                continue
            n = len(_read(path).splitlines())
            if n > LIMIT:
                big[name] = n
        self.assertEqual(big, {}, 'از سقفِ %d خط گذشت: %s' % (LIMIT, big))

    def test_the_three_owners_have_their_own_file(self):
        names = [os.path.basename(p) for p in self.files]
        for want in ('case_flow.dart', 'case_facts.dart', 'case_answer.dart', 'case_text.dart'):
            self.assertIn(want, names, 'فایلِ صاحبِ مسئولیت پیدا نشد: %s' % want)

if __name__ == '__main__':
    unittest.main()
