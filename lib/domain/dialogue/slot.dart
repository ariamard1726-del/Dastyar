/// مقدار یک slot در گفتگوی حقوقی.
///
/// `value` همیشه به شکل canonical (یکسان‌شده) ذخیره می‌شود؛ مثلاً اعداد
/// فارسی به ASCII تبدیل شده، واحد پول یکسان شده، و ZWNJ به فاصله تبدیل
/// شده. این کار باعث می‌شود دو ورودی ظاهراً متفاوت ("ماده ۱۰" و "ماده 10"
/// و "ماده‌۱۰") به یک مقدار یکسان نگاشت شوند.
///
/// `confidence` میزان اطمینان استخراج را نشان می‌دهد (۰ تا ۱).
/// مقادیر زیر ۰.۵ به عنوان «حدس» در نظر گرفته می‌شوند و planner نباید
/// بر اساس آن‌ها بدون تأیید کاربر تصمیم بگیرد.
///
/// `sourceTurn` شماره‌ی نوبتی است که این slot برای نخستین بار پر شده.
/// برای ادغام چند نوبت و حل تعارض احتمالی استفاده می‌شود.
///
/// `explicitlyConfirmed` نشان می‌دهد کاربر خودش این مقدار را اعلام کرده
/// یا از متن استنباط شده. اگر false باشد، planner ممکن است در آینده از
/// کاربر تأیید بخواهد.
class SlotValue {
  /// مقدار یکسان‌شده. برای slotهایی که مقدارشان هنوز نامعلوم است null است.
  final String? value;

  /// عدد بین ۰ و ۱؛ هرچه بیشتر، اطمینان بالاتر.
  final double confidence;

  /// شماره نوبت (turnIndex) که این مقدار در آن استخراج شد.
  final int sourceTurn;

  /// آیا کاربر صریحاً این مقدار را گفته یا از متن استنباط شده؟
  final bool explicitlyConfirmed;

  const SlotValue({
    required this.value,
    required this.confidence,
    required this.sourceTurn,
    this.explicitlyConfirmed = false,
  });

  /// مقدار با اطمینان بالا (کاربر صریحاً اعلام کرده).
  factory SlotValue.confirmed({
    required String value,
    required int sourceTurn,
  }) =>
      SlotValue(
        value: value,
        confidence: 1.0,
        sourceTurn: sourceTurn,
        explicitlyConfirmed: true,
      );

  /// مقدار استنباط‌شده از متن (بدون تأیید صریح).
  factory SlotValue.inferred({
    required String value,
    required double confidence,
    required int sourceTurn,
  }) =>
      SlotValue(
        value: value,
        confidence: confidence,
        sourceTurn: sourceTurn,
        explicitlyConfirmed: false,
      );

  /// مقدار نامعلوم.
  factory SlotValue.unknown({required int sourceTurn}) => SlotValue(
        value: null,
        confidence: 0.0,
        sourceTurn: sourceTurn,
        explicitlyConfirmed: false,
      );

  /// آیا این slot واقعاً پر شده؟
  bool get isFilled => value != null && value!.isNotEmpty;

  /// آیا با اطمینان کافی برای تصمیم‌گیری پر شده؟
  bool get isReliable => isFilled && confidence >= 0.5;

  SlotValue copyWith({
    String? value,
    double? confidence,
    int? sourceTurn,
    bool? explicitlyConfirmed,
  }) =>
      SlotValue(
        value: value ?? this.value,
        confidence: confidence ?? this.confidence,
        sourceTurn: sourceTurn ?? this.sourceTurn,
        explicitlyConfirmed: explicitlyConfirmed ?? this.explicitlyConfirmed,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'value': value,
        'confidence': confidence,
        'sourceTurn': sourceTurn,
        'explicitlyConfirmed': explicitlyConfirmed,
      };

  static SlotValue fromJson(Map<String, dynamic> j) => SlotValue(
        value: j['value'] as String?,
        confidence: (j['confidence'] as num?)?.toDouble() ?? 0.0,
        sourceTurn: (j['sourceTurn'] as int?) ?? 0,
        explicitlyConfirmed: j['explicitlyConfirmed'] == true,
      );

  @override
  String toString() =>
      'SlotValue(value: $value, conf: ${confidence.toStringAsFixed(2)}, '
      'turn: $sourceTurn, confirmed: $explicitlyConfirmed)';

  @override
  bool operator ==(Object other) =>
      other is SlotValue &&
      other.value == value &&
      other.confidence == confidence &&
      other.sourceTurn == sourceTurn &&
      other.explicitlyConfirmed == explicitlyConfirmed;

  @override
  int get hashCode =>
      Object.hash(value, confidence, sourceTurn, explicitlyConfirmed);
}
