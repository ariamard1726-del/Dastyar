// موضوع: ضمانت.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic guaranteeTopic = Topic.dsl(
  id: 'guarantee',
  title: topicText('guarantee_0'),
  cues: {
    'ضمانت ?نامه (?:دادم|دادیم|امضا کردم|کردم)|ضمانت(?:م)? (?:رو )?(?:دادم|دادیم)': 5,
    'ضامن(?:ش)? (?:[^ ]+ ){0,3}(?:شدم|شده بودم|هستم|بودم)|ضامن (?:وام|کسی|دوستم|برادرم|همکارم)|ضمانت[^ ]* (?:کردم|کرده بودم)': 5,
    'از ضمانت (?:[^ ]+ ){0,2}(?:دربیام|در بیام|خارج|بیرون|انصراف)|ضمانت(?:م)? (?:رو )?(?:پس بگیرم|لغو)': 3,
    'ضامن|ضمانت': 2,
  },
  anti: 'چک|گارانتی|ضمانت ?نامه (?:کالا|محصول|گوشی|خودرو|ماشین|لوازم|دستگاه)|کالا|خریدم|وام ازدواج',
  recap: const [
    RecapItem(when: FactYes('paid'), text: Tx('guarantee_1')),
    RecapItem(when: FactNo('paid'), text: Tx('guarantee_2')),
    RecapItem(when: FactYes('asked'), text: Tx('guarantee_3')),
    RecapItem(when: FactNo('asked'), text: Tx('guarantee_4')),
  ],
  claims: [
    Claim.dsl(
      goal: topicText('guarantee_5'),
      elements: [
        Element.dsl(
          topicText('guarantee_6'),
          const FactTri('paid'),
          ifNo: topicText('guarantee_7'),
        ),
        Element.dsl(
          topicText('guarantee_8'),
          const FactTri('asked'),
          ifNo: topicText('guarantee_9'),
        ),
        Element.dsl(
          topicText('guarantee_10'),
          const FactConst(null),
        ),
      ],
      win: const Tx('guarantee_11'),
      counter: const Tx('guarantee_12'),
    ),
  ],
  slots: [
    Slot.dsl(
      id: 'paid',
      ask: topicText('guarantee_13'),
      why: topicText('guarantee_14'),
      options: [topicText('guarantee_15'), topicText('guarantee_16')],
      read: const ReadYn(
        'از (?:حقوقم|حسابم|من) (?:[^ ]+ ){0,2}(?:کم|کسر|برداشت|گرفت)|قسط(?:ش| هاش)? (?:رو )?(?:دادم|میدم)|پرداخت کردم|دادم به بانک|حسابمو بستن',
        'هنوز (?:نه|نگرفتن|ندادم|کم نکردن)|فقط (?:اخطار|نامه|پیامک|زنگ)',
      ),
      effect: const TxCond(
          FactYes('paid'), Tx('guarantee_17'), Tx('guarantee_18')),
    ),
    Slot.dsl(
      id: 'asked',
      ask: topicText('guarantee_19'),
      why: topicText('guarantee_20'),
      options: [topicText('guarantee_21'), topicText('guarantee_22')],
      read: const ReadYn(
        'خودش (?:خواست|گفت|خواهش)|خواهش کرد|ازم خواست',
        'خودش نخواست|بدون اطلاع',
      ),
    ),
  ],
  opening: const Tx('guarantee_23'),
  issues: [
    Issue.dsl(
      id: 'first',
      chip: topicText('guarantee_24'),
      cues: 'چرا (?:سراغ|از) من|اول (?:از )?خودش|خودش (?:داره|پولداره)|به من چه',
      body: const Tx('guarantee_25'),
    ),
    Issue.dsl(
      id: 'exit',
      chip: topicText('guarantee_26'),
      cues: 'بیرون (?:بیام|بیایم)|ضمانتم(?: رو)? (?:بردارم|پس بگیرم|لغو)|آزاد (?:شم|بشم)|ضامن دیگه|جایگزین',
      body: const Tx('guarantee_27'),
    ),
  ],
  follow: const {
    'next': Tx('guarantee_28'),
    'where': Tx('guarantee_29'),
    'evidence': Tx('guarantee_30'),
    'chance': Tx('guarantee_31'),
    'cost': Tx('guarantee_32'),
  },
  drafts: const DraftRule.fixed(['formal_notice', 'demand_money']),
);
