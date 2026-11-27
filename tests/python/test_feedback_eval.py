"""آزمون ابزار تبدیل بازخورد کاربر به مجموعهٔ `eval` (`dev/tools/feedback_eval.py`)."""

import contextlib
import io
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'dev' / 'tools'))

import feedback_eval as FE  # noqa: E402


class FeedbackEvalTests(unittest.TestCase):
    def test_parse_pending_labeled_and_positive(self):
        sample = '\n'.join([
            '# نظرات ذخیره‌شده روی همین گوشی.',
            '# 👎 پاسخ برنامه: ماده 1184 ...',
            'ولی قهری بچه کیه | ؟ | ؟',
            '# 👎 پاسخ برنامه: خلاصه اشتباه',
            'خیار غبن چیست | civil | ماده ۴۱۶',
            'خط خراب',
            '# --- پاسخ‌های مفید ---',
            '# 👍 چک چیست ← ماده 1 قانون صدور چک',
        ])
        parsed = FE.parse_feedback(sample)
        self.assertEqual(len(parsed['pending']), 1)
        self.assertEqual(parsed['pending'][0]['snippet'], 'ماده 1184 ...')
        self.assertEqual(len(parsed['labeled']), 1)
        self.assertEqual(parsed['labeled'][0]['law'], 'civil')
        self.assertEqual(len(parsed['malformed']), 1)
        self.assertEqual(len(parsed['positive']), 1)
        self.assertEqual(parsed['positive'][0]['q'], 'چک چیست')

    def test_validate_checks_law_article_and_duplicates(self):
        with tempfile.TemporaryDirectory() as tmp:
            eval_dir = Path(tmp) / 'eval'
            eval_dir.mkdir()
            (eval_dir / 'eval.txt').write_text(
                '# پرسش|قانون|عنوان مادهٔ درست\n'
                'چک بی‌محل چه مجازاتی دارد|cheque|ماده 7\n',
                encoding='utf-8',
            )
            rows = [
                {'line': 1, 'q': 'سند تازه درباره چک', 'law': 'cheque', 'article': 'ماده ۴'},
                {'line': 2, 'q': 'چک بی‌محل چه مجازاتی دارد', 'law': 'cheque', 'article': 'ماده 7'},
                {'line': 3, 'q': 'قانون غیرواقعی', 'law': 'unknown_law', 'article': 'ماده 1'},
                {'line': 4, 'q': 'ماده غیرواقعی', 'law': 'cheque', 'article': 'ماده 9999'},
            ]
            res = FE.validate_labeled(rows, eval_dir=eval_dir)
            self.assertEqual(len(res['ready']), 1)
            self.assertEqual(res['ready'][0]['article'], 'ماده 4')
            self.assertEqual(len(res['duplicates']), 1)
            self.assertEqual(len(res['invalid']), 2)

    def test_cli_write_appends_cleanly_and_detects_duplicates_next_run(self):
        with tempfile.TemporaryDirectory() as tmp:
            tmp_dir = Path(tmp)
            eval_dir = tmp_dir / 'eval'
            eval_dir.mkdir()
            fb = tmp_dir / 'feedback.txt'
            target = eval_dir / 'eval_feedback.txt'
            fb.write_text(
                '# 👎 پاسخ برنامه: اشتباه\n'
                'پرسش تازه از کاربر | civil | ماده ۱۰\n'
                'پرسش بی برچسب | ؟ | ؟\n',
                encoding='utf-8',
            )
            with contextlib.redirect_stdout(io.StringIO()):
                rc1 = FE.main([str(fb), '--eval-dir', str(eval_dir), '--write', str(target)])
            self.assertEqual(rc1, 0)
            lines = target.read_text(encoding='utf-8').splitlines()
            self.assertEqual(lines, [
                '# پرسش|قانون|عنوان مادهٔ درست',
                'پرسش تازه از کاربر|civil|ماده 10',
            ])
            # اجرای دوباره تکراری نمی‌نویسد.
            with contextlib.redirect_stdout(io.StringIO()):
                rc2 = FE.main([str(fb), '--eval-dir', str(eval_dir), '--write', str(target)])
            self.assertEqual(rc2, 0)
            self.assertEqual(len(target.read_text(encoding='utf-8').splitlines()), 2)


if __name__ == '__main__':
    unittest.main()
