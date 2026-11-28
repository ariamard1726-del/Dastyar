import 'dart:convert';

import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/all.dart';
import 'package:dastyar/domain/advocate/topics/rent_texts_loader.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTopicTexts();
    await loadRentTexts();
  });

  const phase10TopicIds = <String>{'cheque', 'family', 'labor', 'rent'};

  test('همهٔ ۲۴ موضوع از جمله ۴ موضوع فاز ۱۰ با RuleDSL و JSON معتبرند', () {
    expect(allTopics.length, 24);
    for (final topic in allTopics) {
      expect(topic.isDeclarative, isTrue, reason: '${topic.id} باید DSL باشد');
      final decoded =
          jsonDecode(jsonEncode(topic.toJson())) as Map<String, dynamic>;
      expect(decoded['id'], topic.id);
      expect(decoded['slots'], isList);
      expect(decoded['issues'], isList);
      expect(decoded['follow'], isMap);
    }

    for (final id in phase10TopicIds) {
      final topic = allTopics.firstWhere((t) => t.id == id);
      final json = topic.toJson();
      expect(json['recap'], isList, reason: '$id باید recap داشته باشد');
      expect(json['drafts'], isMap, reason: '$id باید drafts داشته باشد');
    }

    final rentJson =
        allTopics.firstWhere((t) => t.id == 'rent').toJson();
    expect(rentJson['petition'], isMap);
    expect(rentJson['brief'], isMap);
    expect(rentJson['fill'], isMap);
    expect(rentJson['askReply'], isMap);
  });

  test('گره‌ها و عملگرهای فاز ۱۰ رفتار دقیق و خروجی toJson دارند', () {
    final empty = CaseFile();
    expect(const FactTouched('bounce').evalCond(empty), isFalse);
    expect(const FactCovered('damage').evalCond(empty), isFalse);
    expect(const FactNumMax('months', 6).evalTri(empty), isNull);
    expect(
      const ReadNumBefore('ماه', max: 12).evalRead(Sense.norm('۱۸ ماه')),
      isNull,
    );
    expect(
      const ReadNumBefore('ماه', max: 12).evalRead(Sense.norm('۵ ماه')),
      '5',
    );
    expect(
      const ReadMonths(min: 2).evalRead(Sense.norm('۳ ماه کار کردم')),
      '3',
    );
    expect(
      const ReadGuard(
        'حقوق',
        ReadMonths(min: 1),
      ).evalRead(Sense.norm('۲ ماه نرفتم')),
      isNull,
    );
    expect(
      const ReadBeforeMatch(
        ' اما ',
        ReadCases([ReadCase('موجر', 'landlord')]),
      ).evalRead(Sense.norm('موجر اما مستاجر')),
      'landlord',
    );
    expect(
      const TxNumOffset('years', 7).evalText(CaseFile()..facts['years'] = '2'),
      contains('۹'),
    );
    expect(
      const TxScaleMul('salary', 'months', 0.5, divideFirst: true)
          .evalText(
            CaseFile()
              ..facts['salary'] = '12000000'
              ..facts['months'] = '6',
          ),
      contains('تومان'),
    );
    expect(
      const TxListJoin(
        prefix: TxRaw('['),
        separator: TxRaw('-'),
        suffix: TxRaw(']'),
        items: [RecapItem(when: FactYes('a'), text: TxRaw('A'))],
        empty: TxRaw('none'),
      ).evalText(empty),
      'none',
    );

    const fillRule = FillRule({
      't': [FillAssign('k', TxRaw('v'), when: FactYes('ok'))],
    });
    expect(fillRule.evalFill(empty, 't'), isEmpty);
    expect(fillRule.evalFill(CaseFile()..facts['ok'] = 'yes', 't'), {'k': 'v'});
    expect(const RankConst(3).toJson()['op'], 'const');
    expect(const PromptNone().toJson()['op'], 'none');
  });

  test('موضوع‌های cheque و family با RuleDSL هم‌ارزی رفتاری دارند', () {
    final cheque = allTopics.firstWhere((t) => t.id == 'cheque');
    final cf = CaseFile()
      ..facts['role'] = 'holder'
      ..facts['amount'] = '50000000'
      ..facts['cert'] = 'yes'
      ..facts['kind'] = 'day'
      ..facts['since'] = '10';
    expect(cheque.recap!(cf), isNotEmpty);
    expect(cheque.drafts!(cf), ['cheque_execution', 'cheque_complaint']);
    expect(
      cheque.drafts!(CaseFile()..facts['role'] = 'issuer'),
      ['insolvency'],
    );
    expect(cheque.claims.single.elements[0].test(cf), isTrue);
    expect(cheque.claims.single.elements[1].test(cf), isTrue);
    expect(cheque.follow['next']!(cf), isNotEmpty);

    final family = allTopics.firstWhere((t) => t.id == 'family');
    final ff = CaseFile()
      ..facts['role'] = 'wife'
      ..facts['violence'] = 'yes'
      ..facts['childAge'] = '4'
      ..facts['coins'] = '110';
    expect(family.recap!(ff), contains('زنِ این زندگی هستید'));
    expect(family.follow['where']!(ff), isNotEmpty);
    expect(family.drafts!(ff), ['legal_aid']);
    expect(
      family.slots.firstWhere((s) => s.id == 'childAge').effect!(ff),
      isNotEmpty,
    );
  });

  test('موضوع‌های labor و rent با RuleDSL هم‌ارزی رفتاری دارند', () {
    final labor = allTopics.firstWhere((t) => t.id == 'labor');
    final lf = CaseFile()
      ..facts['event'] = 'fired'
      ..facts['fired'] = 'yes'
      ..facts['insured'] = 'no'
      ..facts['contract'] = 'yes'
      ..facts['months'] = '14'
      ..facts['salary'] = '20000000';
    expect(labor.recap!(lf), contains('کارفرما شما را اخراج کرده'));
    expect(labor.recap!(lf), contains('بیمه نشده‌اید'));
    expect(labor.follow['next']!(lf), contains(topicText('laborBod_3')));
    expect(labor.follow['chance']!(lf), isNotEmpty);
    expect(
      labor.issues.firstWhere((i) => i.id == 'howmuch').body(lf),
      isNotEmpty,
    );
    expect(
      labor.issues.firstWhere((i) => i.id == 'sanavat').body(lf),
      isNotEmpty,
    );
    expect(labor.drafts!(lf), ['formal_notice']);

    final rent = allTopics.firstWhere((t) => t.id == 'rent');
    final rf = CaseFile()
      ..facts['role'] = 'tenant'
      ..facts['matter'] = 'deposit'
      ..facts['ended'] = 'yes'
      ..facts['vacated'] = 'yes'
      ..facts['contract'] = 'no'
      ..facts['amount'] = '200000000';
    expect(rent.recap!(rf), isNotEmpty);
    expect(rent.follow['evidence']!(rf), rentText('plan32'));
    expect(rent.follow['where']!(rf), isNotEmpty);
    expect(rent.petition!(rf)?.template, 'demand_money');
    expect(rent.brief!(rf)?.template, 'defense_brief');
    expect(rent.fill!(rf, 'demand_money'), containsPair('basis', 'سایر'));
    expect(rent.drafts!(rf), ['formal_notice', 'demand_money']);
    expect(rent.askReply!(rf)?.chips.length, 4);
    expect(rent.claims[4].elements[2].test(rf), isFalse);
    expect(
      rent.issues.firstWhere((i) => i.id == 'goodwill').rank!(
        CaseFile()..facts['place'] = 'shop',
      ),
      4,
    );
    expect(rent.issues.firstWhere((i) => i.id == 'goodwill').rank!(rf), -1);
  });
}
