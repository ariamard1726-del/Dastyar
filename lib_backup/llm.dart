/// تنظیمات تولید پاسخ؛ هر پیاده‌سازی هر چقدر را که می‌فهمد به کار می‌گیرد.
class LlmOptions {
  final int maxTokens;
  final double temperature;
  final List<String> stop;

  const LlmOptions({
    this.maxTokens = 400,
    this.temperature = 0.2,
    this.stop = const [],
  });
}

/// رابط استاندارد مدل زبانی.
///
/// برای وصل کردن مدل واقعی یک کلاس بنویسید که از این کلاس ارث ببرد
/// (extends LlmBackend) و در main.dart به جای NoLlm به Assistant بدهید:
///
///   class MyLlm extends LlmBackend {
///     @override String get name => 'my-model';
///     @override Future<void> load() async { /* بارگذاری فایل مدل */ }
///     @override Future<bool> isReady() async => _loaded;
///     @override
///     Stream<String> generate(String prompt,
///         {LlmOptions options = const LlmOptions()}) async* { /* تکه‌تکه yield */ }
///     @override void cancel() { /* توقف تولید */ }
///     @override Future<void> dispose() async { /* آزاد کردن حافظه */ }
///   }
///
/// دستیار هر پاسخ مدل را با متن قانون‌ها می‌سنجد؛ اگر مادهٔ ساختگی بیاورد،
/// پاسخ مطمئن موتور جای آن می‌نشیند.
abstract class LlmBackend {
  String get name;

  /// آیا مدل بارگذاری شده و آمادهٔ پاسخ است؟
  Future<bool> isReady();

  /// بارگذاری مدل (اختیاری؛ پیش‌فرض کاری نمی‌کند).
  Future<void> load() async {}

  /// پاسخ را تکه‌تکه (به‌صورت جریان) برمی‌گرداند.
  Stream<String> generate(
    String prompt, {
    LlmOptions options = const LlmOptions(),
  });

  /// تولید جاری را متوقف می‌کند (اختیاری).
  void cancel() {}

  /// حافظهٔ مدل را آزاد می‌کند (اختیاری).
  Future<void> dispose() async {}
}

/// جایگزین فعلی: مدلی وصل نیست.
class NoLlm extends LlmBackend {
  @override
  String get name => 'none';

  @override
  Future<bool> isReady() async => false;

  @override
  Stream<String> generate(
    String prompt, {
    LlmOptions options = const LlmOptions(),
  }) =>
      const Stream<String>.empty();
}
