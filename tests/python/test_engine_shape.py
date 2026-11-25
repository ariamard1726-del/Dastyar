"""شکلِ `KnowledgeEngine`: خواندنِ دارایی‌ها نباید با پاسخ‌سازی قاطی شود.

معیارِ «رفع شد» عددی است:

۱. سطحِ عمومی دست‌نخورده و هر امضا دقیقاً یک بار — تقسیم اجازه دارد *جای*
   متد را عوض کند، نه امضا را؛
۲. خواندنِ دارایی (`rootBundle`) فقط در `engine_load.dart` باشد؛ اگر دوباره در
   مسیرِ پاسخ ظاهر شود، «موتورِ بی‌دارایی» (که آزمون‌های `law_*_test` رویش
   حساب می‌کنند) می‌شکند؛
۳. `lib/core/` به `lib/domain/` وابسته نشود؛
۴. هیچ فایلی از سقفِ ۴۲۰ خط نگذرد و `engine.dart` (وضعیت + API) از ۲۰۰ نگذرد.

این آزمون پیش از تقسیم نوشته شد و **روی هر دو حالت** اجرا شد: «یکتا بودنِ
امضاها» و «وابسته نبودنِ core به domain» پیش از تقسیم هم سبز بودند (یعنی واقعاً
قفل‌اند)؛ سه شرطِ دیگر (جای خواندنِ دارایی، بودِ بخش‌ها، سقفِ خط) عمداً پیش از
تقسیم قرمز بودند، چون هدفِ همین گام‌اند.
"""

import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CORE = os.path.join(ROOT, 'lib', 'core')
ENGINE = os.path.join(CORE, 'engine.dart')

LIMIT = 420
ENGINE_MAX = 200

# امضای امروزِ سطحِ عمومی.
API = (
    'Future<void> load()',
    'EngineReply query(String question, {int maxAlternatives = 3})',
    'String answer(String question)',
    'List<String> alternatives(String question, {int max = 3})',
    'Chunk? findArticle(String law, String article)',
    'RankResult rank(String question, {int k = 3})',
    'double coverage(String question, Chunk c)',
    'String format(Chunk c)',
    'bool isLoaded(String id)',
    'int get size',
    'List<Chunk> get chunks',
    'static String normalize(String s)',
    'static List<String> tokenize(String s)',
)


def _read(path):
    with open(path, encoding='utf-8') as f:
        return f.read()


def _engine_files():
    return [os.path.join(CORE, n) for n in sorted(os.listdir(CORE))
            if n.startswith('engine') and n.endswith('.dart')]


class EngineShape(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.files = _engine_files()
        cls.lib = '\n'.join(_read(p) for p in cls.files)
        cls.src = _read(ENGINE)

    def test_public_api_is_intact_and_unique(self):
        counts = {sig: self.lib.count(sig) for sig in API}
        bad = {s: n for s, n in counts.items() if n != 1}
        self.assertEqual(bad, {}, 'امضای عمومی صفر یا چند بار تعریف شده: %s' % bad)

    def test_assets_are_read_only_in_the_loader(self):
        # خودِ `import` در سرِ کتابخانه است (بخش‌ها واردات ندارند)؛ معیار،
        # *خواندنِ* دارایی است، نه نامِ واردات.
        readers = {os.path.basename(p) for p in self.files
                   if 'rootBundle.load' in _read(p)}
        self.assertEqual(readers, {'engine_load.dart'},
                         'خواندنِ دارایی جای دیگری هم هست: %s' % readers)

    def test_core_does_not_depend_on_domain(self):
        bad = []
        for name in os.listdir(CORE):
            if not name.endswith('.dart'):
                continue
            if re.search(r"import\s+'package:dastyar/domain/", _read(os.path.join(CORE, name))):
                bad.append(name)
        self.assertEqual(bad, [], 'لایهٔ core به domain وابسته شد: %s' % bad)

    def test_the_split_parts_exist_and_are_listed(self):
        parts = re.findall(r"^part '([^']+)'", self.src, re.M)
        self.assertEqual(sorted(parts), ['engine_load.dart', 'engine_query.dart'])
        for p in parts:
            self.assertTrue(os.path.exists(os.path.join(CORE, p)), p)

    def test_sizes_stay_within_budget(self):
        big = {os.path.basename(p): len(_read(p).splitlines())
               for p in self.files if len(_read(p).splitlines()) > LIMIT}
        self.assertEqual(big, {}, 'از سقفِ %d خط گذشت: %s' % (LIMIT, big))
        n = len(self.src.splitlines())
        self.assertLessEqual(n, ENGINE_MAX, 'engine.dart پر شد (%d خط)' % n)


if __name__ == '__main__':
    unittest.main()
