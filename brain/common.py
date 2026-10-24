import glob
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NB = 1 << 17
D = 64

_MAP = {'ي': 'ی', 'ى': 'ی', 'ك': 'ک', 'ۀ': 'ه', 'ة': 'ه', 'أ': 'ا', 'إ': 'ا', 'ٱ': 'ا'}
_NONWORD = re.compile(
    r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+')
NOTE = re.compile(
    r'^\(\s*(?:ماده|توضیح|نکته|تفسیر|شرح)\b|^با\s+حذف\s+این\s+ماده'
    r'|نیز\s+وجود\s+دارد|مطابق\s+آخرین\s+اصلاحات')


def normalize(s):
    out = []
    for ch in s:
        o = ord(ch)
        if 0x06F0 <= o <= 0x06F9:
            out.append(chr(o - 0x06F0 + 48))
            continue
        if 0x0660 <= o <= 0x0669:
            out.append(chr(o - 0x0660 + 48))
            continue
        if o in (0x200C, 0x200D, 0x200E, 0x200F):
            out.append(' ')
            continue
        if 0x064B <= o <= 0x065F or o == 0x0640:
            continue
        out.append(_MAP.get(ch, ch))
    return ''.join(out).lower()


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
    n = re.sub(r'\s+', ' ', normalize(body)).strip().lstrip('([ ')
    if len(n) > 300:
        return False
    return n.startswith(('منسوخ', 'ملغی', 'ملغا', 'حذف شد'))


def load_articles():
    arts = []
    notes = 0
    obs = 0
    for p in sorted(glob.glob(os.path.join(ROOT, 'assets', 'laws', '*.txt'))):
        law = os.path.basename(p)[:-4]
        with open(p, encoding='utf-8') as f:
            text = f.read().replace('\r', '')
        source = ''
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
