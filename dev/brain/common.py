import json
import os
import re

import engine_rules as _ER
import text_norm_rules as _R

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NB = 1 << 17
D = 64

# قاعده‌ها از `dev/tools/contracts/text_norm.json` و `engine_rules.json` تولید
# می‌شوند (`dev/brain/{text_norm_rules,engine_rules}.py`).
# نگاشت و بازه‌ها دیگر دستی نوشته نمی‌شوند.
_MAP = _R.CHAR_MAP
_NONWORD = re.compile(_R.NONWORD_PATTERN)
_OBSOLETE_TRIM = re.compile(_ER.OBSOLETE_TRIM_PATTERN)
NOTE = re.compile(
    r'^\(\s*(?:ماده|توضیح|نکته|تفسیر|شرح)\b|^با\s+حذف\s+این\s+ماده'
    r'|نیز\s+وجود\s+دارد|مطابق\s+آخرین\s+اصلاحات')


def _dropped(o):
    if o in _R.DROP_CODEPOINTS:
        return True
    for lo, hi in _R.DROP_RANGES:
        if lo <= o <= hi:
            return True
    return False


def normalize(s):
    """لایهٔ پایه؛ آینهٔ `PersianText.normalize` در دارت."""
    out = []
    for ch in s:
        o = ord(ch)
        hit = False
        for lo, hi, base in _R.DIGIT_RANGES:
            if lo <= o <= hi:
                out.append(chr(o - base + 48))
                hit = True
                break
        if hit:
            continue
        if o in _R.TO_SPACE_CODEPOINTS:
            out.append(' ')
            continue
        if _dropped(o):
            continue
        out.append(_MAP.get(ch, ch))
    text = ''.join(out)
    return text.lower() if _R.LOWERCASE else text


def norm(s):
    """لایهٔ دوم؛ آینهٔ `Sense.norm` در دارت (یکسان‌سازی + نشانه‌ها + بازنویسی).

    پیش‌تر این ترکیب فقط در دارت بود و ابزارهای پایتون نسخهٔ خودشان را داشتند.
    """
    t = normalize(s)
    t = t.replace(_R.QUESTION_MARK_FROM, _R.QUESTION_MARK_TO)
    if _R.QUESTION_MARK_PAD:
        # دارت «؟» را با فاصلهٔ دو طرف جایگزین می‌کند («کنم ؟»)؛ همان رفتار را
        # نگه می‌داریم تا خروجی دو زبان یکی بماند.
        t = t.replace(_R.QUESTION_MARK_TO, ' %s ' % _R.QUESTION_MARK_TO)
    t = re.sub(_R.NORM_PUNCT, ' ', t)
    t = re.sub(_R.NORM_DOT, ' ', t)
    t = re.sub(r'\s+', ' ', t).strip()
    t = re.sub(_R.NORM_JOIN_MI, lambda m: m.group(1) + m.group(2), t)
    if _R.NORM_PAD:
        t = ' ' + t + ' '
    for pattern, repl in _R.CANON:
        t = re.sub(pattern, repl, t)
    return t


def spaced(s, variant='tools'):
    """نسخهٔ ابزارها: بی‌تبدیل ارقام و بی‌کوچک‌سازی.

    تفاوتِ `tools` و `terms` در قرارداد نوشته شده، نه در دو تابعِ جدا؛ خروجیِ
    هر دو با `tests/text_norm_golden.json` قفل است.
    """
    rule = _R.SPACED[variant]
    chars = []
    for ch in s:
        o = ord(ch)
        if any(lo <= o <= hi for lo, hi in rule['drop']):
            continue
        chars.append(rule['map'].get(ch, ch))
    t = re.sub(rule['punct'], ' ', ''.join(chars))
    t = re.sub(r'\s+', ' ', t).strip()
    return ' ' + t + ' ' if rule['pad'] else t


def words(s):
    return [w for w in _NONWORD.sub(' ', normalize(s)).split(' ') if w]


def fnv(s):
    h = 2166136261
    for ch in s:
        h ^= ord(ch)
        h = (h * 16777619) & 0xFFFFFFFF
    return h


def feats(text, nmin=3, nmax=5):
    """ویژگی‌ها: کلمه و n-gramهای حروفی؛ همین الگوریتم باید در Dart تکرار شود."""
    ids = []
    for w in words(text):
        ids.append(fnv('w:' + w) % NB)
        t = '<' + w + '>'
        for n in range(nmin, nmax + 1):
            for i in range(len(t) - n + 1):
                ids.append(fnv(t[i:i + n]) % NB)
    return ids


def is_obsolete(body):
    n = _OBSOLETE_TRIM.sub('', re.sub(r'\s+', ' ', normalize(body)).strip())
    if len(n) > _ER.OBSOLETE_MAX_LEN:
        return False
    return n.startswith(_ER.OBSOLETE_PREFIXES)


def iter_law_files():
    """فهرست (law_id, fallback_title, full_path) را از _meta.json می‌خواند."""
    laws_dir = os.path.join(ROOT, 'assets', 'laws')
    meta_path = os.path.join(laws_dir, '_meta.json')
    if os.path.isfile(meta_path):
        with open(meta_path, encoding='utf-8') as f:
            meta = json.load(f)
    else:
        meta = {}
    out = []
    for lid, info in sorted(meta.items()):
        if not isinstance(info, dict) or not info.get('path'):
            continue
        full = os.path.join(laws_dir, info['path'])
        if os.path.isfile(full):
            out.append((lid, str(info.get('title', '')).strip(), full))
    return out


def load_articles():
    arts = []
    notes = 0
    obs = 0
    for law, fallback_source, p in iter_law_files():
        with open(p, encoding='utf-8') as f:
            text = f.read().replace('\r', '')
        source = fallback_source
        chapter = ''
        for part in re.split(r'\n\s*\n', text):
            lines = part.strip().split('\n')
            if not lines or not lines[0].strip():
                continue
            first = lines[0].strip()
            if first.startswith('##'):
                chapter = first.lstrip('#').strip()
                continue
            if first.startswith('#'):
                source = first.lstrip('#').strip()
                chapter = ''
                continue
            keep = []
            for l in lines[1:]:
                l = l.strip()
                if not l:
                    continue
                if NOTE.search(normalize(l)):
                    notes += 1
                    continue
                keep.append(l)
            body = '\n'.join(keep)
            if not body:
                continue
            if is_obsolete(body):
                obs += 1
                continue
            arts.append({'law': law, 'source': source, 'chapter': chapter,
                         'title': first, 'body': body})
    print('articles: %d | note lines skipped: %d | obsolete skipped: %d'
          % (len(arts), notes, obs), flush=True)
    return arts
