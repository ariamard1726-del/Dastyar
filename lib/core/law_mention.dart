import 'package:dastyar/core/engine_rules.dart';
import 'package:dastyar/core/models.dart';
import 'package:dastyar/core/persian_text.dart';

/// «این متن از کدام قانون‌ها اسم می‌برد؟» و «کدامشان در بانک داریم؟»
///
/// این پرسش‌ها پیش‌تر داخلِ [KnowledgeEngine] بودند، کنارِ ایندکس و رتبه‌بندی
/// و پاسخ‌سازی؛ یعنی موتور هم بانک می‌ساخت، هم امتیاز می‌داد، هم نامِ قانون
/// را از متن بیرون می‌کشید. سه کارِ جدا بود در یک کلاسِ ۱٬۱۵۰ خطی. کارِ
/// «شناسایی نام قانون» فقط به فهرستِ قوانین و متنِ کاربر نیاز دارد، پس
/// می‌تواند جدا زندگی کند و بی‌نیاز از دارایی‌ها آزمون شود
/// (`test/core/law_mention_test.dart`).
class LawMention {
  LawMention({required this.catalog, required this.isLoaded});

  /// فهرست قوانین؛ همان لیستی که موتور پس از بارگذاری پر می‌کند (مرجع، نه کپی).
  final List<CatalogLaw> catalog;

  /// متنِ کدام قانون در بانک هست.
  final bool Function(String lawId) isLoaded;

  /// قوانینی که نامشان در متن آمده است.
  ///
  /// نام‌های کوتاهِ درونِ نام‌های بلند حذف می‌شوند: «قانون مجازات اسلامی» و
  /// «قانون مجازات اسلامی تعزیرات» نباید دو قانونِ جدا شمرده شوند وقتی کاربر
  /// فقط دومی را نوشته است.
  List<CatalogLaw> mentioned(String q) {
    final n = _collapsed(q);
    final matched = <CatalogLaw>[];

    for (final l in catalog) {
      var hit = false;
      for (final name in [l.title, ...l.aliases]) {
        final full = _collapsed(name);
        if (full.isEmpty) continue;

        final isLawName = EngineRules.lawPrefixes.any(full.startsWith);
        if (!isLawName) continue;

        if (n.contains(full)) {
          hit = true;
          break;
        }

        final short = full.startsWith(EngineRules.shortLawPrefix)
            ? full.substring(EngineRules.shortLawPrefix.length).trim()
            : '';
        if (short.length >= EngineRules.shortLawMinLen &&
            n.contains('${EngineRules.shortLawPrefix}$short')) {
          hit = true;
          break;
        }
      }
      if (hit) matched.add(l);
    }

    if (matched.length < 2) return matched;

    final matchedNames = <String, String>{};
    for (final l in matched) {
      for (final name in [l.title, ...l.aliases]) {
        final full = _collapsed(name);
        if (full.isNotEmpty && n.contains(full)) {
          matchedNames[l.id] = full;
          break;
        }
      }
    }

    return matched.where((law) {
      final ownName = matchedNames[law.id];
      if (ownName == null) return true;

      for (final other in matched) {
        if (other.id == law.id) continue;
        final otherName = matchedNames[other.id];
        if (otherName != null &&
            otherName.length > ownName.length &&
            otherName.contains(ownName)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  /// قوانینی که متنشان در بانک است.
  List<CatalogLaw> loaded() => catalog.where((l) => isLoaded(l.id)).toList();

  /// کاربر فهرستِ قوانین را می‌خواهد؟
  bool asksLawList(String n) {
    return n.contains('چه قوانین') ||
        n.contains('کدام قوانین') ||
        n.contains('فهرست قوانین') ||
        n.contains('قوانین موجود') ||
        n.contains('چه قانون');
  }

  static String _collapsed(String s) =>
      PersianText.collapse(PersianText.normalize(s));
}
