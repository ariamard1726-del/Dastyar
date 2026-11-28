// موضوع: طلب و بدهی.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

const String _anyRe = 'هیچ';

const List<RecapItem> _debtRecap = [
  RecapItem(
    when: FactHasNum('amount'),
    text: TxJoin(' ', [TxNum('amount'), Tx('debtRecapAmt')]),
  ),
  RecapItem(when: FactEq('proof', 'doc'), text: Tx('debt_0')),
  RecapItem(when: FactEq('proof', 'transfer'), text: Tx('debt_1')),
  RecapItem(when: FactEq('proof', 'msg'), text: Tx('debt_2')),
  RecapItem(when: FactEq('proof', 'witness'), text: Tx('debt_3')),
  RecapItem(when: FactEq('proof', 'none'), text: Tx('debt_4')),
  RecapItem(when: FactYes('admits'), text: Tx('debt_5')),
  RecapItem(when: FactNo('admits'), text: Tx('debt_6')),
];

final List<Claim> _debtClaims = [
  Claim.dsl(
    goal: topicText('debt_7'),
    cues: 'پول(?:م|مو)|طلب(?:م|مو)|حکم|محکوم',
    uses: const ['amount'],
    elements: [
      Element.dsl(
        topicText('debt_8'),
        const FactTriWhen(FactHas('proof'), FactNot(FactEq('proof', 'none'))),
        needs: const ['proof'],
        because: const TxSwitch(
          'proof',
          {
            'doc': Tx('debt_9'),
            'transfer': Tx('debt_10'),
            'witness': Tx('debt_11'),
          },
          fallback: Tx('debt_12'),
        ),
        ifNo: topicText('debt_13'),
      ),
      Element.dsl(
        topicText('debt_14'),
        const FactTriCases(
          [
            FactCase(FactYes('admits'), FactConst(true)),
            FactCase(FactNot(FactNo('admits')), FactConst(null)),
            FactCase(FactIn('proof', ['doc', 'transfer']), FactConst(true)),
          ],
          fallback: FactTriIf(FactHas('proof'), false),
        ),
        needs: const ['admits', 'proof'],
        because: const TxCond(
            FactYes('admits'), Tx('debt_15'), Tx('debt_16')),
        ifNo: topicText('debt_17'),
      ),
    ],
    win: const Tx('debt_18'),
    counter: const Tx('debt_19'),
  ),
];

final Topic debtTopic = Topic.dsl(
  id: 'debt',
  title: topicText('debt_24'),
  claims: _debtClaims,
  recap: _debtRecap,
  cues: {
    'پول(?:م|مو)? (?:مرا |من را |من رو |رو |را )?(?:پس )?(?:نمیده|نمیدهد|نداده|نمیدن|نمیدهند)|طلبکار هستم|بدهکار (?:است|هست|فرار)|خسارت تاخیر تادیه|از بدهکار': 3,
    'قرض (?:دادم|داده بودم|داده ام|گرفت|کرد)|پول (?:دادم|قرض)|دستی (?:دادم|گرفت)|قرض الحسنه دادم': 3,
    'پول ?(?:م|مو|منو|ام|امو)? ?(?:رو |را )?(?:خورد|خورده|خورده‌ست|بالا کشید|برداشت)': 3,
    'طلب(?:م| دارم|کارم)|ازش طلب|بهم بدهکاره|بدهکار منه|پولمو (?:نمیده|پس نمیده|خورد|بالا کشید)|پولم رو (?:نمیده|پس نمیده)': 3,
    'پس نمیده|نمیده|سفته|بدهی(?:ش)? رو': 1,
  },
  anti: 'بدهکارم|بدهی دارم|قرض گرفتم|قرض کردم|طلبکار(?:ا|ها|م)? (?:اومد|دارم|زیاد)|نمیتونم (?:بدم|پس بدم)|سایت|اینستا|تلگرام|کلاهبردار|حکم گرفتم|رای گرفتم|محکوم شد|اجرای حکم',
  slots: [
    Slot.dsl(
      id: 'proof',
      ask: topicText('debt_25'),
      why: topicText('debt_26'),
      options: [topicText('debt_27'), topicText('debt_28'), topicText('debt_29'), topicText('debt_30')],
      read: const ReadCases([
        ReadCase(
            'هیچ مدرک|مدرک(?:ی)? ندارم|نه سند|هیچی ندارم|فقط خودم و خودش|خودم و خودش میدون|کسی (?:نمیدونه|ندید|نبود)|شاهد(?:ی)? ندارم|هیچ(?:ی)? ننوشتیم|رسید(?:ی)? (?:نگرفتم|ندارم)|دست به دست|بدون (?:مدرک|رسید|سند)',
            'none'),
        ReadCase('سفته|رسید (?:دارم|گرفتم|داد)|دست ?نوشته|دستخط|قرارداد|نوشته (?:دارم|داد)|سند (?:دارم|داد)|امضا کرد', 'doc'),
        ReadCase('کارت به کارت|واریز|حواله|انتقال(?:ی)? بانک|فیش|تراکنش|به حسابش|پایا|ساتنا', 'transfer'),
        ReadCase('پیام|چت|واتساپ|تلگرام|اس ام اس|پیامک|ویس|صدا[^ ]* (?:رو )?ضبط|اسکرین', 'msg'),
        ReadCase('شاهد (?:دارم|هست|داریم)|شاهد |جلوی (?:[^ ]+ ){0,3}دادم|(?:بقیه|چند نفر|دوستام|خانواده) (?:دیدن|میدونن|بودن)', 'witness'),
      ]),
      readPending: const ReadSaysNoOrHas(_anyRe, 'none'),
      yesValue: '',
      noValue: 'none',
      effect: const TxSwitch('proof', {
        'none': TxConcat([
          Tx('debtNoneA'),
          TxCond(
            FactHasNum('amount'),
            TxConcat([Tx('debtSumPrefix'), TxRaw(' '), TxNum('amount'), Tx('debtSumSuffix')]),
            Tx('debtSumGeneric'),
          ),
          TxRaw(' '),
          Tx('debtNoneB'),
        ]),
        'transfer': Tx('debt_20'),
        'msg': Tx('debt_21'),
        'witness': Tx('debt_22'),
        'doc': Tx('debt_23'),
      }),
    ),
    Slot.dsl(
      id: 'admits',
      ask: topicText('debt_31'),
      why: topicText('debt_32'),
      options: [topicText('debt_33'), topicText('debt_34')],
      read: const ReadYn(
        'قبول دار|میگه میدم|قول میده|امروز فردا|هی میگه|انکار نمیکنه|میگه ندارم|وعده میده|دست به سر',
        'انکار(?! نمی)|زیرش (?:میزنه|زد)|میگه نگرفتم|میگه بدهکار نیستم|حاشا|گردن نمیگیره|منکر',
      ),
      effect: const TxCond(
        FactYes('admits'),
        Tx('debt_35'),
        TxCond(FactEq('proof', 'doc'), Tx('debt_36'), Tx('debt_37')),
      ),
    ),
    Slot.dsl(
      id: 'amount',
      ask: topicText('debt_38'),
      why: topicText('debt_39'),
      read: const ReadAmount(),
      readPending: const ReadAmount(loose: true),
      yesValue: '',
      noValue: '',
      effect: const TxForum('amount'),
    ),
  ],
  opening: const Tx('debt_40'),
  issues: [
    Issue.dsl(
      id: 'record',
      chip: topicText('debt_41'),
      cues: 'ضبط|ویس|صدا[^ ]* (?:رو |را )?(?:بگیرم|دارم)|مکالمه',
      body: const Tx('debt_42'),
    ),
    Issue.dsl(
      id: 'interest',
      chip: topicText('debt_43'),
      cues: 'سود|دیرکرد|خسارت تاخیر|ضرر[^ ]* (?:تاخیر|تورم)|تورم|ارزش پول|به نرخ روز',
      body: const Tx('debt_44'),
    ),
    Issue.dsl(
      id: 'hide',
      chip: topicText('debt_45'),
      cues: 'به نام (?:زنش|همسرش|بچه|کس دیگه|دیگری)|اموال[^ ]* (?:رو )?(?:منتقل|انتقال)|فرار (?:از دین|کنه|کرد)|در بره|مال(?:ی)? ندار|هیچی نداره',
      body: const Tx('debt_46'),
    ),
    Issue.dsl(
      id: 'jail',
      chip: topicText('debt_47'),
      cues: 'زندان|حبس|بازداشت|جلب|شکایت کیفری|کلاهبرداری',
      body: const Tx('debt_48'),
    ),
  ],
  follow: const {
    'next': TxJoin('\n', [
      Tx('debtPlanLead'),
      TxCond(FactEq('proof', 'doc'), Tx('debtPlanDoc'), Tx('debtPlanNoDoc')),
      Tx('debtPlanRest'),
      TxForum('amount'),
    ]),
    'where': TxForum('amount'),
    'cost': TxShared(SharedText.moneyCost),
    'time': TxShared(SharedText.moneyTime),
    'deadline': Tx('debt_49'),
    'evidence': Tx('debt_50'),
    'chance': TxSwitch(
      'proof',
      {'doc': Tx('debt_51'), 'none': Tx('debt_52'), '': Tx('debt_53')},
      fallback: Tx('debt_54'),
    ),
    'refuse': Tx('debt_55'),
  },
  drafts: const DraftRule.fixed(['formal_notice', 'demand_money']),
);
