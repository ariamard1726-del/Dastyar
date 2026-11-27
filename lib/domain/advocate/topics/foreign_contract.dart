// موضوع: قرارداد با شرکت خارجی (بدون شعبه در ایران)، قانون حاکم و داوری.
//
// مبنای حقوقی (با متن یا منبع معتبر بررسی شده):
// - ماده ۱۰ قانون مدنی: قراردادهای خصوصی نافذ است مگر مخالف صریح قانون.
// - ماده ۹۶۸ قانون مدنی: تعهدات تابع قانون محل وقوع عقد است، مگر متعاقدین
//   اتباع خارجه باشند و قانون دیگری را صریحاً یا ضمناً حاکم کرده باشند.
// - قانون داوری تجاری بین‌المللی ۱۳۷۶: ماده ۱ (ب) تعریف داوری بین‌المللی
//   (تابعیت یکی از طرفین)، ماده ۱ (ج) شرط داوری یا قرارداد جداگانه، ماده ۲
//   (قلمرو، از جمله «خدمات مشاوره‌ای»)، ماده ۱۶ (صلاحیت داور)، ماده ۲۷ (قانون
//   حاکم در صورت سکوت طرفین).
// متن کامل این قانون در بانک قوانین برنامه نیست؛ شماره‌ها را هنگام اقدام
// با منبع رسمی یا وکیل بسنجید.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic foreignContractTopic = Topic(
  id: 'foreign_contract',
  title: topicText('foreignContract_0'),
  cues: {
    'شرکت(?:ی|های)? خارج(?:ی|از کشور)|خارجی (?:ه )?(?:بدون|که) شعبه|شعبه (?:ای )?در ایران ندار|بدون شعبه': 5,
    'شرکت(?:ی)? (?:آلمانی|انگلیسی|آمریکایی|ترکی|ترکیه ای|چینی|اماراتی|فرانسوی|کانادایی|روسی|هندی)': 4,
    'قانون حاکم|داوری بین ?المللی|داوری خارجی|دادگاه (?:ی )?(?:خارج|انگلیس|آمریکا|دبی|لندن)': 4,
    'قرارداد مشاوره|مشاوره (?:ای|ی)|تفسیر (?:یکی از )?بند|بند (?:های )?قرارداد': 2,
  },
  anti: 'کارفرما|حقوق معوق|اجاره|مستاجر|موجر|چک|طلاق|همسر|کرایه|دزد|سرقت|بیمه',
  slots: [
    Slot(
      id: 'clause',
      ask: topicText('foreignContract_1'),
      why: topicText('foreignContract_2'),
      options: [topicText('foreignContract_3'), topicText('foreignContract_4'), topicText('foreignContract_5')],
      read: (n) {
        if (Sense.has(n, 'داوری|آربیتراژ|آربیتر')) return 'arb';
        if (Sense.has(n, 'قانون حاکم|حاکم است|تابع قانون|قانون انگلیس|قانون آلمان|قانون امارات|قانون انگلستان|قانون دیگر')) return 'law';
        if (Sense.has(n, 'نوشته نشده|چیزی ننوشته|بندی نداریم|هیچ بندی|ننوشتیم|نداریم|ندارد')) return 'none';
        return null;
      },
      effect: (f) => f.eq('clause', 'arb')
          ? topicText('foreignContract_6')
          : f.eq('clause', 'law')
              ? topicText('foreignContract_7')
              : topicText('foreignContract_8'),
    ),
  ],
  issues: [],
  opening: (f) =>
      topicText('foreignContract_9'),
  follow: {
    'next': (f) =>
        topicText('foreignContract_10'),
    'where': (f) =>
        topicText('foreignContract_11'),
    'evidence': (f) =>
        topicText('foreignContract_12'),
    'cost': (f) =>
        topicText('foreignContract_13'),
    'chance': (f) =>
        topicText('foreignContract_14'),
    'deadline': (f) =>
        topicText('foreignContract_15'),
  },
);
