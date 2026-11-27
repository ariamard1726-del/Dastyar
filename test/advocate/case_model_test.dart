import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/advocate/case_file.dart';

/// یک `import`، نُه نام: `case_file.dart` دروازه است و باید هم وضعیتِ گفتگو
/// (`CaseFile`) و هم مدل‌های زبانِ موضوع (`Element`، `Claim`، `Slot`، `Issue`،
/// `Filing`، `Prompt`، `Topic`) را بدهد.
///
/// پیش‌تر هر نُه در یک فایلِ ۴۰۱خطی بودند. این آزمون فقط از همین یک مسیر
/// `import` می‌کند تا اگر روزی یکی از دو `export` گم شود، قرمز شود — نه با
/// خطای کامپایل در چهل فایلِ دیگر، بلکه همین‌جا.
void main() {
  test('نُه نام، از یک import', () {
    final file = CaseFile()
      ..topic = 'rent'
      ..pending = 'deposit';

    final element = Element('مدت اجاره تمام شده باشد', (f) => f.yes('ended'));
    final claim = Claim(
      goal: 'پس‌گرفتن ودیعه',
      elements: [element],
      win: (f) => 'ودیعه برمی‌گردد',
    );
    final slot = Slot(
      id: 'deposit',
      ask: 'ودیعه گرفتید؟',
      why: 'برای مطالبه لازم است',
      read: (n) => null,
    );
    final issue = Issue(
      id: 'deposit_back',
      chip: 'ودیعه را پس نمی‌دهد',
      cues: 'ودیعه',
      body: (f) => 'متن',
    );
    const filing = Filing('demand_money', 'تنظیم دادخواست', 'دادخواست مطالبه وجه');
    const prompt = Prompt('طرف مقابل چه می‌گوید؟', ['هیچ', 'انکار می‌کند']);
    final topic = Topic(
      id: 'rent',
      title: 'اجاره',
      cues: const {'ودیعه': 3},
      slots: [slot],
      issues: [issue],
      opening: (f) => 'متنِ نخست',
      follow: const {},
    );

    expect(file.topic, 'rent');
    expect(topic.id, 'rent');
    expect(claim.goal, 'پس‌گرفتن ودیعه');
    expect(issue.chip, isNotEmpty);
    expect(filing.name, 'دادخواست مطالبه وجه');
    expect(prompt.chips.length, 2);
  });

  test('پیش‌فرض‌های عمومی مدل‌ها عوض نشده‌اند', () {
    final element = Element('شرط', (f) => null);
    expect(element.ifNo, isEmpty);
    expect(element.needs, isEmpty);
    expect(element.because, isNull);

    final claim = Claim(goal: 'هدف', elements: const [], win: (f) => '');
    expect(claim.label, isEmpty);
    expect(claim.uses, isEmpty);
    expect(claim.cues, isEmpty);
    expect(claim.when, isNull);
    expect(claim.counter, isNull);

    final slot = Slot(id: 'x', ask: 'پرسش', why: 'چرا', read: (n) => null);
    expect(slot.yesValue, 'yes');
    expect(slot.noValue, 'no');
    expect(slot.first, isFalse);
    expect(slot.sticky, isFalse);
    expect(slot.options, isEmpty);
    expect(slot.priority, isEmpty);
    expect(slot.readPending, isNull);
    expect(slot.effect, isNull);

    final issue = Issue(id: 'i', chip: 'c', cues: 'u', body: (f) => '');
    expect(issue.covers, isEmpty);
    expect(issue.when, isNull);
    expect(issue.rank, isNull);

    expect(Prompt.none.text, isEmpty);
    expect(Prompt.none.chips, isEmpty);

    final topic = Topic(
      id: 't',
      title: 'عنوان',
      cues: const {},
      slots: const [],
      issues: const [],
      opening: (f) => '',
      follow: const {},
    );
    expect(topic.anti, isEmpty);
    expect(topic.claims, isEmpty);
    expect(topic.gate, isNull);
    expect(topic.drafts, isNull);
    expect(topic.recap, isNull);
    expect(topic.petition, isNull);
    expect(topic.brief, isNull);
    expect(topic.fill, isNull);
    expect(topic.askReply, isNull);
  });

  test('قراردادِ JSON از دروازه رد می‌شود: نسخه ۱ و رفت‌وبرگشت', () {
    expect(CaseFile.schemaVersion, 1);
    final f = CaseFile()
      ..topic = 'labor'
      ..facts['wage_unpaid'] = 'yes'
      ..askCount['wage_unpaid'] = 1
      ..covered.add('wage_unpaid')
      ..turns = 3;
    final g = CaseFile.fromJson(
        jsonDecode(jsonEncode(f.toJson())) as Map<String, dynamic>);
    expect(g.topic, 'labor');
    expect(g.facts, f.facts);
    expect(g.turns, 3);
    expect(g.covered, {'wage_unpaid'});
    // نسخهٔ ناشناخته، پروندهٔ خالی می‌دهد نه کرش.
    final bad = CaseFile.fromJson({'v': 99, 'topic': 'rent'});
    expect(bad.topic, isEmpty);
  });
}
