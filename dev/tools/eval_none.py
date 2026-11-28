"""ارزیابی «رد کردن درست»: پرسش‌هایی که پاسخشان در برنامه نیست.
همگام با پوشش واژگانی (شامل پیشوند و مترادف) و نگهبان حوزه‌های خارج از پوشش lib/core/engine.dart.
اجرا: python3 dev/tools/eval_none.py [-v] [--check]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(
    0,
    os.path.join(
        os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
        'dev',
        'brain',
    ),
)
import engine_rules as _ER  # noqa: E402
from eval_py import ART_QUERY_RE, ROOT, Engine, collapse, normalize, phrase, tok  # noqa: E402

MIN_SCORE = _ER.MIN_SCORE
LOW_COVER = _ER.LOW_COVER

UNLOADED_PENAL_TERMS = _ER.UNLOADED_PENAL_TERMS
PENAL_CONTEXT_MARKERS = _ER.PENAL_CONTEXT_MARKERS
LOADED_CRIMINAL_EXCEPTIONS = _ER.LOADED_CRIMINAL_EXCEPTIONS


def _has_term(c, t):
    return t in c['T'] or t in c['B'] or t in c['C']


def coverage(eng, q, c):
    qt = list(dict.fromkeys(tok(q)))
    if not qt or not eng.idf:
        return 0.0
    mx = eng.max_idf
    den = got = 0.0
    covered = set()
    for t in qt:
        w = eng.idf.get(t, mx)
        den += w
        if _has_term(c, t):
            covered.add(t)
            got += w
        elif len(t) >= _ER.PREFIX_MIN_LEN:
            pref = False
            for m in (c['T'], c['B'], c['C']):
                for k in m:
                    if len(k) >= _ER.PREFIX_MIN_LEN and (k.startswith(t) or t.startswith(k)):
                        pref = True
                        break
                if pref:
                    break
            if pref:
                covered.add(t)
                got += _ER.PREFIX_WEIGHT * mx

    n = f' {phrase(q)} '
    for kk, v in eng.syn:
        if f' {kk} ' not in n:
            continue
        if not any(_has_term(c, t) for t in tok(v)):
            continue
        for t in tok(kk):
            if t in qt and t not in covered:
                covered.add(t)
                got += eng.idf.get(t, mx)

    return got / den if den > 0 else 0.0


def mentions_missing_law(eng, q):
    m = eng.mentioned(q)
    return bool(m) and all(eng.lawcount.get(i, 0) <= 0 for i in m)


def hits_unloaded_domain(eng, norm_q, mentioned_ids, top_chunk):
    if mentioned_ids:
        return False
    cn = collapse(norm_q)

    # ۱) جرایم عمومی کیفری و رایانه‌ای وقتی قانون مجازات اسلامی / جرایم رایانه‌ای بارگذاری نشده
    if eng.lawcount.get('penal', 0) <= 0:
        has_penal_marker = any(m in cn for m in PENAL_CONTEXT_MARKERS)
        has_unloaded_crime = any(t in cn for t in UNLOADED_PENAL_TERMS)
        has_loaded_exc = any(e in cn for e in LOADED_CRIMINAL_EXCEPTIONS)
        if has_penal_marker and has_unloaded_crime and not has_loaded_exc:
            return True

    # ۲) پرسش‌های اختصاصی مالیاتی وقتی قانون مالیات‌های مستقیم بارگذاری نشده
    if eng.lawcount.get('direct_taxes', 0) <= 0 and 'مالیات' in cn:
        if (
            any(trig in cn for trig in _ER.TAX_TRIGGERS)
            or (not _has_term(top_chunk, 'مالیات') and 'مالیات' not in normalize(top_chunk['source']))
        ):
            return True

    # ۳) جزئیات حق بیمه و مستمری تأمین اجتماعی وقتی قانون تأمین اجتماعی بارگذاری نشده
    if eng.lawcount.get('social_security', 0) <= 0:
        if 'تامین اجتماعی' in cn and any(trig in cn for trig in _ER.SOCIAL_SECURITY_TRIGGERS):
            return True

    # ۴) نگهبان عدم انطباق موضوع محوری: اگر پرسش صریحاً دربارهٔ نهاد حقوقی خاصی باشد
    # اما قطعهٔ برتر بازیابی‌شده هیچ‌یک از واژه‌های آن نهاد را نداشته باشد (برخورد واژه‌های عمومی)
    q_words = f' {phrase(norm_q)} '
    for trigger, required_any in _ER.ANCHOR_GROUPS:
        if f' {trigger} ' in q_words:
            if not any(_has_term(top_chunk, r) for r in required_any):
                return True

    return False


def gate(eng, q):
    """True یعنی برنامه با اطمینان جواب می‌دهد (برای پرسش بی‌پاسخ = خطا)."""
    if mentions_missing_law(eng, q):
        return False
    n = normalize(q)
    art = ART_QUERY_RE.search(n)
    mentioned = eng.mentioned(q)
    if art and not mentioned and 'قانون' in n:
        return False
    hits = eng.rank(q, k=4)
    if art and mentioned and not (hits and hits[0][1] >= _ER.EXPLICIT_SCORE):
        return False
    if not hits or hits[0][1] < MIN_SCORE:
        return False
    if (art is None or hits[0][1] < _ER.EXPLICIT_SCORE) and coverage(eng, q, hits[0][0]) < LOW_COVER:
        return False
    if art is None and hits_unloaded_domain(eng, n, mentioned, hits[0][0]):
        return False
    return True


if __name__ == '__main__':
    eng = Engine()
    path = os.path.join(ROOT, 'eval', 'eval_none.txt')
    with open(path, encoding='utf-8') as f:
        qs = [l.strip() for l in f if l.strip() and not l.startswith('#')]
    bad = [q for q in qs if gate(eng, q)]
    rate = (100.0 * len(bad) / len(qs)) if qs else 0.0
    print(
        'eval_none.txt: n=%d رد درست %d | پاسخ غلط با اطمینان %d (%.0f%%)'
        % (len(qs), len(qs) - len(bad), len(bad), rate)
    )
    if '-v' in sys.argv:
        for q in bad:
            h = eng.rank(q, k=1)
            top = '%s | %s' % (h[0][0]['source'], h[0][0]['title']) if h else '-'
            print('  پاسخ داده شد: %s  →  %s' % (q, top))
    if '--check' in sys.argv and rate > 10.0:
        print(f'FAIL eval_none.txt: false confident rate {rate:.1f}% > 10.0%')
        sys.exit(1)
