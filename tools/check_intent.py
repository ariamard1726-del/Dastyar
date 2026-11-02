"""اعتبارسنج مدل نیت (assets/brain/intent_model.json) — آینهٔ پایتونیِ lib/intent_net.dart.

بررسی‌ها:
  ۱. ساختار JSON مدل (ابعاد، base64، برچسب‌ها، مقیاس‌ها)
  ۲. دقت روی مجموعهٔ آزمون brain/intent_eval.txt (آستانهٔ raw و گروه‌های مسیریابی)
  ۳. نگهبان جمله‌های حیاتی اپ (جریان‌هایی که تست‌های Dart به آن‌ها تکیه دارند)

اجرا: python3 tools/check_intent.py   (خروج ۰ = سالم)
"""
import base64
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'brain'))
from common import fnv, normalize  # noqa: E402

MODEL = os.path.join(ROOT, 'assets', 'brain', 'intent_model.json')
EVAL = os.path.join(ROOT, 'brain', 'intent_eval.txt')

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


def words(s):
    return [w for w in _NONWORD.sub(' ', normalize(strip_nonbmp(s))).split(' ')
            if w]


class IntentModel:
    def __init__(self, path=MODEL):
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
        for w in words(text):
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


def main():
    model = IntentModel()
    labels = set(model.labels)
    if labels != set(GROUPS):
        missing = sorted(set(GROUPS) ^ labels)
        print('خطا: برچسب‌های مدل با گروه‌های مسیریابی نمی‌خواند: %s' % missing)
        return 1

    rows = load_rows(EVAL)
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


if __name__ == '__main__':
    sys.exit(main())
