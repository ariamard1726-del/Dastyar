// موضوع: همسایه و آپارتمان.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic neighborTopic = Topic(
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
    Slot(
      id: 'kind',
      ask: topicText('neighbor_1'),
      why: topicText('neighbor_2'),
      options: [topicText('neighbor_3'), topicText('neighbor_4'), topicText('neighbor_5')],
      read: (n) {
        if (Sense.has(n, 'سر ?و ?صدا|صدای|آهنگ|موسیقی|مهمونی|پارتی|میکوب|داد و بیداد')) return 'noise';
        if (Sense.has(n, 'نشتی|نم |آب (?:میده|میاد|چکه)|خسارت|خراب کرد|ترک')) return 'damage';
        if (Sense.has(n, 'پارکینگ|مشاعات|راه ?پله|پشت ?بام|انباری|شارژ')) return 'common';
        return null;
      },
      yesValue: '',
      noValue: '',
    ),
    Slot(
      id: 'talked',
      ask: topicText('neighbor_6'),
      why: topicText('neighbor_7'),
      options: [topicText('neighbor_8'), topicText('neighbor_9')],
      read: (n) => Sense.yn(
        n,
        'گفتم|تذکر دادم|صحبت کردم|چند بار گفتم|حرف زدم|گوش نمیده|محل نمیذاره|فایده نداشت',
        'نگفتم|صحبت نکردم|چیزی نگفتم|روم نمیشه',
      ),
      effect: (f) => f.yes('talked')
          ? topicText('neighbor_10')
          : topicText('neighbor_11'),
    ),
  ],
  opening: (f) =>
      topicText('neighbor_12'),
  issues: [
    Issue(
      id: 'police',
      chip: topicText('neighbor_13'),
      cues: 'پلیس|110|کلانتری|شکایت|کیفری',
      body: (f) =>
          topicText('neighbor_14'),
    ),
    Issue(
      id: 'damage',
      chip: topicText('neighbor_15'),
      cues: 'خسارت|نشتی|نم |تعمیر|خراب|هزینه(?:ش| اش)? (?:رو |را )?(?:نمیده|بده)',
      body: (f) =>
          topicText('neighbor_16'),
    ),
  ],
  follow: {
    'next': (f) =>
        topicText('neighbor_17'),
    'where': (f) =>
        topicText('neighbor_18'),
    'cost': (f) =>
        topicText('neighbor_19'),
    'evidence': (f) =>
        topicText('neighbor_20'),
    'chance': (f) =>
        topicText('neighbor_21'),
    'refuse': (f) =>
        topicText('neighbor_22'),
  },
  drafts: (f) => const ['formal_notice'],
);
