import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/dialogue_state.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/rent.dart';

/// تشخیصِ موضوع و بحث باید بی‌نیاز از `Advocate` آزمون‌شدنی باشد؛ تا دیروز
/// برای سنجیدنِ «این پیام جوابِ همان پرسشِ باز است؟» باید یک وکیلِ کامل با
/// موتور و بانک قوانین ساخته می‌شد.
void main() {
  TopicPicker picker(CaseFile f, {DialogueState? dialog}) => TopicPicker(
        file: f,
        dialog: dialog ?? DialogueState(),
        intentNet: null,
        open: (t, n, {bool guessed = false}) => AdvocateReply('باز شد'),
      );

  test('موضوعِ باز از پرونده خوانده می‌شود، نه از وکیل', () {
    final empty = CaseFile();
    expect(picker(empty).current(), isNull);
    final open = CaseFile()..topic = 'rent';
    expect(picker(open).current()?.id, 'rent');
  });

  test('بی‌پرسشِ باز، هیچ پیامی «جواب» شمرده نمی‌شود', () {
    final f = CaseFile();
    expect(picker(f).answers(rentTopic, Sense.norm('بله')), isFalse);
  });

  test('واژهٔ تک‌افتاده به راهنمای نزدیکش نمی‌چسبد', () {
    // «صیادیه» نباید به راهنمای «دیه» بخورد.
    expect(picker(CaseFile()).matchGuide('صیاد', Sense.norm('صیادیه چیست')), isNull);
  });
}
