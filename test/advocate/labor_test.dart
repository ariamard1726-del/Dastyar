import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/case_plan.dart';
import 'package:dastyar/domain/advocate/topics/labor.dart';

/// آزمون موضوع «کار و کارفرما»: برداشتِ وکیل، ترتیبِ پرسش‌ها و ادعاها —
/// بی‌دارایی و بی‌موتور، تا پیش از هر بازآراییِ این فایل، رفتارش قفل باشد.
void main() {
  test('اخراج در برداشتِ وکیل می‌آید، حتی اگر بعدتر حرفِ بیمه پیش بیاید', () {
    final f = CaseFile()
      ..facts['event'] = 'fired'
      ..facts['insured'] = 'no';
    expect(laborFired(f), isTrue);
    expect(laborRecap(f), contains('کارفرما شما را اخراج کرده'));
    expect(laborRecap(f), contains('بیمه نشده‌اید'));
  });

  test('پروندهٔ تازه با پرسشِ «چه اتفاقی افتاده؟» شروع می‌شود', () {
    final slot = CasePlan.nextSlot(laborTopic, CaseFile());
    expect(slot, isNotNull);
    expect(slot!.id, 'event');
    expect(slot.ask.trim(), isNotEmpty);
  });

  test('پرسش‌های اصلی و کلیدواژه‌های موضوع سرِ جایشان‌اند', () {
    final ids = laborTopic.slots.map((s) => s.id).toList();
    expect(ids, containsAll(['event', 'contract', 'insured', 'proof']));
    expect(laborTopic.claims, isNotEmpty);
    expect(laborTopic.id, 'labor');
    expect(laborTopic.title.trim(), isNotEmpty);
  });
}
