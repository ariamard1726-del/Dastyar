import 'package:dastyar/domain/advocate/advocate_texts_loader.dart';

import 'text_sense.dart';

/// قواعد فهم برای متن کاربر: تشخیص تکرار حرف قبلی، پیوند واژه‌های کاربر با
/// مادهٔ مشخص، و قاعدهٔ تعارض میان دو حکم.
///
/// همهٔ استنادها فقط به موادی‌اند که در متن قانون موجود در برنامه دیده شده‌اند
/// (کلیدها در `assets/laws/_meta.json`). اگر متنی نیست، قاعده هم نیست.
class Understanding {
  Understanding._();

  static final RegExp _digits = RegExp(r'^[0-9۰-۹]+$');

  /// واژه‌های عمومیِ حقوقی و تکراری که برای سنجیدن شباهت به کار نمی‌آیند.
  static const Set<String> _generic = {
    'قانون', 'ماده', 'مواد', 'مجازات', 'اسلامی', 'آیا', 'یکی', 'هست', 'چیست',
    'چیه', 'باید', 'میشه', 'میتونم', 'میتوانم', 'این', 'آن', 'با', 'که',
    'برای', 'درباره', 'تفاوت', 'فرق', 'همان', 'داره', 'دارم', 'کنم', 'چکار',
  };

  /// پیام تازه همان حرف پیشین کاربر است (تقریباً عین). فقط پیام‌های بلند
  /// سنجیده می‌شوند، تا «بله» یا «نه» تکرار حساب نشوند.
  static bool isRepeat(String prevN, String n) {
    if (prevN.isEmpty || n.isEmpty) return false;
    final a = _words(prevN);
    final b = _words(n);
    if (a.length < 6 || b.length < 6) return false;
    final inter = a.intersection(b).length;
    final uni = a.union(b).length;
    return uni > 0 && inter / uni >= 0.8;
  }

  static Set<String> _words(String n) => {
        for (final w in Sense.norm(n).split(' '))
          if (w.isNotEmpty) w,
      };

  /// واژه‌های معنادارِ یک متن (بدون کوتاه‌ها، عدد و واژه‌های عمومی).
  static Set<String> content(String n) => {
        for (final w in Sense.norm(n).split(' '))
          if (w.length >= 3 && !_generic.contains(w) && !_digits.hasMatch(w)) w,
      };

  /// پیوندِ واژه‌های کاربر با مادهٔ مشخص. فهرست کوتاه و تأییدشده است.
  static List<String> linkedArticles(String n) {
    final out = <String>[];
    void add(String ref) {
      if (!out.contains(ref)) out.add(ref);
    }

    if (Sense.has(n, 'گواهی عدم امکان سازش|ثبت طلاق|طلاق توافقی|سردفتر')) {
      add('[[family_protection:24]]');
      add('[[family_protection:35]]');
    }
    if (Sense.has(n, 'مهریه|مهر ')) add('[[civil:1082]]');
    if (Sense.has(n, 'غبن')) {
      add('[[civil:416]]');
      add('[[civil:417]]');
    }
    if (Sense.has(n, 'ودیعه|پیش ?پرداخت|پول پیش')) add('[[landlord_tenant:4]]');
    return out;
  }

  /// ثبت طلاق که یکی از دو طرف از آن امتناع می‌کند.
  static String? divorceRegistration(String n) {
    if (!Sense.has(n, 'طلاق')) return null;
    if (!Sense.has(n, 'ثبت|دفترخانه|دفتر خانه|سردفتر|دفتر رسمی|دفتر ازدواج')) {
      return null;
    }
    if (!Sense.has(n, 'خودداری|امتناع|مانع|نمی\\S*')) return null;
    return advocateText('underDivorceReg');
  }

  /// تعارض میان حکم کلی و حکم خاص، یا میان یک شرط قرارداد و حق قانونی.
  static String? conflictRule(String n) {
    // تخفیف مجازات: ماده ۳۸ کلی است؛ اگر ماده‌ای خاص همان جهت را آورده باشد،
    // همان جهت دوباره حساب نمی‌شود.
    final discount = Sense.has(n, 'ماده ?۳۸|ماده 38|تخفیف') &&
        Sense.has(n, 'گذشت|همکاری|جهات تخفیف');
    final twice = Sense.has(n,
        'ماده خاص|قانون ویژه|ماده ویژه|مواد خاص|جداگانه|دوبار|دوباره|دو بار|دو مرتبه');
    if (discount && twice) return advocateText('underConflictDiscount');

    // غبن: شرط صریح قرارداد دربارهٔ اسقاط غبن در برابر حق قانونی.
    final gabn = Sense.has(n, 'غبن');
    final waiver = Sense.has(n, 'اسقاط|ساقط|صراحت|صراحتاً|به‌صراحت|شرط');
    final fahish = Sense.has(n, 'فاحش|افحش');
    if (gabn && waiver && fahish) return advocateText('underConflictGabn');
    return null;
  }

  /// دکمهٔ پیشنهادیِ مرتبط با همین پیام: کوتاه، به زبان خودِ کاربر، و آماده
  /// برای فرستادن. اگر پیام همین دکمه باشد یا نشانه‌ای نباشد، `null`.
  static String? relevantChip(String raw) {
    final n = Sense.norm(raw);
    if (n.isEmpty) return null;
    for (final r in _chipRules) {
      if (!Sense.has(n, r.cue)) continue;
      if (r.also.isNotEmpty && !Sense.has(n, r.also)) continue;
      if (n.contains(Sense.norm(r.chip))) return null;
      return r.chip;
    }
    return null;
  }

  static List<_ChipRule> get _chipRules => [
        _ChipRule('مهریه', 'نداده|نمی ?دهد|پرداخت نکرده|نپرداخته|پرداخت نشده|نمیده', advocateText('underChip_0')),
        _ChipRule('نفقه', 'نداده|نمی ?دهد|پرداخت نکرده|نپرداخته|معوق|نمیده', advocateText('underChip_1')),
        _ChipRule('ودیعه|پول پیش|پیش ?پرداخت', 'نداده|نمی ?دهد|پس نداد|نمیده|برنمی', advocateText('underChip_2')),
        _ChipRule('حقوق', 'نداده|نداد|نمی ?دهد|معوق|نمیده', advocateText('underChip_3')),
        _ChipRule('چک', 'برگشت', advocateText('underChip_4')),
        _ChipRule('اخراج', '', advocateText('underChip_5')),
        _ChipRule('طلاق', 'ثبت|سردفتر|دفترخانه|دفتر', advocateText('underChip_6')),
        _ChipRule('غبن', '', advocateText('underChip_7')),
      ];
}

class _ChipRule {
  final String cue;
  final String also;
  final String chip;
  const _ChipRule(this.cue, this.also, this.chip);
}
