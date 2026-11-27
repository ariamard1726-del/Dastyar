"""بررسی یکپارچهٔ داده‌ها و دارایی‌های پروژه (جایگزین check.py/check_assets.py/check_meta.py/check_intent.py).

زیردستورها:
  corpus   قالب‌ها + متن قوانین + ثبت بودنشان در _meta.json (بررسی قدیمی check.py)
  assets   پوشش دارایی‌ها در pubspec.yaml (با --fix اصلاح می‌کند)
  meta     اعتبار فیلدهای _meta.json + تازگی مشتق‌ها (laws_catalog.json و data_info.json)
  intent   اعتبار و دقت مدل نیت (assets/brain/intent_model.json)
  parity   تازگی استاندارد طلایی برابری پایتون↔دارت (dev/brain/parity_expected.json)
  pipeline ترتیب و آستانه‌های مسیر پاسخ (assets/pipeline.json)
  topics   طرح‌وارهٔ مسیرهای موضوعی (dev/tools/schemas/topic_flow.schema.json)
  refs     هر ارجاع قانونی در داده، در متن قوانین هست
  textnorm قاعده‌های متن تازه‌اند (dev/tools/contracts/text_norm.json)
  lawterms قاعده‌های تطبیق واژه‌ها تازه‌اند (dev/tools/contracts/law_terms.json)
  debt     هر جفتِ دوپیاده‌سازی نگهبانِ دوطرفه دارد (dev/tools/contracts/duplicated_logic.json)
  all      همهٔ موارد بالا (پیش‌فرض؛ trust عمداً بیرون است)
  trust    دروازهٔ انتشار: قانون تأییدنشده یا قالب بازبینینشده نمانده باشد

اجرا: python3 dev/tools/check.py [زیردستور] [--strict] [--fix] [--require-verified]
با STRICT=1 یا --strict خالی‌بودن منبع و تاریخ قانون «خطا» می‌شود، نه هشدار.
با --require-verified هر قانونی که با منبع رسمی تطبیق داده نشده «خطا» می‌شود.
"""
import base64
import glob
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, 'dev', 'brain'))
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
    """شناسنامهٔ منبع هر قانون: فیلدهای لازم، اثر انگشت متن و وضعیت تطبیق.

    قاعده‌ها در dev/tools/law_registry.py است تا ابزار ثبت و این بررسی یکی باشند.
    با --require-verified (یا REQUIRE_VERIFIED=1) قانونِ تطبیق‌نشده هم خطاست.
    """
    import law_registry

    require = ('--require-verified' in sys.argv
               or os.environ.get('REQUIRE_VERIFIED') == '1')
    with open(os.path.join(LAWS_DIR, '_meta.json'), encoding='utf-8') as f:
        meta = json.load(f)
    errors, warnings, verified = law_registry.validate(
        meta, LAWS_DIR, require_verified=require)

    for e in errors:
        print('خطا:', e)
    if errors:
        print('نتیجه: %d خطا در _meta.json؛ پوش نکنید.' % len(errors))
        return 1
    print('_meta.json درست است. تطبیق‌شده با منبع رسمی: %d از %d.'
          % (verified, len(meta)))
    if warnings:
        print('هشدار: %d قانون هنوز با منبع رسمی تطبیق داده نشده '
              '(python3 dev/tools/law_registry.py status).' % len(warnings))

    # تازگی مشتق‌ها: عنوان‌های کاتالوگ و data_info باید از _meta.json مشتق شده باشند.
    import sync_meta
    return sync_meta.main()


# ---------------------------------------------------------------- intent
INTENT_MODEL = os.path.join(ROOT, 'assets', 'brain', 'intent_model.json')
INTENT_EVAL = os.path.join(ROOT, 'eval', 'intent_eval.txt')

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


# ---------------------------------------------------------------- debt
def cmd_debt():
    """هر جفتِ «یک چیز، دو پیاده‌سازی» هنوز نگهبانِ دوطرفه دارد؟"""
    import debt_check
    return debt_check.main(['--check'])


# ---------------------------------------------------------------- lawterms
def cmd_lawterms():
    """فایل‌های قاعدهٔ تطبیق واژه‌ها از قرارداد تولید شده‌اند و تازه‌اند؟"""
    import gen_law_terms
    return gen_law_terms.main(['--check'])


# ---------------------------------------------------------------- priority
def cmd_priority():
    """ماتریس اولویتِ ۲۰ کاندید (۱۹۰ جفت) کامل و مستند/آزمونش تازه است؟"""
    import gen_priority
    return gen_priority.main(['--check'])


# ---------------------------------------------------------------- textnorm
def cmd_textnorm():
    """فایل‌های قاعدهٔ متن از قرارداد تولید شده‌اند و تازه‌اند؟"""
    import gen_text_norm
    return gen_text_norm.main(['--check'])


# ---------------------------------------------------------------- pipeline
def cmd_pipeline():
    import pipeline_check
    return pipeline_check.main([])


# ---------------------------------------------------------------- topics
def cmd_topics():
    import topic_schema
    return topic_schema.main([])


# ---------------------------------------------------------------- refs
def cmd_refs():
    import data_refs
    return data_refs.main([])


# ---------------------------------------------------------------- text
def cmd_text():
    """هش‌نامهٔ متن: هیچ جملهٔ حقوقی بی‌اعلام عوض نشده باشد."""
    import text_manifest
    return text_manifest.main([])


# ---------------------------------------------------------------- bundle
BUNDLE_FORBIDDEN = ('dev/', 'tools/', 'brain/', 'eval/', 'reports/', 'lab/')


def bundle_entries(pubspec_text):
    """فهرست داراییهای بستهبندیشده از قطعهٔ `assets:` در pubspec."""
    entries, inside = [], False
    for line in pubspec_text.split('\n'):
        if line.startswith('  assets:'):
            inside = True
            continue
        if not inside:
            continue
        if not line.startswith('    '):
            break
        found = re.match(r'^    - (\S+)\s*$', line)
        if found:
            entries.append(found.group(1))
    return entries


def bundle_problems(entries, dart_sources):
    bad = [e for e in entries
           if not e.startswith('assets/') or '/..' in e or e.startswith('assets/../')]
    for src in dart_sources:
        for marker in BUNDLE_FORBIDDEN:
            if "'" + marker in src or '"' + marker in src:
                bad.append('lib: %s' % marker)
    return bad


def cmd_bundle():
    pubspec = open(os.path.join(ROOT, 'pubspec.yaml'), encoding='utf-8').read()
    dart = []
    for directory, _, files in os.walk(os.path.join(ROOT, 'lib')):
        for name in files:
            if name.endswith('.dart'):
                dart.append(open(os.path.join(directory, name), encoding='utf-8').read())
    entries = bundle_entries(pubspec)
    bad = bundle_problems(entries, dart)
    if bad:
        print('خطا: ابزار آفلاین وارد بسته میشود:', *bad, sep='\n  ')
        return 1
    print('bundle OK: %d دارایی، بدون dev/tools/brain/eval/reports/lab.' % len(entries))
    return 0


# ---------------------------------------------------------------- noql
NOQL_REQUIRED = (
    'assets/brain/noql.bin',
    'assets/brain/noql_vocab.json',
    'assets/brain/noql_head.json',
    'assets/brain/noql_licenses.txt',
)
NOQL_READER_PATHS = {
    'weightsAsset': 'assets/brain/noql.bin',
    'vocabAsset': 'assets/brain/noql_vocab.json',
    'headAsset': 'assets/brain/noql_head.json',
}


def _covered(entries, rel):
    """آیا مسیر توسط یک ورودیexact یا یک پوشهٔ بستهبندیشده پوشش میشود؟"""
    return any(e == rel or (e.endswith('/') and rel.startswith(e))
               for e in entries)


def noql_bundle_problems(entries):
    bad = []
    for rel in NOQL_REQUIRED:
        path = os.path.join(ROOT, rel.replace('/', os.sep))
        if not os.path.isfile(path) or os.path.getsize(path) == 0:
            bad.append(rel + ': فایل پاک یا خالی است')
        elif not _covered(entries, rel):
            bad.append(rel + ': وارد pubspec.yaml نمیشود')
    return bad


def cmd_noql():
    pubspec = open(os.path.join(ROOT, 'pubspec.yaml'), encoding='utf-8').read()
    reader = open(os.path.join(
        ROOT, 'lib', 'domain', 'understanding', 'reader_service.dart'),
        encoding='utf-8').read()
    bad = noql_bundle_problems(bundle_entries(pubspec))
    for name, rel in NOQL_READER_PATHS.items():
        if "static const String %s = '%s';" % (name, rel) not in reader:
            bad.append('reader_service.dart: %s به %s اشاره نمیکند' % (name, rel))
    if bad:
        print('خطا: دارایی اصلی Noql آسیب دید:', *bad, sep='\n  ')
        return 1
    print('noql OK: %d فایل موجود، بستهبندیشده و مورد استفاده ReaderService.'
          % len(NOQL_REQUIRED))
    return 0


# ---------------------------------------------------------------- trust
def cmd_trust():
    """دروازهٔ صداقتِ انتشار: محتوای حقوقیِ قابل استناد باید کاملاً بازبینی شده باشد."""
    import law_registry

    with open(os.path.join(LAWS_DIR, '_meta.json'), encoding='utf-8') as f:
        meta = json.load(f)
    errors, warnings, verified = law_registry.validate(
        meta, LAWS_DIR, require_verified=True)
    unreviewed = []
    for path in sorted(glob.glob(os.path.join(ROOT, 'assets', 'templates', '*.json'))):
        with open(path, encoding='utf-8') as f:
            t = json.load(f)
        if not t.get('reviewed'):
            unreviewed.append(os.path.basename(path))
    unknown = [k for k, v in meta.items() if isinstance(v, dict)
               and str(v.get('status', '')).strip() != 'verified']
    print('trust: %d/%d قانون با منبع رسمی تطبیق داده شده' % (verified, len(meta)))
    print('trust: %d/%d قالب بازبینی شده' %
          (len(glob.glob(os.path.join(ROOT, 'assets', 'templates', '*.json'))) - len(unreviewed),
           len(glob.glob(os.path.join(ROOT, 'assets', 'templates', '*.json')))))
    if unreviewed:
        print('خطا: قالبهای بازبینینشده: %s' % '، '.join(unreviewed))
    if unknown:
        print('خطا: قانونهای تأییدنشده: %s' % '، '.join(sorted(unknown)))
    for e in errors:
        print('خطا: %s' % e)
    if errors or unknown or unreviewed:
        print('نتیجه: انتشار مسدود است. متن رسمی یا بازبینی انسانی لازم است؛ '
              'CI معمولی (check.py all) عمداً این دروازه را شامل نمیشود.')
        return 1
    print('نتیجه: محتوای حقوقی قابل انتشار است.')
    return 0


# ---------------------------------------------------------------- main
RELEASE_ONLY = {'trust'}

COMMANDS = {
    'corpus': cmd_corpus,
    'assets': cmd_assets,
    'meta': cmd_meta,
    'intent': cmd_intent,
    'parity': cmd_parity,
    'pipeline': cmd_pipeline,
    'topics': cmd_topics,
    'refs': cmd_refs,
    'textnorm': cmd_textnorm,
    'lawterms': cmd_lawterms,
    'priority': cmd_priority,
    'debt': cmd_debt,
    'text': cmd_text,
    'bundle': cmd_bundle,
    'noql': cmd_noql,
    'trust': cmd_trust,
}


def main(argv):
    cmd = 'all'
    for a in argv:
        if a in COMMANDS or a == 'all':
            cmd = a
            break
    names = ([n for n in COMMANDS if n not in RELEASE_ONLY]
             if cmd == 'all' else [cmd])
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
