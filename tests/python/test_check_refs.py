"""آزمون ارجاع‌های استنادی: هر `[[کلید:شماره]]` در کد باید به ماده‌ای واقعی برسد."""

import unittest

from tools import check_refs


class CheckRefsTest(unittest.TestCase):
    def test_every_citation_in_code_resolves(self):
        files = check_refs.law_files()
        problems = []
        for (key, num), where in check_refs.collect_refs().items():
            self.assertIn(key, files, f"کلید ناشناخته {key} در {where[0]}")
            text = files[key].read_text(encoding="utf-8")
            word = "اصل" if key == "constitution" else "ماده"
            if not check_refs.article_exists(text, num, word):
                problems.append(f"{word} {num} در {key} ({where[0]})")
        self.assertEqual(problems, [])

    def test_article_matcher_accepts_both_digit_styles(self):
        text = "ماده 35\nمتن\n\nماده ۳۶\nمتن"
        self.assertTrue(check_refs.article_exists(text, "35"))
        self.assertTrue(check_refs.article_exists(text, "36"))
        self.assertFalse(check_refs.article_exists(text, "37"))

    def test_constitution_uses_asl_not_madde(self):
        self.assertTrue(check_refs.article_exists("اصل 173\nمتن", "173", "اصل"))
        self.assertFalse(check_refs.article_exists("اصل 173\nمتن", "173", "ماده"))


if __name__ == "__main__":
    unittest.main()
