import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine e;
  setUpAll(() async {
    e = KnowledgeEngine();
    await e.load();
  });

  test('قوانین واقعاً بارگذاری شده‌اند', () {
    for (final id in ['civil', 'cheque', 'commerce', 'landlord_tenant']) {
      expect(e.isLoaded(id), isTrue, reason: id);
    }
  });

  test('واژهٔ موضوعی نام قانون حساب نمی‌شود', () {
    final a = e.answer('شرایط ازدواج چیست');
    expect(a.contains('هنوز در برنامه نیست'), isFalse);
  });
}
