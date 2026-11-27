// موضوع: وام و تسهیلات ازدواج.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic marriageTopic = Topic(
  id: 'marriage',
  title: topicText('marriage_0'),
  cues: {
    'وام ازدواج|تسهیلات ازدواج|صندوق (?:اندوخته )?ازدواج|ودیعه مسکن (?:جوانان|زوج)': 6,
    'وام (?:مسکن|اشتغال) (?:زوج|متاهل|جوان)': 4,
    'خوابگاه متاهل|مسکن (?:زوج|متاهل)|هدیه ازدواج|کمک ?هزینه ازدواج': 4,
  },
  recap: (f) => [
    if (f.yes('refused')) topicText('marriage_1'),
    if (f.no('refused')) topicText('marriage_2'),
  ],
  slots: [
    Slot(
      id: 'refused',
      ask: topicText('marriage_3'),
      why: topicText('marriage_4'),
      options: [topicText('marriage_5'), topicText('marriage_6')],
      read: (n) => Sense.yn(
        n,
        'رد (?:کرد|شد)|معطل|نمید(?:ن|ه)|امروز و فردا|میگن (?:بودجه|اعتبار|ضامن)|جواب نمید',
        'میخوام بدونم|میخواهم بدانم|هنوز (?:نرفتم|درخواست ندادم)|فقط سوال',
      ),
      effect: (f) => f.yes('refused')
          ? topicText('marriage_7')
          : '',
    ),
  ],
  opening: (f) =>
      topicText('marriage_8'),
  issues: [
    Issue(
      id: 'housing',
      chip: topicText('marriage_9'),
      cues: 'ودیعه|مسکن|رهن',
      body: (f) =>
          topicText('marriage_10'),
    ),
    Issue(
      id: 'complain',
      chip: topicText('marriage_11'),
      cues: 'شکایت|اعتراض|ندادن|نمیدن|رد کرد',
      body: (f) =>
          topicText('marriage_12'),
    ),
  ],
  follow: {
    'next': (f) =>
        topicText('marriage_13'),
    'where': (f) =>
        topicText('marriage_14'),
    'evidence': (f) =>
        topicText('marriage_15'),
  },
);
