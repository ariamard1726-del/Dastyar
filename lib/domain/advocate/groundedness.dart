import 'package:dastyar/core/persian_text.dart';

/// خودبررسی پاسخ (Groundedness Check) — بدون هیچ مدل آماری یا زبانی.
///
/// پیش از نمایش پاسخِ استنادی، هر «ماده/اصل» و هر «نام قانون» که داخل پاسخ
/// آمده باید در همان چیزی که موتور واقعاً بازیابی کرده پیدا شود. اگر نشد،
/// پاسخ نباید نمایش داده شود و باید با سؤال پیگیری جایگزین گردد. این کلاس
/// فقط شناسایی را انجام می‌دهد؛ تصمیم «نمایش / جایگزینی» با فراخواننده است.
///
/// سه قانون سادهٔ پایدار:
///   ۱. هر شمارهٔ ماده‌ای که در پاسخ آمده باید در [allowedArticles] باشد؛
///      ماده‌ای که بازیابی نشده، نباید به‌ظاهرِ «استناد» در پاسخ بنشیند.
///   ۲. هر عبارت «قانون …» در پاسخ باید با یکی از [allowedLawTitles] بخواند
///      (واژه‌های اصلی عبارت، همگی داخل عنوان منبع)؛ وگرنه قانونِ بی‌استناد
///      نمایش داده می‌شود.
///   ۳. نقضی نمایان می‌شود نه خاموش؛ فراخواننده می‌تواند پاسخ را کنار
///      بگذارد و [GroundednessIssue]ها را لاگ کند.
class Groundedness {
  Groundedness._();

  // واژهٔ «ماده/مواد/اصل/اصول» سپس فاصلهٔ آزاد (که واژهٔ فارسی نیست یا
  // حرکت/کشیده/نیم‌فاصله است)، بعد شماره؛ تا «اصلاحی ۱۴۰۴» («اصل» داخل
  // «اصلاحی») و «ماده‌ای» ماده شمرده نشوند. حروف در فاصلهٔ آزاد مجاز نیستند.
  static final RegExp _art = RegExp(
    r'(?<![\u0600-\u06FF\uFB50-\uFDFF\uFE70-\uFEFF])'
    r'(?:ماده|مواد|اصل|اصول)'
    r'(?:[^0-9A-Za-z\u0600-\u06FF\uFB50-\uFDFF\uFE70-\uFEFF]|[\u0640\u064B-\u0652\u0670\u200C]){0,8}'
    r'([0-9]{1,5})',
  );
  // نام قانون تا هر مرزِ جمله/خط/خط تیره؛ پیشوند «قانون» خودش نشانه است.
  static final RegExp _lawPhrase = RegExp(
    r'قانون\s+([^،,؛;.!؟\n\-–—()]{2,48})',
  );
  static final RegExp _letterWord = RegExp(
    r'[\u0600-\u06FF\uFB50-\uFDFF\uFE70-\uFEFF]+',
  );

  /// ارقام فارسی/عربی را به لاتین تبدیل می‌کند.
  static String latinDigits(String s) {
    final buf = StringBuffer();
    for (final r in s.runes) {
      if (r >= 0x06F0 && r <= 0x06F9) {
        buf.writeCharCode(0x30 + r - 0x06F0);
      } else if (r >= 0x0660 && r <= 0x0669) {
        buf.writeCharCode(0x30 + r - 0x0660);
      } else {
        buf.writeCharCode(r);
      }
    }
    return buf.toString();
  }

  /// فهرست شمارهٔ مواد/اصول‌هایی که داخل پاسخ آمده‌اند (ارقام لاتین).
  static List<String> articleRefs(String response) {
    final t = latinDigits(response);
    return [for (final m in _art.allMatches(t)) m.group(1)!];
  }

  /// عبارت‌های «قانون …» داخل پاسخ (با نویسه‌های نرمال‌شده).
  static List<String> lawNameRefs(String response) {
    final t = _norm(response);
    return [
      for (final m in _lawPhrase.allMatches(t)) m.group(1)!.trim(),
    ];
  }

  /// پاسخ را در برابر [allowedArticles] (شمارهٔ مواد از عنوان‌ها و متن‌های
  /// چانک‌های بازیابی‌شده) و [allowedLawTitles] (عناوین منبع چانک‌ها)
  /// می‌سنجد؛ [allowedLawBodies] متن‌های کامل همان چانک‌هاست — نیازی
  /// نیست و واژه‌های یکسان در جملهٔ «مطابق قانون کار…» هم قابل‌اثبات
  /// می‌شوند (همهٔ واژه‌ها باید در همان یک متن دیده شوند).
  ///
  /// خروجی: فهرست نقض‌ها؛ خالی یعنی پاسخ قابل‌نمایش است.
  static List<GroundednessIssue> check(
    String response, {
    required Set<String> allowedArticles,
    required List<String> allowedLawTitles,
    List<String> allowedLawBodies = const [],
  }) {
    final issues = <GroundednessIssue>[];
    for (final n in articleRefs(response)) {
      if (!allowedArticles.contains(n)) {
        issues.add(GroundednessIssue('article',
            'مادهٔ $n در پاسخ آمده ولی در ماده‌های بازیابی‌شده نیست'));
      }
    }
    final haystacks = <String>[
      ...allowedLawTitles.map(_norm),
      for (final b in allowedLawBodies) _norm(b),
    ];
    for (final ref in lawNameRefs(response)) {
      // فقط واژه‌های فارسی معنی‌دار شمرده می‌شوند؛ علائم و ارقام کنار می‌روند.
      final words = [
        for (final m in _letterWord.allMatches(ref))
          if (m.group(0)!.length >= 2) m.group(0)!,
      ];
      // نامِ «قانون …» بدون دست‌کم یک واژهٔ چهارحرفی، بیش‌ازحد عمومی است.
      if (!words.any((w) => w.length >= 4)) continue;
      final ok = haystacks.any((h) => words.every(h.contains));
      if (!ok) {
        issues.add(GroundednessIssue(
            'law', 'نام قانونِ «قانون $ref» در متن‌های بازیابی‌شده نیست'));
      }
    }
    return issues;
  }

  /// پاسخ قابل نمایش هست؟ (خالی = بله)
  static bool isGrounded(
    String response, {
    required Set<String> allowedArticles,
    required List<String> allowedLawTitles,
  }) =>
      check(
        response,
        allowedArticles: allowedArticles,
        allowedLawTitles: allowedLawTitles,
      ).isEmpty;

  static String _norm(String s) => PersianText.normalize(s)
      .split('\n')
      .map((l) => l.replaceAll(RegExp(r'\s+'), ' ').trim())
      .where((l) => l.isNotEmpty)
      .join('\n');
}

/// یک نقض خودبررسی: [kind] برابر `article` یا `law` است.
class GroundednessIssue {
  const GroundednessIssue(this.kind, this.detail);

  final String kind;
  final String detail;

  @override
  String toString() => '$kind: $detail';

  @override
  bool operator ==(Object other) =>
      other is GroundednessIssue &&
      other.kind == kind &&
      other.detail == detail;

  @override
  int get hashCode => Object.hash(kind, detail);
}
