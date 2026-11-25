import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// نگهبان هزینهٔ «هر نوبت» (جدا از هزینهٔ استارتآپ).
///
/// استارتآپ یک سقف دارد (`load_budget_test.dart`)، ولی محاسبهٔ مربوط به
/// هر پیام هم روی رشتهٔ رابط کاربری است. اگر روزی بازیابی یا تطبیق واژهها
/// مرتبهای رشد کرد، این آزمون پیش از گیرکردن کاربر در CI قرمز میشود.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;
  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  test('پاسخ به پرسش بلند در بودجهٔ زمانی میماند', () {
    const q = 'من یک سال است که در این آپارتمان زندگی میکنم و صاحبخانه بدون '
        'هیچ دلیلی ودیعهای را که به او دادهام پس نمیدهد و حالا میخواهد مرا '
        'هم زودتر بیرون کند. آیا میتوانم او را مجبور به پس دادن ودیعه و '
        'پرداخت خسارت کنم و از کدام ماده قانون میشود کمک گرفت؟';

    final sw = Stopwatch()..start();
    final reply = Advocate(engine).respond(q);
    sw.stop();

    expect(reply.text, isNotEmpty);
    expect(
      sw.elapsedMilliseconds,
      lessThan(8000),
      reason: 'پردازش یک نوبت ${sw.elapsedMilliseconds}ms طول کشید؛ '
          'مسیر بازیابی یا تطبیق واژهها را بررسی کنید',
    );
  });
}
