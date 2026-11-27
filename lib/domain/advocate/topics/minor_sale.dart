// موضوع: معامله با نوجوان یا کسی که به سن بلوغ نرسیده (اهلیت و اجازهٔ ولی).
//
// اعتبار معامله به سن دقیق، اجازهٔ ولی و نوع مال بستگی دارد؛ این موضوع
// قضاوت قطعی نمی‌کند و همیشه پیشنهاد می‌کند با وکیل تأیید شود.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic minorSaleTopic = Topic(
  id: 'minor_sale',
  title: topicText('minorSale_0'),
  // سن زیر ۱۸ شرط اصلی است (وزن بالا)؛ فعل فروش یا ولی به‌تنهایی کافی نیست.
  cues: {
    '(?<![0-9۰-۹])(?:1[0-7]|۱[۰-۷]|[0-9۰-۹]) ?ساله|سالشه|سالش (?:است|هست|بود)|سن(?:ش|اش)?:? (?<![0-9۰-۹])(?:1[0-7]|۱[۰-۷]|[0-9۰-۹])(?![0-9۰-۹])|زیر ?۱۸|کمتر از ۱۸|صغیر|نابالغ': 4,
    'بیع|معامله|فروختم|فروخته|فروش(?:م)?|خریدم|قول(?:نامه)?': 1,
    'اهلیت|بلوغ|اجازه (?:پدر|مادر|ولی)|پدرش|مادرش|سرپرستش': 1,
  },
  anti:
      'بانک|اجاره|کرایه|ضمانت|چک|طلاق|مهریه|ارث|حضانت|شرکت|سرقت|دزد|کلاهبرداری|آپارتمان|ساختمان|ملک|زمین|خونه|خانه',
  slots: [
    Slot(
      id: 'guardian',
      ask: topicText('minorSale_1'),
      why: topicText('minorSale_2'),
      options: [topicText('minorSale_3'), topicText('minorSale_4')],
      read: (n) => Sense.yn(
        n,
        'خبر داشت|اجازه داد|اجازه داده|راضی بود|خبر داشتن|اجازه دادن',
        'خبر نداشت|نمی‌دانست|نمیدونست|بی‌خبر|اجازه نداد|نداد',
      ),
      effect: (f) => f.yes('guardian')
          ? topicText('minorSale_5')
          : topicText('minorSale_6'),
    ),
  ],
  issues: [],
  opening: (f) =>
      topicText('minorSale_7'),
  follow: {
    'next': (f) =>
        topicText('minorSale_8'),
    'evidence': (f) =>
        topicText('minorSale_9'),
    'chance': (f) =>
        topicText('minorSale_10'),
    'where': (f) =>
        topicText('minorSale_11'),
    'cost': (f) =>
        topicText('minorSale_12'),
    'deadline': (f) =>
        topicText('minorSale_13'),
  },
);
