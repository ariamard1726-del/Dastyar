import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/case_plan.dart';
import 'package:dastyar/domain/advocate/topics/family.dart';

/// آزمون موضوع خانواده: نقش، خشونت، مهریه و حضانت — بی‌دارایی و بی‌موتور.
void main() {
  test('نقش و خشونت در برداشتِ وکیل دیده می‌شوند', () {
    final f = CaseFile()
      ..facts['role'] = 'wife'
      ..facts['violence'] = 'yes'
      ..facts['proofV'] = 'medical';
    expect(familyTopic.recap!(f), contains('زنِ این زندگی هستید'));
    expect(familyTopic.recap!(f), contains('کتک و آزار در کار بوده'));
    expect(familyTopic.recap!(f), contains('گواهی پزشکی قانونی دارید'));
  });

  test('پروندهٔ تازه با پرسشِ نقش شروع می‌شود', () {
    final slot = CasePlan.nextSlot(familyTopic, CaseFile());
    expect(slot, isNotNull);
    expect(slot!.id, 'role');
  });

  test('ادعاها و پرسش‌های اصلی موضوع سرِ جایشان‌اند', () {
    final ids = familyTopic.slots.map((s) => s.id).toList();
    expect(ids, containsAll(['role', 'violence', 'childAge']));
    expect(familyTopic.claims, isNotEmpty);
    expect(familyTopic.id, 'family');
  });
}
