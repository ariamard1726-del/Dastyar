// موضوع: وام و تسهیلات ازدواج.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic marriageTopic = Topic.dsl(
  id: 'marriage',
  title: topicText('marriage_0'),
  cues: {
    'وام ازدواج|تسهیلات ازدواج|صندوق (?:اندوخته )?ازدواج|ودیعه مسکن (?:جوانان|زوج)': 6,
    'وام (?:مسکن|اشتغال) (?:زوج|متاهل|جوان)': 4,
    'خوابگاه متاهل|مسکن (?:زوج|متاهل)|هدیه ازدواج|کمک ?هزینه ازدواج': 4,
  },
  recap: const [
    RecapItem(when: FactYes('refused'), text: Tx('marriage_1')),
    RecapItem(when: FactNo('refused'), text: Tx('marriage_2')),
  ],
  slots: [
    Slot.dsl(
      id: 'refused',
      ask: topicText('marriage_3'),
      why: topicText('marriage_4'),
      options: [topicText('marriage_5'), topicText('marriage_6')],
      read: const ReadYn(
        'رد (?:کرد|شد)|معطل|نمید(?:ن|ه)|امروز و فردا|میگن (?:بودجه|اعتبار|ضامن)|جواب نمید',
        'میخوام بدونم|میخواهم بدانم|هنوز (?:نرفتم|درخواست ندادم)|فقط سوال',
      ),
      effect: const TxCond(FactYes('refused'), Tx('marriage_7')),
    ),
  ],
  opening: const Tx('marriage_8'),
  issues: [
    Issue.dsl(
      id: 'housing',
      chip: topicText('marriage_9'),
      cues: 'ودیعه|مسکن|رهن',
      body: const Tx('marriage_10'),
    ),
    Issue.dsl(
      id: 'complain',
      chip: topicText('marriage_11'),
      cues: 'شکایت|اعتراض|ندادن|نمیدن|رد کرد',
      body: const Tx('marriage_12'),
    ),
  ],
  follow: const {
    'next': Tx('marriage_13'),
    'where': Tx('marriage_14'),
    'evidence': Tx('marriage_15'),
  },
);
