import 'dart:convert';

import 'package:dastyar/domain/advocate/case_file.dart';
import 'package:dastyar/domain/advocate/rule_dsl.dart';
import 'package:dastyar/domain/advocate/text_sense.dart';
import 'package:dastyar/domain/advocate/topics/all.dart';
import 'package:dastyar/domain/advocate/topics/topic_texts_loader.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await loadTopicTexts();
  });

  const phase9TopicIds = <String>{
    'accused',
    'admin',
    'child',
    'company',
    'consumer',
    'cyber',
    'debt',
    'enforce',
    'fight',
    'foreign_contract',
    'guarantee',
    'inherit',
    'injury',
    'marriage',
    'minor_sale',
    'neighbor',
    'partner',
    'property',
    'sale',
    'theft',
  };

  test('همهٔ ۲۰ موضوع فاز ۹ به‌صورت RuleDSL تعریف شده و JSON معتبر می‌دهند', () {
    final migrated = allTopics.where((t) => phase9TopicIds.contains(t.id)).toList();
    expect(migrated.length, 20);
    for (final topic in migrated) {
      expect(topic.isDeclarative, isTrue, reason: '${topic.id} باید DSL باشد');
      final encoded = jsonEncode(topic.toJson());
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;
      expect(decoded['id'], topic.id);
      expect(decoded['slots'], isList);
      expect(decoded['issues'], isList);
      expect(decoded['follow'], isMap);
    }
  });

  test('FactExpr ارزیابی سه‌ارزشی و دوارزشی و toJson را درست انجام می‌دهد', () {
    final empty = CaseFile();
    expect(const FactTri('cert').evalTri(empty), isNull);
    expect(const FactYes('cert').evalCond(empty), isFalse);
    expect(const FactTriWhen(FactHas('self'), FactEq('self', 'taken')).evalTri(empty),
        isNull);
    expect(const FactNumMin('pct', 20).evalTri(empty), isNull);

    final filled = CaseFile()
      ..set('cert', 'yes')
      ..set('pct', '25')
      ..set('amount', '500000000');
    expect(const FactTri('cert').evalTri(filled), isTrue);
    expect(const FactNumMin('pct', 20).evalTri(filled), isTrue);
    expect(const FactNumMin('pct', 30).evalTri(filled), isFalse);
    expect(const TxNum('amount').evalText(filled), contains('تومان'));
    expect(const FactAll([FactYes('cert'), FactNumMin('pct', 20)]).toJson()['op'],
        'all');
  });

  test('موضوع‌های مهاجرت‌یافته در سناریوهای کلیدی خروجی دقیق می‌دهند', () {
    final debtTopic = allTopics.firstWhere((t) => t.id == 'debt');
    final f = CaseFile()
      ..set('proof', 'none')
      ..set('admits', 'no')
      ..set('amount', '20000000');
    expect(debtTopic.claims.single.elements[0].test(f), isFalse);
    expect(debtTopic.claims.single.elements[1].test(f), isFalse);
    expect(debtTopic.recap!(f), isNotEmpty);
    expect(debtTopic.follow['next']!(f), isNotEmpty);

    final fightTopic = allTopics.firstWhere((t) => t.id == 'fight');
    expect(fightTopic.gate!(Sense.norm('منو زدند')), isTrue);
    expect(fightTopic.gate!(Sense.norm('ماشینم زد')), isFalse);
  });
}
