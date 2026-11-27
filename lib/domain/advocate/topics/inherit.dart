// موضوع: ارث.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

final Topic inheritTopic = Topic(
  id: 'inherit',
  title: topicText('inherit_0'),
  cues: {
    'ارث|ارثیه|ماترک|ترکه|انحصار وراثت|حصر وراثت|وراث|ورثه|سهم ?الارث': 4,
    '(?:پدر|مادر|بابا|مامان|همسر|شوهر|برادر|خواهر|پدربزرگ|مادربزرگ)(?:م|مون)? (?:فوت|مرد|مرده|از دنیا|تازه فوت)|مرحوم|خدابیامرز': 2,
    'وصیت|وصیت ?نامه': 3,
    '(?:خونه|ملک|زمین|اموال|مال|حساب|ماشین|مغازه)(?:ش| اش)? (?:[^ ]+ ){0,2}(?:مونده|به جا|باقی)|تقسیم|نمیفروش|بدهی داشت|طلبکار': 2,
  },
  anti: 'طلاق|مهریه(?:م| ام| من)',
  recap: (f) => [
    if (f.eq('rel', 'child')) topicText('inherit_1'),
    if (f.eq('rel', 'wife')) topicText('inherit_2'),
    if (f.eq('rel', 'husband')) topicText('inherit_3'),
    if (f.eq('rel', 'other')) topicText('inherit_4'),
    if (f.yes('cert')) topicText('inherit_5'),
    if (f.no('cert')) topicText('inherit_6'),
    if (f.yes('agree')) topicText('inherit_7'),
    if (f.no('agree')) topicText('inherit_8'),
  ],
  claims: [
    Claim(
      goal: topicText('inherit_9'),
      elements: [
        Element(
          topicText('inherit_10'),
          (f) => f.has('rel') ? (f.eq('rel', 'other') ? null : true) : null,
        ),
        Element(
          topicText('inherit_11'),
          (f) => f.tri('cert'),
          ifNo:
              topicText('inherit_12'),
        ),
        Element(
          topicText('inherit_13'),
          (f) => null,
        ),
      ],
      win: (f) =>
          topicText('inherit_14'),
      counter: (f) =>
          topicText('inherit_15'),
    ),
  ],
  slots: [
    Slot(
      id: 'rel',
      ask: topicText('inherit_16'),
      why: topicText('inherit_17'),
      options: [topicText('inherit_18'), topicText('inherit_19'), topicText('inherit_20'), topicText('inherit_21')],
      yesValue: '',
      noValue: '',
      read: (n) {
        if (Sense.has(n, 'شوهرم (?:[^ ]+ ){0,2}(?:فوت|مرد|از دنیا)|زنش (?:هستم|بودم)|خانمش (?:هستم|بودم)|ارث شوهرم')) return 'wife';
        if (Sense.has(n, '(?:زنم|خانمم) (?:[^ ]+ ){0,2}(?:فوت|مرد|از دنیا)|شوهرش (?:هستم|بودم)|ارث (?:زنم|خانمم)')) return 'husband';
        if (Sense.has(n, '(?:پدر|مادر|بابا|مامان)(?:م|مون) (?:[^ ]+ ){0,2}(?:فوت|مرد|از دنیا|مرحوم)|مرحوم (?:پدر|مادر)|(?:پدر|مادر|بابا|مامان)(?:م|مون) خدا ?بیامرز|ارث (?:پدر|مادر|بابا|مامان)|فرزند(?:ش)? (?:هستم|ام)|پسرش (?:هستم|ام)|دخترش (?:هستم|ام)|بچه(?: ?ش| اش) (?:هستم|ام)')) return 'child';
        if (Sense.has(n, '(?:برادر|خواهر|عمو|دایی|خاله|عمه|پدربزرگ|مادربزرگ)(?:م|مون) (?:[^ ]+ ){0,2}(?:فوت|مرد|از دنیا)|(?:برادر|خواهر|نوه|برادرزاده|خواهرزاده)(?:ش| اش) (?:هستم|ام)|نسبت دیگ')) return 'other';
        return null;
      },
      effect: (f) => f.eq('rel', 'child')
          ? topicText('inherit_22')
          : f.eq('rel', 'wife')
              ? topicText('inherit_23')
              : f.eq('rel', 'husband')
                  ? topicText('inherit_24')
                  : topicText('inherit_25'),
    ),
    Slot(
      id: 'cert',
      ask: topicText('inherit_26'),
      why: topicText('inherit_27'),
      options: [topicText('inherit_28'), topicText('inherit_29')],
      read: (n) => Sense.yn(
        n,
        '(?:حصر|انحصار) وراثت (?:گرفتیم|گرفتم|داریم|دارم|شده)|گواهی(?:ش)? (?:رو )?گرفتیم',
        '(?:حصر|انحصار) وراثت (?:نگرفتیم|نگرفتم|نداریم|ندارم|نشده)|هنوز (?:نگرفتیم|هیچ کاری)',
      ),
      effect: (f) => f.yes('cert')
          ? topicText('inherit_30')
          : topicText('inherit_31'),
    ),
    Slot(
      id: 'agree',
      ask: topicText('inherit_32'),
      why: topicText('inherit_33'),
      options: [topicText('inherit_34'), topicText('inherit_35')],
      read: (n) => Sense.yn(
        n,
        'توافق (?:داریم|کردیم|هست)|مشکلی نداریم|همه راضی',
        'توافق (?:نداریم|نمیکن|نیست)|همراهی نمیکن|کارشکنی|نمیذاره|سهم(?: ارث)?(?:م| من| ما|مون)?[^ ]* (?:رو |را )?نمید|زیر بار نمیر|تصرف کرده|نشسته (?:توش|تو خونه)|اختلاف|دعوا|راضی نمیش|نمیفروش',
      ),
      effect: (f) => f.yes('agree')
          ? topicText('inherit_36')
          : topicText('inherit_37'),
    ),
  ],
  opening: (f) =>
      topicText('inherit_38'),
  issues: [
    Issue(
      id: 'share',
      chip: topicText('inherit_39'),
      cues: 'سهم (?:هر|من|ما|دختر|پسر|زن|همسر)|چقدر (?:میرسه|میبر)|چند درصد|دختر و پسر|نصف پسر|یک ?هشتم|تقسیم (?:میشه|چطور)',
      body: (f) =>
          topicText('inherit_40'),
    ),
    Issue(
      id: 'debt',
      chip: topicText('inherit_41'),
      cues: 'بدهی|بدهکار بود|قرض داشت|طلبکار|وام داشت|مهریه (?:مادر|زنش)',
      body: (f) =>
          topicText('inherit_42'),
    ),
    Issue(
      id: 'tax',
      chip: topicText('inherit_43'),
      cues: 'مالیات|اظهارنامه|دارایی',
      body: (f) =>
          topicText('inherit_44'),
    ),
  ],
  follow: {
    'next': (f) =>
        topicText('inherit_45'),
    'where': (f) =>
        topicText('inherit_46'),
    'evidence': (f) =>
        topicText('inherit_47'),
    'cost': (f) =>
        topicText('inherit_48'),
    'time': (f) =>
        topicText('inherit_49'),
    'chance': (f) =>
        topicText('inherit_50'),
  },
  drafts: (f) => const ['formal_notice'],
);
