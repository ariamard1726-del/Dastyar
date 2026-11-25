"""نگهبانِ متنِ حقوقی: هشِ متن + تفاضلِ ماده‌به‌ماده.

دو ابزار را می‌سنجد که فاز ۱ به آن‌ها تکیه دارد:

1. `tools/text_manifest.py` — هر فایلِ متن‌دار (متنِ قوانین، راهنماها، بانک
   پرسش‌وپاسخ، و فایل‌های Dart که متنِ پاسخ در آن‌ها زندگی می‌کند) یک هش دارد.
   پس هیچ تغییرِ متنی بی‌اعلام نمی‌ماند.
2. `tools/law_diff.py` — وقتی نسخهٔ اعتبارسنجی‌شدهٔ قانون می‌آید، تفاضل
   **ماده‌به‌ماده** گزارش می‌شود، نه فایل‌به‌فایل.
"""

import os
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'tools'))

import law_diff  # noqa: E402
import text_manifest  # noqa: E402


class TextManifestTests(unittest.TestCase):
    def test_manifest_covers_every_text_file(self):
        want = set(text_manifest.text_files(ROOT))
        have = set(text_manifest.load(ROOT)['files'])
        self.assertEqual(want - have, set(), 'این فایل‌ها در هش‌نامه نیستند')
        self.assertEqual(have - want, set(), 'این فایل‌ها دیگر متن‌دار نیستند')

    def test_check_is_green_on_the_current_tree(self):
        changed = text_manifest.diff(ROOT)
        self.assertEqual(changed, [], 'متن عوض شده و هش‌نامه به‌روز نیست')

    def test_a_single_changed_letter_is_caught(self):
        """هش باید به یک نویسه هم حساس باشد — وگرنه نگهبان نیست."""
        manifest = text_manifest.build(ROOT)
        key = next(iter(manifest['files']))
        manifest['files'][key]['sha256'] = '0' * 64
        changed = text_manifest.diff(ROOT, manifest=manifest)
        self.assertEqual([c['path'] for c in changed], [key])
        self.assertEqual(changed[0]['reason'], 'sha256')

    def test_every_catalogued_law_is_hashed(self):
        meta = text_manifest.meta(ROOT)
        manifest = text_manifest.build(ROOT)
        for law in meta.values():
            path = 'assets/laws/' + law['path']
            self.assertIn(path, manifest['files'],
                          'قانونِ «%s» در هش‌نامه نیست' % law.get('title', '?'))


class LawDiffTests(unittest.TestCase):
    def test_parser_reads_articles(self):
        text = ('# قانون آزمایشی\n\n## فصل اول\n\nماده 1\nمتنِ اول.\nادامهٔ اول.\n\n'
                'ماده 2\nمتنِ دوم.\n\n## فصل دوم\n\nماده 3\nمتنِ سوم.\n')
        arts = law_diff.parse_law(text)
        self.assertEqual(sorted(arts), ['ماده 1', 'ماده 2', 'ماده 3'])
        self.assertIn('ادامهٔ اول', arts['ماده 1'])
        self.assertNotIn('فصل دوم', arts['ماده 2'])

    def test_repeated_articles_keep_separate_keys(self):
        """«ماده ۳ مکرر» مادهٔ دیگری است؛ کلیدش نباید روی ماده ۳ بیفتد."""
        arts = law_diff.parse_law('ماده 3\nالف\n\nماده 3 مکرر\nب\n\nاصل 3\nج\n')
        self.assertEqual(sorted(arts), ['اصل 3', 'ماده 3', 'ماده 3 مکرر'])
        self.assertEqual(arts['ماده 3 مکرر'], 'ب')

    def test_diff_detects_add_remove_change(self):
        old = {'ماده 1': 'الف', 'ماده 2': 'ب'}
        new = {'ماده 1': 'الف.', 'ماده 3': 'ج'}
        d = law_diff.diff_articles(old, new)
        self.assertEqual(d['changed'], ['ماده 1'])
        self.assertEqual(d['added'], ['ماده 3'])
        self.assertEqual(d['removed'], ['ماده 2'])

    def test_diff_against_another_tree(self):
        """نسخهٔ نو ممکن است در پوشه‌ای بیاید، نه در گیت: `--dir` هم باید کار کند."""
        import shutil
        import tempfile
        with tempfile.TemporaryDirectory() as tmp:
            rel = law_diff.law_texts(ROOT)[0]
            dest = os.path.join(tmp, rel)
            os.makedirs(os.path.dirname(dest))
            shutil.copy(os.path.join(ROOT, rel), dest)
            with open(dest, encoding='utf-8') as f:
                old = f.read()
            with open(dest, 'w', encoding='utf-8') as f:
                first = next(l for l in old.split('\n') if l.startswith(('ماده', 'اصل')))
                f.write(old.replace(first + '\n', first + '\nواژهٔ قلابی\n', 1))
            rows = law_diff.diff_against_dir(ROOT, tmp)
            mine = [r for r in rows if r['path'] == rel][0]
            self.assertTrue(mine['changed'] or mine['added'],
                            'تفاضلِ دو درخت دیده نشد')
            rest = [r for r in rows if r['path'] != rel]
            self.assertTrue(all(r['old'] == 0 for r in rest),
                            'درختِ دوم فقط یک قانون دارد؛ بقیه باید خالی باشند')

    def test_working_tree_matches_itself(self):
        """تفاضلِ درختِ کاری با HEAD نباید چیزی نشان دهد (متن دست‌نخورده است)."""
        rows = law_diff.diff_against_ref(ROOT, 'HEAD')
        changed = [r for r in rows if r['changed'] or r['added'] or r['removed']]
        self.assertEqual(changed, [], 'متنِ قانون نسبت به HEAD عوض شده: %s'
                         % [r['path'] for r in changed])

    def test_article_counts_match_meta(self):
        bad = law_diff.count_mismatches(ROOT)
        self.assertEqual(bad, [], 'شمارِ مواد با _meta.json نمی‌خواند: %s' % bad)


if __name__ == '__main__':
    unittest.main()
