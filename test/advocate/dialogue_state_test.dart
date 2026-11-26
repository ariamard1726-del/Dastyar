import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/advocate/advocate.dart';
import 'package:dastyar/domain/advocate/dialogue_state.dart';
import 'package:dastyar/domain/lawyer/legal_guides.dart';

/// وضعیت «روی میز» باید قابل ذخیره و بازیابی باشد؛ دکمههایی که در نسخهٔ ۳
/// تاریخچه نمایش داده میشدند ولی معنای خود را از دست میدادند، حالا همراه
/// پرونده برمیگردند.
Map<String, Topic> _topics() => {
      for (final t in Advocate.topics) t.id: t,
    };

void main() {
  Map<String, dynamic> roundTrip(DialogueState d) =>
      jsonDecode(jsonEncode(d.toJson())) as Map<String, dynamic>;

  test('پرسش باز و دکمههایش همانطور برمیگردند', () {
    final d = DialogueState()
      ..askText = 'آیا قرارداد کتبی دارید؟'
      ..askChips = const ['بله', 'خیر']
      ..offer = 'draft'
      ..offerDraft = 'eviction';
    final back = DialogueState.fromJson(roundTrip(d), topicById: _topics());
    expect(back.askText, d.askText);
    expect(back.askChips, d.askChips);
    expect(back.offer, 'draft');
    expect(back.offerDraft, 'eviction');
  });

  test('موضوع منتظرِ تأیید و لیستِ گزینهها همانطور برمیگردند', () {
    final first = Advocate.topics.first;
    final d = DialogueState()
      ..pendingTopic = first
      ..pendingText = 'همسرم …'
      ..choices = Advocate.topics.take(2).toList()
      ..choiceText = 'کدام ماجرا؟';
    final back = DialogueState.fromJson(roundTrip(d), topicById: _topics());
    expect(back.pendingTopic?.id, first.id);
    expect(back.pendingText, d.pendingText);
    expect(back.choices.map((t) => t.id), d.choices.map((t) => t.id));
    expect(back.choiceText, d.choiceText);
  });

  test('راهنمای باز و وضعیت ایمنی از دست نمیروند', () {
    final guide = legalGuides.isNotEmpty ? legalGuides.first : null;
    final d = DialogueState()
      ..guide = guide
      ..guideAsked = true
      ..heard = 'ودیعه پرداخت شد'
      ..lastSafetyText = 'شوهرم منو زد'
      ..safetyShown = true;
    final back = DialogueState.fromJson(roundTrip(d),
        topicById: _topics(),
        guideById: {for (final g in legalGuides) g.id: g});
    expect(back.guide?.id, guide?.id);
    expect(back.guideAsked, isTrue);
    expect(back.heard, d.heard);
    expect(back.lastSafetyText, d.lastSafetyText);
    expect(back.safetyShown, isTrue);
  });

  test('نسخهٔ ناشناخته و شناسهٔ ناشناخته کراش نمیکنند', () {
    final back = DialogueState.fromJson(<String, dynamic>{
      'v': 99,
      'choice': {'pendingTopic': 'topic', 'choices': ['nope']},
    });
    expect(back.pendingTopic, isNull);
    expect(back.choices, isEmpty);
  });
}
