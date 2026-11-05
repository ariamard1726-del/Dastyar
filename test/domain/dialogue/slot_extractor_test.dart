import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/dialogue/domain_slot_schemas.dart';
import 'package:dastyar/domain/dialogue/slot_extractor.dart';
import 'package:dastyar/domain/dialogue/slots.dart';

void main() {
  group('DomainSchemaRegistry', () {
    test('has all 8 domains', () {
      expect(DomainSchemaRegistry.allDomainIds.length, 8);
    });

    test('cheque schema has required slots', () {
      final cheque = DomainSchemaRegistry.forDomain('cheque');
      expect(cheque, isNotNull);
      expect(cheque!.requiredSlots.length, greaterThanOrEqualTo(3));
    });

    test('forDomain returns null for unknown domain', () {
      expect(DomainSchemaRegistry.forDomain('unknown'), isNull);
    });

    test('every schema matches the canonical slot contract', () {
      for (final domain in DomainSchemaRegistry.allDomainIds) {
        final schema = DomainSchemaRegistry.forDomain(domain)!;
        final names = schema.slots.map((slot) => slot.name).toList();

        expect(names.toSet().length, names.length,
            reason: '$domain must not contain duplicate slot keys');
        expect(names.every(Slots.all.contains), isTrue,
            reason: '$domain contains an undeclared slot key');
        expect(
          schema.requiredSlots.map((slot) => slot.name).toList(),
          Slots.coreFor(domain),
          reason: '$domain required slots must match Slots.coreByDomain',
        );
      }
    });
  });

  group('SlotExtractor — golden set', () {
    late List<dynamic> sentences;

    setUpAll(() {
      final file = File('test/domain/dialogue/golden_sentences.json');
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      sentences = json['sentences'] as List<dynamic>;
    });

    test('golden set has at least 30 sentences', () {
      expect(sentences.length, greaterThanOrEqualTo(30));
    });

    test('recall >= 0.85 and precision >= 0.90', () {
      const extractor = SlotExtractor();
      var totalExpected = 0;
      var correctlyFound = 0;
      var extraSlots = 0;
      var wrongValues = 0;

      for (final entry in sentences) {
        final e = entry as Map<String, dynamic>;
        final domain = e['domain'] as String;
        final text = e['text'] as String;
        final expected = (e['expected'] as Map<String, dynamic>)
            .cast<String, dynamic>();

        final schema = DomainSchemaRegistry.forDomain(domain);
        expect(schema, isNotNull, reason: 'No schema for $domain');

        final extracted = extractor.extract(text, schema!);

        for (final exp in expected.entries) {
          totalExpected++;
          final actual = extracted[exp.key];
          if (actual?.value == exp.value) {
            correctlyFound++;
          } else if (actual != null) {
            wrongValues++;
          }
        }

        for (final key in extracted.keys) {
          if (!expected.containsKey(key)) {
            extraSlots++;
          }
        }
      }

      final recall = correctlyFound / totalExpected;
      final precision =
          correctlyFound / (correctlyFound + extraSlots + wrongValues);

      printOnFailure('Total expected: $totalExpected');
      printOnFailure('Correctly found: $correctlyFound');
      printOnFailure('Extra slots: $extraSlots');
      printOnFailure('Wrong values: $wrongValues');
      printOnFailure('Recall: $recall');
      printOnFailure('Precision: $precision');

      expect(recall, greaterThanOrEqualTo(0.85));
      expect(precision, greaterThanOrEqualTo(0.90));
    });
  });

  group('SlotExtractor — edge cases', () {
    const extractor = SlotExtractor();

    test('empty text returns empty map', () {
      final schema = DomainSchemaRegistry.forDomain('cheque')!;
      final result = extractor.extract('', schema);
      expect(result, isEmpty);
    });

    test('unknown domain schema (via null check)', () {
      expect(DomainSchemaRegistry.forDomain('unknown'), isNull);
    });

    test('amount extraction from Persian digits', () {
      final schema = DomainSchemaRegistry.forDomain('cheque')!;
      final result = extractor.extract('چک به مبلغ ۱۰۰۰ تومان', schema);
      expect(result['amount'], isNotNull);
    });
  });
}
