import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/intent_net.dart';

/// پیام‌های «دربارهٔ خودِ برنامه» و پیام‌های شخصیِ غیرحقوقی.
///
/// این آزمون از یک گفتگوی واقعیِ گزارش‌شده می‌آید. کاربر وسط پروندهٔ ودیعه
/// نوشت «از برنامه خارج شدم و دوباره برگشتم» و پاسخِ «منظورتان از … چیست؟»
/// گرفت؛ بعد از «سگم مرده» هم همان پرسش تکرار شد. هر دو پیام یک پاسخ صریح
/// دارند و هیچ‌کدام نباید به نقلِ کلمه‌ها و «کمی بیشتر توضیح می‌دهید؟» برسد.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  Advocate fresh() => Advocate(engine,
      intentNet: IntentNet.fromJson(jsonDecode(
              File('assets/brain/intent_model.json').readAsStringSync())
          as Map<String, dynamic>),
      draftTitles: const {
        'demand_money': 'دادخواست مطالبه وجه',
        'defense_brief': 'لایحه دفاعیه',
      });

  /// پاسخ آخر، با متنِ کامل (بدون بریدن با «ادامه بده»).
  String answer(Advocate a, String text) {
    final r = a.respond(text);
    final more = r.chips.contains(Advocate.moreChip);
    return r.text + (more ? ' ${a.respond(Advocate.moreChip)}' : '');
  }

  test('برنامه را بستن و باز کردن، پرسشِ «منظورتان چیست» نمی‌گیرد', () {
    final a = fresh();
    answer(a, 'صاحب‌خانه پول پیشم را نمی‌دهد');
    final out = answer(a, 'از برنامه خارج شدم و دوباره برگشتم');
    expect(out, isNot(contains('منظورتان از')));
    expect(out, contains('ذخیره'));
    // موضوع پاک نمی‌شود؛ بعد از این پیام همان پروندهٔ اجاره باز می‌ماند.
    expect(a.file.topic, 'rent');
  });

  test('پیامِ کوتاهِ سوگ، تسلیت می‌گیرد نه نقلِ کلمه‌ها', () {
    final a = fresh();
    final out = answer(a, 'سگم مرده');
    expect(out, isNot(contains('منظورتان از')));
    expect(out, contains('تسلیت'));
  });

  test('«مرد» به‌معنای شخص، سوگ شمرده نمی‌شود', () {
    final a = fresh();
    final out = answer(a, 'یک مرد به من حمله کرد و گوشی‌ام را زد');
    expect(out, isNot(contains('تسلیت')));
  });

  test('واژهٔ «برنامه» در جملهٔ حقوقی، پاسخِ برنامه را نمی‌دهد', () {
    final a = fresh();
    final out = answer(a, 'برنامهٔ اقساط وام را پرداخت نکردم و بانک شکایت کرده');
    expect(out, isNot(contains('برنامه را بسته و باز کرده‌اید')));
  });

  test('ادعای خرابی، لحنِ «زیاد می‌شنوم» و «خوشبختانه» ندارد', () {
    final a = fresh();
    answer(a, 'صاحب‌خانه پول پیشم را نمی‌دهد');
    final out = answer(a, 'می‌گوید خانه را خراب کرده‌ای');
    expect(out, contains('سه نکته تعیین‌کننده'));
    expect(out, isNot(contains('زیاد می‌شنوم')));
    expect(out, isNot(contains('خوشبختانه')));
  });

  test('پرسشِ بی‌جواب، بار سوم تکرار نمی‌شود', () {
    final a = fresh();
    final first = answer(a, 'دو تا مگس بهم مشت انداختند');
    final pend = first.split('\n\n').last.trim();
    expect(pend.endsWith('؟'), isTrue, reason: pend);

    final second = answer(a, 'چه مدرکی لازم است؟');
    expect(second, contains(pend), reason: 'بار دوم تکرار مجاز است');

    final third = answer(a, 'چقدر طول می‌کشد؟');
    expect(third, isNot(contains(pend)), reason: 'بار سوم باید رها شود');
    expect(third, contains('از آن می‌گذرم'));

    final fourth = answer(a, 'هزینه‌اش چقدر است؟');
    expect(fourth, isNot(contains(pend)));
  });

  test('پیامِ نامفهومِ کوتاه، از بار اول راهِ خروج دارد', () {
    final a = fresh();
    final r = a.respond('هوم');
    expect(r.text, contains('منظورتان از'));
    expect(r.chips, isNotEmpty);
  });
}
