import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';

/// نگهبان هزینهٔ استارت‌آپ (معماری، بند ۹).
///
/// ساخت نمایهٔ کل بانک قوانین در Isolate جدا انجام می‌شود (KnowledgeEngine._buildAsync).
/// این تست یک سقف زمانی شل ولی قطعی می‌گذارد تا اگر روزی رشد داده‌ها یا
/// یک رگرسیون الگوریتمی، بارگذاری را کند کرد، CI هشدار بدهد.
/// سقف عمداً سخاوتمندانه است (۱۵ ثانیه روی ماشین CI) تا نوسان ماشین باعث قرمزی نشود؛
/// هدف گرفتن رگرسیون‌های مرتبه‌ای است، نه میلی‌ثانیه‌ها.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('بارگذاری کامل بانک قوانین زیر سقف بودجهٔ زمان می‌ماند', () async {
    final sw = Stopwatch()..start();
    final engine = KnowledgeEngine();
    await engine.load();
    sw.stop();

    expect(engine.size, greaterThan(5000),
        reason: 'کل بخش‌های دانش باید بارگذاری شود');
    expect(sw.elapsedMilliseconds, lessThan(15000),
        reason: 'ساخت نمایه از ${sw.elapsedMilliseconds}ms فراتر رفت؛ '
            'docs/ARCHITECTURE.md (بند هزینهٔ استارت‌آپ) را ببینید');
  });
}
