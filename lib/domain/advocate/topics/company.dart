// موضوع: شرکت و سهام.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic companyTopic = Topic(
  id: 'company',
  title: topicText('company_0'),
  cues: {
    'شرکت(?:مون| ما|م)?[^؟]{0,20}(?:ورشکست|تعطیل|منحل|بسته شد|زیان ده)|ورشکستگی شرکت': 4,
    'سهامدار|هیئت مدیره|هیات مدیره|مجمع عمومی|سهم ?الشرکه|سود سهام': 4,
    'شرکت (?:سهامی|با مسئولیت)|سهام(?:م| من| دارم)|درصد (?:سهام|سهم) ': 4,
    'مدیر ?عامل|ترازنامه|صورت ?های مالی|بازرس شرکت|اساسنامه|شرکت (?:ثبت کردیم|ثبت شده)': 2,
    '(?:تو|توی|در) شرکت |شرکت(?:مون| ما) ': 2,
    'اختلاس|حیف و میل|سهم(?:م| من) از شرکت': 2,
  },
  anti: 'کارفرما|اخراج|حقوقم|بیمه',
  recap: (f) => [
    if (f.eq('type', 'saham')) topicText('company_1'),
    if (f.eq('type', 'llc')) topicText('company_2'),
    if (f.n('pct') != null) topicText('companyRecapPctA') + ' ' + Sense.fa(f.n('pct')!) + ' ' + topicText('companyRecapPctB'),
    if (f.eq('issue', 'profit')) topicText('company_3'),
    if (f.eq('issue', 'info')) topicText('company_4'),
    if (f.eq('issue', 'abuse')) topicText('company_5'),
  ],
  claims: [
    Claim(
      goal: topicText('company_6'),
      elements: [
        Element(
          topicText('company_7'),
          (f) => f.isOne('type', const ['saham']),
          ifNo:
              topicText('company_8'),
        ),
        Element(
          topicText('company_9'),
          (f) => f.n('pct') == null ? null : f.n('pct')! >= 20,
          ifNo:
              topicText('company_10'),
        ),
        Element(
          topicText('company_11'),
          (f) => f.eq('issue', 'abuse') ? true : null,
        ),
      ],
      win: (f) =>
          topicText('company_12'),
      counter: (f) =>
          topicText('company_13'),
    ),
  ],
  slots: [
    Slot(
      id: 'type',
      ask: topicText('company_14'),
      why: topicText('company_15'),
      options: [topicText('company_16'), topicText('company_17')],
      yesValue: '',
      noValue: '',
      read: (n) {
        if (Sense.has(n, 'مسئولیت محدود|مسولیت محدود')) return 'llc';
        if (Sense.has(n, 'سهامی|سهامدار|هیئت مدیره|هیات مدیره|مجمع عمومی')) return 'saham';
        return null;
      },
      effect: (f) => f.eq('type', 'llc')
          ? topicText('company_18')
          : topicText('company_19'),
    ),
    Slot(
      id: 'pct',
      ask: topicText('company_20'),
      why: topicText('company_21'),
      yesValue: '',
      noValue: '',
      read: (n) {
        final v = Sense.numberBefore(n, 'درصد');
        return v == null || v <= 0 || v > 100 ? null : '$v';
      },
      readPending: (n) {
        final v = Sense.numberBefore(n, 'درصد') ?? Sense.looseAmount(n);
        return v == null || v <= 0 || v > 100 ? null : '$v';
      },
    ),
    Slot(
      id: 'issue',
      ask: topicText('company_22'),
      why: topicText('company_23'),
      options: [topicText('company_24'), topicText('company_25'), topicText('company_26')],
      yesValue: '',
      noValue: '',
      read: (n) {
        if (Sense.has(n, 'سوء ?استفاده|اختلاس|برداشت(?:ه)? (?:از|کرده)|به نام خودش|قرارداد با خودش|تخلف|بالا کشید|حیف و میل')) return 'abuse';
        if (Sense.has(n, 'حساب(?: و ?کتاب)?[^ ]* (?:رو |را )?نش[او]ن|صورت ?های مالی|ترازنامه|گزارش نمید|مجمع (?:برگزار|تشکیل) نمی|خبر نمید|شفاف')) return 'info';
        if (Sense.has(n, 'سود')) return 'profit';
        return null;
      },
      effect: (f) => f.eq('issue', 'profit')
          ? topicText('company_27')
          : f.eq('issue', 'info')
              ? topicText('company_28')
              : topicText('company_29'),
    ),
  ],
  opening: (f) =>
      topicText('company_30'),
  issues: [
    Issue(
      id: 'liable',
      chip: topicText('company_31'),
      cues: 'بدهی شرکت|ورشکست|طلبکار(?:ا|ها)ی شرکت|گردن من|مال شخصی|مسئول(?:م| هستم)',
      body: (f) =>
          topicText('company_32'),
    ),
    Issue(
      id: 'types',
      chip: topicText('company_33'),
      cues: 'انواع شرکت|چه نوع شرکت|کدوم شرکت|فرق (?:سهامی|مسئولیت)|ثبت شرکت',
      body: (f) =>
          topicText('company_34'),
    ),
  ],
  follow: {
    'next': (f) =>
        topicText('company_35'),
    'where': (f) =>
        topicText('company_36'),
    'evidence': (f) =>
        topicText('company_37'),
    'chance': (f) =>
        topicText('company_38'),
    'cost': (f) =>
        topicText('company_39'),
  },
  drafts: (f) => const ['formal_notice'],
);
