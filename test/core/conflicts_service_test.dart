import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/conflicts_service.dart';

void main() {
  late Map<String, dynamic> relationshipsData;

  setUpAll(() {
    relationshipsData = jsonDecode(
      File('assets/relationships.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  group('سرویس تضادها: زنجیره، حلقه و سقف عمق', () {
    test('ConflictsService زنجیره، حلقه و سقف عمق را به‌درستی مدیریت می‌کند', () {
      final svc = ConflictsService();
      final chains = svc.getConflictsChain('101', relationshipsData);
      expect(chains, contains('101 -> 105 -> 108 -> 109'));
      expect(svc.getTitle('101', relationshipsData), 'ماده ۱۰۱');

      final cyclic = <String, dynamic>{
        'articles': <String, dynamic>{
          '1': <String, dynamic>{
            'conflicts_with': <String>['2'],
          },
          '2': <String, dynamic>{
            'conflicts_with': <String>['1'],
          },
        },
      };
      final cycChains = svc.getConflictsChain('1', cyclic);
      expect(cycChains.any((c) => c.contains('⚠️ (حلقه)')), isTrue);

      final capped =
          svc.getConflictsChain('101', relationshipsData, maxDepth: 2);
      expect(capped, ['101 -> 105']);
    });
  });
}
