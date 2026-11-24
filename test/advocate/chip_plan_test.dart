import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/case_recap.dart';
import 'package:dastyar/domain/advocate/chip_plan.dart';
import 'package:dastyar/domain/advocate/dialogue_state.dart';
import 'package:dastyar/domain/advocate/topics/rent.dart';

/// دکمه‌های پیشنهادی و خلاصهٔ پرونده باید بی‌نیاز از `Advocate` آزمون شوند؛
/// تا دیروز هر دو متدِ خصوصیِ وکیل بودند و آزمودنشان یک گفتگو لازم داشت.
void main() {
  ChipPlan plan(CaseFile f, {DialogueState? dialog}) => ChipPlan(
        file: f,
        dialog: dialog ?? DialogueState(),
        filings: const [],
        draftTitles: const {'demand_money': 'تنظیم دادخواست مطالبهٔ وجه'},
      );

  test('وسط پرونده، دکمه‌ها از بحث‌های همان موضوع می‌آیند', () {
    final f = CaseFile()..topic = 'rent';
    final chips = plan(f).suggest(rentTopic);
    expect(chips, isNotEmpty);
    expect(chips.length, lessThanOrEqualTo(8));
    expect(chips.every((c) => c.trim().isNotEmpty), isTrue);
  });

  test('بی‌پرونده، نمونه‌های آغاز فقط پیش از گفتنِ ماجرا می‌آیند', () {
    final f = CaseFile();
    expect(plan(f).starters(), isNotEmpty);
    f.facts['x'] = '1';
    f.topic = 'rent';
    expect(plan(f).starters(), isEmpty);
  });

  test('خلاصهٔ پرونده فقط جمله‌های ناخالی می‌دهد', () {
    final entries = recapOf(rentTopic, CaseFile()..topic = 'rent');
    for (final e in entries) {
      expect(e, e.trim());
      expect(e, isNotEmpty);
    }
  });
}
