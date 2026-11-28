// موضوع: همسایه و آپارتمان.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic neighborTopic = Topic.dsl(
  id: 'neighbor',
  title: topicText('neighbor_0'),
  cues: {
    'همسایه': 3,
    // دیوار مشترک، نور گرفتن و ساخت بدون اجازه روی حیاط یا دیوار همسایه.
    'دیوار مشترک|دیوار (?:بین|بلندتر)|نور (?:خانه|خونه|ملک|منزل|حیاط|پنجره)[^؟]{0,15}(?:گرفت|بند|مسدود)': 5,
    'سر ?و ?صدا|صدای (?:بلند|آهنگ|موسیقی|مهمونی)|مزاحمت|مشاعات|مدیر ساختمان|واحد (?:بالایی|پایینی|روبرو)': 2,
    'پارکینگ|شارژ ساختمان|نشتی|نم (?:داده|زده)': 1,
  },
  anti: 'شوهر|طلاق|کارفرما',
  slots: [
    Slot.dsl(
      id: 'kind',
      ask: topicText('neighbor_1'),
      why: topicText('neighbor_2'),
      options: [topicText('neighbor_3'), topicText('neighbor_4'), topicText('neighbor_5')],
      read: const ReadCases([
        ReadCase('سر ?و ?صدا|صدای|آهنگ|موسیقی|مهمونی|پارتی|میکوب|داد و بیداد', 'noise'),
        ReadCase('نشتی|نم |آب (?:میده|میاد|چکه)|خسارت|خراب کرد|ترک', 'damage'),
        ReadCase('پارکینگ|مشاعات|راه ?پله|پشت ?بام|انباری|شارژ', 'common'),
      ]),
      yesValue: '',
      noValue: '',
    ),
    Slot.dsl(
      id: 'talked',
      ask: topicText('neighbor_6'),
      why: topicText('neighbor_7'),
      options: [topicText('neighbor_8'), topicText('neighbor_9')],
      read: const ReadYn(
        'گفتم|تذکر دادم|صحبت کردم|چند بار گفتم|حرف زدم|گوش نمیده|محل نمیذاره|فایده نداشت',
        'نگفتم|صحبت نکردم|چیزی نگفتم|روم نمیشه',
      ),
      effect: const TxCond(FactYes('talked'), Tx('neighbor_10'), Tx('neighbor_11')),
    ),
  ],
  opening: const Tx('neighbor_12'),
  issues: [
    Issue.dsl(
      id: 'police',
      chip: topicText('neighbor_13'),
      cues: 'پلیس|110|کلانتری|شکایت|کیفری',
      body: const Tx('neighbor_14'),
    ),
    Issue.dsl(
      id: 'damage',
      chip: topicText('neighbor_15'),
      cues: 'خسارت|نشتی|نم |تعمیر|خراب|هزینه(?:ش| اش)? (?:رو |را )?(?:نمیده|بده)',
      body: const Tx('neighbor_16'),
    ),
  ],
  follow: const {
    'next': Tx('neighbor_17'),
    'where': Tx('neighbor_18'),
    'cost': Tx('neighbor_19'),
    'evidence': Tx('neighbor_20'),
    'chance': Tx('neighbor_21'),
    'refuse': Tx('neighbor_22'),
  },
  drafts: const DraftRule.fixed(['formal_notice']),
);
