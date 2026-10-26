import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAW = os.path.join(ROOT, 'assets', 'laws', 'commerce.txt')
META = os.path.join(ROOT, 'assets', 'laws', '_meta.json')
LO, HI = 21, 93
NOTE = ('توجه: این ماده دربارهٔ شرکت سهامی (عام و خاص) با «لایحهٔ اصلاحی قسمتی '
        'از قانون تجارت» (۱۳۴۷) جایگزین شده است؛ برای شرکت سهامی به آن لایحه '
        'مراجعه کنید.')
END_CHARS = '.؛:)»!؟?'
AI = ['هوش مصنوعی', 'chatgpt', 'gemini', 'claude', 'as an ai', 'language model']
ART = re.compile(r'^ماده\s*([0-9۰-۹٠-٩]+)\s*(?:[-–—ـ.:)]+\s*)?(.*)$')
HEAD = re.compile(r'^(?:مبحث|فصل|باب|بخش|قسمت|گفتار)\s')


def die(msg):
    print('خطا: ' + msg)
    print('هیچ فایلی تغییر نکرد.')
    sys.exit(1)


def digits(s):
    return s.translate(str.maketrans('۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789'))


def clean(t):
    t = t.replace('\r', '')
    t = re.sub('[\u200e\u200f\u202a-\u202e\ufeff]', '', t)
    return t.replace('ي', 'ی').replace('ك', 'ک')


def parse(text):
    arts = []
    cur = None
    for raw in clean(text).split('\n'):
        line = raw.strip()
        if not line:
            continue
        m = ART.match(line)
        if m:
            n = int(digits(m.group(1)))
            if cur is None or n > cur[0]:
                rest = m.group(2).strip()
                if rest.startswith('مکرر'):
                    die('«مکرر» پشتیبانی نمی‌شود: ' + line[:40])
                cur = [n, []]
                arts.append(cur)
                if rest:
                    cur[1].append(rest)
                continue
        if HEAD.match(line) and len(line) < 80 and line[-1] not in END_CHARS:
            print('نادیده گرفته شد (عنوان فصل): ' + line)
            continue
        if cur is None:
            print('نادیده گرفته شد (قبل از اولین ماده): ' + line[:50])
            continue
        cur[1].append(line)
    return arts


def art_num(block):
    m = re.match(r'^ماده (\d+)$', digits(block.split('\n')[0]).strip())
    return int(m.group(1)) if m else None


def main():
    print('مواد را بچسبانید (قالب: «ماده ۲۱ - متن...»).')
    print('در پایان در یک خط جدا بنویسید END و Enter بزنید.')
    new = []
    while True:
        try:
            line = input()
        except EOFError:
            break
        if line.strip() == 'END':
            break
        new.append(line)
    text = '\n'.join(new)
    if any(len(l.encode('utf-8')) >= 3900 for l in new):
        print('هشدار: خط خیلی بلند بود؛ ممکن است ترمینال آن را بریده باشد.')
    low = text.lower()
    for m in AI:
        if m in low:
            die('عبارت مشکوک به متن تولیدشده با هوش مصنوعی: ' + m)

    arts = parse(text)
    if not arts:
        die('هیچ مادهٔ قابل‌شناسایی پیدا نشد.')
    nums = [a[0] for a in arts]
    for n in nums:
        if n < LO or n > HI:
            die('ماده %d خارج از بازهٔ %d تا %d است.' % (n, LO, HI))
    for i in range(1, len(nums)):
        if nums[i] != nums[i - 1] + 1:
            die('شماره‌ها پیوسته نیست: بعد از %d آمده %d (متن ناقص یا ماده افتاده)'
                % (nums[i - 1], nums[i]))
    for n, lines in arts:
        if not lines:
            die('ماده %d متن ندارد.' % n)
    last = arts[-1][1][-1]
    if last[-1] not in END_CHARS:
        print('هشدار: آخر ماده %d به علامت پایان نرسیده؛ شاید متن ناقص است.' % arts[-1][0])

    with open(LAW, encoding='utf-8') as f:
        blocks = [b.strip() for b in re.split(r'\n\s*\n', f.read().replace('\r', '')) if b.strip()]
    have = {art_num(b) for b in blocks}
    for n in nums:
        if n in have:
            die('ماده %d از قبل در فایل هست.' % n)

    for n, lines in arts:
        block = 'ماده %d\n%s\n%s' % (n, '\n'.join(lines), NOTE)
        idx = None
        for i, b in enumerate(blocks):
            k = art_num(b)
            if k is not None and k > n:
                idx = i
                break
        if idx is None:
            die('جای درج ماده %d پیدا نشد.' % n)
        while idx > 0 and blocks[idx - 1].startswith('#'):
            idx -= 1
        blocks.insert(idx, block)

    out = '\n\n'.join(blocks) + '\n'
    with open(LAW, 'w', encoding='utf-8') as f:
        f.write(out)

    count = sum(1 for b in blocks if not b.startswith('#'))
    with open(META, encoding='utf-8') as f:
        meta = json.load(f)
    if isinstance(meta.get('commerce'), dict):
        meta['commerce']['articles'] = count
        with open(META, 'w', encoding='utf-8') as f:
            json.dump(meta, f, ensure_ascii=False, indent=2)
            f.write('\n')

    done = sorted(a for a in {art_num(b) for b in blocks} if a and LO <= a <= HI)
    todo = [n for n in range(LO, HI + 1) if n not in done]
    print('درج شد: ماده %d تا %d (%d ماده). جمع بخش‌های قانون تجارت: %d'
          % (nums[0], nums[-1], len(nums), count))
    if todo:
        print('هنوز نیست: %d ماده، از %d تا %d' % (len(todo), todo[0], todo[-1]))
    else:
        print('همهٔ مواد ۲۱ تا ۹۳ درج شده است.')
    print('حالا بزنید: python tools/check.py   و   git diff --stat')


main()
