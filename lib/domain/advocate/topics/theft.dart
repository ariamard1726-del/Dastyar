// موضوع: سرقت و دزدی (برداشتن مال دیگری بی‌اجازه، با یا بی‌زور).
//
// شماره مواد و مجازات دقیق در این موضوع عمداً نوشته نشده است: حدس عددی
// خطرناک است. پاسخ‌ها به جای عدد، به متن رسمی قانون و وکیل ارجاع می‌دهند.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic theftTopic = Topic.dsl(
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
    Slot.dsl(
      id: 'proof',
      ask: topicText('theft_1'),
      why: topicText('theft_2'),
      options: [topicText('theft_3'), topicText('theft_4')],
      read: const ReadYn(
        'فیلم|دوربین|شاهد|دیده|شهود|عکس|ضبط',
        'نه|ندارم|نداریم|نبود|نیست',
      ),
      effect: const TxCond(FactYes('proof'), Tx('theft_5'), Tx('theft_6')),
    ),
  ],
  issues: const [],
  opening: const Tx('theft_7'),
  follow: const {
    'next': Tx('theft_8'),
    'where': Tx('theft_9'),
    'evidence': Tx('theft_10'),
    'cost': Tx('theft_11'),
    'chance': Tx('theft_12'),
    'deadline': Tx('theft_13'),
  },
);
