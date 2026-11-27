// موضوع: کار اداری و دستگاه‌های دولتی.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

String get _noBank =>
    topicText('admin_0');

final Topic adminTopic = Topic(
  id: 'admin',
  title: topicText('admin_1'),
  cues: {
    'جریمه (?:راهنمایی|رانندگی|پلیس|شهرداری|مالیات|بیمه)|اعتراض به (?:جریمه|رای|حکم|تصمیم|مالیات)|راهنمایی و رانندگی|مالیات': 3,
    'دیوان عدالت': 4,
    'معافیت|سربازی|نظام وظیفه|کمیسیون پزشکی': 3,
    // «سربازی نرفته‌ام چکار کنم» وسط پروندهٔ اجاره: نام خودِ موضوع باید
    // برای جابه‌جایی پرونده به اندازهٔ کافی قوی باشد.
    'سربازی|نظام وظیفه': 2,
    'شهرداری|کمیسیون ماده|اداره (?:مالیات|ثبت|برق|آب|گاز)|سازمان (?:تامین|نظام|امور)|تصمیم (?:اداره|دولت)|از (?:اداره|دولت|سازمان) شکایت': 2,
  },
  anti: 'کارفرما|شوهر',
  slots: [
    Slot(
      id: 'notified',
      ask: topicText('admin_2'),
      why: topicText('admin_3'),
      options: [topicText('admin_4'), topicText('admin_5')],
      read: (n) => Sense.yn(
        n,
        'ابلاغ (?:شد|کرد)|نامه(?:ش)? (?:اومد|رو دادن)|رای(?:ش)? (?:اومد|صادر)|کتبی (?:دادن|گفتن)',
        'ابلاغ نشد|کتبی (?:ندادن|نگفتن|نمیدن)|شفاهی گفتن|نامه ای? ندادن',
      ),
      effect: (f) => f.yes('notified')
          ? topicText('admin_6')
          : topicText('admin_7'),
    ),
  ],
  opening: (f) =>
      topicText('adminOpenA') + '\n' + _noBank + '\n' + topicText('adminOpenB'),
  issues: [
    Issue(
      id: 'military',
      chip: topicText('admin_8'),
      cues: 'معافیت|سربازی|نظام وظیفه|کمیسیون پزشکی|کفالت',
      body: (f) =>
          _noBank + '\n' + topicText('adminMilBody'),
    ),
    Issue(
      id: 'how',
      chip: topicText('admin_9'),
      cues: 'چطور(?:ی)? شکایت|چجوری شکایت|شکایت کنم|ساجد|دادخواست',
      body: (f) =>
          topicText('admin_10'),
    ),
  ],
  follow: {
    'next': (f) =>
        topicText('admin_11'),
    'where': (f) =>
        topicText('admin_12'),
    'deadline': (f) =>
        topicText('admin_13'),
  },
);
