"""خوانندهٔ یکتای متنِ قوانین — همان کاری که `library.py` برای کد Dart می‌کند.

پیش از این، `tools/doctor.py` تنها جایی بود که می‌دانست متنِ قانون چگونه بخش
می‌شود: بلوک‌ها با خطِ خالی جدا می‌شوند، خطِ `#` نامِ منبع است، خطِ `##` سرِ
فصل، و خطی مثل `ماده 12` / `ماده 12 مکرر` / `اصل 9` / `ماده واحده` سرِ یک
بخش. اگر ابزارِ دوم (مثل `law_diff.py`) همین را از نو می‌نوشت، دو تعریف از
«ماده» می‌داشتیم و تفاضل‌ها بی‌صدا اشتباه می‌شدند.

پس این تعریف یک‌جا زندگی می‌کند و `doctor.py` و `law_diff.py` هر دو از همین
می‌خوانند.
"""

import re

FA_DIGITS = str.maketrans('۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789')

# «ماده ۱۲»، «ماده ۱۲ مکرر»، «ماده ۱۲ مکرر ۳»، «ماده واحده»، «اصل ۹»
ARTICLE = re.compile(r'^(?:ماده|اصل)\s*(?:(واحده)|(\d+)(?:\s*(مکرر(?:\s*\d{1,2})?))?)\s*$')


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
