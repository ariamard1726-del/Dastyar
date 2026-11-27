import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';

/// آزمون تغییر موضوع: «انصراف» در هر مرحلهٔ گفتگو آخرین دکمه است، و وقتی پیام
/// به موضوع دیگری اشاره دارد ولی کاربر صریحاً نگفته، اعلام می‌شود و با دکمه‌های
/// «بله/خیر» پرسیده می‌شود که موضوع تازه است یا مربوط به قبلی. تا کاربر پاسخ
/// نداده، پرونده عوض نمی‌شود.
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

  /// پاسخ «بله» یا «بله، موضوع تازه است» — هر کدام که نشان داده شده باشد.
  String yesChip(AdvocateReply r) =>
      r.chips.contains(ChipTexts.newTopicYesChip)
          ? ChipTexts.newTopicYesChip
          : ChipTexts.newTopicChip;

  String noChip(AdvocateReply r) =>
      r.chips.contains(ChipTexts.newTopicYesChip)
          ? ChipTexts.newTopicNoChip
          : ChipTexts.sameCaseChip;

  bool askedNewTopic(AdvocateReply r) =>
      r.chips.contains(ChipTexts.newTopicYesChip) ||
      r.chips.contains(ChipTexts.newTopicChip) ||
      r.chips.contains(ChipTexts.sideChip);

  test('«انصراف» در همهٔ مراحل گفتگو آخرین دکمه است و یک بار می‌آید', () {
    final a = fresh();
    final replies = <AdvocateReply>[
      a.respond('سلام'),
      a.respond('حقوقی'),
      a.respond('صاحبخونه پول پیشمو نمیده'),
      a.respond('ماده ۱۰ قانون مدنی چیست؟'),
      a.respond('یه لاک‌پشت بنفش دارم'),
      a.respond('ممنون'),
    ];
    for (final r in replies) {
      expect(r.chips, contains(ChipTexts.leaveChip), reason: r.text);
      expect(r.chips.last, ChipTexts.leaveChip, reason: r.text);
      expect(r.chips.where((c) => c == ChipTexts.leaveChip).length, 1,
          reason: r.text);
    }
  });

  test('موضوع تازه وسط پرونده: اعلام می‌کند و «بله/خیر» می‌پرسد', () {
    final a = fresh();
    a.respond('همسایه‌ام دیوار مشترک را خراب کرده');
    expect(a.file.topic, 'neighbor');
    final r = a.respond('کارفرمای من دو ماه است حقوقم را نداده و بیمه هم رد نکرده');
    expect(askedNewTopic(r), isTrue, reason: r.chips.join('،'));
    expect(r.chips, contains(ChipTexts.newTopicYesChip));
    expect(r.chips, contains(ChipTexts.leaveChip));
    // تا پاسخ نیامده، پرونده عوض نشده است.
    expect(a.file.topic, 'neighbor');
  });

  test('«بله» پرونده را به موضوع تازه می‌برد', () {
    final a = fresh();
    a.respond('همسایه‌ام دیوار مشترک را خراب کرده');
    final r = a.respond('کارفرمای من دو ماه است حقوقم را نداده و بیمه هم رد نکرده');
    a.respond(yesChip(r));
    expect(a.file.topic, 'labor');
  });

  test('«خیر» همان پرونده را نگه می‌دارد', () {
    final a = fresh();
    a.respond('همسایه‌ام دیوار مشترک را خراب کرده');
    final r = a.respond('کارفرمای من دو ماه است حقوقم را نداده و بیمه هم رد نکرده');
    a.respond(noChip(r));
    expect(a.file.topic, 'neighbor');
  });

  test('«انصراف» در جواب سؤال تغییر موضوع، پرونده را می‌بندد', () {
    final a = fresh();
    a.respond('همسایه‌ام دیوار مشترک را خراب کرده');
    a.respond('کارفرمای من دو ماه است حقوقم را نداده و بیمه هم رد نکرده');
    a.respond(ChipTexts.leaveChip);
    expect(a.file.topic, isEmpty);
  });

  test('وقتی خودِ کاربر موضوع را عوض می‌کند، بی‌پرسش می‌رود', () {
    final a = fresh();
    a.respond('ضامن وام دوستم شدم و حالا قسط نمی‌دهد');
    final r = a.respond('راستی یکی عکسامو تو تلگرام پخش کرده');
    expect(askedNewTopic(r), isFalse, reason: r.chips.join('،'));
    expect(a.file.topic, 'cyber');
  });
}
