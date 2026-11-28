// موضوع: شرکت و سهام.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

const String _pctRe = 'درصد';
const String _profitRe = 'سود';

final Topic companyTopic = Topic.dsl(
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
  recap: const [
    RecapItem(when: FactEq('type', 'saham'), text: Tx('company_1')),
    RecapItem(when: FactEq('type', 'llc'), text: Tx('company_2')),
    RecapItem(
      when: FactHasNum('pct'),
      text: TxJoin(
          ' ', [Tx('companyRecapPctA'), TxNum('pct', fmt: NumFmt.fa), Tx('companyRecapPctB')]),
    ),
    RecapItem(when: FactEq('issue', 'profit'), text: Tx('company_3')),
    RecapItem(when: FactEq('issue', 'info'), text: Tx('company_4')),
    RecapItem(when: FactEq('issue', 'abuse'), text: Tx('company_5')),
  ],
  claims: [
    Claim.dsl(
      goal: topicText('company_6'),
      elements: [
        Element.dsl(
          topicText('company_7'),
          const FactIn('type', ['saham']),
          ifNo: topicText('company_8'),
        ),
        Element.dsl(
          topicText('company_9'),
          const FactNumMin('pct', 20),
          ifNo: topicText('company_10'),
        ),
        Element.dsl(
          topicText('company_11'),
          const FactTriIf(FactEq('issue', 'abuse'), true),
        ),
      ],
      win: const Tx('company_12'),
      counter: const Tx('company_13'),
    ),
  ],
  slots: [
    Slot.dsl(
      id: 'type',
      ask: topicText('company_14'),
      why: topicText('company_15'),
      options: [topicText('company_16'), topicText('company_17')],
      yesValue: '',
      noValue: '',
      read: const ReadCases([
        ReadCase('مسئولیت محدود|مسولیت محدود', 'llc'),
        ReadCase('سهامی|سهامدار|هیئت مدیره|هیات مدیره|مجمع عمومی', 'saham'),
      ]),
      effect: const TxCond(
          FactEq('type', 'llc'), Tx('company_18'), Tx('company_19')),
    ),
    Slot.dsl(
      id: 'pct',
      ask: topicText('company_20'),
      why: topicText('company_21'),
      yesValue: '',
      noValue: '',
      read: const ReadNumBefore(_pctRe, min: 1, max: 100),
      readPending:
          const ReadNumBefore(_pctRe, min: 1, max: 100, fallbackLoose: true),
    ),
    Slot.dsl(
      id: 'issue',
      ask: topicText('company_22'),
      why: topicText('company_23'),
      options: [topicText('company_24'), topicText('company_25'), topicText('company_26')],
      yesValue: '',
      noValue: '',
      read: const ReadCases([
        ReadCase('سوء ?استفاده|اختلاس|برداشت(?:ه)? (?:از|کرده)|به نام خودش|قرارداد با خودش|تخلف|بالا کشید|حیف و میل', 'abuse'),
        ReadCase('حساب(?: و ?کتاب)?[^ ]* (?:رو |را )?نش[او]ن|صورت ?های مالی|ترازنامه|گزارش نمید|مجمع (?:برگزار|تشکیل) نمی|خبر نمید|شفاف', 'info'),
        ReadCase(_profitRe, 'profit'),
      ]),
      effect: const TxSwitch(
        'issue',
        {'profit': Tx('company_27'), 'info': Tx('company_28')},
        fallback: Tx('company_29'),
      ),
    ),
  ],
  opening: const Tx('company_30'),
  issues: [
    Issue.dsl(
      id: 'liable',
      chip: topicText('company_31'),
      cues: 'بدهی شرکت|ورشکست|طلبکار(?:ا|ها)ی شرکت|گردن من|مال شخصی|مسئول(?:م| هستم)',
      body: const Tx('company_32'),
    ),
    Issue.dsl(
      id: 'types',
      chip: topicText('company_33'),
      cues: 'انواع شرکت|چه نوع شرکت|کدوم شرکت|فرق (?:سهامی|مسئولیت)|ثبت شرکت',
      body: const Tx('company_34'),
    ),
  ],
  follow: const {
    'next': Tx('company_35'),
    'where': Tx('company_36'),
    'evidence': Tx('company_37'),
    'chance': Tx('company_38'),
    'cost': Tx('company_39'),
  },
  drafts: const DraftRule.fixed(['formal_notice']),
);
