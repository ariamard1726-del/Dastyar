"""آزمون بانک پرسش‌وپاسخ اجاره: ساختار، یکتایی، و صحت استنادها به متن قانون.

هر پاسخ باید به مادهٔ واقعی‌ای استناد کند که متنش در مخزن موجود است، و هر
شماره‌ای که داخل پاسخ به‌عنوان «ماده …» آمده باید در فهرست استنادهای همان
پرسش باشد. بدین ترتیب پاسخی نمی‌تواند ماده‌ای را بی‌پشتوانه نام ببرد.
"""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
QA_PATH = ROOT / 'assets' / 'qa' / 'lease_qa.json'
LAWS_DIR = ROOT / 'assets' / 'laws'
LAW_FILES = {
    'civil': 'Hoghough_e_Khosousi/Hoghough_e_Madani/ghanoun_e_madani.txt',
    'landlord_tenant': 'Hoghough_e_Khosousi/Hoghough_e_Madani/ghanoun_e_roabat_e_mojer_va_mostajer.txt',
}
MIN_ITEMS = 100
ARTICLE_LINE = re.compile(r'^ماده ([0-9۰-۹]+)\s*$', re.M)
MENTION = re.compile(r'ماده[ \u200c]([0-9۰-۹]+)')
FA_DIGITS = str.maketrans('۰۱۲۳۴۵۶۷۸۹', '0123456789')


def _norm(s):
    return re.sub(r'\s+', ' ', s.replace('\u200c', ' ').replace('ي', 'ی').replace('ك', 'ک')).strip()


def _articles(law_id):
    text = (LAWS_DIR / LAW_FILES[law_id]).read_text(encoding='utf-8')
    return {int(n.translate(FA_DIGITS)) for n in ARTICLE_LINE.findall(text)}


class LeaseQaTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(QA_PATH.read_text(encoding='utf-8'))
        cls.items = cls.data['items']
        cls.articles = {law: _articles(law) for law in LAW_FILES}

    def test_header_is_complete(self):
        self.assertEqual(self.data['schema'], 1)
        self.assertEqual(self.data['topic'], 'lease')
        self.assertTrue(self.data['disclaimer'].strip())
        self.assertEqual(set(self.data['law_titles']), set(LAW_FILES))

    def test_has_at_least_the_required_number_of_items(self):
        self.assertGreaterEqual(len(self.items), MIN_ITEMS)

    def test_ids_are_unique_and_well_formed(self):
        ids = [it['id'] for it in self.items]
        self.assertEqual(len(ids), len(set(ids)), 'شناسهٔ تکراری')
        for i in ids:
            self.assertRegex(i, r'^L\d{3}$')

    def test_questions_are_unique(self):
        qs = [_norm(it['q']) for it in self.items]
        dups = sorted({q for q in qs if qs.count(q) > 1})
        self.assertEqual(dups, [], 'پرسش تکراری')

    def test_every_item_has_text_category_and_sane_length(self):
        categories = {it['category'] for it in self.items}
        self.assertLessEqual(len(categories), 12)
        for it in self.items:
            self.assertTrue(it['q'].strip().endswith('؟'), it['id'] + ': پرسش باید با ؟ تمام شود')
            self.assertTrue(it['category'].strip(), it['id'])
            self.assertGreaterEqual(len(it['a']), 40, it['id'] + ': پاسخ خیلی کوتاه است')
            self.assertLessEqual(len(it['a']), 500, it['id'] + ': پاسخ خیلی بلند است')

    def test_every_item_cites_at_least_one_real_article(self):
        for it in self.items:
            refs = it['refs']
            self.assertGreaterEqual(len(refs), 1, it['id'] + ': بدون استناد')
            for ref in refs:
                law, _, num = ref.partition(':')
                self.assertIn(law, LAW_FILES, f"{it['id']}: قانون ناشناخته {ref}")
                self.assertTrue(num.isdigit(), f"{it['id']}: شمارهٔ ماده نامعتبر {ref}")
                self.assertIn(int(num), self.articles[law],
                              f"{it['id']}: ماده {num} در {law} در متن قانون نیست")

    def test_article_mentions_in_answers_are_backed_by_citations(self):
        for it in self.items:
            cited = {int(r.partition(':')[2]) for r in it['refs']}
            for m in MENTION.findall(it['a']):
                n = int(m.translate(FA_DIGITS))
                self.assertIn(n, cited, f"{it['id']}: پاسخ ماده {n} را نام برده ولی استناد نشده")

    def test_landlord_tenant_articles_are_covered(self):
        # ماده‌های ۱ تا ۱۳ قانون روابط موجر و مستأجر باید در پرسش‌ها دیده شوند.
        used = {int(r.partition(':')[2]) for it in self.items for r in it['refs']
                if r.startswith('landlord_tenant:')}
        self.assertGreaterEqual(len(used), 10, 'پوشش مواد قانون روابط موجر و مستأجر ناکافی است')

    def test_civil_lease_chapter_articles_are_covered(self):
        # فصل «در اجاره» قانون مدنی از ماده ۴۶۶ تا ۵۰۴ است.
        used = {int(r.partition(':')[2]) for it in self.items for r in it['refs']
                if r.startswith('civil:')}
        lease_chapter = {n for n in self.articles['civil'] if 466 <= n <= 504}
        self.assertGreaterEqual(len(used & lease_chapter), 25)

    def test_no_item_recommends_self_help_eviction(self):
        banned = re.compile(r'مجاز است.{0,20}(قفل|وسایل را بیرون)')
        for it in self.items:
            self.assertIsNone(banned.search(it['a']), it['id'])


if __name__ == '__main__':
    unittest.main()
