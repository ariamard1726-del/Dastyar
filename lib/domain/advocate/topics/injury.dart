// موضوع: آسیب بدنی و دیه.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic injuryTopic = Topic.dsl(
  id: 'injury',
  title: topicText('injury_0'),
  cues: {
    'حادثه (?:ی )?(?:کار|ناشی از کار|حین کار)|از داربست|سر کار[^؟]{0,30}(?:آسیب|مصدوم|افتادم|شکست|قطع شد|سوخت|برق گرفت)|دستم (?:رفت )?(?:زیر|لای) (?:دستگاه|پرس)': 6,
    'تصادف|زیر(?:م)? گرفت|زد به (?:ماشینم|من)|کروکی': 4,
    'ماشین(?:م|ام)?[^؟]{0,20}(?:زد|زده|کوبید|خراب کرد)|(?:زد|زده) و فرار|فرار کرد[^؟]{0,20}(?:زد|ماشین)': 4,
    ' دیه |نقص عضو|از ?کار ?افتاد|مصدوم|قطع (?:عضو|انگشت|دست|پا)|خسارت بدنی': 3,
    'گاز(?:م)? گرفت|سگ(?:ش| همسایه)? (?:[^ ]+ ){0,2}حمله|(?:خطا|قصور)(?:ی)? (?:پزشک|دکتر|جراح)|(?:پزشک|دکتر|جراح)[^؟]{0,20}(?:اشتباه|خطا|قصور)|عمل(?:م)? (?:رو )?(?:اشتباه|خراب)': 4,
    'آسیب دید|(?:دست|پا|کمر|سر|چشم|دنده|انگشت)(?:م|ام)? (?:شکست|قطع شد|آسیب|سوخت)': 3,
  },
  anti: 'شوهر|طلاق|همسرم|مهریه',
  recap: const [
    RecapItem(when: FactEq('kind', 'work'), text: Tx('injury_1')),
    RecapItem(when: FactEq('kind', 'car'), text: Tx('injury_2')),
    RecapItem(when: FactEq('kind', 'other'), text: Tx('injury_3')),
    RecapItem(when: FactYes('safe'), text: Tx('injury_4')),
    RecapItem(when: FactNo('safe'), text: Tx('injury_5')),
    RecapItem(when: FactYes('report'), text: Tx('injury_6')),
    RecapItem(when: FactNo('report'), text: Tx('injury_7')),
  ],
  claims: [
    Claim.dsl(
      goal: topicText('injury_8'),
      when: const FactEq('kind', 'work'),
      elements: [
        Element.dsl(
          topicText('injury_9'),
          const FactConst(true),
        ),
        Element.dsl(
          topicText('injury_10'),
          const FactTriWhen(FactHas('safe'), FactNo('safe')),
          ifNo: topicText('injury_11'),
        ),
        Element.dsl(
          topicText('injury_12'),
          const FactTri('report'),
          ifNo: topicText('injury_13'),
        ),
      ],
      win: const Tx('injury_14'),
      counter: const Tx('injury_15'),
    ),
    Claim.dsl(
      goal: topicText('injury_16'),
      elements: [
        Element.dsl(
          topicText('injury_17'),
          const FactTriIf(FactHas('kind'), true),
        ),
        Element.dsl(
          topicText('injury_18'),
          const FactTri('report'),
          ifNo: topicText('injury_19'),
        ),
        Element.dsl(
          topicText('injury_20'),
          const FactConst(null),
        ),
      ],
      win: const Tx('injury_21'),
      counter: const Tx('injury_22'),
    ),
  ],
  slots: [
    Slot.dsl(
      id: 'kind',
      ask: topicText('injury_23'),
      why: topicText('injury_24'),
      options: [topicText('injury_25'), topicText('injury_26'), topicText('injury_27')],
      yesValue: '',
      noValue: '',
      read: const ReadCases([
        ReadCase('سر کار|حین کار|محل کار|کارگاه|کارخونه|کارخانه|داربست|دستگاه|پرس|کارفرما|حادثه (?:ی )?کار', 'work'),
        ReadCase('تصادف|راننده|زیر(?:م)? گرفت|کروکی|عابر|(?:ماشین|موتور)(?:ی)? (?:[^ ]+ ){0,2}(?:زد|خورد)', 'car'),
        ReadCase('جای دیگ|(?:خطا|قصور|اشتباه)(?:ی)? (?:پزشک|دکتر|جراح)|(?:پزشک|دکتر|جراح) (?:[^ ]+ ){0,2}(?:اشتباه|خطا|خراب)|سگ|چاله|گود', 'other'),
      ]),
      effect: const TxSwitch(
        'kind',
        {'work': Tx('injury_28'), 'car': Tx('injury_29')},
        fallback: Tx('injury_30'),
      ),
    ),
    Slot.dsl(
      id: 'safe',
      ask: topicText('injury_31'),
      why: topicText('injury_32'),
      options: [topicText('injury_33'), topicText('injury_34')],
      when: const FactEq('kind', 'work'),
      read: const ReadYn(
        'ایمنی (?:داشتیم|داده بودن|بود)|کلاه (?:داشتم|داده بودن)|آموزش (?:دیدم|داده بودن)|کمربند (?:داشتم|بسته بودم)|بله داده بودند',
        'ایمنی (?:نداشت|نبود|ندادن|نداده بودن)|کلاه (?:نداشتم|ندادن)|کمربند (?:نداشتم|نبود|ندادن)|آموزش (?:ندادن|ندیدم|نداده بودن)|حفاظ نداشت|هیچ(?:ی)? ندادن|بدون (?:ایمنی|کمربند|کلاه|حفاظ)|نداده بودن',
      ),
      effect: const TxCond(
          FactNo('safe'), Tx('injury_35'), Tx('injury_36')),
    ),
    Slot.dsl(
      id: 'report',
      ask: topicText('injury_37'),
      why: topicText('injury_38'),
      options: [topicText('injury_39'), topicText('injury_40')],
      read: const ReadYn(
        'پزشک(?:ی)? قانونی (?:رفتم|دارم|نظر داد)|گزارش (?:بازرس|حادثه|پلیس) (?:دارم|هست|نوشت)|کروکی (?:کشید|دارم)|صورت ?جلسه (?:شد|دارم)|طول درمان',
        'پزشک(?:ی)? قانونی نرفتم|گزارش(?:ی)? (?:ندارم|نشد|ننوشتن)|کروکی (?:نکشید|ندارم)|هنوز (?:نرفتم|هیچ کاری)',
      ),
      effect: const TxCond(
          FactYes('report'), Tx('injury_41'), Tx('injury_42')),
    ),
  ],
  opening: const Tx('injury_43'),
  issues: [
    Issue.dsl(
      id: 'beyond',
      chip: topicText('injury_44'),
      cues: 'غیر از دیه|بیشتر از دیه|هزینه درمان|نمیتونم کار کنم|خرج (?:درمان|بیمارستان)|بیکار شدم',
      body: const Tx('injury_45'),
    ),
    Issue.dsl(
      id: 'ins',
      chip: topicText('injury_46'),
      cues: 'تامین اجتماعی|غرامت|مستمری|بیمه (?:چی|چه)',
      when: const FactNot(FactEq('kind', 'car')),
      body: const Tx('injury_47'),
    ),
    Issue.dsl(
      id: 'boss',
      chip: topicText('injury_48'),
      cues: 'کارگر(?:ش| اون| شرکت| کس دیگ| یکی دیگ)|راننده(?:ی)? شرکت|مامور(?:ش)?|پیک',
      body: const Tx('injury_49'),
    ),
  ],
  follow: const {
    'next': TxCond(FactEq('kind', 'work'), Tx('injury_50'), Tx('injury_51')),
    'where': Tx('injury_52'),
    'evidence': Tx('injury_53'),
    'time': Tx('injury_54'),
    'chance': Tx('injury_55'),
    'cost': Tx('injury_56'),
  },
  drafts: const DraftRule.fixed(['complaint']),
);
