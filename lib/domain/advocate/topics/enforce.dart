// موضوع: اجرای حکم.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic enforceTopic = Topic.dsl(
  id: 'enforce',
  title: topicText('enforce_0'),
  cues: {
    'اجرای (?:حکم|احکام|رای)|حکم(?:م| رو)? اجرا|رای(?:م| رو)? اجرا': 5,
    'حکم (?:گرفتم|قطعی|به نفع)|رای (?:گرفتم|قطعی|به نفع)|محکوم (?:شد|کرد)|محکومیت': 4,
    'مزایده|توقیف (?:اموال|حساب|حقوق|ماشین|خونه|ملک)|حساب(?:م|مو| من)[^ ]* (?:رو |را )?(?:بستن|مسدود|توقیف)|حقوقم[^ ]* (?:رو |را )?(?:توقیف|کسر)': 4,
    'اجرائیه (?:گرفتم|صادر|اومد|دارم)': 4,
    '(?:ماشین|خونه|ملک|حساب|حقوق|اموال|مغازه)(?:م|مو|مون| من)(?: [^ ]+){0,5} (?:توقیف|مسدود)': 4,
    'اجرائیه|دایره اجرا|واحد اجرا': 2,
  },
  anti: 'چک|طلاق|مهریه|احضاریه|ضامن',
  recap: const [
    RecapItem(when: FactEq('side', 'winner'), text: Tx('enforce_1')),
    RecapItem(when: FactEq('side', 'loser'), text: Tx('enforce_2')),
    RecapItem(when: FactEq('side', 'third'), text: Tx('enforce_3')),
    RecapItem(when: FactYes('final'), text: Tx('enforce_4')),
    RecapItem(when: FactNo('final'), text: Tx('enforce_5')),
    RecapItem(when: FactYes('assets'), text: Tx('enforce_6')),
    RecapItem(when: FactNo('assets'), text: Tx('enforce_7')),
  ],
  claims: [
    Claim.dsl(
      goal: topicText('enforce_8'),
      when: const FactNot(FactIn('side', ['loser', 'third'])),
      elements: [
        Element.dsl(
          topicText('enforce_9'),
          const FactTri('final'),
          ifNo: topicText('enforce_10'),
        ),
        Element.dsl(
          topicText('enforce_11'),
          const FactConst(null),
        ),
        Element.dsl(
          topicText('enforce_12'),
          // سراغ‌نداشتنِ مال یعنی «هنوز معلوم نیست»، نه اینکه شرط برقرار نیست.
          const FactTriIf(FactYes('assets'), true),
        ),
      ],
      win: const Tx('enforce_13'),
      counter: const Tx('enforce_14'),
    ),
  ],
  slots: [
    Slot.dsl(
      id: 'side',
      ask: topicText('enforce_15'),
      why: topicText('enforce_16'),
      options: [topicText('enforce_17'), topicText('enforce_18'), topicText('enforce_19')],
      yesValue: '',
      noValue: '',
      read: const ReadCases([
        ReadCase('به ?جای (?:دیگری|یکی|کس)|بدهی (?:برادر|پدر|شوهر|دیگری|یکی دیگه)|مال من(?:ه| است)? (?:ولی|اما)|ربطی به من نداره|شخص ثالث', 'third'),
        ReadCase('علیه من|محکوم شدم|محکومم کرد|حساب(?:م| من)[^ ]* (?:رو |را )?(?:بستن|مسدود|توقیف)|حقوقم[^ ]* (?:رو |را )?(?:توقیف|کسر)|(?:ماشینم|خونم|خونه ام|اموالم)[^ ]* (?:رو |را )?توقیف|باید (?:بدم|بپردازم)', 'loser'),
        ReadCase('به نفع (?:من|م)|حکم گرفتم|رای گرفتم|محکوم (?:شد |شده)|نمیده|نمیپردازه|اجرا نمیشه|طلبم', 'winner'),
      ]),
      effect: const TxSwitch('side', {
        'loser': Tx('enforce_20'),
        'third': Tx('enforce_21'),
      }),
    ),
    Slot.dsl(
      id: 'final',
      ask: topicText('enforce_22'),
      why: topicText('enforce_23'),
      options: [topicText('enforce_24'), topicText('enforce_25')],
      when: const FactEq('side', 'winner'),
      read: const ReadYn(
        'قطعی (?:شد|است|هست)|تجدید ?نظر(?:م| هم)? (?:تایید|رد شد)|اجرائیه (?:صادر|گرفتم|اومد)',
        'قطعی (?:نشد|نیست)|هنوز (?:بدوی|تجدید)|تجدید ?نظر (?:داده|خواست|کرد)|اعتراض (?:کرده|داده)',
      ),
      effect: const TxCond(FactYes('final'), Tx('enforce_26'), Tx('enforce_27')),
    ),
    Slot.dsl(
      id: 'assets',
      ask: topicText('enforce_28'),
      why: topicText('enforce_29'),
      options: [topicText('enforce_30'), topicText('enforce_31')],
      when: const FactEq('side', 'winner'),
      read: const ReadYn(
        'ماشین داره|خونه داره|ملک داره|مغازه داره|حقوق (?:میگیره|بگیره)|کارمند|حساب داره|سراغ دارم|پولداره|وضعش خوبه',
        'هیچی نداره|چیزی نداره|به نام(?:ش)? (?:نیست|چیزی)|سراغ ندارم|نمیدونم چی داره|همه رو (?:زده|کرده) به نام',
      ),
      effect: const TxCond(FactYes('assets'), Tx('enforce_32'), Tx('enforce_33')),
    ),
  ],
  opening: const Tx('enforce_34'),
  issues: [
    Issue.dsl(
      id: 'salary',
      chip: topicText('enforce_35'),
      cues: 'حقوق|کسر (?:از|میشه)|یک ?چهارم|یک ?سوم|ربع|ثلث',
      body: const Tx('enforce_36'),
    ),
    Issue.dsl(
      id: 'exempt',
      chip: topicText('enforce_37'),
      cues: 'خونه(?:م| ام)? (?:رو )?(?:میگیرن|میفروشن|توقیف)|مستثنیات|وسایل (?:زندگی|خونه)|ابزار کار|اثاث',
      body: const Tx('enforce_38'),
    ),
    Issue.dsl(
      id: 'install',
      chip: topicText('enforce_39'),
      cues: 'قسط|اعسار|ندارم (?:بدم|بپردازم)|نمیتونم (?:بدم|بپردازم)|تقسیط',
      body: const Tx('enforce_40'),
    ),
  ],
  follow: const {
    'next': TxCond(FactEq('side', 'loser'), Tx('enforce_41'), Tx('enforce_42')),
    'where': Tx('enforce_43'),
    'cost': Tx('enforce_44'),
    'time': Tx('enforce_45'),
    'chance': Tx('enforce_46'),
    'refuse': Tx('enforce_47'),
  },
  drafts: const DraftRule.when(FactEq('side', 'loser'), thenIds: ['insolvency']),
);
