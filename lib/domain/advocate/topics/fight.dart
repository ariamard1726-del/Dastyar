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
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';

const ReadRule _fightRoleRule = ReadCases([
  ReadCase('کتک خوردم|زدنم|منو زد|من رو زد|زده شدم|زد به من|زد تو صورتم|زد به سرم|زد تو سرم|کتکم زد', 'victim'),
  ReadCase('من زدم|زدمش|زدم به|زدم تو|زدمش|سرش زدم|کتک زدم|سنگ زدم', 'perp'),
]);

const String _fightActors =
    'کسی|یک نفر|نفر|آدم|مرد|زن|پسر|دختر|بچه|نوجوان|همسایه|شوهر|زنم|رفیق|'
    'دوست|راننده|مأمور|پلیس|نگهبان|کارگر|پدر|مادر|برادر|خواهر|عمو|دایی|'
    'خاله|عمه|سرایدار|باجناق|خواستگار';

const String _fightHarm =
    'خون|زخم|شکست|کبودی|جراحت|آسیب|بیمارستان|بیهوش|پزشکی|درد';

const String _fightAct =
    'زد|زدن|زدند|کتک|مشت|لگد|چاقو|هل داد|هلم داد|پرت کرد|پرتم کرد';

const GateRule _fightGate = GateAny([
  GateReadMatches(_fightRoleRule),
  GateWord(_fightActors),
  GateAllHas([_fightHarm, _fightAct]),
]);

final Topic fightTopic = Topic.dsl(
  id: 'fight',
  title: topicText('fight_0'),
  cues: {
    'کتک|مشت|لگد|ضرب و جرح|جرح|نزاع|منازعه|چاقو|زخمی': 4,
    'با سنگ|سنگ زد|سنگ زدم|سرش زدم|زدم به سرش|زد به سرم|زدم تو صورتش|زد تو صورتم': 4,
    'دعوا': 2,
  },
  anti:
      'تصادف|اجاره|مستاجر|چک|طلاق|مهریه|ارث|سرقت|دزد|قرارداد|فروشنده|حضانت|کارفرما|حقوق معوق|همسرم|شوهرم|زنم|ماشینم زد|ماشین(?:م|مو)? زد',
  gate: _fightGate,
  slots: [
    Slot.dsl(
      id: 'role',
      ask: topicText('fight_1'),
      why: topicText('fight_2'),
      options: [topicText('fight_3'), topicText('fight_4')],
      read: _fightRoleRule,
      effect: const TxSwitch(
        'role',
        {'perp': Tx('fight_5'), 'victim': Tx('fight_6')},
        fallback: Tx('fight_7'),
      ),
    ),
    Slot.dsl(
      id: 'hurt',
      ask: topicText('fight_8'),
      why: topicText('fight_9'),
      options: [topicText('fight_10'), topicText('fight_11')],
      read: const ReadYn(
        'خون|شکست|جراحت|زخم|بیمارستان|بیهوش|آسیب دیده|پزشکی',
        'نه|نداشت|نیست|نبود|سالم',
      ),
      effect: const TxCond(FactYes('hurt'), Tx('fight_12'), Tx('fight_13')),
    ),
  ],
  issues: const [],
  opening: const Tx('fight_14'),
  follow: const {
    'next': Tx('fight_15'),
    'where': Tx('fight_16'),
    'evidence': Tx('fight_17'),
    'cost': Tx('fight_18'),
    'chance': Tx('fight_19'),
    'deadline': Tx('fight_20'),
  },
);
