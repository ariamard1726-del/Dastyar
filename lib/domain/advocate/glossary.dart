import 'package:dastyar/domain/advocate/advocate_texts_loader.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';

/// یک اصطلاح حقوقی به زبان ساده.
class Term {
  final String id;
  final String cue;
  final String title;
  final String text;
  const Term(this.id, this.cue, this.title, this.text);
}

/// واژه‌نامهٔ وکیل: اصطلاح‌هایی که خودش به کار می‌برد باید بتواند ساده
/// توضیح بدهد. متن اصطلاح‌ها و مقایسه‌ها در `assets/brain/advocate_texts.json`
/// است و با [advocateText] خوانده می‌شود.
class Glossary {
  Glossary._();

  static Term _term(String id, String cue) => Term(
        id,
        cue,
        advocateText('term_${id}_title'),
        advocateText('term_${id}_text'),
      );

  static List<Term> get terms => [
        _term('esar', 'اعسار|معسر'),
        _term('dadkhast', 'دادخواست'),
        _term('shekvaiye', 'شکوائیه|شکایت ?نامه'),
        _term('ezharname', 'اظهارنامه'),
        _term('tamin_khaste', 'تامین خواسته'),
        _term('tamin_dalil', 'تامین دلیل'),
        _term('vakhahi', 'واخواهی|حکم غیابی|رای غیابی'),
        _term('tajdid', 'تجدید ?نظر'),
        _term('ejraiye', 'اجرائیه'),
        _term('sana', 'ثنا|ابلاغ الکترونیک'),
        _term('khahan', 'خواهان|خوانده'),
        _term('gharar', 'قرار تامین|قرار وثیقه|قرار کفالت'),
        _term('vasighe', 'وثیقه'),
        _term('kefalat', 'کفالت|کفیل'),
        _term('jalb', 'جلب'),
        _term('ojrat', 'اجرت ?المثل'),
        _term('sanavat', 'سنوات'),
        _term('mostasna', 'مستثنیات دین'),
        _term('osr', 'عسر و حرج'),
        _term('nafaqe', 'نفقه'),
        _term('hezanat', 'حضانت'),
        _term('tamkin', 'تمکین|نشوز|ناشزه'),
        _term('diye', 'دیه|ارش'),
        _term('khiar', 'خیار عیب|حق فسخ|فسخ'),
        _term('gozasht', 'قابل ?گذشت|جرم خصوصی'),
        _term('govahi', 'گواهی عدم پرداخت|برگشت زدن'),
        _term('sazesh', 'شورای حل اختلاف|سازش'),
        _term('baraat', 'برائت|منع تعقیب'),
      ];

  /// اصطلاح‌هایی که در متن آمده‌اند (به ترتیب واژه‌نامه).
  static List<Term> find(String n) =>
      [for (final t in terms) if (Sense.has(n, t.cue)) t];

  static String get civilVsCriminal => advocateText('glossCivilVsCriminal');

  static String get appealVsObjection => advocateText('glossAppealVsObjection');

  static String get bailVsSurety => advocateText('glossBailVsSurety');

  /// پاسخ مقایسه‌ای، اگر متن یکی از جفت‌های شناخته‌شده را بپرسد.
  static String? compare(String n) {
    final cmp = Sense.has(n, 'فرق|تفاوت|بهتره یا|یا (?:[^ ]+ ){0,3}بهتره|کدوم بهتر|فرقش');
    if (!cmp) return null;
    if (Sense.has(n, 'دادخواست') && Sense.has(n, 'شکوائیه|شکایت')) {
      return civilVsCriminal;
    }
    if (Sense.has(n, 'حقوقی') && Sense.has(n, 'کیفری') && !Sense.has(n, 'چک')) {
      return civilVsCriminal;
    }
    if (Sense.has(n, 'واخواهی') && Sense.has(n, 'تجدید ?نظر')) {
      return appealVsObjection;
    }
    if (Sense.has(n, 'وثیقه') && Sense.has(n, 'کفالت|کفیل')) {
      return bailVsSurety;
    }
    final ts = find(n);
    if (ts.length >= 2) {
      return '${ts[0].text}\n\n${ts[1].text}';
    }
    return null;
  }

  /// آیا متن معنی یک اصطلاح را می‌پرسد؟
  static bool asksMeaning(String n) => Sense.has(
        n,
        'یعنی چی|یعنی چه|چیه |چیست|چی هست|به چی میگن|منظور از|معنی(?:ش)? |تعریف|یعنی چی ؟',
      );
}
