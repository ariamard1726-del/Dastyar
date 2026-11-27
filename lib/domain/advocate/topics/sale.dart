// موضوع: فروش خودرو یا کالا و عدم تحویل آن پس از پرداخت ثمن.
//
// مواد استنادی (همه از متن قانون مدنی موجود در assets/laws تطبیق داده شده‌اند):
// - ماده ۲۱۹: قرارداد برای طرفین لازم‌الاتباع است.
// - بند ۳ ماده ۳۶۲: فروشنده ملزم به تسلیم مبیع است.
// - ماده ۳۷۶: در صورت تأخیر در تسلیم، امتناع فروشنده قابل اجبار به تسلیم است.
// - مواد ۲۲۱ و ۲۲۶–۲۲۷: خسارت ناشی از عدم انجام تعهد.
// فسخ قرارداد و استرداد ثمن در متن موجود نیست؛ پاسخ آن را به وکیل ارجاع می‌دهد.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic saleTopic = Topic(
  id: 'sale',
  title: topicText('sale_0'),
  cues: {
    'فروشنده|مبایعه|بیع(?: |\$)|قولنامه|قرارداد (?:فروش|خرید)': 3,
    'خودرو|ماشین|اتومبیل|پراید|پژو|سمند|موتور': 2,
    'تحویل (?:نمی|نداد|نده)|ندادن|تحویل ندا|ماشین رو نمیده|ماشینو نمیده': 4,
    'پول (?:رو |را )?(?:دادم|دادیم|واریز)|پرداخت (?:کردم|کرده)|ثمن|بیعانه|پیش ?پرداخت': 3,
  },
  anti:
      'اجاره|مستاجر|موجر|چک|طلاق|مهریه|کارفرما|حقوق معوق|حقوقم|دستمزد|سرقت|دزد|تصادف|کتک|تهدید|ملک|آپارتمان',
  slots: [
    Slot(
      id: 'proof',
      ask:
          topicText('sale_1'),
      why:
          topicText('sale_2'),
      options: [topicText('sale_3'), topicText('sale_4')],
      read: (n) => Sense.yn(
        n,
        'مبایعه|قولنامه|رسید|فیش|پیامک|قرارداد|کتبی|مدرک|سند|بله',
        'نه|ندارم|نداریم|نداشتم|نیست|نبود',
      ),
      effect: (f) => f.yes('proof')
          ? topicText('sale_5')
          : topicText('sale_6'),
    ),
  ],
  issues: [],
  opening: (f) =>
      topicText('sale_7'),
  follow: {
    'next': (f) =>
        topicText('sale_8'),
    'where': (f) =>
        topicText('sale_9'),
    'evidence': (f) =>
        topicText('sale_10'),
    'cost': (f) =>
        topicText('sale_11'),
    'chance': (f) =>
        topicText('sale_12'),
    'deadline': (f) =>
        topicText('sale_13'),
  },
);
