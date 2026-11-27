// موضوع: ضمانت.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic guaranteeTopic = Topic(
  id: 'guarantee',
  title: topicText('guarantee_0'),
  cues: {
    'ضمانت ?نامه (?:دادم|دادیم|امضا کردم|کردم)|ضمانت(?:م)? (?:رو )?(?:دادم|دادیم)': 5,
    'ضامن(?:ش)? (?:[^ ]+ ){0,3}(?:شدم|شده بودم|هستم|بودم)|ضامن (?:وام|کسی|دوستم|برادرم|همکارم)|ضمانت[^ ]* (?:کردم|کرده بودم)': 5,
    'از ضمانت (?:[^ ]+ ){0,2}(?:دربیام|در بیام|خارج|بیرون|انصراف)|ضمانت(?:م)? (?:رو )?(?:پس بگیرم|لغو)': 3,
    'ضامن|ضمانت': 2,
  },
  anti: 'چک|گارانتی|ضمانت ?نامه (?:کالا|محصول|گوشی|خودرو|ماشین|لوازم|دستگاه)|کالا|خریدم|وام ازدواج',
  recap: (f) => [
    if (f.yes('paid')) topicText('guarantee_1'),
    if (f.no('paid')) topicText('guarantee_2'),
    if (f.yes('asked')) topicText('guarantee_3'),
    if (f.no('asked')) topicText('guarantee_4'),
  ],
  claims: [
    Claim(
      goal: topicText('guarantee_5'),
      elements: [
        Element(
          topicText('guarantee_6'),
          (f) => f.tri('paid'),
          ifNo:
              topicText('guarantee_7'),
        ),
        Element(
          topicText('guarantee_8'),
          (f) => f.tri('asked'),
          ifNo:
              topicText('guarantee_9'),
        ),
        Element(
          topicText('guarantee_10'),
          (f) => null,
        ),
      ],
      win: (f) =>
          topicText('guarantee_11'),
      counter: (f) =>
          topicText('guarantee_12'),
    ),
  ],
  slots: [
    Slot(
      id: 'paid',
      ask: topicText('guarantee_13'),
      why: topicText('guarantee_14'),
      options: [topicText('guarantee_15'), topicText('guarantee_16')],
      read: (n) => Sense.yn(
        n,
        'از (?:حقوقم|حسابم|من) (?:[^ ]+ ){0,2}(?:کم|کسر|برداشت|گرفت)|قسط(?:ش| هاش)? (?:رو )?(?:دادم|میدم)|پرداخت کردم|دادم به بانک|حسابمو بستن',
        'هنوز (?:نه|نگرفتن|ندادم|کم نکردن)|فقط (?:اخطار|نامه|پیامک|زنگ)',
      ),
      effect: (f) => f.yes('paid')
          ? topicText('guarantee_17')
          : topicText('guarantee_18'),
    ),
    Slot(
      id: 'asked',
      ask: topicText('guarantee_19'),
      why: topicText('guarantee_20'),
      options: [topicText('guarantee_21'), topicText('guarantee_22')],
      read: (n) => Sense.yn(
        n,
        'خودش (?:خواست|گفت|خواهش)|خواهش کرد|ازم خواست',
        'خودش نخواست|بدون اطلاع',
      ),
    ),
  ],
  opening: (f) =>
      topicText('guarantee_23'),
  issues: [
    Issue(
      id: 'first',
      chip: topicText('guarantee_24'),
      cues: 'چرا (?:سراغ|از) من|اول (?:از )?خودش|خودش (?:داره|پولداره)|به من چه',
      body: (f) =>
          topicText('guarantee_25'),
    ),
    Issue(
      id: 'exit',
      chip: topicText('guarantee_26'),
      cues: 'بیرون (?:بیام|بیایم)|ضمانتم(?: رو)? (?:بردارم|پس بگیرم|لغو)|آزاد (?:شم|بشم)|ضامن دیگه|جایگزین',
      body: (f) =>
          topicText('guarantee_27'),
    ),
  ],
  follow: {
    'next': (f) =>
        topicText('guarantee_28'),
    'where': (f) =>
        topicText('guarantee_29'),
    'evidence': (f) =>
        topicText('guarantee_30'),
    'chance': (f) =>
        topicText('guarantee_31'),
    'cost': (f) =>
        topicText('guarantee_32'),
  },
  drafts: (f) => const ['formal_notice', 'demand_money'],
);
