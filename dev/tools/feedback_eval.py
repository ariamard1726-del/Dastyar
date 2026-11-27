"""پالایش و تبدیل خروجی بازخوردهای کاربر (`FeedbackStore.exportText`) به ردیف‌های `eval`.

کاربر در برنامه می‌تواند خروجی متنی بازخوردها را بگیرد؛ این خروجی برای پرسش‌های
«مفید نبود» سطرهای `پرسش | ؟ | ؟` و برای «مفید بود» یادداشت `# 👍` می‌سازد.
پس از آن‌که بررسی‌کننده به‌جای `؟` شناسهٔ قانون و عنوان ماده را نوشت، این ابزار:

- ردیف‌های برچسب‌خورده را با `_meta.json` و متن واقعی قوانین (`lawtext`) می‌سنجد؛
- پرسش‌های تکراریِ موجود در `eval/*.txt` را جدا می‌کند؛
- موارد آماده را (در صورت دادن `--write`) به‌صورت امن به فایل هدف در `eval/` می‌افزاید.

اجرا:
  python3 dev/tools/feedback_eval.py path/to/feedback.txt
  python3 dev/tools/feedback_eval.py path/to/feedback.txt --write eval/eval_extra.txt
"""

from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
TOOLS_DIR = Path(__file__).resolve().parent
if str(TOOLS_DIR) not in sys.path:
    sys.path.insert(0, str(TOOLS_DIR))

import lawtext  # noqa: E402

PENDING_MARKS = {'', '؟', '?'}


def parse_feedback(text):
    """متن صادرشدهٔ `FeedbackStore.exportText` را به دسته‌های ساختاریافته می‌شکند."""
    pending = []
    labeled = []
    malformed = []
    positive = []
    last_snippet = ''

    for line_no, raw in enumerate(text.replace('\r', '').splitlines(), 1):
        line = raw.strip()
        if not line:
            continue
        if line.startswith('#'):
            body = line[1:].strip()
            if body.startswith('👎 پاسخ برنامه:'):
                last_snippet = body.split(':', 1)[1].strip()
            elif body.startswith('👍 '):
                item = body[2:].strip()
                q, sep, snippet = item.partition('←')
                positive.append({
                    'line': line_no,
                    'q': q.strip(),
                    'snippet': snippet.strip() if sep else '',
                })
            continue

        parts = [p.strip() for p in line.split('|')]
        if len(parts) != 3 or not parts[0]:
            malformed.append({'line': line_no, 'raw': line, 'reason': 'قالب سه‌ستونی (پرسش | قانون | ماده) نیست'})
            last_snippet = ''
            continue

        q, law, art = parts
        if law in PENDING_MARKS or art in PENDING_MARKS:
            pending.append({'line': line_no, 'q': q, 'law': law, 'article': art, 'snippet': last_snippet})
        else:
            labeled.append({'line': line_no, 'q': q, 'law': law, 'article': art, 'snippet': last_snippet})
        last_snippet = ''

    return {
        'pending': pending,
        'labeled': labeled,
        'malformed': malformed,
        'positive': positive,
    }


def existing_eval_questions(eval_dir=None):
    """پرسش‌های یکسان‌شدهٔ موجود در فایل‌های `eval/*.txt` را گردآوری می‌کند."""
    base = Path(eval_dir) if eval_dir else ROOT / 'eval'
    seen = set()
    if not base.is_dir():
        return seen
    for path in sorted(base.glob('*.txt')):
        with open(path, encoding='utf-8') as f:
            for raw in f:
                line = raw.strip()
                if not line or line.startswith('#') or '|' not in line:
                    continue
                q = line.split('|', 1)[0].strip()
                if q:
                    seen.add(lawtext.norm(q))
    return seen


def validate_labeled(rows, meta=None, root=None, eval_dir=None):
    """ردیف‌های برچسب‌خورده را با متن واقعی قوانین و مجموعهٔ `eval` می‌سنجد."""
    base = Path(root) if root else ROOT
    meta_data = meta if meta is not None else lawtext.load_meta(root=base)
    files = lawtext.law_files(meta_data, root=base)
    seen = existing_eval_questions(eval_dir if eval_dir is not None else base / 'eval')

    article_cache = {}
    ready = []
    duplicates = []
    invalid = []

    for row in rows:
        q = row['q'].strip()
        law = row['law'].strip()
        raw_art = row['article'].strip()
        if law not in files or not files[law].is_file():
            invalid.append({**row, 'reason': 'قانون ناشناخته در _meta.json: %s' % law})
            continue
        if law not in article_cache:
            with open(files[law], encoding='utf-8') as f:
                article_cache[law] = lawtext.articles_of(f.read())
        art_key = lawtext.block_key(raw_art)
        if not lawtext.is_article(art_key) or art_key not in article_cache[law]:
            invalid.append({**row, 'reason': 'عنوان ماده «%s» در قانون %s پیدا نشد' % (raw_art, law)})
            continue

        norm_q = lawtext.norm(q)
        if norm_q in seen:
            duplicates.append({**row, 'article': art_key})
            continue
        seen.add(norm_q)
        ready.append({**row, 'article': art_key})

    return {'ready': ready, 'duplicates': duplicates, 'invalid': invalid}


def format_eval_row(row):
    return '%s|%s|%s' % (row['q'].strip(), row['law'].strip(), row['article'].strip())


def append_eval_rows(rows, target_path):
    """ردیف‌های معتبر را بدون دست‌زدن به سطرهای قبلی به فایل `eval` می‌افزاید."""
    if not rows:
        return 0
    target = Path(target_path)
    target.parent.mkdir(parents=True, exist_ok=True)
    need_header = not target.exists() or target.stat().st_size == 0
    with open(target, 'a', encoding='utf-8') as f:
        if need_header:
            f.write('# پرسش|قانون|عنوان مادهٔ درست\n')
        for row in rows:
            f.write(format_eval_row(row) + '\n')
    return len(rows)


def main(argv):
    args = [a for a in argv if a]
    write_target = None
    eval_dir = None
    src_path = None
    i = 0
    while i < len(args):
        a = args[i]
        if a == '--write' and i + 1 < len(args):
            write_target = args[i + 1]
            i += 2
            continue
        if a == '--eval-dir' and i + 1 < len(args):
            eval_dir = args[i + 1]
            i += 2
            continue
        if src_path is None:
            src_path = a
        i += 1

    if not src_path or not Path(src_path).is_file():
        print('خطا: مسیر فایل بازخورد معتبر نیست: %s' % (src_path or '—'))
        return 1

    with open(src_path, encoding='utf-8') as f:
        parsed = parse_feedback(f.read())
    checked = validate_labeled(parsed['labeled'], eval_dir=eval_dir)

    invalid_all = parsed['malformed'] + checked['invalid']
    print(
        'feedback_eval: آماده=%d، در انتظار برچسب=%d، تکراری=%d، نامعتبر=%d، بازخورد مثبت=%d'
        % (
            len(checked['ready']),
            len(parsed['pending']),
            len(checked['duplicates']),
            len(invalid_all),
            len(parsed['positive']),
        )
    )
    for err in invalid_all:
        print('خطا (خط %d): %s' % (err['line'], err['reason']))

    if invalid_all:
        return 1

    if write_target:
        added = append_eval_rows(checked['ready'], write_target)
        print('نوشته‌شده در %s: %d ردیف' % (write_target, added))
    else:
        for row in checked['ready']:
            print(format_eval_row(row))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
