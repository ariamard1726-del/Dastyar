import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// آزمون تغییر موضوع: «انصراف» همیشه آخرین دکمه است، و وقتی پیام به موضوع
/// دیگری اشاره دارد ولی کاربر صریحاً نگفته، پرسیده می‌شود که موضوع تازه است یا
/// مربوط به قبلی. تا کاربر «انصراف» را نزده، پرونده عوض نمی‌شود.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine, draftTitles: const {
        'demand_money': 'دادخواست مطالبه وجه',
        'defense_brief': 'لایحه دفاعیه',
      });

  test('«انصراف» دکمهٔ آخر است وقتی پرونده باز است', () {
    final a = fresh();
    final r = a.respond('همسایه‌ام دیوار مشترک را خراب کرده');
    expect(r.chips, isNotEmpty);
    expect(r.chips.last, Advocate.leaveChip);
    expect(r.chips.where((c) => c == Advocate.leaveChip).length, 1);
  });

  test('بدون پرونده، «انصراف» دکمه نیست', () {
    final r = fresh().respond('سلام');
    expect(r.chips, isNot(contains(Advocate.leaveChip)));
  });

  test('پیام با موضوع دیگر، پرونده را بی‌پرسش عوض نمی‌کند', () {
    final a = fresh();
    a.respond('همسایه من دیوار مشترک بین حیاط ما و خودش را بدون اجازه من خراب کرده');
    expect(a.file.topic, 'neighbor');
    final r = a.respond(
        'امشب یک نفر از ماشینم کیف پول مرا دزدید و با یک موتور فرار کرد');
    if (r.chips.contains(Advocate.sideChip)) {
      // سؤال «تازه است یا مربوط؟» آمده: تا پاسخ نیامده، موضوع عوض نشده است.
      expect(a.file.topic, 'neighbor');
      expect(r.chips, contains(Advocate.relatedChip));
      expect(r.chips.last, Advocate.leaveChip);
      a.respond(Advocate.relatedChip);
      expect(a.file.topic, 'neighbor');
    }
  });

  test('«موضوع تازه است» پرونده را به موضوع جدید می‌برد', () {
    final a = fresh();
    a.respond('همسایه من دیوار مشترک بین حیاط ما و خودش را بدون اجازه من خراب کرده');
    final r = a.respond(
        'امشب یک نفر از ماشینم کیف پول مرا دزدید و با یک موتور فرار کرد');
    if (r.chips.contains(Advocate.sideChip)) {
      a.respond(Advocate.sideChip);
      expect(a.file.topic, isNot('neighbor'));
    }
  });

  test('«انصراف» در جواب سؤال تغییر موضوع، پرونده را می‌بندد', () {
    final a = fresh();
    a.respond('همسایه من دیوار مشترک بین حیاط ما و خودش را بدون اجازه من خراب کرده');
    final r = a.respond(
        'امشب یک نفر از ماشینم کیف پول مرا دزدید و با یک موتور فرار کرد');
    if (r.chips.contains(Advocate.sideChip)) {
      a.respond(Advocate.leaveChip);
      expect(a.file.topic, isEmpty);
    }
  });
}
