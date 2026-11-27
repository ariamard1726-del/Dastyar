part of 'labor.dart';

// ادعاهای حقوقیِ کار و کارفرما: ارکان، شرط و نتیجه.

final Element _laborRel = Element(
  topicText('laborClm_0'),
  (f) {
    if (f.yes('contract') || f.yes('insured') || f.yes('proof')) return true;
    if (f.no('contract') && f.no('insured') && f.no('proof')) return false;
    return null;
  },
  needs: const ['contract', 'insured', 'proof'],
  because: (f) => f.yes('contract')
      ? topicText('laborClm_1')
      : (f.yes('insured')
          ? topicText('laborClm_2')
          : (f.yes('proof') ? topicText('laborClm_3') : '')),
  ifNo:
      topicText('laborClm_4'),
);

/// برگه‌ای امضا نشده باشد که کارفرما آن را «رفتن با میل خود» یا «گرفتنِ همهٔ
/// پول» جا بزند.
Element _laborUnsigned(String text, String ifNo) => Element(
      text,
      (f) => f.no('signed') ? true : (f.yes('signed') ? false : null),
      needs: const ['signed'],
      because: (f) => topicText('laborClm_5'),
      ifNo: ifNo,
    );

/// ادعاهای کارگر، به ترتیب اهمیت. هر کدام فقط وقتی روی میز می‌آید که
/// واقعیت‌های پرونده آن را پیش کشیده باشد؛ یک ماجرا می‌تواند چند ادعا داشته
/// باشد (اخراج + حقوق معوق + سنوات + بیمه).
final List<Claim> laborClaims = [
  Claim(
    label: topicText('laborClaimFiredLabel'),
    goal: topicText('laborClm_6'),
    cues:
        'برگرد(?:م|ی)? سر کار|برمیگرد(?:م|ی)? سر کار|بازگشت به کار|اخراج(?:م|ش)? (?:[^ ]+ ){0,2}(?:قانونی|غیر ?قانونی|درست|ناموجه|موجه)|حق (?:داشت|داره|دارد|داشته) (?:[^ ]+ ){0,2}اخراج|میتون(?:ه|ست|د) (?:[^ ]+ ){0,2}اخراج|خسارت اخراج',
    when: (f) => laborFired(f),
    uses: const ['months', 'salary'],
    elements: [
      _laborRel,
      _laborUnsigned(
        topicText('laborClm_7'),
        topicText('laborClm_8'),
      ),
      Element(
        topicText('laborClm_9'),
        (f) {
          if (f.no('contract')) return true;
          if (f.no('expired')) return true;
          if (f.yes('expired')) return false;
          return null;
        },
        needs: const ['contract', 'expired'],
        because: (f) => f.no('expired')
            ? topicText('laborClm_10')
            : topicText('laborClm_11'),
        ifNo:
            topicText('laborClm_12'),
      ),
      Element(
        topicText('laborClm_13'),
        (f) => f.no('warned') ? true : (f.yes('warned') ? false : null),
        needs: const ['warned'],
        because: (f) => topicText('laborClm_14'),
        ifNo:
            topicText('laborClm_15'),
      ),
    ],
    win: (f) =>
        topicText('laborClm_16'),
    counter: (f) =>
        topicText('laborClm_17'),
  ),
  Claim(
    label: topicText('laborClm_18'),
    goal: topicText('laborClm_19'),
    cues: 'حقوق[^ ]* (?:[^ ]+ ){0,3}(?:بگیرم|میگیرم|گرفت|وصول|میرسه|میدن)',
    when: (f) => f.eq('event', 'unpaid') || f.yes('owed'),
    uses: const ['salary'],
    elements: [
      _laborRel,
      _laborUnsigned(
        topicText('laborClm_20'),
        topicText('laborClm_21'),
      ),
    ],
    win: (f) =>
        topicText('laborClm_22'),
    counter: (f) =>
        topicText('laborClm_23'),
  ),
  Claim(
    label: topicText('laborClm_24'),
    goal: topicText('laborClm_25'),
    cues: 'سنوات|مزایای پایان کار',
    uses: const ['salary'],
    elements: [
      _laborRel,
      Element(
        topicText('laborClm_26'),
        (f) {
          if (laborFired(f) || f.no('working')) return true;
          if (f.yes('working')) return false;
          return null;
        },
        needs: const ['working'],
        because: (f) => topicText('laborClm_27'),
        ifNo:
            topicText('laborClm_28'),
      ),
      Element(
        topicText('laborClm_29'),
        (f) {
          final m = f.n('months');
          return m == null ? null : m >= 12;
        },
        needs: const ['months'],
        because: (f) => Sense.span(f.n('months') ?? 0) + ' ' + topicText('laborClaimMonthsBecause'),
        ifNo:
            topicText('laborClm_30'),
      ),
    ],
    win: (f) =>
        topicText('laborClm_31'),
    counter: (f) =>
        topicText('laborClm_32'),
  ),
  Claim(
    label: topicText('laborClm_33'),
    goal: topicText('laborClm_34'),
    cues: 'بیمه',
    when: (f) => !f.yes('insured'),
    elements: [
      _laborRel,
      Element(
        topicText('laborClm_35'),
        (f) => f.no('insured') || f.eq('event', 'insurance') ? true : null,
        needs: const ['insured'],
        because: (f) => topicText('laborClm_36'),
      ),
    ],
    win: (f) =>
        topicText('laborClm_37'),
    counter: (f) =>
        topicText('laborClm_38'),
  ),
];
