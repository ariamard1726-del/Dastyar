import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';
import 'package:dastyar/domain/templates.dart';

/// تشخیص‌های مشترک دربارهٔ پیام کاربر که وکیل ([Advocate]) و پیشنهادهای
/// هنگام نوشتن از آن استفاده می‌کنند: پیام به کدام راهنمای حقوقی می‌خورد
/// و آیا کاربر ناراحتی یا ترس ابراز کرده است. کاملاً قطعی و بدون مدل.
///
/// متن پاسخ اینجا ساخته نمی‌شود؛ تنها نویسندهٔ پاسخ خودِ وکیل است.
class LawyerVoice {
  LawyerVoice._();

  static final RegExp _directArtRe = RegExp(r'(?:ماده|اصل)\s*(?:واحده|\d+)');

  static String _phrase(String s) => ' ${PersianText.phrase(s)} ';

  static final Map<String, List<List<String>>> _normTriggers = {
    for (final g in legalGuides)
      g.id: [
        for (final group in g.triggers)
          [for (final t in group) PersianText.phrase(t)],
      ],
  };

  static final Map<String, List<String>> _normExcludes = {
    for (final g in legalGuides)
      g.id: [for (final t in g.excludes) PersianText.phrase(t)],
  };

  /// آیا پیام ارجاع مستقیم به یک ماده است («ماده ۱۰ قانون مدنی»)؟
  static bool isDirectArticleRef(String rawText) =>
      _directArtRe.hasMatch(PersianText.normalize(rawText));

  /// مناسب‌ترین راهنما برای پیام کاربر، یا `null`.
  static LegalGuide? matchGuide(String rawText) {
    final all = matchGuides(rawText);
    return all.isEmpty ? null : all.first;
  }

  /// پیشوند دکمه‌ای که کاربر را به یک موضوع دیگرِ همان ماجرا می‌برد.
  static const String topicChipPrefix = 'دربارهٔ ';

  /// همهٔ راهنماهای منطبق، به ترتیب امتیاز (بهترین اول). عنوان دقیق یک
  /// راهنما (یا «دربارهٔ <عنوان>») مستقیماً همان راهنما را برمی‌گرداند.
  static List<LegalGuide> matchGuides(String rawText) {
    if (rawText.trim().isEmpty || isDirectArticleRef(rawText)) return const [];
    final p = _phrase(rawText);
    final bare = PersianText.phrase(rawText);
    for (final g in legalGuides) {
      final t = PersianText.phrase(g.title);
      if (bare == t || bare == PersianText.phrase('$topicChipPrefix${g.title}')) {
        return [g];
      }
    }
    final scored = <(LegalGuide, int)>[];
    for (final g in legalGuides) {
      if (_normExcludes[g.id]!.any((e) => e.isNotEmpty && p.contains(e))) {
        continue;
      }
      var score = 0;
      for (final group in _normTriggers[g.id]!) {
        if (group.every((t) => t.isNotEmpty && p.contains(t))) {
          final s = group.fold<int>(0, (a, t) => a + t.length) * 10;
          if (s > score) score = s;
        }
      }
      if (score == 0) continue;
      score += g.priority;
      scored.add((g, score));
    }
    // مرتب‌سازی پایدار: در تساوی، ترتیب تعریف حفظ می‌شود (قطعی).
    final idx = {for (var i = 0; i < legalGuides.length; i++) legalGuides[i].id: i};
    scored.sort((a, b) {
      final c = b.$2.compareTo(a.$2);
      return c != 0 ? c : idx[a.$1.id]!.compareTo(idx[b.$1.id]!);
    });
    return [for (final x in scored) x.$1];
  }

  static final List<String> _distressCues = [
    'ناراحت',
    'نگران',
    'استرس',
    'میترسم',
    'می ترسم',
    'ترسیدم',
    'بدبخت',
    'کلافه',
    'خسته شدم',
    'گریه',
    'داغون',
    'افسرده',
    'بیچاره',
    'تو رو خدا',
    'تورو خدا',
    'کمکم کن',
    'کمکم کنید',
    'نمیدونم چکار',
    'نمی دونم چکار',
    'نمیدونم چیکار',
    'نمی دانم چه کنم',
    'ظلم',
    'عصبانی',
    'اعصابم',
    'حالم بد',
    'دلم شکست',
    'آبروم',
    'آبرویم',
    'زندگیم',
    'زندگیم نابود',
    'خیلی بد',
    'وحشت',
    'ترس',
  ].map(PersianText.phrase).toList();

  /// آیا کاربر احساس ناراحتی، ترس یا فشار روانی ابراز کرده است؟
  static bool expressesDistress(String rawText) {
    final p = _phrase(rawText);
    return _distressCues.any((c) => p.contains(' $c') || p.contains(c));
  }

  /// قالب‌های پیش‌نویس مرتبط با راهنما (عنوان دقیق قالب، تا لمس دکمه
  /// مستقیماً تنظیم سند را شروع کند).
  static List<String> templateChips(
    LegalGuide g,
    List<LegalTemplate> templates,
  ) {
    final out = <String>[];
    for (final id in g.templateIds) {
      for (final t in templates) {
        if (t.id == id) {
          out.add(t.title);
          break;
        }
      }
    }
    return out;
  }
}
