// موضوع: خرید کالا و خدمات.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic consumerTopic = Topic(
  id: 'consumer',
  title: topicText('consumer_0'),
  cues: {
    'گارانتی|ضمانت ?نامه|خدمات پس از فروش|حقوق مصرف ?کننده': 3,
    'معیوب|خراب (?:بود|از آب|در ?اومد|دراومد|شد)|تقلبی|اصل نبود|پس نمیگیر|عوض نمیکن|تعویض نمیکن|مرجوع': 3,
    '(?:جنس|کالا|رنگ|سایز|مدل)(?:ش)? (?:[^ ]+ ){0,3}فرق (?:داشت|داره|میکرد)|درست تعمیر نکرد|پول اضافه گرفت|هزینه اضافه گرفت': 3,
    'گرون ?فروشی|گران ?فروشی|کم ?فروشی|تعزیرات': 3,
    'خریدم|خریده بودم|فروشنده|مغازه ?دار|فروشگاه|نمایندگی|تعمیرگاه': 1,
  },
  anti: 'چک|صاحبخونه|مستاجر|کارفرما|شوهر|طلاق|ملک|زمین|آپارتمان|سند',
  recap: (f) => [
    if (f.yes('proof')) topicText('consumer_1'),
    if (f.no('proof')) topicText('consumer_2'),
    if (f.yes('told')) topicText('consumer_3'),
    if (f.no('told')) topicText('consumer_4'),
    if (f.eq('want', 'refund')) topicText('consumer_5'),
    if (f.eq('want', 'replace')) topicText('consumer_6'),
    if (f.eq('want', 'repair')) topicText('consumer_7'),
  ],
  claims: [
    Claim(
      goal: topicText('consumer_8'),
      elements: [
        Element(
          topicText('consumer_9'),
          (f) => f.tri('proof'),
          ifNo:
              topicText('consumer_10'),
        ),
        Element(
          topicText('consumer_11'),
          (f) => null,
        ),
        Element(
          topicText('consumer_12'),
          (f) => f.tri('told'),
          ifNo:
              topicText('consumer_13'),
        ),
      ],
      win: (f) =>
          topicText('consumer_14'),
      counter: (f) =>
          topicText('consumer_15'),
    ),
  ],
  slots: [
    Slot(
      id: 'proof',
      ask: topicText('consumer_16'),
      why: topicText('consumer_17'),
      options: [topicText('consumer_18'), topicText('consumer_19')],
      read: (n) => Sense.yn(
        n,
        'فاکتور (?:دارم|داد|گرفتم)|ضمانت ?نامه (?:دارم|داره|داد)|گارانتی (?:دارم|داره|داشت)|رسید (?:دارم|گرفتم)|کارت کشیدم',
        'فاکتور (?:ندارم|نداد|نگرفتم)|رسید (?:ندارم|نگرفتم)|بدون فاکتور|گارانتی نداشت',
      ),
      effect: (f) => f.yes('proof')
          ? topicText('consumer_20')
          : topicText('consumer_21'),
    ),
    Slot(
      id: 'told',
      ask: topicText('consumer_22'),
      why: topicText('consumer_23'),
      options: [topicText('consumer_24'), topicText('consumer_25')],
      read: (n) => Sense.yn(
        n,
        'گفتم|بردم(?:ش)? (?:پیش|مغازه|نمایندگی)|قبول نکرد|قبول نمیکن|پس نمیگیره|عوض نمیکن|زیر بار نمیره|جواب نمیده|میگه (?:به من|تقصیر|خودت)',
        'نگفتم|نگفته ام|هنوز (?:نرفتم|نبردم)|خبر ندادم',
      ),
      effect: (f) => f.yes('told')
          ? topicText('consumer_26')
          : topicText('consumer_27'),
    ),
    Slot(
      id: 'want',
      ask: topicText('consumer_28'),
      why: topicText('consumer_29'),
      options: [topicText('consumer_30'), topicText('consumer_31'), topicText('consumer_32')],
      yesValue: '',
      noValue: '',
      read: (n) {
        if (Sense.has(n, 'پول(?:م|مو|م رو| را)? ?(?:پس|برگرد)|پس بده|فسخ|مرجوع')) return 'refund';
        if (Sense.has(n, 'عوض|تعویض|سالم(?:ش)? (?:رو )?بده|یکی دیگه')) return 'replace';
        if (Sense.has(n, 'تعمیر|درست(?:ش)? کن')) return 'repair';
        return null;
      },
      effect: (f) => f.eq('want', 'refund')
          ? topicText('consumer_33')
          : '',
    ),
  ],
  opening: (f) =>
      topicText('consumer_34'),
  issues: [
    Issue(
      id: 'where',
      chip: topicText('consumer_35'),
      cues: 'کجا (?:شکایت|برم)|تعزیرات|۱۲۴|124|صمت|اتحادیه|شکایت کنم',
      body: (f) =>
          topicText('consumer_36'),
    ),
    Issue(
      id: 'ad',
      chip: topicText('consumer_37'),
      cues: 'تبلیغ|دروغ گفت|گول(?:م)? زد|فریب|چیز دیگه ای? (?:بود|گفته بود)|مشخصات(?:ش)? فرق',
      body: (f) =>
          topicText('consumer_38'),
    ),
    Issue(
      id: 'service',
      chip: topicText('consumer_39'),
      cues: 'قطعه|خدمات پس از فروش|تعمیرگاه|سرویس نمید',
      body: (f) =>
          topicText('consumer_40'),
    ),
  ],
  follow: {
    'next': (f) =>
        topicText('consumer_41'),
    'where': (f) =>
        topicText('consumer_42'),
    'evidence': (f) =>
        topicText('consumer_43'),
    'cost': (f) =>
        topicText('consumer_44'),
    'chance': (f) =>
        topicText('consumer_45'),
    'refuse': (f) =>
        topicText('consumer_46'),
  },
  drafts: (f) => const ['formal_notice', 'demand_money'],
);
