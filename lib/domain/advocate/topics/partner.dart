// موضوع: شراکت.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

const List<RecapItem> _partnerRecap = [
  RecapItem(text: Tx('partner_0')),
  RecapItem(when: FactYes('written'), text: Tx('partner_1')),
  RecapItem(when: FactNo('written'), text: Tx('partner_2')),
  RecapItem(when: FactEq('lease', 'both'), text: Tx('partner_3')),
  RecapItem(when: FactEq('lease', 'his'), text: Tx('partner_4')),
  RecapItem(when: FactEq('lease', 'mine'), text: Tx('partner_5')),
  RecapItem(when: FactEq('goal', 'exit'), text: Tx('partner_6')),
  RecapItem(when: FactEq('goal', 'stay'), text: Tx('partner_7')),
];

final Topic partnerTopic = Topic.dsl(
  id: 'partner',
  title: topicText('partner_8'),
  recap: _partnerRecap,
  cues: {
    'شرکت (?:زدیم|کردیم|راه انداختیم|داشتیم|داریم)|سهم(?:ش|م| من| منو)(?: رو)? (?:نمیده|نمی ?ده|نمیدهد)': 3,
    'شریک|شراکت|شراکتی': 3,
    'با هم (?:[^ ]+ ){0,3}(?:اجاره کردیم|خریدیم|راه انداختیم|زدیم|سرمایه گذاشتیم|کار میکنیم)': 3,
    'سود[^ ]* (?:رو |را )?(?:برمیداره|نمیده|بالا کشید|میبره)|همه سود|سهم(?:م| من| منو)(?: رو)? نمیده|حساب و کتاب': 2,
  },
  slots: [
    Slot.dsl(
      id: 'written',
      ask: topicText('partner_9'),
      why: topicText('partner_10'),
      options: [topicText('partner_11'), topicText('partner_12')],
      read: const ReadYn(
        'شراکت ?نامه|قرارداد (?:دارم|داریم|نوشتیم)|نوشتیم|کتبی|مشارکت نامه',
        'ننوشتیم|شفاهی|قرارداد (?:نداریم|ندارم)|هیچ(?:ی)? ننوشتیم|رو حساب (?:رفاقت|اعتماد|فامیلی)|نوشته ای? (?:نداریم|ندارم)',
      ),
      effect: const TxCond(
          FactYes('written'), Tx('partner_13'), Tx('partner_14')),
    ),
    Slot.dsl(
      id: 'lease',
      ask: topicText('partner_15'),
      why: topicText('partner_16'),
      options: [topicText('partner_17'), topicText('partner_18'), topicText('partner_19')],
      read: const ReadCases([
        ReadCase('به (?:اسم|نام) (?:هر ?دو|جفت|دوتامون)|هر دو(?:مون)? امضا|با هم (?:[^ ]+ ){0,3}اجاره کردیم|دوتایی اجاره', 'both'),
        ReadCase('به (?:اسم|نام) (?:اون|خودش|شریکم|او)', 'his'),
        ReadCase('به (?:اسم|نام) (?:من|خودم)', 'mine'),
      ]),
      readPending: const ReadCases([
        ReadCase('هر ?دو|جفت', 'both'),
        ReadCase('من|خودم', 'mine'),
        ReadCase('اون|او |خودش|شریک', 'his'),
      ]),
      yesValue: '',
      noValue: '',
      effect: const TxSwitch(
        'lease',
        {'both': Tx('partner_20'), 'his': Tx('partner_21')},
        fallback: Tx('partner_22'),
      ),
    ),
    Slot.dsl(
      id: 'goal',
      ask: topicText('partner_23'),
      why: topicText('partner_24'),
      options: [topicText('partner_25'), topicText('partner_26')],
      read: const ReadCases([
        ReadCase('جدا (?:شم|بشم|شیم|شوم|بشوم)|تموم(?:ش)? کنم|به هم بزنم|سهمم(?: رو)? بفروشم|بیام بیرون|انحلال', 'exit'),
        ReadCase('ادامه|فقط (?:سهم|سود|حق)|سودم(?: رو)? (?:میخوام|بده)', 'stay'),
      ]),
      yesValue: '',
      noValue: '',
      effect: const TxCond(
          FactEq('goal', 'exit'), Tx('partner_27'), Tx('partner_28')),
    ),
  ],
  opening: const Tx('partner_29'),
  issues: [
    Issue.dsl(
      id: 'profit',
      chip: topicText('partner_30'),
      cues: 'سود|دخل|حساب(?: و کتاب)?(?: رو)? (?:پس )?نمیده|برمیداره|بالا کشید|سهم(?:م| من)(?: رو)? نمیده',
      body: const Tx('partner_31'),
    ),
    Issue.dsl(
      id: 'criminal',
      chip: topicText('partner_32'),
      cues: 'شکایت|کیفری|خیانت در امانت|کلاهبرداری|دزدی|زندان',
      body: const Tx('partner_33'),
    ),
    Issue.dsl(
      id: 'lock',
      chip: topicText('partner_34'),
      cues: 'راه(?:م)? نمیده|قفل(?: رو| را)? عوض|بیرونم کرد|نمیذاره بیام|کلید(?: رو)? (?:نمیده|گرفت)',
      body: const Tx('partner_35'),
    ),
  ],
  follow: const {
    'next': Tx('partner_36'),
    'where': TxForum('amount'),
    'cost': TxJoin('\n', [TxShared(SharedText.moneyCost), Tx('partnerCostTail')]),
    'time': TxShared(SharedText.moneyTime),
    'evidence': Tx('partner_37'),
    'chance': TxJoin(' ', [
      TxCond(FactNo('written'), Tx('partnerChanceNoWritten')),
      Tx('partnerChanceRest'),
    ]),
    'refuse': Tx('partner_38'),
  },
  drafts: const DraftRule.fixed(['formal_notice']),
);
