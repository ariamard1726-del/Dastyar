"""بررسی یکپارچهٔ داده‌ها و دارایی‌های پروژه (جایگزین check.py/check_assets.py/check_meta.py/check_intent.py).

زیردستورها:
  corpus   قالب‌ها + متن قوانین + ثبت بودنشان در _meta.json (بررسی قدیمی check.py)
  assets   پوشش دارایی‌ها در pubspec.yaml (با --fix اصلاح می‌کند)
  meta     اعتبار فیلدهای _meta.json + تازگی مشتق‌ها (laws_catalog.json و data_info.json)
  intent   اعتبار و دقت مدل نیت (assets/brain/intent_model.json)
  parity   تازگی استاندارد طلایی برابری پایتون↔دارت (brain/parity_expected.json)
  all      همهٔ موارد بالا (پیش‌فرض)

اجرا: python3 tools/check.py [زیردستور] [--strict] [--fix]
با STRICT=1 یا --strict خالی‌بودن منبع و تاریخ قانون «خطا» می‌شود، نه هشدار.
"""
import base64
import glob
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'brain'))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import fnv, normalize  # noqa: E402  (آینهٔ PersianText در دارت)

LAWS_DIR = os.path.join(ROOT, 'assets', 'laws')
TYPES = {'text', 'multiline', 'number', 'choice', 'check'}

STRICT = os.environ.get('STRICT') == '1' or '--strict' in sys.argv

# نشانهٔ متنی که ممکن است با هوش مصنوعی نوشته شده باشد، نه از منبع رسمی.
AI_MARKERS = [
    'هوش مصنوعی', 'تولید شده توسط', 'تولیدشده توسط', 'این متن توسط',
    'chatgpt', 'gemini', 'claude', 'as an ai', 'language model',
]


def digits(s):
    return s.translate(str.maketrans('۰۱۲۳۴۵۶۷۸۹٠١٢٣٤٥٦٧٨٩', '01234567890123456789'))


# ---------------------------------------------------------------- corpus
def cmd_corpus():
    errors = []
    warnings = []

    try:
        with open(os.path.join(LAWS_DIR, '_meta.json'), encoding='utf-8') as _f:
            META = json.load(_f)
    except Exception as _e:
        META = {}
        errors.append('_meta.json: %s' % _e)

    def check_template(path):
        name = os.path.basename(path)
        try:
            with open(path, encoding='utf-8') as f:
                t = json.load(f)
        except Exception as e:
            errors.append('%s: JSON خراب است (%s)' % (name, e))
            return
        for k in ('id', 'title', 'fields', 'body'):
            if k not in t:
                errors.append('%s: کلید %s وجود ندارد' % (name, k))
                return
        ids = []
        for f in t['fields']:
            fid = f.get('id')
            if not fid:
                errors.append('%s: یک فیلد بدون id' % name)
                continue
            if fid in ids:
                errors.append('%s: id تکراری: %s' % (name, fid))
            ids.append(fid)
            ft = f.get('type', 'text')
            if ft not in TYPES:
                errors.append('%s: نوع نامعتبر برای %s: %s' % (name, fid, ft))
            if ft == 'choice' and not f.get('options'):
                errors.append('%s: فیلد گزینه‌ای %s گزینه ندارد' % (name, fid))
        body = t['body']
        if isinstance(body, list):
            body = '\n'.join(str(x) for x in body)
        opens = len(re.findall(r'\{\{\s*#if\s+\w+\s*\}\}', body))
        closes = len(re.findall(r'\{\{\s*/if\s*\}\}', body))
        if opens != closes:
            errors.append('%s: تعداد #if (%d) و /if (%d) برابر نیست' % (name, opens, closes))
        used = set(re.findall(r'\{\{\s*#if\s+(\w+)\s*\}\}', body))
        for m in re.finditer(r'\{\{\s*(\w+)(?:\|\w+)?\s*\}\}', body):
            if m.group(1) != 'else':
                used.add(m.group(1))
        bad = used - set(ids)
        if bad:
            errors.append('%s: جای‌نگهدار تعریف‌نشده: %s' % (name, ', '.join(sorted(bad))))
        for r in t.get('lawRefs', []):
            if not str(r.get('law', '')).strip() or not str(r.get('article', '')).strip():
                errors.append('%s: یک lawRefs بدون law یا article' % name)
        if not t.get('reviewed'):
            warnings.append('%s: بازبینی‌نشده' % name)
        print('قالب %s: %d فیلد' % (name, len(ids)))

    def check_law(lid, path):
        rel_name = os.path.relpath(path, LAWS_DIR)
        if not os.path.isfile(path):
            errors.append('%s: فایل %s وجود ندارد' % (lid, rel_name))
            return
        with open(path, encoding='utf-8') as f:
            text = f.read().replace('\r', '')
        parts = [p.strip() for p in re.split(r'\n\s*\n', text) if p.strip()]
        if not parts:
            warnings.append('%s: فایل خالی است' % rel_name)
            return
        if not parts[0].startswith('#'):
            errors.append('%s: خط اول باید با # و نام قانون شروع شود' % rel_name)
        seen = set()
        n = 0
        for p in parts:
            if p.startswith('#'):
                continue
            lines = p.split('\n')
            title = digits(lines[0]).strip()
            n += 1
            if not (title.startswith('ماده') or title.startswith('اصل')):
                warnings.append('%s: بخشی بدون عنوان ماده/اصل: %s' % (rel_name, title[:30]))
            if title in seen:
                warnings.append('%s: عنوان تکراری: %s' % (rel_name, title))
            seen.add(title)
            if len(lines) < 2:
                warnings.append('%s: %s بدون متن است' % (rel_name, title))
        print('قانون %s (%s): %d بخش' % (lid, os.path.basename(path), n))

        low = text.lower()
        for m in AI_MARKERS:
            if m in low:
                errors.append('%s: عبارت مشکوک به متن تولیدشده با هوش مصنوعی: «%s»' % (rel_name, m))

        info = META.get(lid) if lid else None
        if not isinstance(info, dict):
            errors.append('%s: در _meta.json ثبت نشده' % rel_name)
            return
        problems = []
        if not str(info.get('source', '')).strip():
            problems.append('منبع (source) خالی است')
        if not str(info.get('date', '')).strip():
            problems.append('تاریخ (date) خالی است')
        for pr in problems:
            msg = '%s: %s' % (lid, pr)
            (errors if STRICT else warnings).append(msg)
        want = info.get('articles')
        if isinstance(want, int) and want != n:
            warnings.append('%s: در _meta.json %d ماده نوشته شده ولی %d بخش خوانده شد' % (lid, want, n))

    for p in sorted(glob.glob(os.path.join(ROOT, 'assets', 'templates', '*.json'))):
        check_template(p)

    checked_paths = set()
    for lid, info in sorted(META.items()):
        if not isinstance(info, dict) or not info.get('path'):
            errors.append('%s: کلید path در _meta.json وجود ندارد' % lid)
            continue
        full = os.path.normpath(os.path.join(LAWS_DIR, info['path']))
        checked_paths.add(full)
        check_law(lid, full)

    for root, _dirs, files in os.walk(LAWS_DIR):
        for fn in sorted(files):
            if not fn.endswith('.txt'):
                continue
            full = os.path.normpath(os.path.join(root, fn))
            if full not in checked_paths:
                check_law(None, full)

    info_path = os.path.join(ROOT, 'assets', 'data_info.json')
    try:
        with open(info_path, encoding='utf-8') as f:
            json.load(f)
    except Exception as e:
        errors.append('data_info.json: %s' % e)

    for w in warnings:
        print('هشدار:', w)
    for e in errors:
        print('خطا:', e)
    if errors:
        print('نتیجه: %d خطا؛ پوش نکنید.' % len(errors))
        return 1
    print('نتیجه: همه چیز درست است.')
    return 0


# ---------------------------------------------------------------- assets
def cmd_assets():
    fix = '--fix' in sys.argv
    P = os.path.join(ROOT, 'pubspec.yaml')
    L = open(P, encoding='utf-8').read().split('\n')
    ents = [m.group(1) for l in L for m in [re.match(r'^    - (\S+)\s*$', l)] if m]
    files = {e for e in ents if not e.endswith('/')}
    need = []
    for d, _, fs in os.walk(os.path.join(ROOT, 'assets')):
        rel = os.path.relpath(d, ROOT).replace(os.sep, '/')
        if fs and not all(rel + '/' + x in files for x in fs):
            need.append(rel + '/')
    need.sort()
    miss = [d for d in need if d not in ents]
    if not miss:
        print('assets OK:', len(need), 'folders')
        return 0
    print('NOT bundled:', *miss, sep='\n  ')
    if not fix:
        return 1
    out, skip = [], False
    for l in L:
        if skip and re.match(r'^    - ', l):
            continue
        skip = False
        out.append(l)
        if re.match(r'^  assets:\s*$', l):
            out += ['    - ' + e for e in sorted(files)] + ['    - ' + d for d in need]
            skip = True
    open(P, 'w', encoding='utf-8').write('\n'.join(out))
    print('fixed')
    return 0


# ---------------------------------------------------------------- meta
def cmd_meta():
    P = os.path.join(LAWS_DIR, '_meta.json')
    DATE = re.compile(r'^[0-9۰-۹]{4}/[0-9۰-۹]{1,2}/[0-9۰-۹]{1,2}$')
    PERSIAN = re.compile(r'[\u0600-\u06FF]')
    SHELL = re.compile(
        r'(\bgit\b|\bpython3?\b|\bcat\b|\bnano\b|\btail\b|\bgrep\b|\bpush\b|'
        r'\bcommit\b|\bcd\b|[|$><]|--|\.py\b|\.txt\b|\.json\b)',
        re.IGNORECASE,
    )

    errors = []
    with open(P, encoding='utf-8') as f:
        meta = json.load(f)

    for lid, info in meta.items():
        if not isinstance(info, dict):
            errors.append('%s: ساختار نادرست' % lid)
            continue
        src = str(info.get('source', '')).strip()
        if src:
            if SHELL.search(src):
                errors.append('%s: منبع شبیه دستور ترمینال است: %s' % (lid, src))
            elif not PERSIAN.search(src):
                errors.append('%s: منبع باید نام فارسی سازمان یا سایت باشد: %s' % (lid, src))
        for key in ('date', 'amended'):
            v = str(info.get(key, '')).strip()
            if v and not DATE.match(v):
                errors.append('%s: %s باید به شکل ۱۴۰۵/۰۸/۰۲ باشد: %s' % (lid, key, v))

    for e in errors:
        print('خطا:', e)
    if errors:
        print('نتیجه: %d خطا در _meta.json؛ پوش نکنید.' % len(errors))
        return 1
    print('_meta.json درست است.')

    # تازگی مشتق‌ها: عنوان‌های کاتالوگ و data_info باید از _meta.json مشتق شده باشند.
    import sync_meta
    return sync_meta.main()


# ---------------------------------------------------------------- intent
INTENT_MODEL = os.path.join(ROOT, 'assets', 'brain', 'intent_model.json')
INTENT_EVAL = os.path.join(ROOT, 'brain', 'eval', 'intent_eval.txt')

MIN_RAW_ACC = 0.90
MIN_GROUP_ACC = 0.92

GROUPS = {
    'cheque': 'COUNSEL', 'labor': 'COUNSEL', 'lease': 'COUNSEL',
    'family': 'COUNSEL', 'fraud_cyber': 'COUNSEL',
    'criminal_harm': 'COUNSEL', 'litigation_defense': 'COUNSEL',
    'debt': 'COUNSEL', 'general_intake': 'COUNSEL',
    'legal_question': 'RAG', 'article_lookup': 'RAG',
    'draft_request': 'DRAFT', 'cancel': 'CANCEL',
    'chitchat': 'TALK', 'out_of_scope': 'REJECT',
    'counsel_answer': 'ANSWER',
}

# جمله‌هایی که جریان‌های برنامه (و تست‌های Dart) به برچسب درستشان تکیه دارند.
CRITICAL = [
    ('lease', 'مستأجرم مدت قراردادش تمام شده ولی خانه را تخلیه نمی‌کند'),
    ('counsel_answer', 'قرارداد کتبی با امضای دو شاهد داریم'),
    ('litigation_defense', 'حکم غیابی علیه من صادر شده چه کار کنم؟'),
    ('counsel_answer', 'کمتر از ۲۰ روز گذشته است'),
    ('cheque', 'چک دادم بابت ضمانت الان برگشت زده و می‌خواهم بدانم چه کار کنم'),
    ('counsel_answer', 'بله، گواهی دارم و زیر ۶ ماه است'),
    ('debt', 'دوستم پول قرض گرفته و پس نمی‌دهد'),
    ('general_intake', 'مشاورهٔ حقوقی گام‌به‌گام'),
    ('general_intake', 'مشاوره'),
    ('legal_question', 'قانون چک چه می‌گوید؟'),
    ('legal_question', 'مجازات کلاهبرداری چیست'),
    ('article_lookup', 'ماده ۱۰ قانون مدنی چه می‌گوید'),
    ('article_lookup', 'اصل ۳۵ قانون اساسی'),
    ('cancel', 'انصراف'),
    ('cancel', 'پایان مشاوره'),
    ('chitchat', 'سلام'),
    ('out_of_scope', 'امروز هوا چطور است'),
    ('draft_request', 'برایم شکوائیه بنویس'),
    ('draft_request', 'لایحه دفاعیه آماده کن'),
    ('cheque', 'چک برگشتی دارم'),
    ('labor', 'کارفرما اخراجم کرده'),
    ('family', 'مهریه‌ام را نمی‌دهد'),
]

_NONWORD = re.compile(
    r'[^\u0621-\u063A\u0641-\u064A\u067E\u0686\u0698\u06A9\u06AF\u06CCa-z0-9]+')


def strip_nonbmp(s):
    return ''.join(ch for ch in s if ord(ch) <= 0xFFFF)


def intent_words(s):
    return [w for w in _NONWORD.sub(' ', normalize(strip_nonbmp(s))).split(' ')
            if w]


class IntentModel:
    def __init__(self, path=INTENT_MODEL):
        with open(path, encoding='utf-8') as f:
            m = json.load(f)
        self.m = m
        self.nb = int(m['nb'])
        self.hidden = int(m['hidden'])
        self.labels = list(m['labels'])
        if m.get('activation') != 'relu' or m.get('input_norm') != 'l1':
            raise ValueError('پیکربندی پشتیبانی‌نشده: %s/%s' % (
                m.get('activation'), m.get('input_norm')))
        nmin, nmax = m.get('ngram', [3, 5])
        self.nmin, self.nmax = int(nmin), int(nmax)
        self.w1 = self._deq(m['w1'], self.nb * self.hidden)
        self.b1 = self._deq(m['b1'], self.hidden)
        self.w2 = self._deq(m['w2'], self.hidden * len(self.labels))
        self.b2 = self._deq(m['b2'], len(self.labels))

    @staticmethod
    def _deq(t, want_len):
        raw = base64.b64decode(t['b64'])
        shape = t.get('shape')
        size = 1
        for d in shape or []:
            size *= d
        if len(raw) != want_len or size != want_len:
            raise ValueError('اندازهٔ تانسور نادرست: %d != %d' % (len(raw), want_len))
        scale = float(t['scale'])
        if not (scale > 0) or not math.isfinite(scale):
            raise ValueError('مقیاس نامعتبر')
        return [(b - 256 if b > 127 else b) * scale for b in raw]

    def feats(self, text):
        ids = []
        for w in intent_words(text):
            ids.append(fnv('w:' + w) % self.nb)
            t = '<' + w + '>'
            for n in range(self.nmin, self.nmax + 1):
                for i in range(len(t) - n + 1):
                    ids.append(fnv(t[i:i + n]) % self.nb)
        return ids

    def scores(self, text):
        x = {}
        for b in self.feats(text):
            x[b] = x.get(b, 0) + 1
        total = sum(x.values())
        if total == 0:
            return [0.0] * len(self.labels)
        h = list(self.b1)
        for i, cnt in x.items():
            xi = cnt / total
            base = i * self.hidden
            row = self.w1[base:base + self.hidden]
            for j in range(self.hidden):
                h[j] += xi * row[j]
        h = [v if v > 0 else 0.0 for v in h]
        C = len(self.labels)
        logits = list(self.b2)
        for j in range(self.hidden):
            if h[j] == 0.0:
                continue
            hj = h[j]
            base = j * C
            for c in range(C):
                logits[c] += hj * self.w2[base + c]
        mx = max(logits)
        exps = [math.exp(v - mx) for v in logits]
        s = sum(exps)
        return [e / s for e in exps]

    def classify(self, text):
        p = self.scores(text)
        best = max(range(len(p)), key=lambda i: p[i])
        return self.labels[best], p[best]


def load_rows(path):
    rows = []
    with open(path, encoding='utf-8') as f:
        for l in f:
            l = l.strip()
            if not l or l.startswith('#') or '|' not in l:
                continue
            label, text = l.split('|', 1)
            rows.append((label.strip(), text.strip()))
    return rows


def cmd_intent():
    model = IntentModel()
    labels = set(model.labels)
    if labels != set(GROUPS):
        missing = sorted(set(GROUPS) ^ labels)
        print('خطا: برچسب‌های مدل با گروه‌های مسیریابی نمی‌خواند: %s' % missing)
        return 1

    rows = load_rows(INTENT_EVAL)
    raw_ok = grp_ok = 0
    wrong = []
    for want, text in rows:
        pred, score = model.classify(text)
        raw_ok += pred == want
        grp_ok += GROUPS.get(pred) == GROUPS.get(want)
        if pred != want:
            wrong.append((want, pred, score, text))
    n = len(rows)
    raw, grp = raw_ok / n, grp_ok / n
    print('intent eval: n=%d raw_acc %.3f group_acc %.3f' % (n, raw, grp))
    for want, pred, score, text in wrong:
        print('  [%s->%s %.2f] %s' % (want, pred, score, text))

    bad = 0
    for want, text in CRITICAL:
        pred, score = model.classify(text)
        if pred != want:
            bad += 1
            print('نگهبان شکست: [%s->%s %.2f] %s' % (want, pred, score, text))
    print('critical guards: %d/%d' % (len(CRITICAL) - bad, len(CRITICAL)))

    ok = raw >= MIN_RAW_ACC and grp >= MIN_GROUP_ACC and bad == 0
    print('نتیجه: %s' % ('سالم' if ok else 'ناموفق'))
    return 0 if ok else 1


# ---------------------------------------------------------------- parity
def cmd_parity():
    import parity
    return parity.main()


# ---------------------------------------------------------------- main
COMMANDS = {
    'corpus': cmd_corpus,
    'assets': cmd_assets,
    'meta': cmd_meta,
    'intent': cmd_intent,
    'parity': cmd_parity,
}


def main(argv):
    cmd = 'all'
    for a in argv:
        if a in COMMANDS or a == 'all':
            cmd = a
            break
    names = list(COMMANDS) if cmd == 'all' else [cmd]
    failed = []
    for name in names:
        if len(names) > 1:
            print('===== check %s =====' % name)
        try:
            rc = COMMANDS[name]()
        except Exception as e:  # هر استثنا = شکست آن بخش
            print('خطا: بررسی %s با استثنا شکست خورد: %s' % (name, e))
            rc = 1
        if rc != 0:
            failed.append(name)
    if failed:
        print('check: بخش‌های ناموفق: %s' % '، '.join(failed))
        return 1
    print('check: همهٔ بررسی‌ها سالم است.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
