import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';

/// [KnowledgeEngine.warnings] جای خطاهای بارگذاری است؛ هر ردیف در آن یعنی یک
/// فایلِ دارایی خوانده نشد و برنامه با دانشِ ناقص بالا آمده. این آزمون همان
/// خرابیِ خاموش را بلند می‌کند: «برنامه کار می‌کند» ولی یک تکه‌اش نیست.
///
/// فهرستِ `assets/` در `tests/python/test_assets_are_shipped.py` نگهبانِ
/// اعلام‌شدنِ فایل‌ها است؛ این آزمون نگهبانِ خوانده‌شدنشان.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('بارگذاریِ کاملِ دارایی‌ها هیچ هشدارِ بی‌صدایی باقی نمی‌گذارد', () async {
    final engine = KnowledgeEngine();
    await engine.load();

    expect(engine.warnings, isEmpty,
        reason: 'این فایل‌ها خوانده نشدند: ${engine.warnings.join(' | ')}');
    expect(engine.size, greaterThan(5500));
    expect(engine.catalog.length, greaterThanOrEqualTo(24));
    expect(engine.qa.isEmpty, isFalse);
    expect(engine.legalTerms.isEmpty, isFalse);
    expect(engine.topicFlows.isEmpty, isFalse);
  });
}
