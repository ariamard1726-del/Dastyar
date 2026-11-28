// موضوع: خرید کالا و خدمات.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic consumerTopic = Topic.dsl(
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
  recap: const [
    RecapItem(when: FactYes('proof'), text: Tx('consumer_1')),
    RecapItem(when: FactNo('proof'), text: Tx('consumer_2')),
    RecapItem(when: FactYes('told'), text: Tx('consumer_3')),
    RecapItem(when: FactNo('told'), text: Tx('consumer_4')),
    RecapItem(when: FactEq('want', 'refund'), text: Tx('consumer_5')),
    RecapItem(when: FactEq('want', 'replace'), text: Tx('consumer_6')),
    RecapItem(when: FactEq('want', 'repair'), text: Tx('consumer_7')),
  ],
  claims: [
    Claim.dsl(
      goal: topicText('consumer_8'),
      elements: [
        Element.dsl(
          topicText('consumer_9'),
          const FactTri('proof'),
          ifNo: topicText('consumer_10'),
        ),
        Element.dsl(
          topicText('consumer_11'),
          const FactConst(null),
        ),
        Element.dsl(
          topicText('consumer_12'),
          const FactTri('told'),
          ifNo: topicText('consumer_13'),
        ),
      ],
      win: const Tx('consumer_14'),
      counter: const Tx('consumer_15'),
    ),
  ],
  slots: [
    Slot.dsl(
      id: 'proof',
      ask: topicText('consumer_16'),
      why: topicText('consumer_17'),
      options: [topicText('consumer_18'), topicText('consumer_19')],
      read: const ReadYn(
        'فاکتور (?:دارم|داد|گرفتم)|ضمانت ?نامه (?:دارم|داره|داد)|گارانتی (?:دارم|داره|داشت)|رسید (?:دارم|گرفتم)|کارت کشیدم',
        'فاکتور (?:ندارم|نداد|نگرفتم)|رسید (?:ندارم|نگرفتم)|بدون فاکتور|گارانتی نداشت',
      ),
      effect: const TxCond(
          FactYes('proof'), Tx('consumer_20'), Tx('consumer_21')),
    ),
    Slot.dsl(
      id: 'told',
      ask: topicText('consumer_22'),
      why: topicText('consumer_23'),
      options: [topicText('consumer_24'), topicText('consumer_25')],
      read: const ReadYn(
        'گفتم|بردم(?:ش)? (?:پیش|مغازه|نمایندگی)|قبول نکرد|قبول نمیکن|پس نمیگیره|عوض نمیکن|زیر بار نمیره|جواب نمیده|میگه (?:به من|تقصیر|خودت)',
        'نگفتم|نگفته ام|هنوز (?:نرفتم|نبردم)|خبر ندادم',
      ),
      effect: const TxCond(
          FactYes('told'), Tx('consumer_26'), Tx('consumer_27')),
    ),
    Slot.dsl(
      id: 'want',
      ask: topicText('consumer_28'),
      why: topicText('consumer_29'),
      options: [topicText('consumer_30'), topicText('consumer_31'), topicText('consumer_32')],
      yesValue: '',
      noValue: '',
      read: const ReadCases([
        ReadCase('پول(?:م|مو|م رو| را)? ?(?:پس|برگرد)|پس بده|فسخ|مرجوع', 'refund'),
        ReadCase('عوض|تعویض|سالم(?:ش)? (?:رو )?بده|یکی دیگه', 'replace'),
        ReadCase('تعمیر|درست(?:ش)? کن', 'repair'),
      ]),
      effect: const TxCond(FactEq('want', 'refund'), Tx('consumer_33')),
    ),
  ],
  opening: const Tx('consumer_34'),
  issues: [
    Issue.dsl(
      id: 'where',
      chip: topicText('consumer_35'),
      cues: 'کجا (?:شکایت|برم)|تعزیرات|۱۲۴|124|صمت|اتحادیه|شکایت کنم',
      body: const Tx('consumer_36'),
    ),
    Issue.dsl(
      id: 'ad',
      chip: topicText('consumer_37'),
      cues: 'تبلیغ|دروغ گفت|گول(?:م)? زد|فریب|چیز دیگه ای? (?:بود|گفته بود)|مشخصات(?:ش)? فرق',
      body: const Tx('consumer_38'),
    ),
    Issue.dsl(
      id: 'service',
      chip: topicText('consumer_39'),
      cues: 'قطعه|خدمات پس از فروش|تعمیرگاه|سرویس نمید',
      body: const Tx('consumer_40'),
    ),
  ],
  follow: const {
    'next': Tx('consumer_41'),
    'where': Tx('consumer_42'),
    'evidence': Tx('consumer_43'),
    'cost': Tx('consumer_44'),
    'chance': Tx('consumer_45'),
    'refuse': Tx('consumer_46'),
  },
  drafts: const DraftRule.fixed(['formal_notice', 'demand_money']),
);
