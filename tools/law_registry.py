#!/usr/bin/env python3
"""شناسنامهٔ منبع قوانین (assets/laws/_meta.json).

هر قانون باید این فیلدها را داشته باشد:
  title     نام رسمی قانون
  source    نام ناشر متن (فارسی)
  url       نشانی دقیق همان صفحه‌ای که متن از آن گرفته شده
  date      تاریخ دریافت متن، به شکل ۱۴۰۵/۰۸/۱۰ (ارقام فارسی)
  amended   تاریخ آخرین اصلاحِ قانون طبق همان منبع (ارقام فارسی)
  articles  تعداد بخش‌های فایل
  path      مسیر فایل زیر assets/laws
  sha256    اثر انگشت بایت‌های فایل؛ با هر تغییرِ متن عوض می‌شود
  status    verified   = متن ماده‌به‌ماده با منبع رسمی تطبیق داده شده
            unverified = هنوز تطبیق داده نشده (در برنامه با برچسب نشان داده می‌شود)

«verified» را فقط دستور verify همین ابزار می‌نویسد، آن هم وقتی متنِ خامِ
برداشته‌شده از منبع رسمی با متن داخل برنامه هیچ اختلافی نداشته باشد.

دستورها:
  python3 tools/law_registry.py status
  python3 tools/law_registry.py stamp
      اثر انگشت همهٔ فایل‌ها را تازه می‌کند. اگر متن یک قانونِ تأییدشده عوض
      شده باشد، وضعیتش به unverified برمی‌گردد.
  python3 tools/law_registry.py verify ID --url URL --raw FILE --amended ۱۴۰۳/۰۳/۳۰
      FILE متنی است که از صفحهٔ URL در منبع رسمی کپی شده. اگر با متن برنامه
      یکی بود، قانون verified می‌شود؛ وگرنه فهرست اختلاف‌ها چاپ می‌شود و چیزی
      عوض نمی‌شود. با --report PATH گزارش کامل اختلاف‌ها در فایل نوشته می‌شود.
  python3 tools/law_registry.py check [--require-verified]
      همان بررسی‌ای که tools/check.py meta اجرا می‌کند.
"""
import argparse
import datetime
import hashlib
import json
import os
import re
import sys
from urllib.parse import urlparse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAWS_DIR = os.path.join(ROOT, 'assets', 'laws')
META = os.path.join(LAWS_DIR, '_meta.json')

REQUIRED = ('title', 'source', 'url', 'date', 'amended', 'articles', 'path',
            'sha256', 'status')
STATUSES = ('verified', 'unverified')

# منبع‌هایی که «رسمی» حساب می‌شوند. فقط با یکی از این‌ها می‌شود verified شد.
OFFICIAL_HOSTS = {
    'qavanin.ir': 'سامانه ملی قوانین و مقررات جمهوری اسلامی ایران',
    'rrk.ir': 'روزنامه رسمی جمهوری اسلامی ایران',
    'dotic.ir': 'معاونت تدوین، تنقیح و انتشار قوانین و مقررات',
    'rc.majlis.ir': 'مرکز پژوهش‌های مجلس شورای اسلامی',
}

FA = '۰۱۲۳۴۵۶۷۸۹'
AR = '٠١٢٣٤٥٦٧٨٩'
DATE_FA = re.compile(r'^[۰-۹]{4}/[۰-۹]{2}/[۰-۹]{2}$')
PERSIAN = re.compile(r'[\u0600-\u06FF]')
SHELL = re.compile(
    r'(\bgit\b|\bpython3?\b|\bcat\b|\bnano\b|\btail\b|\bgrep\b|\bpush\b|'
    r'\bcommit\b|\bcd\b|[|$><]|--|\.py\b|\.txt\b|\.json\b)',
    re.IGNORECASE,
)
SHA = re.compile(r'^[0-9a-f]{64}$')


# ------------------------------------------------------------------ پایه
def to_latin(s):
    return s.translate(str.maketrans(FA + AR, '0123456789' * 2))


def to_fa(s):
    return s.translate(str.maketrans('0123456789' + AR, FA * 2))


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for block in iter(lambda: f.read(65536), b''):
            h.update(block)
    return h.hexdigest()


def host_of(url):
    try:
        host = (urlparse(url).hostname or '').lower()
    except ValueError:
        return ''
    return host[4:] if host.startswith('www.') else host


def official_host(url):
    """نام میزبان رسمی، اگر نشانی https و از فهرست منابع رسمی باشد."""
    if not url.startswith('https://'):
        return ''
    host = host_of(url)
    for known in OFFICIAL_HOSTS:
        if host == known or host.endswith('.' + known):
            return known
    return ''


def jalali(d):
    """تاریخ میلادی را به هجری شمسی برمی‌گرداند: (سال، ماه، روز)."""
    gy, gm, gd = d.year, d.month, d.day
    g_d_m = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
    gy2 = gy + 1 if gm > 2 else gy
    days = (355666 + 365 * gy + (gy2 + 3) // 4 - (gy2 + 99) // 100
            + (gy2 + 399) // 400 + gd + g_d_m[gm - 1])
    jy = -1595 + 33 * (days // 12053)
    days %= 12053
    jy += 4 * (days // 1461)
    days %= 1461
    if days > 365:
        jy += (days - 1) // 365
        days = (days - 1) % 365
    if days < 186:
        jm, jd = 1 + days // 31, 1 + days % 31
    else:
        jm, jd = 7 + (days - 186) // 30, 1 + (days - 186) % 30
    return jy, jm, jd


def today_fa():
    y, m, d = jalali(datetime.date.today())
    return to_fa('%04d/%02d/%02d' % (y, m, d))


def load_meta(path=None):
    with open(path or META, encoding='utf-8') as f:
        return json.load(f)


def save_meta(meta, path=None):
    with open(path or META, 'w', encoding='utf-8') as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
        f.write('\n')


# ------------------------------------------------------- خواندن و مقایسه
_UNIFY = str.maketrans({
    'ي': 'ی', 'ى': 'ی', 'ئ': 'ی', 'ك': 'ک', 'ة': 'ه', 'ۀ': 'ه',
    'أ': 'ا', 'إ': 'ا', 'ؤ': 'و',
})
_DROP = re.compile(r'[\u064B-\u0652\u0654\u0655\u0670\u0640\u200c\u200d\u200e\u200f\ufeff]')
_NOT_WORD = re.compile(r'[^0-9A-Za-z\u0600-\u06FF]+')

MARK = re.compile(
    r'^\s*(ماده|اصل)\s*([0-9۰-۹٠-٩]+)\s*(مکرر\s*[0-9۰-۹٠-٩]*)?[\s\u200c]*(?:[-–—\u0640:)(.]|$)')
SINGLE = re.compile(r'^\s*ماده\s*واحده[\s\u200c]*(?:[-–—\u0640:)(.]|$)')
HEADING = re.compile(
    r'^\s*(?:#|(?:کتاب|باب|بخش|فصل|مبحث|قسمت|گفتار|فقره)\s.{0,90}$)')


def canon(text):
    """متن را برای مقایسه یکدست می‌کند: فقط حرف و رقم می‌ماند.

    تفاوت‌های نگارشی (فاصله، نیم‌فاصله، ي/ی، ك/ک، اعراب، کشیده، نقطه‌گذاری)
    نادیده گرفته می‌شود؛ هر تفاوتی در واژه یا عدد دیده می‌شود.
    """
    t = to_latin(text).translate(_UNIFY)
    t = _DROP.sub('', t)
    return _NOT_WORD.sub('', t)


def parse_articles(text):
    """متن یک قانون را به ماده‌ها می‌شکند: فهرستِ (کلید، متن).

    هم قالب برنامه را می‌خواند («ماده 5» روی یک خط جدا) هم متن خامی که از
    سایت کپی شده («ماده 5 - …»، «ماده 5 ) …»). عنوان باب و فصل جزو متن ماده
    حساب نمی‌شود. کلید تکراری (شماره‌گذاری دوباره در یک قانون) با #۲، #۳
    جدا می‌شود.
    """
    text = text.replace('\r', '').replace('\u00a0', ' ')
    text = text.translate(str.maketrans({'ي': 'ی', 'ك': 'ک'}))
    out = []
    seen = {}
    cur = None

    def start(key, rest):
        nonlocal cur
        seen[key] = seen.get(key, 0) + 1
        if seen[key] > 1:
            key = '%s #%d' % (key, seen[key])
        cur = [key, [rest] if rest else []]
        out.append(cur)

    for line in text.split('\n'):
        s = line.strip()
        if not s:
            continue
        m = MARK.match(s)
        if m:
            extra = ''
            if m.group(3):
                extra = ' ' + re.sub(r'\s+', ' ', to_latin(m.group(3).strip()))
            key = '%s %s%s' % (m.group(1), to_latin(m.group(2)), extra)
            start(key, s[m.end():].strip())
            continue
        m = SINGLE.match(s)
        if m:
            start('ماده واحده', s[m.end():].strip())
            continue
        if HEADING.match(s):
            continue
        if cur is not None:
            cur[1].append(s)
    return [(k, '\n'.join(lines)) for k, lines in out]


def glued_articles(text):
    """ماده‌هایی که سرِ خط جدا ندارند و به متن مادهٔ قبلی چسبیده‌اند.

    در قالب برنامه هر ماده با یک خط خالی جدا می‌شود؛ اگر وسط متن یک ماده
    خطی با «ماده N -» شروع شود، آن ماده در جستجو جدا پیدا نمی‌شود (یا دو نسخه
    از آن در فایل هست). فهرستِ (مادهٔ میزبان، مادهٔ چسبیده) برمی‌گردد.
    """
    out = []
    text = text.replace('\r', '')
    for part in re.split(r'\n\s*\n', text):
        lines = [l.strip() for l in part.strip().split('\n') if l.strip()]
        if not lines or lines[0].startswith('#'):
            continue
        host = to_latin(lines[0])
        for l in lines[1:]:
            m = MARK.match(l)
            if m:
                out.append((host, '%s %s' % (m.group(1), to_latin(m.group(2)))))
    return out


def _first_diff(a, b, width=45):
    i = 0
    n = min(len(a), len(b))
    while i < n and a[i] == b[i]:
        i += 1
    lo = max(0, i - 15)
    return a[lo:i + width], b[lo:i + width]


def compare(bundled_text, official_text):
    """متن برنامه را با متن منبع رسمی ماده‌به‌ماده می‌سنجد."""
    ours = parse_articles(bundled_text)
    theirs = parse_articles(official_text)
    our_map = dict(ours)
    their_map = dict(theirs)
    missing = [k for k, _ in theirs if k not in our_map]
    extra = [k for k, _ in ours if k not in their_map]
    different = []
    same = 0
    for k, body in ours:
        if k not in their_map:
            continue
        a, b = canon(body), canon(their_map[k])
        if a == b:
            same += 1
        else:
            mine, official = _first_diff(a, b)
            different.append({'key': k, 'ours': mine, 'official': official})
    return {
        'ours': len(ours),
        'official': len(theirs),
        'same': same,
        'missing': missing,
        'extra': extra,
        'different': different,
    }


def is_identical(result):
    return (result['official'] > 0 and not result['missing']
            and not result['extra'] and not result['different'])


# ------------------------------------------------------------ اعتبارسنجی
def validate(meta, laws_dir=None, require_verified=False):
    """(خطاها، هشدارها، تعداد تأییدشده) را برمی‌گرداند."""
    laws_dir = laws_dir or LAWS_DIR
    errors = []
    warnings = []
    verified = 0
    for lid, info in meta.items():
        if not isinstance(info, dict):
            errors.append('%s: ساختار نادرست' % lid)
            continue
        absent = [k for k in REQUIRED if k not in info]
        if absent:
            errors.append('%s: فیلد لازم وجود ندارد: %s' % (lid, '، '.join(absent)))
            continue

        for key in ('title', 'source', 'date', 'path', 'sha256', 'status'):
            if not str(info.get(key, '')).strip():
                errors.append('%s: فیلد %s خالی است' % (lid, key))

        src = str(info['source']).strip()
        if src:
            if SHELL.search(src):
                errors.append('%s: منبع شبیه دستور ترمینال است: %s' % (lid, src))
            elif not PERSIAN.search(src):
                errors.append('%s: منبع باید نام فارسی سازمان یا سایت باشد: %s' % (lid, src))

        date = str(info['date']).strip()
        if date and not DATE_FA.match(date):
            errors.append('%s: date باید با ارقام فارسی و به شکل ۱۴۰۵/۰۸/۰۲ باشد: %s' % (lid, date))
        amended = str(info['amended']).strip()
        if amended and not DATE_FA.match(amended):
            errors.append('%s: amended باید با ارقام فارسی و به شکل ۱۴۰۵/۰۸/۰۲ باشد: %s' % (lid, amended))

        if not isinstance(info['articles'], int) or info['articles'] <= 0:
            errors.append('%s: articles باید عدد صحیح مثبت باشد' % lid)

        status = str(info['status']).strip()
        if status and status not in STATUSES:
            errors.append('%s: status باید verified یا unverified باشد: %s' % (lid, status))

        sha = str(info['sha256']).strip()
        path = os.path.normpath(os.path.join(laws_dir, str(info['path'])))
        if sha and not SHA.match(sha):
            errors.append('%s: sha256 باید ۶۴ رقم شانزده‌شانزدهی باشد' % lid)
        elif not os.path.isfile(path):
            errors.append('%s: فایل %s وجود ندارد' % (lid, info['path']))
        elif sha and sha256_of(path) != sha:
            errors.append(
                '%s: متن فایل با sha256 ثبت‌شده نمی‌خواند (متن عوض شده). '
                'اجرا: python3 tools/law_registry.py stamp و سپس تطبیق دوباره با منبع' % lid)

        url = str(info['url']).strip()
        if url and not url.startswith('https://'):
            errors.append('%s: url باید با https:// شروع شود: %s' % (lid, url))

        if status == 'verified':
            verified += 1
            if not official_host(url):
                errors.append(
                    '%s: قانون verified باید url از منبع رسمی داشته باشد (%s)'
                    % (lid, '، '.join(sorted(OFFICIAL_HOSTS))))
            if 'اختبار' in src:
                errors.append('%s: «اختبار» منبع رسمی نیست و نمی‌تواند verified باشد' % lid)
            if not amended:
                errors.append('%s: قانون verified باید تاریخ آخرین اصلاح (amended) داشته باشد' % lid)
        elif status == 'unverified':
            msg = '%s: هنوز با منبع رسمی تطبیق داده نشده است' % lid
            (errors if require_verified else warnings).append(msg)
    return errors, warnings, verified


# -------------------------------------------------------------- دستورها
def cmd_status(_args):
    meta = load_meta()
    done = 0
    for lid, info in meta.items():
        ok = info.get('status') == 'verified'
        done += 1 if ok else 0
        print('%s %-22s %s | %s | %s' % (
            '✅' if ok else '⬜', lid, info.get('title', ''),
            info.get('source', ''), info.get('url', '') or 'بدون نشانی'))
    print('\nتطبیق‌شده با منبع رسمی: %d از %d' % (done, len(meta)))
    for lid, info in meta.items():
        path = os.path.normpath(os.path.join(LAWS_DIR, str(info.get('path', ''))))
        if not os.path.isfile(path):
            continue
        with open(path, encoding='utf-8') as f:
            for host, inner in glued_articles(f.read()):
                print('هشدار ساختاری: %s: «%s» به متن «%s» چسبیده است' % (lid, inner, host))
    return 0


def cmd_stamp(_args):
    meta = load_meta()
    changed = []
    for lid, info in meta.items():
        path = os.path.normpath(os.path.join(LAWS_DIR, str(info.get('path', ''))))
        if not os.path.isfile(path):
            print('خطا: %s: فایل %s وجود ندارد' % (lid, info.get('path')))
            return 1
        sha = sha256_of(path)
        if info.get('sha256') != sha:
            if info.get('sha256') and info.get('status') == 'verified':
                info['status'] = 'unverified'
                print('توجه: متن %s عوض شده؛ وضعیت به unverified برگشت.' % lid)
            info['sha256'] = sha
            changed.append(lid)
        info.setdefault('url', '')
        info.setdefault('status', 'unverified')
    save_meta(meta)
    print('stamp: %d اثر انگشت تازه شد%s' % (
        len(changed), (': ' + '، '.join(changed)) if changed else '.'))
    return 0


def write_report(path, lid, url, result):
    lines = ['# گزارش تطبیق %s' % lid, '', 'منبع: %s' % url, '',
             'ماده‌های برنامه: %d | ماده‌های منبع: %d | یکسان: %d' % (
                 result['ours'], result['official'], result['same']), '']
    if result['missing']:
        lines += ['## در منبع هست، در برنامه نیست', ''] + [
            '- %s' % k for k in result['missing']] + ['']
    if result['extra']:
        lines += ['## در برنامه هست، در منبع نیست', ''] + [
            '- %s' % k for k in result['extra']] + ['']
    if result['different']:
        lines += ['## متن متفاوت (اولین جای اختلاف، بدون فاصله و نقطه‌گذاری)', '']
        for d in result['different']:
            lines += ['- %s' % d['key'], '  - برنامه: %s' % d['ours'],
                      '  - منبع:   %s' % d['official']]
        lines.append('')
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines))


def cmd_verify(args):
    meta = load_meta()
    info = meta.get(args.id)
    if not isinstance(info, dict):
        print('خطا: قانونی با شناسهٔ %s در _meta.json نیست.' % args.id)
        return 1
    host = official_host(args.url)
    if not host:
        print('خطا: نشانی باید https و از یکی از منابع رسمی باشد: %s'
              % '، '.join(sorted(OFFICIAL_HOSTS)))
        return 1
    amended = to_fa(args.amended.strip())
    if not DATE_FA.match(amended):
        print('خطا: --amended باید تاریخ آخرین اصلاح به شکل ۱۴۰۳/۰۳/۳۰ باشد.')
        return 1
    date = to_fa(args.date.strip()) if args.date else today_fa()
    if not DATE_FA.match(date):
        print('خطا: --date باید به شکل ۱۴۰۵/۰۸/۱۰ باشد.')
        return 1
    path = os.path.normpath(os.path.join(LAWS_DIR, str(info.get('path', ''))))
    with open(path, encoding='utf-8') as f:
        bundled = f.read()
    with open(args.raw, encoding='utf-8') as f:
        official = f.read()

    result = compare(bundled, official)
    print('ماده‌های برنامه: %d | ماده‌های منبع: %d | یکسان: %d' % (
        result['ours'], result['official'], result['same']))
    if args.report:
        write_report(args.report, args.id, args.url, result)
        print('گزارش کامل: %s' % args.report)
    if not is_identical(result):
        if result['official'] == 0:
            print('خطا: در فایل خام هیچ ماده‌ای پیدا نشد؛ متن صفحه را کامل کپی کنید.')
        for label, keys in (('در منبع هست، در برنامه نیست', result['missing']),
                            ('در برنامه هست، در منبع نیست', result['extra'])):
            if keys:
                print('%s (%d): %s%s' % (label, len(keys), '، '.join(keys[:12]),
                                         ' …' if len(keys) > 12 else ''))
        if result['different']:
            print('متن متفاوت (%d):' % len(result['different']))
            for d in result['different'][:12]:
                print('  %s\n    برنامه: %s\n    منبع:   %s' % (
                    d['key'], d['ours'], d['official']))
            if len(result['different']) > 12:
                print('  … و %d مادهٔ دیگر' % (len(result['different']) - 12))
        print('نتیجه: یکسان نیست؛ وضعیت %s تغییر نکرد.' % args.id)
        return 1

    info['source'] = OFFICIAL_HOSTS[host]
    info['url'] = args.url
    info['date'] = date
    info['amended'] = amended
    info['sha256'] = sha256_of(path)
    info['status'] = 'verified'
    info.pop('note', None)
    save_meta(meta)
    print('نتیجه: %s ماده‌به‌ماده با منبع یکی است و verified شد.' % args.id)
    return 0


def cmd_check(args):
    meta = load_meta()
    errors, warnings, verified = validate(
        meta, require_verified=args.require_verified)
    for e in errors:
        print('خطا:', e)
    print('تطبیق‌شده با منبع رسمی: %d از %d' % (verified, len(meta)))
    return 1 if errors else 0


def main(argv=None):
    ap = argparse.ArgumentParser(description='شناسنامهٔ منبع قوانین')
    sub = ap.add_subparsers(dest='cmd', required=True)
    sub.add_parser('status')
    sub.add_parser('stamp')
    v = sub.add_parser('verify')
    v.add_argument('id')
    v.add_argument('--url', required=True)
    v.add_argument('--raw', required=True)
    v.add_argument('--amended', required=True)
    v.add_argument('--date', default='')
    v.add_argument('--report', default='')
    c = sub.add_parser('check')
    c.add_argument('--require-verified', action='store_true')
    args = ap.parse_args(argv)
    return {'status': cmd_status, 'stamp': cmd_stamp, 'verify': cmd_verify,
            'check': cmd_check}[args.cmd](args)


if __name__ == '__main__':
    sys.exit(main())
