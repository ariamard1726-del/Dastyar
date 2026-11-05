import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/persian_text.dart';

/// حافظهٔ کوتاه‌مدت گفتگو برای درک پرسش‌های پیگیری
/// («ماده بعدی‌اش؟»، «مهلتش چقدره؟»).
///
/// این کلاس در Phase 0.2 از `legal_counselor.dart` به اینجا منتقل شد
/// تا چرخهٔ وابستگی کاهش یابد و بتواند در `dialogue_state.dart`
/// (Phase 0.3) نیز به کار گرفته شود. رفتار کلاس نسبت به نسخهٔ قبلی
/// بدون تغییر است.
class ConversationMemory {
  String lastTopicQuery = '';
  String lastLawId = '';
  String lastLawTitle = '';
  int? lastArticleNum;
  String lastArticleKind = 'ماده';

  void clear() {
    lastTopicQuery = '';
    lastLawId = '';
    lastLawTitle = '';
    lastArticleNum = null;
    lastArticleKind = 'ماده';
  }

  static final RegExp _artNumRe = RegExp(r'^(ماده|اصل)\s+(\d+)$');

  void recordTurn(String userQuery, EngineReply reply) {
    final cleanQ = PersianText.collapse(PersianText.normalize(userQuery));
    if (cleanQ.length >= 4) {
      lastTopicQuery = userQuery.trim();
    }
    if (reply.contextHits.isNotEmpty) {
      final top = reply.contextHits.first.chunk;
      if (top.lawId.isNotEmpty && top.lawId != 'knowledge') {
        lastLawId = top.lawId;
        lastLawTitle = top.source;
        final m = _artNumRe.firstMatch(top.normTitle);
        if (m != null) {
          lastArticleKind = m.group(1)!;
          lastArticleNum = int.tryParse(m.group(2)!);
        }
      }
    }
  }

  static final List<String> _nextMarkers = [
    'ماده بعدی',
    'ماده بعد',
    'اصل بعدی',
    'اصل بعد',
    'بعدی اش',
    'بعدیش',
  ];
  static final List<String> _prevMarkers = [
    'ماده قبلی',
    'ماده قبل',
    'اصل قبلی',
    'اصل قبل',
    'قبلی اش',
    'قبلیش',
  ];
  static final List<String> _ellipticalMarkers = [
    'مهلتش',
    'مجازاتش',
    'شرایطش',
    'مدارکش',
    'حکمش',
    'کجا باید برم',
    'کجا شکایت کنم',
    'کجا مراجعه کنم',
    'چطور اقدام کنم',
    'چگونه اقدام کنم',
    'قابل گذشت است',
    'قابل گذشت هست',
    'اگر ندهد',
    'اگر نپردازد',
    'اگر قبول نکرد',
  ];

  /// بازنویسی هوشمند پرسش‌های کوتاهِ وابسته به پیام قبلی
  /// (بدون تغییر پرسش‌های مستقل).
  String resolveFollowUp(String rawQuestion) {
    final n = PersianText.collapse(PersianText.normalize(rawQuestion));
    if (lastArticleNum != null && lastLawTitle.isNotEmpty) {
      if (_nextMarkers.any(n.contains)) {
        final nextN = lastArticleNum! + 1;
        return '$lastArticleKind $nextN $lastLawTitle';
      }
      if (_prevMarkers.any(n.contains) && lastArticleNum! > 1) {
        final prevN = lastArticleNum! - 1;
        return '$lastArticleKind $prevN $lastLawTitle';
      }
    }

    if (lastTopicQuery.isEmpty) return rawQuestion;
    final words = PersianText.tokenizeIndex(rawQuestion);
    if (words.length <= 5 && _ellipticalMarkers.any(n.contains)) {
      return '$rawQuestion درباره $lastTopicQuery';
    }
    return rawQuestion;
  }
}
