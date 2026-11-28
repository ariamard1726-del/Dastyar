// موضوع: فروش خودرو یا کالا و عدم تحویل آن پس از پرداخت ثمن.
//
// مواد استنادی (همه از متن قانون مدنی موجود در assets/laws تطبیق داده شده‌اند):
// - ماده ۲۱۹: قرارداد برای طرفین لازم‌الاتباع است.
// - بند ۳ ماده ۳۶۲: فروشنده ملزم به تسلیم مبیع است.
// - ماده ۳۷۶: در صورت تأخیر در تسلیم، امتناع فروشنده قابل اجبار به تسلیم است.
// - مواد ۲۲۱ و ۲۲۶–۲۲۷: خسارت ناشی از عدم انجام تعهد.
// فسخ قرارداد و استرداد ثمن در متن موجود نیست؛ پاسخ آن را به وکیل ارجاع می‌دهد.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic saleTopic = Topic.dsl(
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
    Slot.dsl(
      id: 'proof',
      ask: topicText('sale_1'),
      why: topicText('sale_2'),
      options: [topicText('sale_3'), topicText('sale_4')],
      read: const ReadYn(
        'مبایعه|قولنامه|رسید|فیش|پیامک|قرارداد|کتبی|مدرک|سند|بله',
        'نه|ندارم|نداریم|نداشتم|نیست|نبود',
      ),
      effect: const TxCond(FactYes('proof'), Tx('sale_5'), Tx('sale_6')),
    ),
  ],
  issues: const [],
  opening: const Tx('sale_7'),
  follow: const {
    'next': Tx('sale_8'),
    'where': Tx('sale_9'),
    'evidence': Tx('sale_10'),
    'cost': Tx('sale_11'),
    'chance': Tx('sale_12'),
    'deadline': Tx('sale_13'),
  },
);
