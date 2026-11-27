// موضوع: دعوا و ضرب و جرح (آسیب بدنی؛ هم برای کسی که زده و هم برای کسی که آسیب دیده).
//
// مواد استنادی (از «قانون مجازات اسلامی - کتاب پنجم» موجود در assets/laws):
// - ماده ۶۱۴: جرح یا ضرب عمدی که به آسیب بدنی برسد؛ تبصرهٔ آن برای جرح با چاقو یا اسلحه.
// - ماده ۶۱۵: منازعهٔ جمعی؛ هر شرکت‌کننده مجازات دارد، مگر دفاع مشروع باشد.
// - تبصرهٔ ۱ ماده ۶۱۵: دفاع مشروع از این ماده مستثناست.
// - تبصرهٔ ۲ ماده ۶۱۵: این مجازات‌ها مانع اجرای قصاص یا دیه نیست.
//
// میزان جراحت و تشخیص آن با پزشکی قانونی است؛ این موضوع عددی حدس نمی‌زند.
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

String? _fightRole(String n) {
  if (Sense.has(n, 'کتک خوردم|زدنم|منو زد|من رو زد|زده شدم|زد به من|زد تو صورتم|زد به سرم|زد تو سرم|کتکم زد')) {
    return 'victim';
  }
  if (Sense.has(n, 'من زدم|زدمش|زدم به|زدم تو|زدمش|سرش زدم|کتک زدم|سنگ زدم')) {
    return 'perp';
  }
  return null;
}

/// واژه‌های انسانی: بی‌یکی از این‌ها، بی‌نقشِ روشن و بی‌آسیب، حکم نمی‌دهیم.
///
/// در یک گفتگوی واقعی «دو تا مگس بهم مشت انداختند» جوابِ مطمئنِ مواد ۶۱۴ و
/// ۶۱۵ گرفت؛ فقط چون واژهٔ «مشت» در جمله بود. ضرب‌وجرح دربارهٔ *آدم* است؛
/// اگر آدمی در جمله نیست، پرسش درست است نه ماده.
const String _fightActors =
    'کسی|یک نفر|نفر|آدم|مرد|زن|پسر|دختر|بچه|نوجوان|همسایه|شوهر|زنم|رفیق|'
    'دوست|راننده|مأمور|پلیس|نگهبان|کارگر|پدر|مادر|برادر|خواهر|عمو|دایی|'
    'خاله|عمه|سرایدار|باجناق|خواستگار';

/// نتیجهٔ آسیب؛ با یک کنشِ صریح، حتی بی‌نام‌بردنِ طرف، ماجرا روشن است.
const String _fightHarm =
    'خون|زخم|شکست|کبودی|جراحت|آسیب|بیمارستان|بیهوش|پزشکی|درد';

const String _fightAct =
    'زد|زدن|زدند|کتک|مشت|لگد|چاقو|هل داد|هلم داد|پرت کرد|پرتم کرد';

/// شرطِ بازشدنِ پروندهٔ ضرب‌وجرح (`Topic.gate`).
bool fightGate(String n) =>
    _fightRole(n) != null ||
    Sense.word(n, _fightActors) ||
    (Sense.has(n, _fightHarm) && Sense.has(n, _fightAct));

final Topic fightTopic = Topic(
  id: 'fight',
  title: topicText('fight_0'),
  cues: {
    'کتک|مشت|لگد|ضرب و جرح|جرح|نزاع|منازعه|چاقو|زخمی': 4,
    'با سنگ|سنگ زد|سنگ زدم|سرش زدم|زدم به سرش|زد به سرم|زدم تو صورتش|زد تو صورتم': 4,
    'دعوا': 2,
  },
  anti:
      'تصادف|اجاره|مستاجر|چک|طلاق|مهریه|ارث|سرقت|دزد|قرارداد|فروشنده|حضانت|کارفرما|حقوق معوق|همسرم|شوهرم|زنم|ماشینم زد|ماشین(?:م|مو)? زد',
  gate: fightGate,
  slots: [
    Slot(
      id: 'role',
      ask: topicText('fight_1'),
      why:
          topicText('fight_2'),
      options: [topicText('fight_3'), topicText('fight_4')],
      read: _fightRole,
      effect: (f) => f.eq('role', 'perp')
          ? topicText('fight_5')
          : f.eq('role', 'victim')
              ? topicText('fight_6')
              : topicText('fight_7'),
    ),
    Slot(
      id: 'hurt',
      ask: topicText('fight_8'),
      why:
          topicText('fight_9'),
      options: [topicText('fight_10'), topicText('fight_11')],
      read: (n) => Sense.yn(
        n,
        'خون|شکست|جراحت|زخم|بیمارستان|بیهوش|آسیب دیده|پزشکی',
        'نه|نداشت|نیست|نبود|سالم',
      ),
      effect: (f) => f.yes('hurt')
          ? topicText('fight_12')
          : topicText('fight_13'),
    ),
  ],
  issues: [],
  opening: (f) =>
      topicText('fight_14'),
  follow: {
    'next': (f) =>
        topicText('fight_15'),
    'where': (f) =>
        topicText('fight_16'),
    'evidence': (f) =>
        topicText('fight_17'),
    'cost': (f) =>
        topicText('fight_18'),
    'chance': (f) =>
        topicText('fight_19'),
    'deadline': (f) =>
        topicText('fight_20'),
  },
);
