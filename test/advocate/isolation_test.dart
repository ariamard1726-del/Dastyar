import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/case_plan.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topic_score.dart';
import 'package:dastyar/domain/advocate/topics/all.dart';
import 'package:dastyar/domain/advocate/topics/rent.dart';

/// دو کارِ اصلیِ وکیل — «این پیام کدام موضوع است؟» و «حالا چه بپرسم؟» — باید
/// بدون ساختنِ `Advocate` و بدون بانک قوانین آزمون‌شدنی باشند. اگر روزی این
/// دو دوباره به حالتِ گفتگو گره بخورند، همین آزمون قرمز می‌شود.
void main() {
  test('امتیاز موضوع، بی‌نیاز از وکیل', () {
    final n = Sense.norm('مستأجرم ودیعه را پس نمی‌دهد و از خانه تخلیه نمی‌کند');
    expect(TopicScore.of(rentTopic, n), greaterThanOrEqualTo(3));
  });

  test('تشخیص موضوع، بی‌نیاز از وکیل', () {
    final n = Sense.norm('مستأجرم ودیعه را پس نمی‌دهد و از خانه تخلیه نمی‌کند');
    var best = '';
    var bestScore = 0;
    for (final t in allTopics) {
      final s = TopicScore.of(t, n);
      if (s > bestScore) {
        best = t.id;
        bestScore = s;
      }
    }
    expect(best, 'rent');
  });

  test('فروشنده‌ای که ثمن را نگرفته، موضوع طلب است نه مصرف‌کننده', () {
    final n = Sense.norm(
        'ماشینم را فروخته ام ولی خریدار پولش را کامل نداده است');
    var best = '';
    var bestScore = -1;
    for (final t in allTopics) {
      final s = TopicScore.ignoringGate(t, n);
      if (s > bestScore) {
        best = t.id;
        bestScore = s;
      }
    }
    expect(best, 'debt');
    expect(bestScore, greaterThanOrEqualTo(3));
  });

  test('پرسش بعدی، بی‌نیاز از وکیل', () {
    var asked = 0;
    for (final t in allTopics) {
      final f = CaseFile()..topic = t.id;
      final q = CasePlan.nextSlot(t, f);
      if (q == null) continue;
      asked++;
      // هرچه برگشت باید واقعاً پرسیدنی باشد.
      expect(q.ask, isNotEmpty, reason: '${t.id}/${q.id} متن پرسش ندارد');
      expect(f.touched(q.id), isFalse, reason: '${t.id}/${q.id} قبلاً جواب دارد');
      final w = q.when;
      expect(w == null || w(f), isTrue,
          reason: '${t.id}/${q.id} شرطش برقرار نیست');
      expect(f.askCount[q.id] ?? 0, lessThan(2));
      // جواب که داده شد، همان پرسش دوباره نمی‌آید.
      f.facts[q.id] = 'yes';
      expect(CasePlan.nextSlot(t, f)?.id, isNot(q.id),
          reason: '${t.id}/${q.id} بعد از جواب دوباره پرسیده شد');
    }
    expect(asked, greaterThan(3), reason: 'هیچ موضوعی پرسشِ بعدی نداشت');
  });

  test('پرسشی که دو بار بی‌جواب ماند، سومین بار پرسیده نمی‌شود', () {
    for (final t in allTopics) {
      final f = CaseFile()..topic = t.id;
      final q = CasePlan.nextSlot(t, f);
      if (q == null) continue;
      f.askCount[q.id] = 2;
      expect(CasePlan.nextSlot(t, f)?.id, isNot(q.id), reason: t.id);
    }
  });
}
