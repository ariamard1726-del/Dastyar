import 'package:dastyar/core/persian_text.dart';
import 'package:dastyar/domain/dialogue/domain_slot_schemas.dart';
import 'package:dastyar/domain/dialogue/slot.dart';

/// استخراج اسلات‌ها از متن خام کاربر بر اساس `DomainSchema`.
///
/// این کلاس مسئولیت استخراج را از درخت تصمیم جدا می‌کند. برخلاف
/// `_QuestionStep` قبلی که فقط یک اسلات را در هر گام می‌پر کرد،
/// `SlotExtractor` همهٔ اسلات‌های قابل استخراج را **یک‌جا** استخراج
/// می‌کند — یعنی اگر کاربر در همان جملهٔ اول چند فاکت را بگوید
/// («چک برگشتی دارم و گواهی عدم پرداخت هم گرفتم»)، هر دو استخراج
/// می‌شوند.
class SlotExtractor {
  const SlotExtractor();

  /// استخراج همهٔ اسلات‌های قابل‌تشخیص از `rawText` بر اساس `schema`.
  ///
  /// [turnIndex] برای مقداردهی `SlotValue.sourceTurn` استفاده می‌شود.
  ///
  /// اگر یک اسلات با چند کلیدواژه تطبیق یابد، اولین مقدار در ترتیب
  /// iteration `valueKeywords` برنده است (که با ترتیب تعریف در
  /// `DomainSchema` سازگار است).
  Map<String, SlotValue> extract(
    String rawText,
    DomainSchema schema, {
    int turnIndex = 0,
  }) {
    final normalized = PersianText.collapse(PersianText.normalize(rawText));
    if (normalized.isEmpty) return const {};

    final result = <String, SlotValue>{};
    for (final slot in schema.slots) {
      final value = _extractSlot(normalized, slot, turnIndex);
      if (value != null && value.isFilled) {
        result[slot.name] = value;
      }
    }
    return result;
  }

  SlotValue? _extractSlot(String normalized, SlotSpec slot, int turnIndex) {
    switch (slot.type) {
      case SlotType.category:
      case SlotType.document:
      case SlotType.timeRange:
      case SlotType.boolean:
        return _extractFromKeywords(normalized, slot, turnIndex);
      case SlotType.amount:
        return _extractAmount(normalized, turnIndex);
      case SlotType.date:
        return _extractDate(normalized, turnIndex);
    }
  }

  SlotValue? _extractFromKeywords(
    String normalized,
    SlotSpec slot,
    int turnIndex,
  ) {
    final keywords = slot.valueKeywords;
    if (keywords == null || keywords.isEmpty) return null;
    for (final entry in keywords.entries) {
      for (final kw in entry.value) {
        final normalizedKw = PersianText.collapse(PersianText.normalize(kw));
        if (normalizedKw.isNotEmpty && normalized.contains(normalizedKw)) {
          return SlotValue.inferred(
            value: entry.key,
            confidence: 0.8,
            sourceTurn: turnIndex,
          );
        }
      }
    }
    return null;
  }

  /// استخراج مبلغ. الگوهای فعلی: «۵۰,۰۰۰ تومان» / «۵۰۰۰۰۰ ریال» /
  /// «۵۰ تومن». الگوی «۵۰ میلیون تومان» برای Phase 1 پشتیبانی نمی‌شود
  /// (به Phase 2 موکول شد).
  static final RegExp _amountRe = RegExp(
    r'([۰-۹0-9]+(?:[,،٬][۰-۹0-9]+)*)\s*(?:تومان|تومن|ریال)',
  );

  SlotValue? _extractAmount(String normalized, int turnIndex) {
    final m = _amountRe.firstMatch(normalized);
    if (m == null) return null;
    final raw = m.group(1);
    if (raw == null || raw.isEmpty) return null;
    return SlotValue.inferred(
      value: raw,
      confidence: 0.85,
      sourceTurn: turnIndex,
    );
  }

  /// استخراج تاریخ شمسی به شکل YYYY/MM/DD یا YYYY-MM-DD.
  static final RegExp _dateRe = RegExp(
    r'[۰-۹0-9]{4}[\/\-][۰-۹0-9]{1,2}[\/\-][۰-۹0-9]{1,2}',
  );

  SlotValue? _extractDate(String normalized, int turnIndex) {
    final m = _dateRe.firstMatch(normalized);
    if (m == null) return null;
    final text = m.group(0);
    if (text == null || text.isEmpty) return null;
    return SlotValue.inferred(
      value: text,
      confidence: 0.9,
      sourceTurn: turnIndex,
    );
  }
}
