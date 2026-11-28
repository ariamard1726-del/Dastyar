"""خوانندهٔ یکتای متنِ قوانین — همان کاری که `library.py` برای کد Dart می‌کند.

پیش از این، `dev/tools/doctor.py` تنها جایی بود که می‌دانست متنِ قانون چگونه بخش
می‌شود و ده‌ها ابزار دیگر نیز ارقام فارسی/عربی، خواندن `_meta.json` و نشانه‌های
متن ساختگی (`AI_MARKERS`) را جداگانه کپی کرده بودند.

پس این تعریف‌ها یک‌جا زندگی می‌کنند تا همهٔ ابزارهای `dev/tools/` از همین بخوانند.
"""

import json
import os
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]
LAWS_DIR = ROOT / 'assets' / 'laws'
META_PATH = LAWS_DIR / '_meta.json'

FA = '\u06f0\u06f1\u06f2\u06f3\u06f4\u06f5\u06f6\u06f7\u06f8\u06f9'
AR = '\u0660\u0661\u0662\u0663\u0664\u0665\u0666\u0667\u0668\u0669'
FA_DIGITS = str.maketrans(FA + AR, '0123456789' * 2)
TO_FA = str.maketrans('0123456789' + AR, FA * 2)

# نشانهٔ متنی که ممکن است با هوش مصنوعی نوشته شده باشد، نه از منبع رسمی.
AI_MARKERS = (
    'هوش مصنوعی', 'تولید شده توسط', 'تولیدشده توسط', 'این متن توسط',
    'chatgpt', 'gemini', 'claude', 'as an ai', 'language model',
)

# «ماده ۱۲»، «ماده ۱۲ مکرر»، «ماده ۱۲ مکرر ۳»، «ماده واحده»، «اصل ۹»
ARTICLE = re.compile(r'^(?:ماده|اصل)\s*(?:(واحده)|(\d+)(?:\s*(مکرر(?:\s*\d{1,2})?))?)\s*$')


def digits(s):
    """تبدیل ارقام فارسی و عربی به لاتین."""
    return str(s).translate(FA_DIGITS)


def to_fa(s):
    """تبدیل ارقام لاتین و عربی به فارسی."""
    return str(s).translate(TO_FA)


def load_meta(path=None, root=None):
    """خواندن فهرست شناسنامهٔ قوانین (`assets/laws/_meta.json`)."""
    p = Path(path) if path else (Path(root) / 'assets' / 'laws' / '_meta.json' if root else META_PATH)
    with open(p, encoding='utf-8') as f:
        return json.load(f)


def law_files(meta=None, root=None):
    """{شناسه: Path} برای تمام فایل‌های قانون ثبت‌شده در `_meta.json`."""
    base = Path(root) if root else ROOT
    data = meta if meta is not None else load_meta(root=base)
    return {
        k: base / 'assets' / 'laws' / v['path']
        for k, v in data.items()
        if isinstance(v, dict) and v.get('path')
    }


def norm(s):
    """یکسان‌سازی برای مقایسه: رقمِ فارسی، ي/ك عربی، نویسه‌های بی‌عرض، فاصله‌ها."""
    s = s.translate(FA_DIGITS).replace('ي', 'ی').replace('ك', 'ک')
    s = re.sub('[\u200c\u200d\u200e\u200f]', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()


def parse(text):
    """[(عنوانِ بخش، متن، منبع)] — مثل `_parse` در engine.dart."""
    source, blocks = '', []
    for chunk in re.split(r'\n\s*\n', text.replace('\r', '')):
        lines = chunk.strip().split('\n')
        if not lines or not lines[0].strip():
            continue
        first = lines[0].strip()
        if first.startswith('##'):
            continue
        if first.startswith('#'):
            source = first.lstrip('#').strip()
            continue
        body = '\n'.join(lines[1:]).strip() if len(lines) > 1 else first
        blocks.append((first, body, source))
    return blocks


def is_article(title):
    return bool(ARTICLE.match(norm(title)))


def block_key(title):
    """کلیدِ پایدارِ یک بخش: «ماده 3 مکرر» برای مواد، وگرنه «یادداشت: …».

    کلیدها یکتا می‌شوند تا دو مادهٔ هم‌شماره یکی نشوند و تفاضل ماده‌ای گم نشود.
    """
    t = norm(title)
    m = ARTICLE.match(t)
    if m:
        if m.group(1):
            return 'ماده واحده'
        kind = 'اصل' if t.startswith('اصل') else 'ماده'
        key = '%s %s' % (kind, m.group(2))
        if m.group(3):
            key += ' ' + norm(m.group(3))
        return key
    return 'یادداشت: ' + t[:80]


def articles_of(text):
    """{کلید: متن} برای همهٔ بخش‌ها؛ یادداشت‌ها هم کلید دارند تا دیده شوند."""
    out, seen = {}, {}
    for first, body, _source in parse(text):
        key = block_key(first)
        if key in seen:
            seen[key] += 1
            key = '%s #%d' % (key, seen[key])
        else:
            seen[key] = 1
        out[key] = body
    return out
