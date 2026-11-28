// موضوع: چک برگشتی.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

const FactExpr _chequeIsIssuer = FactEq('role', 'issuer');
const FactExpr _chequeNotIssuer = FactNot(_chequeIsIssuer);

const List<RecapItem> _chequeRecap = [
  RecapItem(when: FactEq('role', 'holder'), text: Tx('cheque_0')),
  RecapItem(when: _chequeIsIssuer, text: Tx('cheque_1')),
  RecapItem(
    when: FactHasNum('amount'),
    text: TxConcat([
      Tx('chequeRecapAmtA'),
      TxRaw(' '),
      TxNum('amount'),
      TxRaw(' '),
      Tx('chequeRecapAmtB'),
    ]),
  ),
  RecapItem(when: FactYes('cert'), text: Tx('cheque_2')),
  RecapItem(when: FactNo('cert'), text: Tx('cheque_3')),
  RecapItem(when: FactEq('kind', 'guarantee'), text: Tx('cheque_4')),
  RecapItem(when: FactEq('kind', 'postdated'), text: Tx('cheque_5')),
  RecapItem(when: FactEq('kind', 'day'), text: Tx('cheque_6')),
];

const TextExpr _chequeIssuer = Tx('cheque_27');

const TextExpr _chequeRoutes = TxConcat([
  Tx('cheque_21'),
  Tx('cheque_22'),
  TxSwitch(
    'kind',
    {
      'guarantee': Tx('cheque_23'),
      'postdated': Tx('cheque_24'),
    },
    fallback: TxCond(
      FactNumMin('since', 7, missingNull: false),
      Tx('cheque_25'),
      Tx('cheque_26'),
    ),
  ),
]);

const TextExpr _chequeKindEffect = TxSwitch(
  'kind',
  {
    'guarantee': TxCond(_chequeIsIssuer, Tx('cheque_15'), Tx('cheque_16')),
    'postdated': TxCond(_chequeIsIssuer, Tx('cheque_17'), Tx('cheque_18')),
  },
  fallback: TxCond(_chequeIsIssuer, Tx('cheque_19'), Tx('cheque_20')),
);

const ReadRule _chequeRoleRead = ReadCases([
  ReadCase(
    'خودم (?:چک[^ ]* )?(?:رو )?(?:کشیدم|دادم|نوشتم|صادر)|چک[^ ]* (?:رو |را )?(?:کشیدم|نوشتم|صادر کردم)|صادرکننده (?:ام|منم|هستم|خودمم)|چک دادم|حسابم (?:خالی|پول نداشت|موجودی نداشت)|نتونستم پاس|نمیتونم پاسش|پاسش کنم|چکم دست|چکم (?:رو )?(?:برگشت زد|گذاشت(?:ه)? اجرا)|برام اجرائیه',
    'issuer',
  ),
  ReadCase(
    'چک[^ ]* (?:رو |را )?(?:گرفتم|گرفته بودم|داد(?:ه)? بهم|بهم داد)|ازش چک|چک(?:ی)? (?:[^ ]+ ){0,3}(?:دارم|دستمه|دست منه)|چکش|چک طرف|چک مشتری|بهم چک داد|دارنده (?:ام|هستم)|چک(?:ی)? (?:که )?(?:ازش|بهم)|(?:بذارم|بگذارم|میذارم) اجرا|اجرا (?:بذارم|بگذارم)|برگشت (?:زدم|بزنم)|گواهی عدم پرداخت(?: رو)? گرفتم|شکایت کیفری کنم|پاسش نمیکنه|پولمو نمیده',
    'holder',
  ),
]);

const ReadRule _chequeKindRead = ReadCases([
  ReadCase('ضمانت|تضمین|امانی|امانت|سفید امضا|حسن انجام', 'guarantee'),
  ReadCase(
      'وعده ?دار|مدت ?دار|تاریخ[^ ]* (?:مال|برای) (?:بعد|ماه)|برای (?:چند|یه|دو|سه) ماه بعد',
      'postdated'),
  ReadCase('به روز|روز بود|همون روز|تاریخ روز', 'day'),
]);

final List<Claim> chequeClaims = [
  Claim.dsl(
    goal: topicText('cheque_7'),
    when: _chequeNotIssuer,
    cues: 'اجرائیه|اجراییه|وصول|پول(?:م|مو|ش)|نقد',
    uses: const ['amount'],
    elements: [
      Element.dsl(
        topicText('cheque_8'),
        const FactTri('cert'),
        needs: const ['cert'],
        because: const Tx('cheque_9'),
        ifNo: topicText('cheque_10'),
      ),
      Element.dsl(
        topicText('cheque_11'),
        const FactTriWhen(
          FactHas('kind'),
          FactTriIf(FactEq('kind', 'guarantee'), null, true),
        ),
        needs: const ['kind'],
        because: const Tx('cheque_12'),
      ),
    ],
    win: const Tx('cheque_13'),
    counter: const Tx('cheque_14'),
  ),
];

final Topic chequeTopic = Topic.dsl(
  id: 'cheque',
  title: topicText('cheque_28'),
  claims: chequeClaims,
  recap: _chequeRecap,
  cues: const {
    'چک(?!ار|ه |ه میکن| کرد| کن| میکن| نکرد| شد )': 3,
    'برگشت(?:ی| خورد| زد)|پاس نشد|پاس نمیشه|بلامحل|گواهی عدم پرداخت|صیاد': 1,
  },
  slots: [
    Slot.dsl(
      id: 'role',
      first: true,
      ask: topicText('cheque_29'),
      why: topicText('cheque_30'),
      options: [topicText('cheque_31'), topicText('cheque_32')],
      read: _chequeRoleRead,
      readPending: const ReadCases([
        ReadCase('خودم|صادر کرد|کشیدم|دادم', 'issuer'),
        ReadCase('گرفتم|گرفته|دارنده|طلبکار|ازش|بهم', 'holder'),
      ]),
      yesValue: '',
      noValue: '',
      effect: const TxCond(_chequeIsIssuer, _chequeIssuer, _chequeRoutes),
    ),
    Slot.dsl(
      id: 'cert',
      ask: topicText('cheque_33'),
      why: topicText('cheque_34'),
      options: [topicText('cheque_35'), topicText('cheque_36')],
      read: const ReadYn(
        'گواهی عدم پرداخت(?: رو| را)? (?:گرفتم|دارم)|برگشت زدم|برگشتی گرفتم|گواهی(?: رو)? گرفتم|گواهی دارم',
        'گواهی[^ ]*(?: عدم پرداخت)?(?: رو)? (?:نگرفتم|ندارم)|هنوز (?:بانک نرفتم|برگشت نزدم)|برگشت نزدم',
      ),
      when: const FactEq('role', 'holder'),
      effect: const TxCond(
          FactYes('cert'), Tx('cheque_37'), Tx('cheque_38')),
    ),
    Slot.dsl(
      id: 'kind',
      ask: topicText('cheque_39'),
      why: topicText('cheque_40'),
      options: [
        topicText('cheque_41'),
        topicText('cheque_42'),
        topicText('cheque_43'),
      ],
      read: _chequeKindRead,
      yesValue: '',
      noValue: '',
      effect: _chequeKindEffect,
    ),
    Slot.dsl(
      id: 'amount',
      ask: topicText('cheque_44'),
      why: topicText('cheque_45'),
      read: const ReadAmount(),
      readPending: const ReadAmount(loose: true),
      yesValue: '',
      noValue: '',
      when: const FactEq('role', 'holder'),
    ),
  ],
  opening: const TxSwitch(
    'role',
    {
      'issuer': TxRaw(''),
      'holder': Tx('cheque_46'),
    },
    fallback: Tx('cheque_47'),
  ),
  issues: [
    Issue.dsl(
      id: 'compare',
      chip: topicText('cheque_48'),
      cues:
          'بهتره یا|بهتر است یا|اجرائیه (?:[^ ]+ ){0,4}کیفری|یا (?:[^ ]+ ){0,3}بهتره|کدوم (?:راه |یکی )?بهتر|کدام (?:راه )?بهتر|اجرا (?:[^ ]+ ){0,3}کیفری|کیفری (?:[^ ]+ ){0,3}(?:اجرا|حقوقی)|حقوقی (?:[^ ]+ ){0,3}کیفری|چه راه|راه هاش',
      body: _chequeRoutes,
      when: _chequeNotIssuer,
    ),
    Issue.dsl(
      id: 'criminal',
      chip: topicText('cheque_49'),
      cues:
          'شکایت کیفری|کیفری|زندان[^ ]* (?:میره|میفته|بندازم)|جلب[^ ]* (?:کنم|بگیرم)|بندازمش|شکایت کنم',
      body: const Tx('cheque_50'),
      when: _chequeNotIssuer,
    ),
    Issue.dsl(
      id: 'onface',
      chip: topicText('cheque_51'),
      cues:
          'روی چک|در متن چک|تو(?:ی)? چک (?:ننوشت|نوشت)|ننوشتم بابت|قید نکرد|قید نشده',
      body: const TxCond(_chequeIsIssuer, Tx('cheque_52'), Tx('cheque_53')),
      covers: const {'kind'},
    ),
    Issue.dsl(
      id: 'sayad',
      chip: topicText('cheque_54'),
      cues: 'صیاد|بنفش|ثبت (?:نشده|نکرد|نکرده)|تایید (?:نکردم|نشده)',
      body: const TxConcat([
        Tx('chequeSayadA'),
        TxRaw(' '),
        TxCond(
          _chequeIsIssuer,
          Tx('chequeSayadIssuer'),
          Tx('chequeSayadHolder'),
        ),
        TxRaw(' '),
        Tx('chequeSayadB'),
      ]),
    ),
    Issue.dsl(
      id: 'lost',
      chip: topicText('cheque_55'),
      cues:
          'گم (?:شد|کرد)|مفقود|دزدی|سرقت|دزدید|کلاهبرداری[^ ]* چک|ازم گرفت[^ ]* به زور',
      body: const Tx('cheque_56'),
    ),
    Issue.dsl(
      id: 'noassets',
      chip: topicText('cheque_57'),
      cues:
          'به نامش نباش|مال(?:ی)? (?:به نامش )?ندار|هیچی به نام|اموال(?:ی)? ندار|به نام (?:زنش|همسرش|کس دیگه)|فرار کرد|در رفت|پیداش نمیکنم|گوشی(?:ش)? خاموش',
      body: const Tx('cheque_58'),
      when: _chequeNotIssuer,
    ),
  ],
  follow: const {
    'next': TxCond(
      _chequeIsIssuer,
      _chequeIssuer,
      TxConcat([
        Tx('chequeNextLead'),
        TxRaw('\n'),
        TxCond(FactYes('cert'), Tx('cheque_59'), Tx('cheque_60')),
        TxRaw('\n'),
        Tx('chequeNextTail'),
      ]),
    ),
    'where': Tx('cheque_61'),
    'cost': TxShared(SharedText.moneyCost),
    'time': Tx('cheque_62'),
    'deadline': Tx('cheque_63'),
    'chance': TxCond(_chequeIsIssuer, Tx('cheque_64'), Tx('cheque_65')),
    'evidence': Tx('cheque_66'),
    'refuse': Tx('cheque_67'),
  },
  drafts: const DraftRule.when(
    _chequeIsIssuer,
    thenIds: ['insolvency'],
    elseIds: ['cheque_execution', 'cheque_complaint'],
  ),
);
