/// یک تکه شاهد قانونی که توسط موتور جستجو بازیابی شده.
///
/// [articleId] شناسه‌ی قابل‌نمایش ماده است، معمولاً به شکل
/// «ماده ۲ قانون مدنی». برای ارجاع در متن پاسخ و برای اعتبارسنجی
/// استنادها استفاده می‌شود.
///
/// [text] متن کامل یا بریده‌شده‌ی ماده است (بسته به آنچه موتور
/// برگردانده). این همان چیزی است که مدل زبانی یا planner به عنوان
/// زمینه می‌بیند.
///
/// [rank] ترتیب بازیابی است: ۱ بهترین نتیجه، ۲ دومین، و به همین
/// ترتیب. از [score] متمایز است؛ [rank] را موتور تعیین می‌کند،
/// [score] امتیاز خام BM25F است.
///
/// [score] امتیاز BM25F ماده است. مقادیر بالاتر بهتر هستند، ولی
/// مقیاس مطلق به اندازه‌ی بار معنایی مهم نیست؛ نسبت‌ها در تصمیم
/// planner تأثیر دارند.
///
/// [matchedSlots] فهرست slotهایی است که این ماده با آن‌ها تطبیق
/// داده شده. اگر خالی باشد، یعنی ماده صرفاً از روی شباهت متنی
/// بازیابی شده و برای slot خاصی انتخاب نشده.
class Evidence {
  final String articleId;
  final String text;
  final int rank;
  final double score;
  final List<String> matchedSlots;

  const Evidence({
    required this.articleId,
    required this.text,
    required this.rank,
    required this.score,
    this.matchedSlots = const [],
  });

  /// آیا این شاهد برای slot مشخصی تطبیق یافته؟
  bool matchesSlot(String slotKey) => matchedSlots.contains(slotKey);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'articleId': articleId,
        'text': text,
        'rank': rank,
        'score': score,
        'matchedSlots': matchedSlots,
      };

  static Evidence fromJson(Map<String, dynamic> j) => Evidence(
        articleId: (j['articleId'] as String?) ?? '',
        text: (j['text'] as String?) ?? '',
        rank: (j['rank'] as int?) ?? 0,
        score: (j['score'] as num?)?.toDouble() ?? 0.0,
        matchedSlots: ((j['matchedSlots'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(),
      );

  @override
  String toString() =>
      'Evidence(rank: $rank, articleId: $articleId, score: ${score.toStringAsFixed(2)})';
}

/// مجموعه‌ی شواهد بازیابی‌شده برای یک پرسش.
///
/// این کلاس نتیجه‌ی `KnowledgeEngine.retrieveWithEvidence` است و
/// planner در Phase 2 بر اساس آن تصمیم می‌گیرد که پاسخ بدهد یا
/// سؤال تکمیلی بپرسد.
///
/// [hasSufficientSupport] اگر true باشد، planner مجاز است بر اساس
/// [items] پاسخ نهایی بدهد. اگر false باشد، planner باید یا از
/// کاربر سؤال تکمیلی بپرسد یا (در صورت امکان) صریحاً بگوید
/// «در دانش من نیست». منطق:
///
///   hasSufficientSupport =
///       coverage >= 0.4 && items.isNotEmpty && conflicts.isEmpty
///
/// یعنی: پوشش واژگانی حداقل ۴۰٪، حداقل یک شاهد، و هیچ شاهد متناقضی.
///
/// توجه: مواد منسوخ باید **قبل** از ساخت این مجموعه فیلتر شوند؛
/// در غیر این صورت ممکن است coverage و items بالا باشد ولی شواهد
/// بی‌اعتبار باشند.
class EvidenceSet {
  /// امتیاز پوشش واژگانی، بین ۰ و ۱.
  static const double coverageThreshold = 0.4;

  final List<Evidence> items;
  final List<Evidence> conflicts;
  final double coverage;

  const EvidenceSet({
    required this.items,
    required this.conflicts,
    required this.coverage,
  });

  /// مجموعه‌ی خالی (هیچ شاهدی بازیابی نشد).
  factory EvidenceSet.empty() => const EvidenceSet(
        items: [],
        conflicts: [],
        coverage: 0.0,
      );

  /// مجموعه با شواهد کافی.
  factory EvidenceSet.sufficient({
    required List<Evidence> items,
    double coverage = 1.0,
  }) =>
      EvidenceSet(
        items: List.unmodifiable(items),
        conflicts: const [],
        coverage: coverage.clamp(0.0, 1.0),
      );

  /// مجموعه با شواهد ناکافی یا متناقض.
  factory EvidenceSet.insufficient({
    List<Evidence> items = const [],
    List<Evidence> conflicts = const [],
    double coverage = 0.0,
  }) =>
      EvidenceSet(
        items: List.unmodifiable(items),
        conflicts: List.unmodifiable(conflicts),
        coverage: coverage.clamp(0.0, 1.0),
      );

  /// آیا شواهد برای پاسخ‌دهی کافی است؟
  bool get hasSufficientSupport =>
      coverage >= coverageThreshold &&
      items.isNotEmpty &&
      conflicts.isEmpty;

  /// بهترین شاهد (اولین مورد پس از مرتب‌سازی موتور).
  Evidence? get top => items.isEmpty ? null : items.first;

  /// همه‌ی شناسه‌های ماده در این مجموعه (برای ارجاع و گارد استناد).
  Set<String> get articleIds => items.map((e) => e.articleId).toSet();

  /// آیا هیچ شاهدی نداریم؟
  bool get isEmpty => items.isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'items': items.map((e) => e.toJson()).toList(),
        'conflicts': conflicts.map((e) => e.toJson()).toList(),
        'coverage': coverage,
      };

  static EvidenceSet fromJson(Map<String, dynamic> j) => EvidenceSet(
        items: ((j['items'] as List?) ?? const [])
            .map((e) => Evidence.fromJson(e as Map<String, dynamic>))
            .toList(),
        conflicts: ((j['conflicts'] as List?) ?? const [])
            .map((e) => Evidence.fromJson(e as Map<String, dynamic>))
            .toList(),
        coverage: (j['coverage'] as num?)?.toDouble() ?? 0.0,
      );

  @override
  String toString() =>
      'EvidenceSet(items: ${items.length}, conflicts: ${conflicts.length}, '
      'coverage: ${coverage.toStringAsFixed(2)}, '
      'sufficient: $hasSufficientSupport)';
}
