// موضوع: کار اداری و دستگاه‌های دولتی.
//
// قرارداد نگارش در shared.dart آمده است.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

const TextExpr _noBank = Tx('admin_0');

final Topic adminTopic = Topic.dsl(
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
    Slot.dsl(
      id: 'notified',
      ask: topicText('admin_2'),
      why: topicText('admin_3'),
      options: [topicText('admin_4'), topicText('admin_5')],
      read: const ReadYn(
        'ابلاغ (?:شد|کرد)|نامه(?:ش)? (?:اومد|رو دادن)|رای(?:ش)? (?:اومد|صادر)|کتبی (?:دادن|گفتن)',
        'ابلاغ نشد|کتبی (?:ندادن|نگفتن|نمیدن)|شفاهی گفتن|نامه ای? ندادن',
      ),
      effect: const TxCond(FactYes('notified'), Tx('admin_6'), Tx('admin_7')),
    ),
  ],
  opening: const TxJoin('\n', [Tx('adminOpenA'), _noBank, Tx('adminOpenB')]),
  issues: [
    Issue.dsl(
      id: 'military',
      chip: topicText('admin_8'),
      cues: 'معافیت|سربازی|نظام وظیفه|کمیسیون پزشکی|کفالت',
      body: const TxJoin('\n', [_noBank, Tx('adminMilBody')]),
    ),
    Issue.dsl(
      id: 'how',
      chip: topicText('admin_9'),
      cues: 'چطور(?:ی)? شکایت|چجوری شکایت|شکایت کنم|ساجد|دادخواست',
      body: const Tx('admin_10'),
    ),
  ],
  follow: const {
    'next': Tx('admin_11'),
    'where': Tx('admin_12'),
    'deadline': Tx('admin_13'),
  },
);
