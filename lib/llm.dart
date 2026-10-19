/// رابط استاندارد مدل زبانی.
/// برای وصل کردن مدل واقعی، یک کلاس جدید بنویسید که این رابط را پیاده کند
/// و در main.dart به جای NoLlm به Assistant بدهید.
abstract class LlmBackend {
  String get name;

  /// آیا مدل بارگذاری شده و آمادهٔ پاسخ است؟
  Future<bool> isReady();

  /// پاسخ را تکه‌تکه (به‌صورت جریان) برمی‌گرداند.
  Stream<String> generate(String prompt);
}

/// جایگزین فعلی: مدلی وصل نیست.
class NoLlm implements LlmBackend {
  @override
  String get name => 'none';

  @override
  Future<bool> isReady() async => false;

  @override
  Stream<String> generate(String prompt) => const Stream<String>.empty();
}
