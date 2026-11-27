// موضوع: جرم‌های اینترنتی.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic cyberTopic = Topic.dsl(
  id: 'cyber',
  title: topicText('cyber_0'),
  cues: {
    'عکس(?:های|هام|ام|م|امو|مو|هایم|هایمو)?[^؟]{0,30}(?:پخش|منتشر|فرستادن)|پخش (?:کردن|کرد|کنن)[^؟]{0,15}عکس': 4,
    'با (?:عکس|اسم|نام)[^ ]* (?:[^ ]+ ){0,2}(?:پیج|اکانت|صفحه) (?:ساخت|زد)|جعل هویت|کیف پول دیجیتال|ارز دیجیتال|سایت جعلی|درگاه پرداخت': 4,
    'فیشینگ|کلاهبرداری اینترنتی|پلیس فتا| فتا |درگاه (?:جعلی|قلابی)|لینک (?:جعلی|قلابی)': 4,
    'هک (?:شد|کرد)|هکر|حساب(?:م| من| بانکیم)?[^ ]* (?:رو |را )?خالی|از حسابم (?:[^ ]+ ){0,2}(?:برداشت|کم شد|رفت)|برداشت غیر ?مجاز|رمز دوم': 4,
    '(?:عکس|فیلم)(?:م|ام|امو|مو|هام|های من)?[^؟]{0,12}(?:پخش|منتشر)|آبرومو[^؟]{0,20}(?:اینستا|پیج|گروه|کانال)|پیج فیک|اکانت فیک': 4,
    '(?:پول|بیعانه)[^؟]{0,25}(?:نفرستاد|ارسال نکرد|بلاک(?:م)? کرد)|(?:واریز کردم|کارت به کارت کردم|پول ریختم)[^؟]{0,40}(?:نفرستاد|ارسال نکرد|بلاک|کلاهبردار|غیبش زد)': 4,
    'اینستا|تلگرام|واتس ?اپ|پیج|فضای مجازی|اینترنتی|آنلاین|سایت|پیامک': 1,
  },
  anti: 'ازم شکایت|علیه من|متهم|چک',
  recap: const [
    RecapItem(when: FactEq('kind', 'money'), text: Tx('cyber_1')),
    RecapItem(when: FactEq('kind', 'hack'), text: Tx('cyber_2')),
    RecapItem(when: FactEq('kind', 'expose'), text: Tx('cyber_3')),
    RecapItem(when: FactEq('self', 'self'), text: Tx('cyber_4')),
    RecapItem(when: FactEq('self', 'taken'), text: Tx('cyber_5')),
    RecapItem(when: FactYes('proof'), text: Tx('cyber_6')),
    RecapItem(when: FactNo('proof'), text: Tx('cyber_7')),
  ],
  claims: [
    Claim.dsl(
      goal: topicText('cyber_8'),
      when: const FactEq('kind', 'money'),
      elements: [
        Element.dsl(
          topicText('cyber_9'),
          const FactTriWhen(FactHas('self'), FactEq('self', 'taken')),
          ifNo: topicText('cyber_10'),
        ),
        Element.dsl(
          topicText('cyber_11'),
          const FactConst(true),
        ),
        Element.dsl(
          topicText('cyber_12'),
          const FactTri('proof'),
          ifNo: topicText('cyber_13'),
        ),
      ],
      win: const Tx('cyber_14'),
      counter: const Tx('cyber_15'),
    ),
    Claim.dsl(
      goal: topicText('cyber_16'),
      when: const FactEq('kind', 'expose'),
      elements: [
        Element.dsl(
          topicText('cyber_17'),
          const FactConst(true),
        ),
        Element.dsl(
          topicText('cyber_18'),
          const FactConst(true),
        ),
        Element.dsl(
          topicText('cyber_19'),
          const FactTri('proof'),
          ifNo: topicText('cyber_20'),
        ),
      ],
      win: const Tx('cyber_21'),
      counter: const Tx('cyber_22'),
    ),
  ],
  slots: [
    Slot.dsl(
      id: 'kind',
      ask: topicText('cyber_23'),
      why: topicText('cyber_24'),
      options: [topicText('cyber_25'), topicText('cyber_26'), topicText('cyber_27')],
      yesValue: '',
      noValue: '',
      read: const ReadCases([
        ReadCase('پخش|منتشر|آبرو|تهمت|فیک|شایعه|(?:عکس|فیلم)(?:م|ام|مو|امو|هام|های من|های خصوصی| خصوصی)|حرف(?:ی)? (?:دروغ|پخش)', 'expose'),
        ReadCase('پول|برداشت|کارت(?:م| به کارت)|واریز|خالی|فیشینگ|درگاه|کلاهبردار|میلیون|تومان', 'money'),
        ReadCase('هک|رمز|وارد (?:پیج|حساب|اکانت)|پیج(?:م|مو)? (?:رو )?(?:گرفت|برد|دزدید)|دسترسی', 'hack'),
      ]),
      effect: const TxSwitch('kind', {
        'hack': Tx('cyber_28'),
        'expose': Tx('cyber_29'),
      }),
    ),
    Slot.dsl(
      id: 'self',
      ask: topicText('cyber_30'),
      why: topicText('cyber_31'),
      options: [topicText('cyber_32'), topicText('cyber_33')],
      yesValue: '',
      noValue: '',
      when: const FactEq('kind', 'money'),
      read: const ReadCases([
        ReadCase('خودم (?:واریز|زدم|دادم|کارت)|واریز کردم|کارت به کارت کردم|بیعانه|پیش ?پرداخت|پول (?:رو )?(?:دادم|ریختم|زدم)', 'self'),
        ReadCase('بی ?خبر|بدون اطلاع|نفهمیدم|یهو|یکدفعه|برداشت (?:شد|کردن|زدن)|برداشتن|خالی (?:شد|کردن)|فیشینگ|درگاه|رمز(?:م| دوم)', 'taken'),
      ]),
      effect: const TxCond(
          FactEq('self', 'taken'), Tx('cyber_34'), Tx('cyber_35')),
    ),
    Slot.dsl(
      id: 'proof',
      ask: topicText('cyber_36'),
      why: topicText('cyber_37'),
      options: [topicText('cyber_38'), topicText('cyber_39')],
      read: const ReadYn(
        'اسکرین|عکس گرفتم|پیامک(?:ش)? (?:رو )?دارم|شماره (?:تراکنش|پیگیری)|لینک(?:ش)? (?:رو )?دارم|نگه داشتم|نگه داشته ام|مدرک دارم|شماره(?:ش)? (?:رو )?دارم',
        'پاک (?:کرد|شد)|چیزی ندارم|مدرک(?:ی)? ندارم|هیچی ندارم',
      ),
      effect: const TxCond(
          FactYes('proof'), Tx('cyber_40'), Tx('cyber_41')),
    ),
  ],
  opening: const TxCond(
      FactEq('kind', 'expose'), Tx('cyber_42'), Tx('cyber_43')),
  issues: [
    Issue.dsl(
      id: 'back',
      chip: topicText('cyber_44'),
      cues: 'پول(?:م|مو)? (?:بر ?می ?گرد|پس میاد|برگشت)|بر ?می ?گرد|پس میگیرم|جبران',
      body: const Tx('cyber_45'),
    ),
    Issue.dsl(
      id: 'how',
      chip: topicText('cyber_46'),
      cues: 'چطور(?:ی)? شکایت|چجوری شکایت|کجا شکایت|شکایت کنم|فتا',
      body: const Tx('cyber_47'),
    ),
    Issue.dsl(
      id: 'remove',
      chip: topicText('cyber_48'),
      cues: 'پاک (?:کنه|بشه|کنن)|حذف|جلو(?:ی)?(?:ش)? (?:رو )?بگیر|جلو(?:ی)? (?:پخش|انتشار)|بیشتر پخش|ادامه نده',
      body: const Tx('cyber_49'),
    ),
  ],
  follow: const {
    'next': Tx('cyber_50'),
    'where': Tx('cyber_51'),
    'evidence': Tx('cyber_52'),
    'cost': Tx('cyber_53'),
    'chance': Tx('cyber_54'),
    'time': Tx('cyber_55'),
  },
  drafts: const DraftRule.fixed(['complaint']),
);
