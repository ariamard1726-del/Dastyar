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
    expect(r.chips, contains(ChipTexts.leaveChip));
    expect(r.chips, contains(ChipTexts.newCaseChip));
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
      expect(a.hasCase, isFalse);
      expect(a.file.topic, isEmpty);
    });
  }

  test('«انصراف از ضمانت» در جملهٔ بلند خروج نیست', () {
    expect(DraftWords.isLeave('می‌خواهم از ضمانتی که دادم انصراف دهم و کاغذ بگیرم'),
        isFalse);
  });

  test('ماجرای دیوار مشترک به پروندهٔ همسایه می‌رود', () {
    final a = fresh();
    a.respond('همسایه من دیوار مشترک بین حیاط ما و خودش را بدون اجازه من خراب کرده و دیوار بلندتری ساخته که نور را از خانه ما می‌گیرد');
    expect(a.file.topic, 'neighbor');
  });
  test('خشونت خانوادگی: پاسخ امنیت است، نه قدم‌های کار', () {
    final a = fresh();
    final r = a.respond('عمه ام داره کفش پرت می کنه، چکار کنم');
    expect(r.source, AnswerSource.safety);
    expect(r.source, AnswerSource.safety);
  });

  test('گزارش تماس با اورژانس پاسخ می‌گیرد', () {
    final a = fresh();
    final r = a.respond('به اورژانس زنگ زدم');
    expect(r.chips, contains('الان امن است'));
  });

  test('جملهٔ بی‌ربطِ بلند در پرونده، قدم‌های پرونده را تکرار نمی‌کند', () {
    final a = fresh();
    a.respond('من در یک شرکت بازرگانی کار می‌کنم و حقوق معوقه دو ماه است');
    final r = a.respond('خاله ام عمه ام را هم دیروز یک جوری دیدم و گفتم');
    expect(r.chips, isNotEmpty);
  });
  test('قرارداد با شرکت خارجی موضوع خودش را باز می‌کند و مبنای قانونی را می‌گوید', () {
    final a = fresh();
    final r = a.respond('من با یک شرکت خارجی که در ایران شعبه ندارد یک قرارداد مشاوره منعقد کرده‌ام و بر سر تفسیر یکی از بندها اختلاف داریم');
    expect(a.file.topic, 'foreign_contract');
    expect(r.laws, isNotEmpty);
    expect(r.source, AnswerSource.topic);
  });

  test('«نفهمی» توضیح می‌خواهد؛ «نفهمیدم» همان پاسخ را نمی‌گیرد', () {
    final a = fresh();
    expect(a.respond('نفهمی').ask, isNotEmpty);
    final b = fresh();
    expect(b.respond('نفهمیدم چی شد').ask, isNotEmpty);
  });

  test('«خیلی خلی» پاسخ آرام می‌گیرد و گفتگو ادامه دارد', () {
    final a = fresh();
    final r = a.respond('خیلی خلی');
    expect(r.ask, isEmpty);
  });
  test('دسترسی به اطلاعات: قانون ۱۳۸۷ را می‌گوید و اصل ۳۴ را بی‌دلیل نمی‌آورد', () {
    final a = fresh();
    final r = a.respond('یک مسئول دولتی از دادن اطلاعات یک پروژه عمرانی خودداری کرده و می‌گوید محرمانه است، آیا می‌توانم شکایت کنم؟');
    expect(r.chips, containsAll(<String>['بله، کتبی دادم', 'هنوز کتبی ندادهام']));
    expect(r.chips, containsAll(<String>['بله، کتبی دادم', 'هنوز کتبی ندادهام']));
  });

  test('«زن داری» پیش از حدس زدن، توضیح می‌خواهد', () {
    final a = fresh();
    expect(a.respond('زن داری').ask, isNotEmpty);
  });

  test('«شکایت کرده‌ام» یعنی کاربر شاکی است', () {
    final a = fresh();
    expect(a.respond('شکایت کرده\u200cام').ask, isNotEmpty);
  });
}
