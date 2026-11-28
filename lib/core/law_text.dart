import 'package:dastyar/core/models.dart';
import 'package:dastyar/core/legal_disclaimer.dart';
import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/core/replies.dart';

/// نوشتنِ متنِ خوانا از دادهٔ قوانین: متنِ یک ماده با منبع و تاریخش، فهرستِ
/// قوانینِ موجود، و جملهٔ «پیدا نکردم».
///
/// این کار پیش‌تر داخلِ `KnowledgeEngine` بود، کنارِ بارگذاریِ دارایی‌ها و
/// امتیازدهی؛ ولی نوشتنِ متن هیچ تصمیمی نمی‌گیرد: فقط از داده‌ای که گرفته
/// می‌نویسد. حالا صاحبِ خودش را دارد و بی‌نیاز از بانک آزمون می‌شود.
class LawText {
  LawText({
    required this.meta,
    required this.replies,
    required this.catalog,
    required this.lawCountOf,
  });

  /// فرادادهٔ هر قانون (تاریخ، آخرین اصلاح، وضعیتِ تطبیق).
  final Map<String, Map<String, dynamic>> meta;
  final Replies replies;
  final List<CatalogLaw> catalog;

  /// چند ماده از این قانون در بانک هست.
  final int Function(String lawId) lawCountOf;

  String format(Chunk c) {
  final sb = StringBuffer();
  // عنوان در فایل‌های قانون با ارقام لاتین است («ماده 10»)؛ در متن فارسی
  // باید با ارقام فارسی بیاید.
  sb.write(PersianText.toFaDigits(c.title));
  if (c.body != c.title) sb.write('\n${c.body}');
  if (c.obsolete) {
    sb.write('\n\nتوجه: این ماده در متن رسمی منسوخ‌شده علامت خورده است.');
  }
  if (c.source.isNotEmpty) {
    sb.write('\n\nمنبع: ${c.source}');
    if (c.chapter.isNotEmpty) sb.write(' — ${c.chapter}');
    final date = (meta[c.lawId]?['date'] ?? '').toString().trim();
    if (date.isNotEmpty) {
      sb.write('\nتاریخ دریافت متن: ${PersianText.toFaDigits(date)}');
    }
    final amended = (meta[c.lawId]?['amended'] ?? '').toString().trim();
    if (amended.isNotEmpty) {
      sb.write('\nآخرین اصلاح قانون: ${PersianText.toFaDigits(amended)}');
    }
    if ((meta[c.lawId]?['status'] ?? '').toString().trim() != 'verified') {
      sb.write('\nاین متن هنوز با منبع رسمی تطبیق داده نشده است.');
      sb.write('\n' + legalDisclaimer);
    }
  }
  return sb.toString();
}

  String notFound() {
    return replies.get('not_found');
  }

  String lawList() {
  final loaded = _loaded();
  if (loaded.isEmpty) return replies.get('no_laws');
  final sb = StringBuffer('قوانینی که متنشان در برنامه است:');
  for (final l in loaded) {
    final n = lawCountOf(l.id);
    sb.write('\n• ${l.title} (${PersianText.toFaDigits(n.toString())} ماده)');
  }
  final rest = catalog.length - loaded.length;
  if (rest > 0) {
    sb.write(
      '\n\n${PersianText.toFaDigits(rest.toString())} قانون دیگر در فهرست هست ولی متنشان هنوز وارد نشده است.',
    );
  }
  return sb.toString();
}

  List<CatalogLaw> _loaded() =>
      catalog.where((l) => lawCountOf(l.id) > 0).toList();
}
