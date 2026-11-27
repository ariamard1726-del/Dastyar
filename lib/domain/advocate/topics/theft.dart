// موضوع: سرقت و دزدی (برداشتن مال دیگری بی‌اجازه، با یا بی‌زور).
//
// شماره مواد و مجازات دقیق در این موضوع عمداً نوشته نشده است: حدس عددی
// خطرناک است. پاسخ‌ها به جای عدد، به متن رسمی قانون و وکیل ارجاع می‌دهند.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic theftTopic = Topic(
  id: 'theft',
  title: topicText('theft_0'),
  cues: {
    'سرقت|دزدی|دزدیده|دزدیدن|دزدیدند|دزدیدم|سارق|دستبرد|دزدگیر|دزد(?:ا|ها)?': 5,
    'ربود|ربوده|ربودن|کش رفت|کش‌رفت|کش رفتن': 4,
    'قاپ(?:ید|یدن|یدند|یده)|کیف(?:م)? ?(?:رو |را )?(?:قاپ|زد|برد)|جیب ?بر|جیب(?:م| منو) (?:زد|زدن|رفت)': 4,
    'قفل (?:رو |را )?شکست|شکستن قفل|در (?:رو |را )?شکست|شکستن در|دزدی از (?:مغازه|خونه|خانه|انبار)': 4,
    'صندوق|گاوصندوق|کیف پول|پول(?:م| رو)? برداشت|وسایلم(?:و)? برد|طلاهام|طلاهایم|مال(?:م| رو)? برداشت': 2,
  },
  anti: 'متهم|اتهام|احضاریه|ازم شکایت|از من شکایت|علیه من|سرقفلی|حق کسب|کسب و پیشه|متهمم',
  slots: [
    Slot(
      id: 'proof',
      ask: topicText('theft_1'),
      why: topicText('theft_2'),
      options: [topicText('theft_3'), topicText('theft_4')],
      read: (n) => Sense.yn(
        n,
        'فیلم|دوربین|شاهد|دیده|شهود|عکس|ضبط',
        'نه|ندارم|نداریم|نبود|نیست',
      ),
      effect: (f) => f.yes('proof')
          ? topicText('theft_5')
          : topicText('theft_6'),
    ),
  ],
  issues: [],
  opening: (f) =>
      topicText('theft_7'),
  follow: {
    'next': (f) =>
        topicText('theft_8'),
    'where': (f) =>
        topicText('theft_9'),
    'evidence': (f) =>
        topicText('theft_10'),
    'cost': (f) =>
        topicText('theft_11'),
    'chance': (f) =>
        topicText('theft_12'),
    'deadline': (f) =>
        topicText('theft_13'),
  },
);
