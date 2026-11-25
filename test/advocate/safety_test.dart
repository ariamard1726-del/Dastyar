import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// ایمنی، پیش از هر موضوع و مستقل از امتیاز تشخیص موضوع.
///
/// پیش‌تر بررسی خشونت فقط وقتی اجرا می‌شد که هیچ موضوعی امتیاز ۴ به بالا
/// نگرفته باشد؛ پس پیام روشنِ خشونت که واژهٔ طلاق یا مهریه هم دارد، پیام
/// اضطراری را از دست می‌داد. این آزمون همان حالت را قفل می‌کند.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine);

  test('پیام خشونت + طلاق، پیام ایمنی می‌گیرد نه پرسش پرونده', () {
    final a = fresh();
    final r = a.respond('شوهرم منو زد و می‌خوام طلاق بگیرم');
    expect(r.source, AnswerSource.safety, reason: r.text);
    expect(r.chips, containsAll(<String>['الان امن هستم', 'هنوز در خطر هستم']));
    expect(r.chips, contains('الان امن است'));
    // پاسخِ این نوبت ایمنی است، ولی پرونده بی‌صدا باز می‌شود تا نوبت بعد
    // گفتگو از سرِ همان موضوع ادامه یابد.
    expect(a.hasCase, isTrue);
    expect(a.file.topic, 'family');
    // پرسشِ پرونده جای پرسش ایمنی را نمی‌گیرد.
    expect(r.ask, isNotEmpty);
  });

  test('پیام خشونت با امتیاز موضوع بالا هم ایمنی را از دست نمی‌دهد', () {
    final a = fresh();
    final r = a.respond('شوهرم کتکم می‌زند، مهریه‌ام را هم نمی‌دهد، می‌خواهم طلاق بگیرم');
    expect(r.source, AnswerSource.safety, reason: r.text);
    expect(r.chips, contains('الان امن است'));
  });

  test('پیام ایمنی در یک پرونده تکرار نمی‌شود', () {
    final a = fresh();
    final first = a.respond('شوهرم منو زد');
    expect(first.source, AnswerSource.safety);
    final second = a.respond('شوهرم دوباره منو زد');
    // بار دوم مسیر عادی ادامه می‌یابد، ولی ایمنی دوباره تکرار نمی‌شود.
    expect(second.source, isNot(AnswerSource.safety));
  });

  test('گفتن دوبارهٔ «در خطر هستم» هم پاسخ فوری می‌گیرد', () {
    final a = fresh();
    a.respond('شوهرم منو زد');
    // حتی اگر هشدار یک بار داده شده باشد، اعلام خطر تازه نادیده گرفته نمی‌شود.
    final again = a.respond('الان در خطر هستم');
    expect(again.source, AnswerSource.safety, reason: again.text);
    expect(again.chips, contains('الان امن هستم'));
  });

  test('«الان در خطر هستم» راهنمای فوری می‌گیرد', () {
    final a = fresh();
    final r = a.respond('الان در خطر هستم');
    expect(r.source, AnswerSource.safety, reason: r.text);
    expect(r.chips, contains('الان امن هستم'));
  });

  test('جملهٔ عادی، ایمنی را فعال نمی‌کند', () {
    final a = fresh();
    final r = a.respond('کارفرما حقوقم را نداده');
    expect(r.source, isNot(AnswerSource.safety));
  });
}
