part of 'advocate.dart';

// گفت‌وگوی انسانی: حرف‌های غیرحقوقی، خلاصه، احوال‌پرسی و کنجکاوی.

const List<List<String>> _parties = [
  ['همسایه', 'همسایه‌تان'],
  ['برادر|داداش', 'برادرتان'],
  ['خواهر|آبجی', 'خواهرتان'],
  [' پدر| بابا', 'پدرتان'],
  [' مادر| مامان', 'مادرتان'],
  ['نامزد', 'نامزدتان'],
  ['همکار', 'همکارتان'],
  ['دوستم|رفیق', 'دوستتان'],
  ['عمو|دایی|خاله|عمه|فامیل|اقوام|پسرعمو|دخترعمو', 'یکی از بستگانتان'],
  ['بانک', 'بانک'],
  ['شهرداری', 'شهرداری'],
  ['بیمه', 'بیمه'],
  ['پلیس|مامور|کلانتری', 'پلیس'],
  ['مدرسه|دانشگاه|آموزشگاه|مهدکودک', 'یک مرکز آموزشی'],
  ['دکتر|پزشک|بیمارستان|کلینیک|درمانگاه', 'پزشک یا مرکز درمانی'],
  ['فروشنده|مغازه دار|فروشگاه|نمایشگاه', 'فروشنده'],
  [' پیک |پستچی|اداره پست|شرکت پست|تیپاکس|باربری|اسنپ|تپسی', 'پیک یا شرکت حمل‌ونقل'],
  ['شرکت', 'یک شرکت'],
];

/// طرفِ ماجرا، اگر کاربر نامش را برده باشد.
/// عبارت‌های ناامیدی؛ هم در `_meta` (وقتی موضوع باز است) و هم در `TalkReply`.
const String _hopelessPattern =
    'هیچ راهی|راهی نیست|راهی نداره|پولم رفت|کاری نمیشه کرد|یعنی هیچی|بیچاره شدم|بدبخت شدم|امیدی نیست|دستم به جایی';

String _party(String n) {
  for (final p in _parties) {
    if (Sense.has(n, p[0])) return p[1];
  }
  return '';
}

const Map<String, String> _areas = {
  'criminal_harm': 'به نظرم ماجرا جنبهٔ کیفری دارد.',
  'fraud_cyber': 'به نظرم پای کلاهبرداری یا سوءاستفاده در میان است.',
  'litigation_defense': 'پس پای دادگاه یا یک رأی در میان است.',
  'family': 'پس ماجرا خانوادگی است.',
  'labor': 'پس ماجرا به کار و کارفرما برمی‌گردد.',
  'lease': 'پس ماجرا به اجاره برمی‌گردد.',
  'debt': 'پس حرفِ پول و طلب است.',
  'cheque': 'پس حرفِ چک است.',
};

String _clip(String raw) {
  final t = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (t.length <= 60) return t;
  final cut = t.lastIndexOf(' ', 60);
  return '${t.substring(0, cut < 20 ? 60 : cut)}…';
}

extension _Talk on Advocate {
  // پاسخ‌های گفت‌وگوی انسانی در `TalkReply` (talk_reply.dart) هستند؛ این‌ها
  // فقط پوستهٔ نازک‌اند تا بقیهٔ بخش‌ها همان نام‌های پیشین را صدا بزنند.
  AdvocateReply? _hopeless(String n) => _talk.hopeless(n);

  AdvocateReply? _social(String n, Topic? topic) => _talk.social(n, topic);

    // مسیرِ گفت‌وگوی عمومی در `TalkRoute` (talk_route.dart) است؛ این‌ها پوستهٔ
  // نازک‌اند تا بقیهٔ بخش‌ها همان نام‌های پیشین را صدا بزنند.
  AdvocateReply? _meta(String n, Topic? topic, {bool explicit = false}) =>
      _talkRoute.meta(n, topic, explicit: explicit);

  List<String> _branchStart() => _talkRoute.branchStart();

  AdvocateReply? _branchReply(String raw, String n, {required bool asked}) =>
      _talkRoute.branchReply(raw, n, asked: asked);

  AdvocateReply _intake(String raw) => _talkRoute.intake(raw);

  bool _anyTopicCue(String n) => _talk.anyTopicCue(n);

    bool _vague(String n) =>
      Sense.words(n) <= 9 &&
      Sense.has(n,
          'مشکل(?:ی)? (?:حقوقی |قانونی )?(?:دارم|پیش اومده|برام)|سوال(?:ی)? (?:حقوقی )?(?:داشتم|دارم)|مشاوره|کمک(?:م)? (?:کن|میخوام|کنید)|راهنمایی(?:م)? (?:کن|میخوام|کنید)|گرفتار شدم|یه مسئله');

}

/// نقل کوتاهِ کلمه‌های کاربر: بی‌علامت پایانی و حداکثر شش کلمه.
String _quoteWords(String raw) {
  final words = raw
      .replaceAll(RegExp("[«»\"“”'‘’]"), ' ')
      .trim()
      .replaceAll(RegExp(r'[؟?!.،,]+$'), '')
      .trim()
      .split(RegExp(r'\s+'));
  final head = words.take(6).join(' ');
  return words.length > 6 ? '$head…' : head;
}
