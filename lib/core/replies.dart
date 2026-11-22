import 'dart:math';

/// پاسخ‌های برنامه با پشتیبانی از قالب‌های متنوع (بدون هیچ مدل زبانی).
///
/// متن‌ها در assets/replies.json ویرایش می‌شوند؛ مقدار هر کلید می‌تواند یک
/// رشته (حالت قطعی) یا فهرستی از رشته‌ها (حالت متنوع) باشد:
///   - [get] همیشه نخستین عنصر (نسخهٔ مرجع) را برمی‌گرداند تا رفتارهای
///     قطعی و تست‌های قدیمی تغییر نکنند؛
///   - [pick] هر بار یکی از عنصرها را تصادفی انتخاب می‌کند تا لحن پاسخ‌ها
///     طبیعی و غیررباتیک باشد.
/// مقدارهای زیر پیش‌فرض‌اند تا اگر فایل خراب بود برنامه ساکت نماند.
class Replies {
  static const Map<String, String> defaults = {
    'capabilities':
        'من دستیار حقوقی آفلاین هستم. می‌توانم در متن قوانین موجود در برنامه جست‌وجو کنم، مواد مرتبط را نمایش دهم و در موارد پشتیبانی‌شده برای تنظیم پیش‌نویس اسناد کمک کنم. اگر قانون یا اطلاعات لازم در داده‌های برنامه نباشد، ممکن است نتوانم پاسخ بدهم. من وکیل نیستم و نمی‌توانم نتیجه پرونده را قطعی پیش‌بینی کنم.',
    'outcome_prediction':
        'نمی‌توانم حکم قاضی یا نتیجه یک پرونده را به‌طور قطعی پیش‌بینی کنم. نتیجه به جزئیات پرونده، ادله، قوانین قابل اعمال و تشخیص مرجع قضایی بستگی دارد. اگر موضوع و اطلاعات غیرحساس پرونده را توضیح دهید، می‌توانم در حد قوانین موجود در برنامه به شناسایی مسائل حقوقی مرتبط کمک کنم.',
    'greeting':
        'سلام! چه کمکی از من برمی‌آید؟',
    'ask_more':
        'لطفاً پرسش خود را کامل‌تر بنویسید.',
    'no_knowledge':
        'هنوز دانشی در برنامه نیست.',
    'no_laws':
        'هنوز متن هیچ قانونی در برنامه نیست.',
    'not_found':
        'پاسخ این پرسش را در دانش خودم پیدا نکردم. پرسش را با کلمات دیگر بنویسید.',
    'missing_law':
        'توجه: متن «{law}» هنوز در برنامه نیست.',
  };

  Map<String, List<String>> _over = {};

  /// جای‌گذاری از JSON: رشته → تک‌عنصری، فهرست → قالب‌های متنوع.
  void setOverridesRaw(Map<String, dynamic> m) {
    final out = <String, List<String>>{};
    m.forEach((k, v) {
      if (v is List) {
        final items =
            v.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        if (items.isNotEmpty) out[k] = items;
      } else {
        final s = v.toString();
        if (s.isNotEmpty) out[k] = [s];
      }
    });
    _over = out;
  }

  bool has(String key) => _over.containsKey(key) || defaults.containsKey(key);

  /// همهٔ قالب‌های یک کلید (دست‌کم یکی).
  List<String> variants(String key) =>
      _over[key] ?? [defaults[key] ?? ''];

  String _fill(String t, Map<String, String> vars) {
    vars.forEach((k, v) => t = t.replaceAll('{$k}', v));
    return t;
  }

  /// نسخهٔ مرجع (نخستین قالب) — قطعی و بدون تصادف.
  /// جای‌نگهدار {name} با مقدار vars جایگزین می‌شود.
  String get(String key, [Map<String, String> vars = const {}]) =>
      _fill(variants(key).first, vars);

  /// انتخاب تصادفی یکی از قالب‌های کلید تا لحن پاسخ‌ها تکراری نباشد؛
  /// با [rnd] در تست‌ها قابل قطعی‌سازی است.
  String pick(
    String key, {
    Map<String, String> vars = const {},
    Random? rnd,
  }) {
    final vs = variants(key);
    if (vs.length == 1) return _fill(vs.first, vars);
    final r = rnd ?? Random();
    return _fill(vs[r.nextInt(vs.length)], vars);
  }
}
