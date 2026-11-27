// موضوع: جرم‌های اینترنتی.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic cyberTopic = Topic(
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
  recap: (f) => [
    if (f.eq('kind', 'money')) topicText('cyber_1'),
    if (f.eq('kind', 'hack')) topicText('cyber_2'),
    if (f.eq('kind', 'expose')) topicText('cyber_3'),
    if (f.eq('self', 'self')) topicText('cyber_4'),
    if (f.eq('self', 'taken')) topicText('cyber_5'),
    if (f.yes('proof')) topicText('cyber_6'),
    if (f.no('proof')) topicText('cyber_7'),
  ],
  claims: [
    Claim(
      goal: topicText('cyber_8'),
      when: (f) => f.eq('kind', 'money'),
      elements: [
        Element(
          topicText('cyber_9'),
          (f) => f.has('self') ? f.eq('self', 'taken') : null,
          ifNo:
              topicText('cyber_10'),
        ),
        Element(
          topicText('cyber_11'),
          (f) => true,
        ),
        Element(
          topicText('cyber_12'),
          (f) => f.tri('proof'),
          ifNo:
              topicText('cyber_13'),
        ),
      ],
      win: (f) =>
          topicText('cyber_14'),
      counter: (f) =>
          topicText('cyber_15'),
    ),
    Claim(
      goal: topicText('cyber_16'),
      when: (f) => f.eq('kind', 'expose'),
      elements: [
        Element(
          topicText('cyber_17'),
          (f) => true,
        ),
        Element(
          topicText('cyber_18'),
          (f) => true,
        ),
        Element(
          topicText('cyber_19'),
          (f) => f.tri('proof'),
          ifNo:
              topicText('cyber_20'),
        ),
      ],
      win: (f) =>
          topicText('cyber_21'),
      counter: (f) =>
          topicText('cyber_22'),
    ),
  ],
  slots: [
    Slot(
      id: 'kind',
      ask: topicText('cyber_23'),
      why: topicText('cyber_24'),
      options: [topicText('cyber_25'), topicText('cyber_26'), topicText('cyber_27')],
      yesValue: '',
      noValue: '',
      read: (n) {
        if (Sense.has(n, 'پخش|منتشر|آبرو|تهمت|فیک|شایعه|(?:عکس|فیلم)(?:م|ام|مو|امو|هام|های من|های خصوصی| خصوصی)|حرف(?:ی)? (?:دروغ|پخش)')) return 'expose';
        if (Sense.has(n, 'پول|برداشت|کارت(?:م| به کارت)|واریز|خالی|فیشینگ|درگاه|کلاهبردار|میلیون|تومان')) return 'money';
        if (Sense.has(n, 'هک|رمز|وارد (?:پیج|حساب|اکانت)|پیج(?:م|مو)? (?:رو )?(?:گرفت|برد|دزدید)|دسترسی')) return 'hack';
        return null;
      },
      effect: (f) => f.eq('kind', 'hack')
          ? topicText('cyber_28')
          : f.eq('kind', 'expose')
              ? topicText('cyber_29')
              : '',
    ),
    Slot(
      id: 'self',
      ask: topicText('cyber_30'),
      why: topicText('cyber_31'),
      options: [topicText('cyber_32'), topicText('cyber_33')],
      yesValue: '',
      noValue: '',
      when: (f) => f.eq('kind', 'money'),
      read: (n) {
        if (Sense.has(n, 'خودم (?:واریز|زدم|دادم|کارت)|واریز کردم|کارت به کارت کردم|بیعانه|پیش ?پرداخت|پول (?:رو )?(?:دادم|ریختم|زدم)')) return 'self';
        if (Sense.has(n, 'بی ?خبر|بدون اطلاع|نفهمیدم|یهو|یکدفعه|برداشت (?:شد|کردن|زدن)|برداشتن|خالی (?:شد|کردن)|فیشینگ|درگاه|رمز(?:م| دوم)')) return 'taken';
        return null;
      },
      effect: (f) => f.eq('self', 'taken')
          ? topicText('cyber_34')
          : topicText('cyber_35'),
    ),
    Slot(
      id: 'proof',
      ask: topicText('cyber_36'),
      why: topicText('cyber_37'),
      options: [topicText('cyber_38'), topicText('cyber_39')],
      read: (n) => Sense.yn(
        n,
        'اسکرین|عکس گرفتم|پیامک(?:ش)? (?:رو )?دارم|شماره (?:تراکنش|پیگیری)|لینک(?:ش)? (?:رو )?دارم|نگه داشتم|نگه داشته ام|مدرک دارم|شماره(?:ش)? (?:رو )?دارم',
        'پاک (?:کرد|شد)|چیزی ندارم|مدرک(?:ی)? ندارم|هیچی ندارم',
      ),
      effect: (f) => f.yes('proof')
          ? topicText('cyber_40')
          : topicText('cyber_41'),
    ),
  ],
  opening: (f) => f.eq('kind', 'expose')
      ? topicText('cyber_42')
      : topicText('cyber_43'),
  issues: [
    Issue(
      id: 'back',
      chip: topicText('cyber_44'),
      cues: 'پول(?:م|مو)? (?:بر ?می ?گرد|پس میاد|برگشت)|بر ?می ?گرد|پس میگیرم|جبران',
      body: (f) =>
          topicText('cyber_45'),
    ),
    Issue(
      id: 'how',
      chip: topicText('cyber_46'),
      cues: 'چطور(?:ی)? شکایت|چجوری شکایت|کجا شکایت|شکایت کنم|فتا',
      body: (f) =>
          topicText('cyber_47'),
    ),
    Issue(
      id: 'remove',
      chip: topicText('cyber_48'),
      cues: 'پاک (?:کنه|بشه|کنن)|حذف|جلو(?:ی)?(?:ش)? (?:رو )?بگیر|جلو(?:ی)? (?:پخش|انتشار)|بیشتر پخش|ادامه نده',
      body: (f) =>
          topicText('cyber_49'),
    ),
  ],
  follow: {
    'next': (f) =>
        topicText('cyber_50'),
    'where': (f) =>
        topicText('cyber_51'),
    'evidence': (f) =>
        topicText('cyber_52'),
    'cost': (f) =>
        topicText('cyber_53'),
    'chance': (f) =>
        topicText('cyber_54'),
    'time': (f) =>
        topicText('cyber_55'),
  },
  drafts: (f) => const ['complaint'],
);
