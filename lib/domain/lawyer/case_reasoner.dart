/// استدلال روی پروندهٔ در جریان: فهم پرسش‌های وابسته به بافت گفتگو
/// («حالا چیکار کنم؟»، «کجا شکایت کنم؟»، «شانس دارم؟»، «اگه انکار کنه چی؟»)،
/// ارزیابی موقعیت اثباتی، و انتخاب مهم‌ترین پرسشی که هنوز جوابش را نداریم.
///
/// همه‌چیز قطعی است و هیچ متن قانونی ساخته نمی‌شود: هر جا به ماده‌ای استناد
/// شده، آن ماده در [ReasonedAnswer.refs] هم آمده و آزمون‌ها وجودش را در بانک
/// قانون بررسی می‌کنند.
library;

import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/lawyer/case_facts.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';
import 'package:dastyar/domain/lawyer/phrase_variator.dart';

/// نوع پرسش یا پاسخ کوتاه کاربر در ادامهٔ یک پرونده.
enum FollowUpKind {
  whatNow,
  where,
  cost,
  duration,
  deadline,
  chance,
  denial,
  lawyer,
  evidenceNeeded,
  yes,
  no,
  dontKnow,
}

/// اطلاعاتی که برای ارزیابی یک موضوع لازم است و پرسش متناظرش.
class CaseNeed {
  /// `amount`، `duration`، `evidence`، `counterparty` یا نام یک وضعیت
  /// [CaseFlag] (پرسش بله/خیر).
  final String key;
  final String question;

  /// راهنمای «نمی‌دانم»: چطور می‌شود جواب را پیدا کرد.
  final String howToFind;
  const CaseNeed(this.key, this.question, [this.howToFind = '']);

  bool get isYesNo =>
      key != 'amount' &&
      key != 'duration' &&
      key != 'evidence' &&
      key != 'counterparty';

  bool satisfiedBy(CaseFacts f) {
    switch (key) {
      case 'amount':
        return f.amounts.isNotEmpty;
      case 'duration':
        return f.durations.isNotEmpty;
      case 'evidence':
        return f.evidence.isNotEmpty ||
            f.has(CaseFlag.noEvidence) ||
            f.has(CaseFlag.noWrittenContract);
      case 'counterparty':
        return f.counterparties.isNotEmpty;
      default:
        return f.knows(key);
    }
  }
}

class ReasonedAnswer {
  final String text;
  final List<LegalRef> refs;
  const ReasonedAnswer(this.text, [this.refs = const []]);
}

class CaseReasoner {
  CaseReasoner._();

  // ───────────────────────── دسته‌بندی ─────────────────────────

  static const Map<String, String> _family = {
    'deposit_return': 'lease',
    'eviction': 'lease',
    'rent_increase': 'lease',
    'dismissal': 'labor',
    'unpaid_wages': 'labor',
    'labor_insurance': 'labor',
    'mahrieh': 'family',
    'nafaqeh': 'family',
    'custody': 'family',
    'divorce': 'family',
    'tamkin': 'family',
    'cheque_bounced': 'cheque',
    'cheque_issuer': 'cheque',
    'cheque_guarantee': 'cheque',
    'debt_claim': 'debt',
    'insolvency': 'debt',
    'accident': 'accident',
    'diyeh': 'accident',
    'assault': 'criminal',
    'insult_threat': 'criminal',
    'defamation': 'criminal',
    'theft': 'criminal',
    'fraud': 'criminal',
    'private_media': 'criminal',
    'trust_breach': 'criminal',
    'contract_cancel': 'contract',
    'consumer': 'contract',
    'legal_aid': 'general',
    'juvenile_detention': 'detention',
    'inheritance': 'inheritance',
    'neighbor_damage': 'property_damage',
    'presale_delivery': 'contract',
    'defect_purchase': 'contract',
    'appeal': 'procedure',
    'summons': 'procedure',
  };

  static String familyOf(LegalGuide g) => _family[g.id] ?? 'general';

  // ───────────────────────── نیازها ─────────────────────────

  static const _evidenceQ = CaseNeed(
    'evidence',
    'چه مدرکی دارید (قرارداد، رسید یا واریز بانکی، پیام، شاهد)؟',
    'هر چیزی که نشان دهد ماجرا اتفاق افتاده مدرک است: پیام‌ها، پرینت حساب بانکی، قرارداد، رسید یا کسی که در جریان بوده.',
  );

  static const Map<String, List<CaseNeed>> _needs = {
    'deposit_return': [
      CaseNeed('amount', 'مبلغ ودیعه چقدر است؟',
          'مبلغ ودیعه معمولاً در خود اجاره‌نامه نوشته شده است.'),
      CaseNeed(CaseFlag.contractEnded,
          'مدت قرارداد اجاره تمام شده است؟',
          'تاریخ پایان را در اجاره‌نامه ببینید؛ معمولاً در بند «مدت اجاره» آمده است.'),
      _evidenceQ,
    ],
    'eviction': [
      CaseNeed(CaseFlag.contractEnded,
          'مدت قرارداد اجاره تمام شده است؟',
          'تاریخ پایان را در اجاره‌نامه ببینید.'),
      _evidenceQ,
    ],
    'cheque_bounced': [
      CaseNeed('amount', 'مبلغ چک چقدر است؟'),
      CaseNeed(CaseFlag.certificateIssued,
          'چک را به بانک برده‌اید و گواهی عدم پرداخت گرفته‌اید؟',
          'گواهی عدم پرداخت را بانک هنگام برگشت زدن چک صادر و در سامانه ثبت می‌کند؛ اگر مطمئن نیستید، از همان شعبه بپرسید.'),
      CaseNeed('duration', 'تاریخ چک مال چه زمانی است؟',
          'تاریخ روی خود چک نوشته شده است.'),
    ],
    'debt_claim': [
      CaseNeed('amount', 'مبلغ طلب چقدر است؟'),
      _evidenceQ,
      CaseNeed('duration', 'پول را کی داده‌اید؟'),
    ],
    'unpaid_wages': [
      CaseNeed('duration', 'چند ماه است که حقوق نگرفته‌اید؟'),
      CaseNeed(CaseFlag.fired, 'همکاری‌تان با کارفرما قطع شده است؟'),
      _evidenceQ,
    ],
    'dismissal': [
      CaseNeed('duration', 'چه زمانی اخراج شدید؟'),
      _evidenceQ,
    ],
    'labor_insurance': [
      CaseNeed('duration', 'چه مدتی است که آنجا کار می‌کنید؟'),
      _evidenceQ,
    ],
    'nafaqeh': [
      CaseNeed('duration', 'از چه زمانی نفقه پرداخت نشده است؟'),
      CaseNeed(CaseFlag.hasChildren, 'فرزند هم دارید؟'),
    ],
    'mahrieh': [
      CaseNeed('amount', 'مهریه چند سکه یا چه مبلغی است؟',
          'مقدار مهریه در سند ازدواج (عقدنامه) نوشته شده است.'),
    ],
    'accident': [
      CaseNeed(CaseFlag.otherAtFault,
          'طبق کروکی یا نظر پلیس، مقصر طرف مقابل است؟',
          'مقصر را کارشناس پلیس راهور در کروکی مشخص می‌کند؛ اگر کروکی نگرفته‌اید، هرچه زودتر با ۱۱۰ تماس بگیرید.'),
      CaseNeed(CaseFlag.injured, 'کسی آسیب جسمی دیده است؟'),
    ],
    'theft': [
      CaseNeed('duration', 'سرقت کی اتفاق افتاد؟'),
      CaseNeed('evidence', 'شاهد یا دوربینی در محل بوده است؟'),
    ],
    'neighbor_damage': [_evidenceQ],
    'defect_purchase': [
      CaseNeed('duration', 'چه زمانی متوجه عیب شدید؟'),
      _evidenceQ,
    ],
    'presale_delivery': [
      CaseNeed('duration', 'موعد تحویل چه زمانی بوده است؟',
          'موعد تحویل در قرارداد پیش‌فروش آمده است.'),
    ],
    'fraud': [
      CaseNeed('amount', 'چه مبلغی از دست داده‌اید؟'),
      _evidenceQ,
    ],
  };

  static List<CaseNeed> needsFor(LegalGuide g) => _needs[g.id] ?? const [];

  /// پرسش‌هایی که هنوز جوابشان را نداریم (به ترتیب اهمیت).
  static List<CaseNeed> missingNeeds(
    LegalGuide g,
    CaseFacts f, {
    Set<String> skip = const {},
  }) =>
      [
        for (final n in needsFor(g))
          if (!skip.contains(n.key) && !n.satisfiedBy(f)) n,
      ];

  static const List<String> _askHeads = [
    'برای اینکه دقیق‌تر راهنمایی‌تان کنم:',
    'فقط چند نکته را بگویید تا ارزیابی‌ام دقیق‌تر شود:',
    'برای اینکه جواب مخصوص پروندهٔ خودتان باشد:',
  ];

  /// پرسش پایانی پاسخ: فقط چیزهایی که هنوز معلوم نیست (حداکثر دو مورد).
  /// اگر همه معلوم باشد، `null` (یعنی از followUp پیش‌فرض راهنما استفاده نشود
  /// و ارزیابی بیاید).
  static (String, List<CaseNeed>)? nextQuestion(
    LegalGuide g,
    CaseFacts f, {
    PhraseVariator? v,
    Set<String> skip = const {},
  }) {
    final miss = missingNeeds(g, f, skip: skip).take(2).toList();
    if (miss.isEmpty) return null;
    final head = v == null ? _askHeads.first : v.pick('need.head', _askHeads);
    if (miss.length == 1) return ('$head ${miss.first.question}', miss);
    return (
      '$head\n• ${miss[0].question}\n• ${miss[1].question}',
      miss,
    );
  }

  // ───────────────────────── فهم پرسش ─────────────────────────

  static final Map<FollowUpKind, RegExp> _kindRe = {
    FollowUpKind.denial: RegExp(
        r'(?:اگه|اگر|چنانچه) (?:انکار|زیرش بزنه|زیر بار نره|قبول نکنه|حاشا|بگه (?:نگرفتم|نمیدونم|دروغه))'
        r'|انکار کنه|انکار کند|زیرش بزنه|زیرش بزند|حاشا کنه'),
    FollowUpKind.where: RegExp(
        r'(?:کجا|چه جایی|کدوم (?:مرجع|دادگاه|اداره)|کدام (?:مرجع|دادگاه|اداره)|به کجا|کدوم دادگاه|چه مرجعی)'
        r'(?: باید| برم| بروم| مراجعه| شکایت| دادخواست| ثبت|$| )'),
    FollowUpKind.cost: RegExp(
        r'(?:هزینه|خرج|پول (?:دادگاه|شکایت|دادخواست)|چقدر (?:پول|هزینه) (?:میخواد|میشه|می شود|لازمه))'),
    FollowUpKind.deadline: RegExp(r'(?:مهلت|تا کی (?:وقت|فرصت)|فرصت دارم|دیر شده|مرور زمان|دیر نشده)'),
    FollowUpKind.duration: RegExp(
        r'(?:چقدر طول|چند وقت طول|کی (?:تموم|تمام) میشه|چقدر زمان|چه مدت طول|طول میکشه|طول می کشد|طول میکشد)'),
    FollowUpKind.chance: RegExp(
        r'(?:شانس|حق با منه|حق با من است|حق با منه|برنده میشم|می برم|میبرم|موفق میشم|پیروز|احتمال (?:موفقیت|بردن)|میتونم (?:پولمو|حقمو) بگیرم|می تونم (?:پولمو|حقمو) بگیرم|پولمو (?:بگیرم|میگیرم|پس میگیرم)|حقمو (?:بگیرم|میگیرم))'),
    FollowUpKind.lawyer: RegExp(
        r'(?:وکیل (?:لازم|بگیرم|میخوام|می خوام|نیاز|لازمه|بگیریم)|نیاز به وکیل|بدون وکیل|خودم (?:میتونم|می تونم|می توانم) (?:اقدام|شکایت|پیگیری))'),
    FollowUpKind.evidenceNeeded: RegExp(
        r'(?:چه|چی|کدوم|کدام) (?:مدرک|مدارک|سند|اسناد|مدرکی)(?:ی)? (?:لازم|میخواد|نیاز|ببرم|بیارم|داشته باشم)'),
    FollowUpKind.whatNow: RegExp(
        r'(?:چیکار کنم|چکار کنم|چی کار کنم|چه کار کنم|چه کنم|چیکار باید بکنم|باید چیکار کنم|باید چکار کنم|قدم (?:اول|بعدی)|از کجا شروع کنم|اول (?:باید )?چیکار|الان چی|حالا چی|راهش چیه|راه حل چیه|چه اقدامی)'),
  };

  static final RegExp _yesRe =
      RegExp(r'^(?:آره|اره|بله|بلی|آری|آره خب|بله خب|درسته|همینطوره|همین طوره|دقیقا|آره دقیقا|بله دقیقا|اوهوم|آهان آره|بله همینطوره|آره تموم شده|بله تموم شده)$');
  static final RegExp _noRe =
      RegExp(r'^(?:نه|خیر|نخیر|نه خیر|نه هنوز|هنوز نه|نه اصلا|اصلا|نه بابا|نچ|نه نیست|نه ندارم|نه نداریم|ندارم|نداریم|نیست)$');
  static final RegExp _dontKnowRe = RegExp(
      r'^(?:نمیدونم|نمی دونم|نمی دانم|نمیدانم|نمی‌دونم|مطمئن نیستم|خبر ندارم|یادم نیست|اطلاع ندارم|نمیدونم والا|والا نمیدونم)$');

  /// نوع پیام کوتاه/پرسش کاربر در بافت پرونده، یا `null`.
  static FollowUpKind? classify(String rawText) {
    final p = PersianText.phrase(rawText);
    if (p.isEmpty) return null;
    if (_yesRe.hasMatch(p)) return FollowUpKind.yes;
    if (_noRe.hasMatch(p)) return FollowUpKind.no;
    if (_dontKnowRe.hasMatch(p)) return FollowUpKind.dontKnow;
    // پیام‌های بلند معمولاً شرح ماجرای تازه‌اند، نه پرسش وابسته به بافت.
    if (p.split(' ').length > 12) return null;
    for (final e in _kindRe.entries) {
      if (e.value.hasMatch(p)) return e.key;
    }
    return null;
  }

  static bool isQuestionKind(FollowUpKind k) =>
      k != FollowUpKind.yes && k != FollowUpKind.no && k != FollowUpKind.dontKnow;

  // ───────────────────────── پاسخ‌ها ─────────────────────────

  static String _fa(String s) => PersianText.toFaDigits(s);

  static String _tomanText(int t) {
    if (t >= 1000000000 && t % 100000000 == 0) {
      final b = t / 1000000000;
      final s = b == b.roundToDouble() ? '${b.toInt()}' : b.toStringAsFixed(1);
      return _fa('$s میلیارد تومان');
    }
    if (t >= 1000000) return _fa('${t ~/ 1000000} میلیون تومان');
    return _fa('$t تومان');
  }

  static const LegalRef _councils12 = LegalRef('dispute_councils', '12');

  /// توضیح نصاب دادگاه صلح بر اساس مبلغی که کاربر گفته.
  static String? _nisabLine(CaseFacts f) {
    final t = f.firstAmountToman;
    if (t == null) return null;
    const nisab = 100000000; // یک میلیارد ریال
    final amount = _tomanText(t);
    if (t <= nisab) {
      return 'مبلغی که گفتید (حدود $amount، اگر منظورتان تومان است) از نصاب یک میلیارد ریال (صد میلیون تومان) بیشتر نیست؛ پس دعوای مالی شما در «دادگاه صلح» رسیدگی می‌شود (بند ۱ مادهٔ ۱۲ قانون شوراهای حل اختلاف). این نصاب را رئیس قوه قضائیه می‌تواند هر سه سال تعدیل کند؛ هنگام ثبت، دفتر خدمات قضایی مرجع درست را تعیین می‌کند.';
    }
    return 'مبلغی که گفتید (حدود $amount، اگر منظورتان تومان است) از نصاب یک میلیارد ریال (صد میلیون تومان) دادگاه صلح بیشتر است؛ پس دعوای مالی شما در «دادگاه عمومی حقوقی» رسیدگی می‌شود (بند ۱ مادهٔ ۱۲ قانون شوراهای حل اختلاف). این نصاب ممکن است تعدیل شده باشد؛ هنگام ثبت، دفتر خدمات قضایی مرجع درست را تعیین می‌کند.';
  }

  static ReasonedAnswer where(LegalGuide g, CaseFacts f) {
    final fam = familyOf(g);
    final lines = <String>[];
    final refs = <LegalRef>[];
    switch (fam) {
      case 'lease':
        lines.add(
            'دعاوی تخلیه در «دادگاه صلح» رسیدگی می‌شود (بند ۴ مادهٔ ۱۲ قانون شوراهای حل اختلاف).');
        refs.add(_councils12);
        final n = _nisabLine(f);
        if (g.id == 'deposit_return') {
          lines.add(n ??
              'مطالبهٔ ودیعه یک دعوای مالی است: تا نصاب یک میلیارد ریال در دادگاه صلح و بیشتر از آن در دادگاه عمومی حقوقی (بند ۱ همان ماده).');
        }
        lines.add(
            'ثبت درخواست یا دادخواست از طریق دفاتر خدمات الکترونیک قضایی انجام می‌شود.');
        break;
      case 'labor':
        lines.add(
            'اختلاف کارگر و کارفرما در دادگستری رسیدگی نمی‌شود؛ باید به «ادارهٔ کار» محل کارگاه مراجعه کنید. اگر سازش نشود، «هیئت تشخیص» رسیدگی می‌کند (مادهٔ ۱۵۷ قانون کار) و به رأی آن ظرف ۱۵ روز از ابلاغ می‌شود در «هیئت حل اختلاف» اعتراض کرد (مادهٔ ۱۵۹).');
        refs.addAll(const [LegalRef('labor', '157'), LegalRef('labor', '159')]);
        if (g.id == 'labor_insurance' || f.has(CaseFlag.noInsurance)) {
          lines.add(
              'برای بیمه‌نشدن، جداگانه به شعبهٔ «سازمان تأمین اجتماعی» شکایت کنید.');
        }
        break;
      case 'family':
        lines.add(
            'دعاوی مهریه، نفقه، طلاق و حضانت در «دادگاه خانواده» رسیدگی می‌شود (مادهٔ ۴ قانون حمایت خانواده).');
        refs.add(const LegalRef('family_protection', '4'));
        if (g.id == 'mahrieh' || g.id == 'nafaqeh') {
          lines.add(
              'البته مهریه و نفقه تا نصاب یک میلیارد ریال، اگر همراه طلاق مطرح نشود، در «دادگاه صلح» رسیدگی می‌شود (بند ۳ مادهٔ ۱۲ قانون شوراهای حل اختلاف).');
          refs.add(_councils12);
        }
        break;
      case 'cheque':
        lines.add(
            'برای وصول پول، با گواهی عدم پرداخت از «دادگاه صالح» درخواست صدور اجرائیه کنید (مادهٔ ۲۳ قانون صدور چک). برای جنبهٔ کیفری، شکوائیه را از طریق دفاتر خدمات الکترونیک قضایی ثبت کنید.');
        refs.add(const LegalRef('cheque', '23'));
        final n = _nisabLine(f);
        if (n != null) lines.add(n);
        break;
      case 'debt':
        lines.add(_nisabLine(f) ??
            'دعوای مطالبهٔ طلب تا نصاب یک میلیارد ریال (صد میلیون تومان) در «دادگاه صلح» و بیشتر از آن در «دادگاه عمومی حقوقی» رسیدگی می‌شود (بند ۱ مادهٔ ۱۲ قانون شوراهای حل اختلاف).');
        refs.add(_councils12);
        lines.add(
            'اصولاً دعوا باید در حوزهٔ قضایی محل اقامت خوانده (بدهکار) طرح شود (مادهٔ ۱۱ قانون آیین دادرسی مدنی). ثبت از طریق دفاتر خدمات الکترونیک قضایی است.');
        refs.add(const LegalRef('civil_procedure', '11'));
        break;
      case 'accident':
        lines.add(
            'جنبهٔ کیفری و خصوصی جرائم غیرعمدی ناشی از تصادفات رانندگی در «دادگاه صلح» رسیدگی می‌شود (بند ۹ مادهٔ ۱۲ قانون شوراهای حل اختلاف). برای خسارت مالی، اول با کروکی به شرکت بیمهٔ مقصر مراجعه کنید.');
        refs.add(_councils12);
        break;
      case 'criminal':
      case 'detention':
        lines.add(
            'شکایت کیفری را می‌توانید از طریق دفاتر خدمات الکترونیک قضایی یا مستقیم در دادسرا ثبت کنید؛ دادستان مکلف است شکایت کتبی یا شفاهی را همه وقت قبول کند (مادهٔ ۶۹ قانون آیین دادرسی کیفری). در موارد فوری با ۱۱۰ تماس بگیرید.');
        refs.add(const LegalRef('criminal_procedure', '69'));
        break;
      case 'inheritance':
        lines.add(
            'گواهی حصر وراثت را «دادگاه صلح» صادر می‌کند (بند ۶ مادهٔ ۱۲ قانون شوراهای حل اختلاف)؛ درخواستش را از طریق دفاتر خدمات الکترونیک قضایی ثبت کنید. دعوای تقسیم ترکه پس از آن مطرح می‌شود.');
        refs.add(_councils12);
        break;
      case 'property_damage':
        lines.add(
            'برای ثبت فوری وضعیت خسارت، از «دادگاه صلح» درخواست تأمین دلیل کنید (بند ۷ مادهٔ ۱۲ قانون شوراهای حل اختلاف).');
        refs.add(_councils12);
        lines.add(_nisabLine(f) ??
            'خود دعوای خسارت تا نصاب یک میلیارد ریال در دادگاه صلح و بیشتر از آن در دادگاه عمومی حقوقی رسیدگی می‌شود.');
        break;
      default:
        lines.add(
            'رسیدگی نخستین به دعاوی با دادگاه‌های عمومی است مگر قانون مرجع دیگری تعیین کرده باشد (مادهٔ ۱۰ قانون آیین دادرسی مدنی)، و اصولاً دعوا در محل اقامت خوانده طرح می‌شود (مادهٔ ۱۱). دفاتر خدمات الکترونیک قضایی هنگام ثبت، مرجع صالح را تعیین می‌کنند.');
        refs.addAll(const [
          LegalRef('civil_procedure', '10'),
          LegalRef('civil_procedure', '11'),
        ]);
    }
    return ReasonedAnswer(
      'برای «${g.title}» مرجع رسیدگی این است:\n${lines.map((l) => '• ${_fa(l)}').join('\n')}',
      refs,
    );
  }

  static ReasonedAnswer deadline(LegalGuide g, CaseFacts f) {
    final fam = familyOf(g);
    switch (fam) {
      case 'cheque':
        final cert = f.has(CaseFlag.certificateIssued);
        return ReasonedAnswer(
          _fa(
              'بله، در چک مهلت مهم است. طبق مادهٔ ۱۱ قانون صدور چک، جنبهٔ کیفری فقط با شکایت دارنده تعقیب می‌شود و اگر دارنده تا شش ماه از تاریخ صدور چک به بانک مراجعه نکند، یا ظرف شش ماه از تاریخ صدور گواهی عدم پرداخت شکایت نکند، دیگر حق شکایت کیفری ندارد.\n\n'
              '${cert ? 'چون گواهی عدم پرداخت گرفته‌اید، شش ماه از تاریخ همان گواهی برای شکایت کیفری وقت دارید.' : 'اگر هنوز گواهی عدم پرداخت نگرفته‌اید، حواستان به شش ماه از تاریخ چک باشد و هرچه زودتر به بانک بروید.'}'
              ' گذشتن این مهلت فقط حق شکایت کیفری را از بین می‌برد؛ مطالبهٔ حقوقی پول از مسیر دادگاه همچنان ممکن است.'),
          const [LegalRef('cheque', '11')],
        );
      case 'procedure':
        return ReasonedAnswer(
          _fa(
              'مهلت تجدیدنظرخواهی از رأی دادگاه برای اشخاص مقیم ایران بیست روز و برای مقیم خارج دو ماه از تاریخ ابلاغ است (مادهٔ ۳۳۶ قانون آیین دادرسی مدنی). تاریخ ابلاغ را دقیق از سامانهٔ ثنا ببینید.'),
          const [LegalRef('civil_procedure', '336')],
        );
      case 'labor':
        return ReasonedAnswer(
          _fa(
              'در متن قانون کار که در برنامه هست، برای ثبت شکایت حقوق یا اخراج مهلت مشخصی نیامده؛ اما هرچه دیرتر اقدام کنید، اثبات سخت‌تر می‌شود و درخواست بازگشت به کار هم تضعیف می‌شود. مهلت مهمی که قانون صریحاً گفته این است: به رأی هیئت تشخیص ظرف ۱۵ روز از ابلاغ می‌شود اعتراض کرد (مادهٔ ۱۵۹ قانون کار).'),
          const [LegalRef('labor', '159')],
        );
      case 'contract':
        if (g.id == 'defect_purchase') {
          return ReasonedAnswer(
            _fa(
                'اینجا مهلت بسیار کوتاه است: خیار عیب و خیار تدلیس «فوری»‌اند (مواد ۴۳۵ و ۴۴۰ قانون مدنی)؛ یعنی به‌محض اطلاع از عیب یا فریب، باید فسخ یا مطالبهٔ ارش را اعلام کنید. بهترین راه، فرستادن اظهارنامهٔ رسمی همین حالاست.'),
            const [LegalRef('civil', '435'), LegalRef('civil', '440')],
          );
        }
        break;
    }
    return ReasonedAnswer(_fa(
        'برای «${g.title}» در متن قوانینی که در برنامه دارم، مهلت مشخصی برای شروع اقدام ثبت نشده و نمی‌خواهم عددی حدسی بگویم. قاعدهٔ کلی این است که هرچه زودتر اقدام کنید، مدارک تازه‌تر و موقعیت شما محکم‌تر است. اگر رأیی صادر شد، برای اعتراض به آن مهلت قانونی دارید که در برگهٔ ابلاغ قید می‌شود.'));
  }

  static ReasonedAnswer cost(LegalGuide g, CaseFacts f) {
    final fam = familyOf(g);
    final sb = StringBuffer();
    if (fam == 'labor') {
      sb.write(
          'شکایت در ادارهٔ کار مسیر کم‌هزینه‌ای است و معمولاً بدون وکیل هم انجام می‌شود.');
    } else if (fam == 'criminal' || fam == 'detention' || fam == 'accident') {
      sb.write(
          'ثبت شکوائیه هزینهٔ زیادی ندارد؛ بیشتر هزینه‌ها مربوط به کارشناسی یا وکیل (اگر بگیرید) است.');
    } else {
      sb.write(
          'در دعاوی مالی، هزینهٔ دادرسی به مبلغ خواسته بستگی دارد و طبق تعرفهٔ قانونی محاسبه می‌شود؛ مبلغ دقیق را دفتر خدمات الکترونیک قضایی هنگام ثبت اعلام می‌کند (مادهٔ ۵۰۳ قانون آیین دادرسی مدنی). ');
      final t = f.firstAmountToman;
      if (t != null) {
        sb.write(
            'چون مبلغ شما حدود ${_tomanText(t)} است، هزینه هم بر همین اساس محاسبه می‌شود. ');
      }
      sb.write(
          'فرستادن اظهارنامه پیش از دعوا ارزان است و گاهی بدون دادگاه کار را تمام می‌کند. اگر توان پرداخت هزینه را ندارید، می‌توانید هم‌زمان «دادخواست اعسار از هزینهٔ دادرسی» بدهید.');
    }
    return ReasonedAnswer(
      _fa(sb.toString()),
      fam == 'labor' || fam == 'criminal' || fam == 'detention' || fam == 'accident'
          ? const []
          : const [LegalRef('civil_procedure', '503')],
    );
  }

  static ReasonedAnswer duration(LegalGuide g, CaseFacts f) {
    final fam = familyOf(g);
    final fast = switch (fam) {
      'cheque' =>
        'سریع‌ترین مسیر در چک، درخواست اجرائیه است؛ چون رسیدگی کامل دادگاه لازم ندارد.',
      'labor' =>
        'در ادارهٔ کار، اول جلسهٔ سازش برگزار می‌شود؛ اگر کارفرما همکاری کند، کار زودتر تمام می‌شود.',
      'lease' =>
        'اگر قرارداد شرایط لازم را داشته باشد، دستور تخلیه در قالب درخواست ساده و سریع‌تر از دادخواست صادر می‌شود.',
      'criminal' =>
        'در پرونده‌های کیفری، سرعت ثبت شکایت و کامل بودن مدارک بیشترین اثر را دارد.',
      _ =>
        'فرستادن اظهارنامه و تلاش برای سازش پیش از دادگاه، معمولاً سریع‌ترین راه به نتیجه است.',
    };
    return ReasonedAnswer(_fa(
        'زمان دقیق را نمی‌شود از قبل گفت و نمی‌خواهم عددی حدسی بدهم؛ به حجم کار شعبه، ابلاغ به طرف مقابل، نیاز به کارشناسی و اعتراض‌ها بستگی دارد. $fast'));
  }

  static ReasonedAnswer lawyer(LegalGuide g, CaseFacts f) {
    final fam = familyOf(g);
    final head = switch (fam) {
      'labor' =>
        'برای شکایت در ادارهٔ کار معمولاً وکیل لازم نیست و خودتان می‌توانید پیگیری کنید.',
      'detention' =>
        'در بازداشت، داشتن وکیل بسیار مهم است و متهم از همان ابتدای تحت نظر بودن می‌تواند تقاضای حضور وکیل کند (مادهٔ ۴۸ قانون آیین دادرسی کیفری).',
      'criminal' =>
        'برای ثبت شکایت وکیل اجباری نیست، اما اگر اتهام سنگین است یا طرف مقابل وکیل دارد، گرفتن وکیل موقعیت شما را بهتر می‌کند.',
      _ =>
        'در بیشتر دعاوی، داشتن وکیل اجباری نیست و خودتان می‌توانید دادخواست یا درخواست را ثبت کنید.',
    };
    final big = (f.firstAmountToman ?? 0) > 1000000000;
    return ReasonedAnswer(
      _fa(
          '$head${big ? ' چون مبلغ پرونده زیاد است، مشورت با وکیل پیش از اقدام ارزشش را دارد.' : ''} اگر هزینهٔ وکیل برایتان سنگین است، از کانون وکلا یا مرکز وکلای قوه قضائیه «وکیل معاضدتی» بخواهید. تا آن موقع، من کمکتان می‌کنم مدارک را مرتب و متن‌ها را آماده کنید.'),
      fam == 'detention' ? const [LegalRef('criminal_procedure', '48')] : const [],
    );
  }

  static ReasonedAnswer denial(LegalGuide g, CaseFacts f) {
    final sb = StringBuffer(
        'اگر طرف مقابل انکار کند، «بار اثبات» با کسی است که ادعا می‌کند؛ یعنی شما باید ادعایتان را ثابت کنید و اگر نتوانید، با سوگند او حکم به برائتش داده می‌شود (مادهٔ ۱۹۷ قانون آیین دادرسی مدنی). پس همه‌چیز به دلیل برمی‌گردد.\n\nبا چیزهایی که تا اینجا گفته‌اید:');
    final e = f.evidence;
    final bullets = <String>[];
    if (e.contains('receipt')) {
      bullets.add(
          'سابقهٔ واریز بانکی ثابت می‌کند پول به حساب او رفته است؛ اما اینکه بابت قرض بوده (نه هدیه یا بدهی دیگر) را بهتر است با پیام، شاهد یا قرائن دیگر تقویت کنید.');
    }
    if (e.contains('cheque') || e.contains('promissory') || e.contains('contract')) {
      bullets.add(
          'سند کتبی (چک، سفته یا قرارداد) قوی‌ترین دلیل است؛ سند هر نوشته‌ای است که در دعوا قابل استناد باشد (مادهٔ ۱۲۸۴ قانون مدنی) و امضای او روی سند، علیه خودش دلیل است (مادهٔ ۱۳۰۱).');
    }
    if (e.contains('messages') || e.contains('screenshot')) {
      bullets.add(
          'پیام‌هایی که در آن به بدهی یا ماجرا اشاره کرده، می‌تواند حکم «اقرار» داشته باشد؛ اقرار یعنی خبر دادن به حقی برای دیگری به ضرر خود (مادهٔ ۱۲۵۹ قانون مدنی). اصل پیام‌ها را نگه دارید.');
    }
    if (e.contains('witness')) {
      bullets.add(
          'شاهدی که ماجرا را دیده یا شنیده، از دلایل پذیرفته‌شده است؛ مطمئن شوید حاضر است در دادگاه شهادت دهد.');
    }
    if (bullets.isEmpty) {
      bullets.add(
          'هنوز مدرکی از شما نشنیده‌ام. دلایل قابل استناد این‌هاست: سند کتبی (مادهٔ ۱۲۸۴ قانون مدنی)، اقرار طرف مقابل حتی در پیام (مادهٔ ۱۲۵۹)، شهادت شهود، و «اماره» یعنی اوضاع و احوالی که دلیل بر امری شناخته می‌شود (مادهٔ ۱۳۲۱). هرچه از این‌ها دارید جمع کنید.');
    }
    sb.write('\n${bullets.map((b) => '• $b').join('\n')}');
    if (familyOf(g) == 'criminal') {
      sb.write(
          '\n\nدر شکایت کیفری، بازپرس هم خودش تحقیق می‌کند؛ پس اطلاعاتی مثل شمارهٔ حساب، شمارهٔ تلفن یا محل دوربین‌ها را حتماً در شکوائیه بنویسید.');
    }
    return ReasonedAnswer(_fa(sb.toString()), const [
      LegalRef('civil_procedure', '197'),
      LegalRef('civil', '1284'),
      LegalRef('civil', '1301'),
      LegalRef('civil', '1259'),
      LegalRef('civil', '1321'),
    ]);
  }

  /// ارزیابی اولیهٔ موقعیت کاربر: نقاط قوت، نقاط ضعف و آنچه هنوز معلوم نیست.
  static ReasonedAnswer chance(
    LegalGuide g,
    CaseFacts f, {
    Set<String> skip = const {},
  }) {
    final strong = <String>[];
    final weak = <String>[];
    final e = f.evidence;
    final hasDoc = e.any((x) => const {
          'contract',
          'receipt',
          'cheque',
          'promissory',
          'police_report',
        }.contains(x));
    final hasSoft = e.any((x) => const {
          'messages',
          'screenshot',
          'witness',
          'photos',
          'recording',
        }.contains(x));
    if (hasDoc) {
      strong.add('مدرک کتبی یا بانکی دارید؛ این مهم‌ترین پشتوانهٔ هر دعواست.');
    } else if (hasSoft) {
      strong.add(
          'مدارکی مثل پیام یا شاهد دارید که قابل استناد است؛ اما بهتر است با مدرک کتبی یا بانکی تقویت شود.');
    } else if (f.has(CaseFlag.noEvidence)) {
      weak.add(
          'فعلاً مدرکی ندارید؛ در صورت انکار طرف مقابل، اثبات چالش اصلی پرونده است.');
    }
    switch (g.id) {
      case 'deposit_return':
        if (f.has(CaseFlag.contractEnded)) {
          strong.add(
              'مدت قرارداد تمام شده و صاحبخانه از همین حالا موظف به استرداد ودیعه است؛ تا ودیعه را نگیرید، تحویل ملک به او الزامی ندارد (مادهٔ ۴ قانون روابط موجر و مستأجر).');
        } else if (f.denies(CaseFlag.contractEnded)) {
          weak.add(
              'مدت قرارداد هنوز تمام نشده؛ اصولاً پیش از پایان مدت، صاحبخانه تکلیفی به استرداد ودیعه ندارد، مگر قرارداد به شکل قانونی فسخ شده باشد.');
        }
        break;
      case 'cheque_bounced':
        if (f.has(CaseFlag.certificateIssued)) {
          strong.add(
              'گواهی عدم پرداخت دارید؛ با آن می‌شود مستقیم درخواست اجرائیه داد (مادهٔ ۲۳ قانون صدور چک)، که سریع‌ترین مسیر وصول است.');
        } else if (f.denies(CaseFlag.certificateIssued)) {
          weak.add(
              'هنوز گواهی عدم پرداخت نگرفته‌اید؛ بدون آن نه اجرائیه ممکن است و نه شکایت کیفری. اولین کار رفتن به بانک است.');
        }
        break;
      case 'unpaid_wages':
      case 'dismissal':
        if (f.has(CaseFlag.noWrittenContract)) {
          weak.add(
              'قرارداد کتبی ندارید؛ اما رابطهٔ کاری را می‌شود با شاهد، پیام‌ها و واریزهای حقوق ثابت کرد.');
        }
        strong.add(
            'قانون کار از کارگر حمایت جدی می‌کند و مرجع رسیدگی (ادارهٔ کار) هم کم‌هزینه است.');
        break;
      case 'accident':
        if (f.has(CaseFlag.otherAtFault)) {
          strong.add(
              'مقصر طرف مقابل است؛ پس مسئول جبران خسارت است (مادهٔ ۱ قانون مسئولیت مدنی).');
        } else if (f.has(CaseFlag.selfAtFault)) {
          weak.add(
              'اگر مقصر شما هستید، مطالبه‌ای از طرف مقابل ندارید و موضوع اصلی، پرداخت خسارت او از بیمهٔ خودروی شماست.');
        }
        break;
      case 'nafaqeh':
        strong.add(
            'نفقهٔ زن در عقد دائم بر عهدهٔ شوهر است (مادهٔ ۱۱۰۶ قانون مدنی) و نفقهٔ گذشته هم قابل مطالبه است.');
        break;
    }
    final missing = missingNeeds(g, f, skip: skip);
    final sb = StringBuffer(
        'با اطلاعاتی که تا اینجا داده‌اید، ارزیابی اولیهٔ من این است (پیش‌بینی قطعی نتیجه ممکن نیست و به مدارک و دفاع طرف مقابل بستگی دارد):');
    if (strong.isNotEmpty) {
      sb.write('\n\nنقاط قوت شما:\n${strong.map((s) => '• $s').join('\n')}');
    }
    if (weak.isNotEmpty) {
      sb.write('\n\nنکته‌هایی که باید حواستان باشد:\n${weak.map((s) => '• $s').join('\n')}');
    }
    if (strong.isEmpty && weak.isEmpty) {
      sb.write(
          '\n\nهنوز اطلاعات کافی برای ارزیابی ندارم؛ مهم‌ترین چیز، مدارکی است که در دست دارید.');
    }
    if (missing.isNotEmpty) {
      sb.write('\n\nبرای ارزیابی دقیق‌تر، این را هم بگویید: ${missing.first.question}');
    }
    final refs = <LegalRef>[
      if (g.id == 'deposit_return' && f.has(CaseFlag.contractEnded))
        const LegalRef('landlord_tenant', '4'),
      if (g.id == 'cheque_bounced' && f.has(CaseFlag.certificateIssued))
        const LegalRef('cheque', '23'),
      if (g.id == 'accident' && f.has(CaseFlag.otherAtFault))
        const LegalRef('civil_liability', '1'),
      if (g.id == 'nafaqeh') const LegalRef('civil', '1106'),
    ];
    return ReasonedAnswer(_fa(sb.toString()), refs);
  }

  static ReasonedAnswer evidenceNeeded(LegalGuide g, CaseFacts f) {
    final fam = familyOf(g);
    final list = switch (fam) {
      'lease' => [
          'اجاره‌نامه',
          'رسید یا سابقهٔ بانکی پرداخت ودیعه و اجاره‌ها',
          'هر پیام یا نامه‌ای دربارهٔ تخلیه یا استرداد',
        ],
      'labor' => [
          'قرارداد کار (اگر دارید)',
          'فیش‌ها یا واریزهای حقوق',
          'سابقهٔ بیمه',
          'نام همکارانی که شهادت می‌دهند',
          'پیام‌ها دربارهٔ کار یا اخراج',
        ],
      'family' => [
          'سند ازدواج (عقدنامه)',
          'شناسنامه‌ها',
          'هر مدرکی از توان مالی شوهر یا قطع هزینه‌ها',
        ],
      'cheque' => [
          'اصل چک',
          'گواهی عدم پرداخت',
          'کارت ملی',
        ],
      'debt' => [
          'رسید یا پرینت واریز',
          'پیام‌هایی که بدهی را نشان می‌دهد',
          'سند، چک یا سفته (اگر هست)',
          'مشخصات شاهد',
        ],
      'accident' => [
          'کروکی یا گزارش پلیس',
          'عکس صحنه و خودروها',
          'بیمه‌نامه‌ها',
          'مدارک پزشکی (اگر آسیب جسمی هست)',
        ],
      'criminal' => [
          'هر مدرکی از وقوع جرم (پیام، عکس، فیلم، فیش واریز)',
          'مشخصات یا شمارهٔ طرف مقابل',
          'نام و شمارهٔ شاهدان',
        ],
      _ => [
          'هر سند یا قراردادی که دارید',
          'پیام‌ها و مکاتبات',
          'رسیدهای پرداخت',
          'مشخصات شاهدان',
        ],
    };
    final have = f.evidence.map((x) => CaseFacts.evidenceLabel[x] ?? x).toList();
    final sb = StringBuffer('برای «${g.title}» این مدارک را آماده کنید:\n');
    sb.write(list.map((x) => '• $x').join('\n'));
    if (have.isNotEmpty) {
      sb.write('\n\nاز این‌ها، این‌ها را گفته‌اید که دارید: ${have.join('، ')}.');
    }
    sb.write('\n\nاز همه کپی بگیرید و اصل مدارک را تا جلسهٔ رسیدگی نزد خودتان نگه دارید.');
    return ReasonedAnswer(_fa(sb.toString()));
  }

  static const List<String> _whatNowHeads = [
    'با توجه به همهٔ چیزهایی که گفتید، پیشنهاد من به ترتیب این است:',
    'اگر جای شما بودم، از همین امروز این‌طور پیش می‌رفتم:',
    'برنامهٔ عملی شما، متناسب با وضعیتی که گفتید:',
  ];

  static ReasonedAnswer whatNow(LegalGuide g, CaseFacts f, {PhraseVariator? v}) {
    final steps = <String>[];
    // اقدام فوری مخصوص وضعیت، پیش از قدم‌های عمومی راهنما.
    if (g.id == 'cheque_bounced' && !f.has(CaseFlag.certificateIssued)) {
      steps.add('اول چک را به بانک ببرید و گواهی عدم پرداخت بگیرید؛ بدون آن هیچ اقدامی ممکن نیست.');
    }
    if (g.id == 'deposit_return' && f.has(CaseFlag.contractEnded)) {
      steps.add('تا ودیعه را نگرفته‌اید، کلید و ملک را تحویل ندهید؛ این قوی‌ترین اهرم شماست.');
    }
    if (g.id == 'accident' && !f.has(CaseFlag.otherAtFault) && !f.has(CaseFlag.selfAtFault)) {
      steps.add('اگر هنوز کروکی نگرفته‌اید، همین حالا با ۱۱۰ تماس بگیرید.');
    }
    for (final s in g.steps) {
      if (steps.length >= 4) break;
      if (f.evidence.isNotEmpty && _isEvidenceStep(s)) continue;
      // قدمی که وضعیتش معلوم شده (مثلاً گواهی عدم پرداخت گرفته شده).
      if (s.contains('اگر هنوز گواهی عدم پرداخت') &&
          f.knows(CaseFlag.certificateIssued)) {
        continue;
      }
      if (steps.any((x) => _similar(x, s))) continue;
      steps.add(s);
    }
    final head = v == null ? _whatNowHeads.first : v.pick('whatnow.head', _whatNowHeads);
    final sb = StringBuffer(head);
    for (var i = 0; i < steps.length; i++) {
      sb.write('\n${_fa('${i + 1}')}. ${_fa(steps[i])}');
    }
    if (f.evidence.isNotEmpty) {
      final have = f.evidence.map((x) => CaseFacts.evidenceLabel[x] ?? x).join('، ');
      sb.write(_fa('\n\nمدارکی که گفتید ($have) را همراه داشته باشید.'));
    }
    return ReasonedAnswer(sb.toString());
  }

  /// دو قدم تقریباً یکسان‌اند اگر بیشتر واژه‌های قدم کوتاه‌تر در دیگری باشد.
  static bool _similar(String a, String b) {
    final wa = PersianText.phrase(a).split(' ').toSet();
    final wb = PersianText.phrase(b).split(' ').toSet();
    final small = wa.length <= wb.length ? wa : wb;
    final big = identical(small, wa) ? wb : wa;
    if (small.isEmpty) return false;
    final common = small.where(big.contains).length;
    return common / small.length >= 0.7;
  }

  static bool _isEvidenceStep(String s) =>
      s.contains('مدارک') && (s.contains('نگه دارید') || s.contains('جمع'));

  /// پاسخ به یک نوع پرسش وابسته به بافت.
  static ReasonedAnswer answer(
    FollowUpKind k,
    LegalGuide g,
    CaseFacts f, {
    PhraseVariator? v,
  }) {
    switch (k) {
      case FollowUpKind.where:
        return where(g, f);
      case FollowUpKind.cost:
        return cost(g, f);
      case FollowUpKind.duration:
        return duration(g, f);
      case FollowUpKind.deadline:
        return deadline(g, f);
      case FollowUpKind.chance:
        return chance(g, f);
      case FollowUpKind.denial:
        return denial(g, f);
      case FollowUpKind.lawyer:
        return lawyer(g, f);
      case FollowUpKind.evidenceNeeded:
        return evidenceNeeded(g, f);
      case FollowUpKind.whatNow:
      case FollowUpKind.yes:
      case FollowUpKind.no:
      case FollowUpKind.dontKnow:
        return whatNow(g, f, v: v);
    }
  }

  /// همهٔ ارجاع‌هایی که این ماژول ممکن است بدهد (برای آزمون وجود در بانک).
  static List<LegalRef> allPossibleRefs() => const [
        LegalRef('dispute_councils', '12'),
        LegalRef('labor', '157'),
        LegalRef('labor', '159'),
        LegalRef('family_protection', '4'),
        LegalRef('cheque', '11'),
        LegalRef('cheque', '23'),
        LegalRef('civil_procedure', '10'),
        LegalRef('civil_procedure', '11'),
        LegalRef('civil_procedure', '197'),
        LegalRef('civil_procedure', '336'),
        LegalRef('civil_procedure', '503'),
        LegalRef('criminal_procedure', '48'),
        LegalRef('criminal_procedure', '69'),
        LegalRef('civil', '435'),
        LegalRef('civil', '440'),
        LegalRef('civil', '1106'),
        LegalRef('civil', '1259'),
        LegalRef('civil', '1284'),
        LegalRef('civil', '1301'),
        LegalRef('civil', '1321'),
        LegalRef('landlord_tenant', '4'),
        LegalRef('civil_liability', '1'),
      ];
}
