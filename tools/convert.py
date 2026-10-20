import argparse
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAWS_DIR = os.path.join(ROOT, 'assets', 'laws')

ORD = ('اول|دوم|سوم|چهارم|پنجم|ششم|هفتم|هشتم|نهم|دهم|یازدهم|دوازدهم|'
       'سیزدهم|چهاردهم|پانزدهم|شانزدهم|هفدهم|هجدهم|نوزدهم|بیستم')
HEAD = re.compile(r'^(فصل|بخش|کتاب|باب|مبحث|گفتار)\s+(?:' + ORD + r'|\d+)(?!\w)')
ONE = re.compile(r'^ماده\s+واحده\s*(?:[-–—ـ.:]+)?\s*(.*)$')
ART_SEP = re.compile(r'^ماده\s*(\d+)(\s*مکرر(?:\s*\d+)?)?\s*[-–—ـ.:)]+\s*(.*)$')
ART_END = re.compile(r'^ماده\s*(\d+)(\s*مکرر(?:\s*\d+)?)?\s*$')
ART_LOOSE = re.compile(r'^ماده\s*(\d+)\s+(.+)$')


def digits(s):
    return s.translate(str.maketrans('۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789'))


def clean(text):
    text = text.replace('\r', '')
    text = re.sub('[\u200e\u200f\u202a-\u202e\ufeff]', '', text)
    return text.replace('ي', 'ی').replace('ك', 'ک')


def mk_title(num, mk):
    t = 'ماده ' + str(int(num))
    mk = (mk or '').strip()
    if mk:
        t += ' ' + re.sub(r'\s+', ' ', mk)
    return t


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('law_id')
    ap.add_argument('raw')
    ap.add_argument('name')
    ap.add_argument('--source', default='')
    ap.add_argument('--date', default='')
    ap.add_argument('--chapters', action='store_true')
    a = ap.parse_args()

    if not re.fullmatch(r'[a-z0-9_]+', a.law_id):
        print('خطا: شناسهٔ قانون فقط حروف کوچک انگلیسی، عدد و _ باشد.')
        sys.exit(1)
    if not os.path.exists(a.raw):
        print('خطا: فایل پیدا نشد:', a.raw)
        sys.exit(1)

    with open(a.raw, encoding='utf-8') as f:
        text = clean(f.read())

    articles = []
    cur = None
    chapter = ''
    heads = 0
    ignored = 0
    last = 0

    for raw_line in text.split('\n'):
        line = re.sub(r'\s+', ' ', raw_line).strip()
        if not line:
            continue
        d = digits(line)

        if len(line) < 90 and HEAD.match(line):
            chapter = line
            heads += 1
            cur = None
            continue

        title = None
        first = ''
        m = ONE.match(d)
        if m:
            title = 'ماده واحده'
            first = line[m.start(1):].strip()
        else:
            m = ART_SEP.match(d)
            if m:
                title = mk_title(m.group(1), m.group(2))
                first = line[m.start(3):].strip()
                if not m.group(2):
                    last = int(m.group(1))
            else:
                m = ART_END.match(d)
                if m:
                    title = mk_title(m.group(1), m.group(2))
                    first = ''
                    if not m.group(2):
                        last = int(m.group(1))
                else:
                    m = ART_LOOSE.match(d)
                    if (m and int(m.group(1)) == last + 1
                            and not m.group(2).startswith('مکرر')):
                        title = mk_title(m.group(1), '')
                        first = line[m.start(2):].strip()
                        last = int(m.group(1))

        if title:
            cur = {'title': title, 'lines': [first] if first else [], 'chapter': chapter}
            articles.append(cur)
        elif cur:
            cur['lines'].append(line)
        else:
            ignored += 1

    out = ['# ' + a.name, '']
    prev = None
    for art in articles:
        if a.chapters and art['chapter'] and art['chapter'] != prev:
            out += ['## ' + art['chapter'], '']
            prev = art['chapter']
        body = '\n'.join(art['lines']).strip()
        out.append(art['title'])
        if body:
            out.append(body)
        out.append('')

    os.makedirs(LAWS_DIR, exist_ok=True)
    dest = os.path.join(LAWS_DIR, a.law_id + '.txt')
    with open(dest, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out).strip() + '\n')

    # ثبت منبع و تاریخ
    meta_path = os.path.join(LAWS_DIR, '_meta.json')
    meta = {}
    if os.path.exists(meta_path):
        try:
            with open(meta_path, encoding='utf-8') as f:
                meta = json.load(f)
        except Exception:
            meta = {}
    meta[a.law_id] = {
        'title': a.name,
        'source': a.source,
        'date': a.date,
        'articles': len(articles),
    }
    with open(meta_path, 'w', encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
        f.write('\n')

    # گزارش
    nums = set()
    seen = set()
    dups = []
    empty = []
    for art in articles:
        m = re.match(r'^ماده (\d+)$', art['title'])
        if m:
            nums.add(int(m.group(1)))
        if art['title'] in seen:
            dups.append(art['title'])
        seen.add(art['title'])
        if not art['lines']:
            empty.append(art['title'])

    print('نوشته شد: assets/laws/%s.txt' % a.law_id)
    print('تعداد ماده:', len(articles))
    print('عنوان فصل/بخش دیده‌شده:', heads)
    if a.chapters:
        print('هشدار: --chapters فقط بعد از به‌روزرسانی موتور برنامه (بخش ۲) استفاده شود.')
    if ignored:
        print('خطوط قبل از اولین ماده (نادیده گرفته شد):', ignored)
    if nums:
        gaps = [i for i in range(1, max(nums) + 1) if i not in nums]
        if gaps:
            print('شمارهٔ ماده‌های جاافتاده (%d مورد): %s%s' % (
                len(gaps), ', '.join(map(str, gaps[:15])), ' ...' if len(gaps) > 15 else ''))
            print('  اگر ماده‌ای منسوخ نشده، متن را بررسی کنید؛ احتمالاً کپی ناقص است.')
        else:
            print('شماره‌گذاری: پیوسته از ۱ تا %d' % max(nums))
    if dups:
        print('عنوان تکراری:', ', '.join(dups[:10]))
    if empty:
        print('مادهٔ بدون متن:', ', '.join(empty[:10]))
    if not articles:
        print('هیچ ماده‌ای پیدا نشد. قالب خطوط باید «ماده ۱ - متن» باشد.')
    else:
        print('نمونه: %s | %s' % (articles[0]['title'], ' '.join(articles[0]['lines'])[:60]))
    if not a.source or not a.date:
        print('یادآوری: منبع و تاریخ را با --source و --date ثبت کنید.')


main()
