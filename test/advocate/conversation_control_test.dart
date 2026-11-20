import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/drafting.dart';

/// آزمون کنترل گفتگو: نوشتنِ «بنویسم» از سوی کاربر فرم سند را باز نمی‌کند،
/// «انصراف» و «خروج از موضوع» پرونده را می‌بندند، و موضوع تازهٔ روشن
/// پروندهٔ قبلی را عوض می‌کند.
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

  const cheque =
      'قرار است برای خرید یک ماشین به فروشنده یک چک ۵۰۰ میلیون تومانی بدهم. '
      'فروشنده می‌گوید باید چک را «در وجه حامل» بنویسم. آیا این کار خطرناک است؟';

  test('«بنویسم» کاربر درخواست سند نیست', () {
    expect(Advocate.wantsDraft(cheque), isFalse);
    expect(Advocate.wantsDraft('این متن را برایم بنویس'), isTrue);
  });

  test('«گزینه‌ای وجود ندارد» راه خروج نشان داده می‌شود', () {
    final a = fresh();
    a.respond('همسایه‌ام دیوار مشترک را خراب کرده');
    final r = a.respond('گزینه ای وجود ندارد');
    expect(r.text, contains('انصراف'));
    expect(r.chips, contains(Advocate.newCaseChip));
  });

  for (final exit in [
    'انصراف',
    'خروج از موضوع',
    'چرا از موضوع خارج نمی شوی',
    'نمی خواهم این بحث را ادامه دهم',
  ]) {
    test('«$exit» پرونده را می‌بندد', () {
      final a = fresh();
      a.respond('همسایه‌ام دیوار مشترک را خراب کرده');
      expect(a.file.topic, isNotEmpty);
      final r = a.respond(exit);
      expect(r.text, contains('کنار گذاشتم'));
      expect(a.file.topic, isEmpty);
    });
  }

  test('«انصراف از ضمانت» در جملهٔ بلند خروج نیست', () {
    expect(Drafting.isLeave('می‌خواهم از ضمانتی که دادم انصراف دهم و کاغذ بگیرم'),
        isFalse);
  });

  test('ماجرای دیوار مشترک به پروندهٔ همسایه می‌رود', () {
    final a = fresh();
    a.respond('همسایه من دیوار مشترک بین حیاط ما و خودش را بدون اجازه من خراب کرده و دیوار بلندتری ساخته که نور را از خانه ما می‌گیرد');
    expect(a.file.topic, 'neighbor');
  });
}
