import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import '../support/reply_shape.dart';

/// نمونهٔ مهاجرت از آزمون متنمحور به آزمون ساختاری: آنچه قرارداد است،
/// مسیر پاسخ، دکمهها و موضوع پروندهاند — نه عبارت دقیق جملهها.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  test('پرسش اضطراری از مسیر ایمنی و با دکمهٔ خروج میآید', () {
    final a = Advocate(engine);
    final r = a.respond('شوهرم منو زد و میخوام طلاق بگیرم');
    expectSource(r, AnswerSource.safety);
    expectChip(r, ChipTexts.leaveChip);
  });

  test('ماجرای اجاره پروندهٔ اجاره باز میکند و دکمههای همان موضوع را دارد', () {
    final a = Advocate(engine);
    final r = a.respond('صاحبخونه پول پیشمو نمیده');
    expectTopic(a, 'rent');
    expectChip(r, ChipTexts.leaveChip);
    expectNoChip(r, 'تنظیم دادخواست مطالبهٔ مهریه');
  });
}
