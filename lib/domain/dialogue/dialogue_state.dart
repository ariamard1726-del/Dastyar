import 'dart:convert';

import 'package:dastyar/domain/dialogue/evidence.dart';
import 'package:dastyar/domain/dialogue/slot.dart';

/// هش پایدار ۳۲-بیتی به روش FNV-1a.
///
/// هدف: تبدیل یک رشته به شناسه‌ی یکتای قابل‌تکیه در طول اجراهای مختلف
/// برنامه و پلتفرم‌های مختلف (Android / iOS / وب). `String.hashCode` در
/// Dart بین اجراها پایدار نیست، پس برای conversationId که باید پس از
/// ری‌استارت برنامه یکسان بماند، استفاده‌ی مستقیم از آن نادرست است.
///
/// چرا FNV-1a و نه SHA-256؟ چون:
///   ۱) بدون وابستگی به پکیج `crypto` (که در pubspec نیست) کار می‌کند.
///   ۲) برای شناسه‌ی کوتاه (۸ کاراکتر hex) کافی است — collision در
///      محدوده‌ی چند هزار مکالمه‌ی یک کاربر عملاً ممکن نیست.
///   ۳) سریع و آفلاین.
String _stableHash(String input) {
  var hash = 0x811c9dc5;
  final bytes = utf8.encode(input);
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// شناسه‌ی پایدار یک مکالمه، مشتق از موضوع و پیام اولیه.
///
/// چرا از (topicId, initialMessage) مشتق می‌شود؟ چون:
///   • مکالمه‌ای که از یک نقطه شروع می‌شود باید همیشه همان شناسه را
///     بگیرد (determinism در انتخاب variantهای پاسخ).
///   • مکالمه‌ی متفاوت با پیام اولیه‌ی متفاوت، شناسه‌ی متفاوت می‌گیرد.
///   • این شناسه در `DialogueState` ذخیره می‌شود تا پس از ری‌استارت
///     برنامه همان باقی بماند.
String deriveConversationId(String topicId, String initialMessage) {
  return _stableHash('$topicId|$initialMessage');
}

/// وضعیت جاری یک گفتگوی حقوقی (frame + slots + شواهد).
///
/// این کلاس قابل serialize است تا در `CounselCheckpointStore` ذخیره شود
/// و پس از بسته شدن برنامه، با همان slotها و همان `turnIndex` بازیابی
/// شود. به همین دلیل، `fromJson` نسبت به فیلدهای جدید tolerant است:
/// اگر نسخه‌ی قدیمی‌تری از برنامه، JSON بدون `matchedSpans` یا
/// `lastUserUtterance` ذخیره کرده باشد، این نسخه بدون خطا آن را
/// بارگذاری می‌کند.
///
/// فیلدهای `conversationId` و `turnIndex` در همان `DialogueState`
/// ذخیره می‌شوند (نه در `CounselingSession`) تا همه‌ی state مربوط به
/// انتخاب variant در یک جا متمرکز باشد.
class DialogueState {
  /// دامنه‌ی حقوقی فعلی، مثل "cheque" یا "labor".
  final String domain;

  /// slotهای پر شده‌ی این مکالمه، keyed by slotKey.
  final Map<String, SlotValue> slots;

  /// شواهد بازیابی‌شده برای آخرین پرسش (خالی اگر هنوز چیزی بازیابی نشده).
  final EvidenceSet evidence;

  /// slot بعدی که planner در حال پرسیدن است (null اگر هیچ سؤالی باز نیست).
  final String? pendingSlot;

  /// مجموعه‌ی slotهایی که تا حالا از کاربر پرسیده شده‌اند (برای اینکه
  /// planner دوباره سؤال نکند).
  final Set<String> askedSlots;

  /// شناسه‌ی پایدار مکالمه (نتیجه‌ی `deriveConversationId`).
  final String conversationId;

  /// شماره‌ی نوبت جاری، از ۰ شروع می‌شود. هر بار که یک turn کامل
  /// پردازش می‌شود (کاربر پیام می‌فرستد + planner تصمیم می‌گیرد) یک
  /// واحد افزایش می‌یابد. از این مقدار برای انتخاب deterministic
  /// variantهای پاسخ استفاده می‌شود.
  final int turnIndex;

  /// آخرین گفته‌ی خام کاربر. برای echo و برای planner مفید است
  /// (planner در Phase 2 می‌تواند از کلمات خودِ کاربر استفاده کند).
  final String lastUserUtterance;

  /// بازتاب متن خام کاربر برای هر slot — مثلاً slot `dueDate` که
  /// کاربر گفته «۲۲ خرداد»، `matchedSpans['dueDate'] = '۲۲ خرداد'`
  /// می‌شود تا composer بتواند همان عبارت را در پاسخ بازتاب دهد.
  final Map<String, String> matchedSpans;

  const DialogueState({
    required this.domain,
    required this.slots,
    required this.evidence,
    required this.pendingSlot,
    required this.askedSlots,
    required this.conversationId,
    required this.turnIndex,
    required this.lastUserUtterance,
    required this.matchedSpans,
  });

  /// ساخت وضعیت تازه در ابتدای یک مکالمه.
  factory DialogueState.fresh({
    required String domain,
    required String topicId,
    required String initialMessage,
  }) {
    return DialogueState(
      domain: domain,
      slots: const {},
      evidence: EvidenceSet.empty(),
      pendingSlot: null,
      askedSlots: const {},
      conversationId: deriveConversationId(topicId, initialMessage),
      turnIndex: 0,
      lastUserUtterance: '',
      matchedSpans: const {},
    );
  }

  /// آیا این وضعیت در ابتدای مکالمه است؟
  bool get isFresh => turnIndex == 0 && slots.isEmpty;

  /// slotهای پر شده‌ی قابل‌اعتماد (برای planner).
  ///
  /// توجه: نقشه‌ی بازگشتی تازه است؛ `slots` اصلی دست‌نخورده می‌ماند.
  Map<String, SlotValue> get reliableSlots => Map.fromEntries(
        slots.entries.where((e) => e.value.isReliable),
      );

  /// آیا slot مشخصی پر شده و قابل اعتماد است؟
  bool hasReliableSlot(String key) => slots[key]?.isReliable ?? false;

  DialogueState copyWith({
    String? domain,
    Map<String, SlotValue>? slots,
    EvidenceSet? evidence,
    String? pendingSlot,
    bool clearPendingSlot = false,
    Set<String>? askedSlots,
    String? conversationId,
    int? turnIndex,
    String? lastUserUtterance,
    Map<String, String>? matchedSpans,
  }) {
    return DialogueState(
      domain: domain ?? this.domain,
      slots: slots ?? this.slots,
      evidence: evidence ?? this.evidence,
      pendingSlot:
          clearPendingSlot ? null : (pendingSlot ?? this.pendingSlot),
      askedSlots: askedSlots ?? this.askedSlots,
      conversationId: conversationId ?? this.conversationId,
      turnIndex: turnIndex ?? this.turnIndex,
      lastUserUtterance: lastUserUtterance ?? this.lastUserUtterance,
      matchedSpans: matchedSpans ?? this.matchedSpans,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'domain': domain,
        'slots': slots.map((k, v) => MapEntry(k, v.toJson())),
        'evidence': evidence.toJson(),
        'pendingSlot': pendingSlot,
        'askedSlots': askedSlots.toList(),
        'conversationId': conversationId,
        'turnIndex': turnIndex,
        'lastUserUtterance': lastUserUtterance,
        'matchedSpans': matchedSpans,
      };

  /// بازسازی از JSON با تحمل نسخه‌های قدیمی.
  ///
  /// فیلدهای جدید (`turnIndex`, `lastUserUtterance`, `matchedSpans`)
  /// اگر در JSON نباشند، به مقدار پیش‌فرض امن نگاشت می‌شوند تا
  /// checkpointهایی که پیش از افزودن این فیلدها ذخیره شده‌اند، بی‌خطا
  /// بارگذاری شوند.
  static DialogueState fromJson(Map<String, dynamic> j) {
    final rawSlots =
        (j['slots'] as Map?)?.cast<String, dynamic>() ?? const {};
    final slots = <String, SlotValue>{};
    rawSlots.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        slots[k] = SlotValue.fromJson(v);
      }
    });

    final rawEvidence = j['evidence'];
    final evidence = rawEvidence is Map<String, dynamic>
        ? EvidenceSet.fromJson(rawEvidence)
        : EvidenceSet.empty();

    final rawAsked = (j['askedSlots'] as List?) ?? const [];
    final asked = rawAsked.map((e) => e.toString()).toSet();

    final rawSpans =
        (j['matchedSpans'] as Map?)?.cast<String, dynamic>() ?? const {};
    final spans = <String, String>{};
    rawSpans.forEach((k, v) {
      spans[k.toString()] = v.toString();
    });

    return DialogueState(
      domain: (j['domain'] as String?) ?? '',
      slots: slots,
      evidence: evidence,
      pendingSlot: j['pendingSlot'] as String?,
      askedSlots: asked,
      conversationId: (j['conversationId'] as String?) ?? '',
      turnIndex: (j['turnIndex'] as int?) ?? 0,
      lastUserUtterance: (j['lastUserUtterance'] as String?) ?? '',
      matchedSpans: spans,
    );
  }

  @override
  String toString() => 'DialogueState(domain: $domain, '
      'turnIndex: $turnIndex, slots: ${slots.length}, '
      'evidence: ${evidence.items.length}, pending: $pendingSlot, '
      'convId: $conversationId)';
} 
