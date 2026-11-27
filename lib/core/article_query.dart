import 'package:dastyar/core/engine_rules.dart';
import 'package:dastyar/core/persian_text.dart';

/// الگوی «ماده/اصل ۱۲» در متنِ کاربر و نامِ استانداردِ همان ماده.
///
/// این سه تابع پیش‌تر داخلِ `KnowledgeEngine` بودند، ولی هیچ‌کدام به بانکِ
/// قوانین کاری ندارند: فقط یک عبارت را می‌خوانند و به «ماده ۱۲» تبدیل
/// می‌کنند. هم موتور لازمش دارد، هم رتبه‌بندی؛ پس یک جای بی‌طرف ایستاده‌اند.
class ArticleQuery {
  const ArticleQuery._();

  static final RegExp re = RegExp(EngineRules.articleQueryPattern);

  /// «ماده ۱۲» یا «اصل ۱۲» با ارقامِ فارسی؛ خالی اگر عبارت ماده نداشته باشد.
  static String canonical(String rawArticle) {
    var a = _collapse(_normalize(rawArticle));
    if (a.isEmpty) return '';
    if (!a.startsWith('ماده ') && !a.startsWith('اصل ')) a = 'ماده $a';
    return _collapse(a);
  }

  static String wanted(RegExpMatch m) {
  final kind = m.group(1) == 'اصل' ? 'اصل' : 'ماده';
  if (m.group(2) != null) return '$kind واحده';
  final num = m.group(3)!;
  final mk = m.group(4) != null
      ? (m.group(5) != null ? ' مکرر ${m.group(5)}' : ' مکرر')
      : '';
  return '$kind $num$mk';
}


  static String label(RegExpMatch m) {
  if (m.group(2) != null) return 'واحده';
  final num = PersianText.toFaDigits(m.group(3)!);
  final mk = m.group(4) != null
      ? (m.group(5) != null
          ? ' مکرر ${PersianText.toFaDigits(m.group(5)!)}'
          : ' مکرر')
      : '';
  return '$num$mk';
}


  static String _normalize(String s) => PersianText.normalize(s);

  static String _collapse(String s) => PersianText.collapse(s);
}
