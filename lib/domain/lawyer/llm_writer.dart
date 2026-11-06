/// لایهٔ «نویسنده»: مدل زبانی اختیاری فقط برای لحن انسانی‌تر به کار می‌رود.
///
/// اصل مهم: محتوای حقوقی (مواد، مهلت‌ها، مرجع‌ها، اعداد) همیشه از موتور قطعی
/// می‌آید. مدل فقط یکی دو جملهٔ آغازین می‌نویسد که نشان دهد حرف کاربر فهمیده
/// شده است؛ و [ProseGuard] هر جمله‌ای را که عدد، نام قانون، ماده، مهلت یا
/// قول نتیجه داشته باشد رد می‌کند تا هیچ‌وقت قانون ساختگی وارد پاسخ نشود.
library;

import 'dart:async';

import 'package:dastyar/core/llm.dart';

class ProseGuard {
  ProseGuard._();

  /// واژه‌هایی که یعنی مدل وارد محتوای حقوقی شده است (فقط موتور قطعی مجاز است).
  static const List<String> _legalTerms = [
    'ماده',
    'مادهٔ',
    'قانون',
    'تبصره',
    'بند ',
    'اصل ',
    'مهلت',
    'حکم',
    'رأی',
    'رای ',
    'مجازات',
    'زندان',
    'حبس',
    'جریمه',
    'دیه',
    'تومان',
    'ریال',
    'میلیون',
    'میلیارد',
    'درصد',
    'دادگاه',
    'دادسرا',
    'شورای حل',
    'اداره کار',
    'ادارهٔ کار',
    'تضمین',
    'قطعاً',
    'قطعا',
    'حتماً برنده',
    'حتما برنده',
    'برنده می',
    'می‌برید',
    'میبرید',
    'هوش مصنوعی',
    'مدل زبانی',
    'به عنوان یک',
    'به‌عنوان یک',
  ];

  static final RegExp _digits = RegExp(r'[0-9۰-۹٠-٩]');
  static final RegExp _latin = RegExp(r'[A-Za-z]');
  static final RegExp _persianLetter = RegExp(r'[\u0600-\u06FF]');
  static final RegExp _sentenceEnd = RegExp(r'[.!؟?]');

  /// متن تمیزشده اگر امن باشد، وگرنه `null`.
  static String? accept(String raw) {
    var t = raw.trim();
    // حذف علامت‌های قالب‌بندی و نقل‌قول دورتادور.
    t = t.replaceAll(RegExp(r'[*#_`>]'), '').trim();
    t = t.replaceAll(RegExp(r'^[«"\x27]+|[»"\x27]+$'), '').trim();
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    // ي/ك عربی به فارسی.
    t = t.replaceAll('ي', 'ی').replaceAll('ك', 'ک');
    if (t.length < 20 || t.length > 320) return null;
    if (_digits.hasMatch(t) || _latin.hasMatch(t)) return null;
    final letters = t.replaceAll(RegExp(r'[\s\p{P}]', unicode: true), '');
    if (letters.isEmpty) return null;
    final fa = _persianLetter.allMatches(letters).length;
    if (fa / letters.length < 0.9) return null;
    // واژه باید در آغاز یک کلمه بیاید («برای» نباید با «رای» اشتباه شود).
    for (final w in _legalTerms) {
      if (RegExp('(?:^|[^\u0600-\u06FF])${RegExp.escape(w)}').hasMatch(t)) {
        return null;
      }
    }
    if (_sentenceEnd.allMatches(t).length > 3) return null;
    // جملهٔ ناتمام (قطع‌شده در سقف توکن) پذیرفته نمی‌شود.
    if (!RegExp(r'[.!؟?]$').hasMatch(t)) return null;
    return t;
  }
}

class LlmWriter {
  final LlmBackend llm;
  final Duration timeout;

  LlmWriter(this.llm, {this.timeout = const Duration(seconds: 25)});

  static String openerPrompt(String userText, String topicTitle) {
    final u = userText.length > 500 ? userText.substring(0, 500) : userText;
    return 'تو یک وکیل باتجربه، آرام و همدل ایرانی هستی و با موکلت فارسی صحبت می‌کنی.\n'
        'موکل نوشته است: «$u»\n'
        'موضوع: $topicTitle\n\n'
        'فقط دو جملهٔ کوتاه و طبیعی فارسی بنویس:\n'
        'جملهٔ اول: با کلمات خودت نشان بده دقیقاً فهمیده‌ای چه اتفاقی برایش افتاده (به جزئیات خودش اشاره کن).\n'
        'جملهٔ دوم: با لحن گرم و صادقانه به او آرامش بده که با هم قدم‌به‌قدم پیش می‌روید.\n'
        'قوانین مهم: هیچ عدد، نام قانون، شمارهٔ ماده، مهلت، مبلغ، نام دادگاه یا توصیهٔ حقوقی ننویس. قول نتیجه نده. '
        'سلام و مقدمه ننویس. فقط همان دو جمله.';
  }

  /// جملهٔ آغازین شخصی‌شده یا `null` (مدل آماده نیست، دیر شد یا متن امن نبود).
  Future<String?> personalOpener(String userText, String topicTitle) async {
    try {
      if (!await llm.isReady()) return null;
      final buf = StringBuffer();
      // سقف زمانی کل تولید (نه فاصلهٔ بین توکن‌ها).
      final watch = Stopwatch()..start();
      var timedOut = false;
      final timer = Timer(timeout, () {
        timedOut = true;
        llm.cancel();
      });
      try {
        await for (final t in llm.generate(
          openerPrompt(userText, topicTitle),
          options: const LlmOptions(maxTokens: 120, temperature: 0.3),
        )) {
          if (timedOut || watch.elapsed > timeout) {
            timedOut = true;
            llm.cancel();
            break;
          }
          buf.write(t);
          if (buf.length > 600) {
            llm.cancel();
            break;
          }
        }
      } finally {
        timer.cancel();
      }
      if (timedOut) return null;
      return ProseGuard.accept(buf.toString());
    } catch (_) {
      return null;
    }
  }
}
