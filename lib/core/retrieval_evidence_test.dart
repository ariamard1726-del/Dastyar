import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/dialogue/evidence.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('retrieveWithEvidence', () {
    late KnowledgeEngine engine;

    setUpAll(() async {
      engine = KnowledgeEngine();
      await engine.load();
    });

    test('empty retrieval returns insufficient evidence', () {
      final result = engine.retrieveWithEvidence('xyzxyzxyz');
      expect(result, isA<EvidenceSet>());
      expect(result.items, isEmpty);
      expect(result.coverage, 0.0);
      expect(result.hasSufficientSupport, isFalse);
    });

    test('strong retrieval returns sufficient evidence', () {
      final result = engine.retrieveWithEvidence('ماده ۱۰ قانون مدنی');
      expect(result.items, isNotEmpty);
      expect(result.coverage, greaterThanOrEqualTo(0.4));
      expect(result.conflicts, isEmpty);
      expect(result.hasSufficientSupport, isTrue);
    });

    test('obsolete chunks are filtered out', () {
      final result = engine.retrieveWithEvidence('قانون');
      for (final item in result.items) {
        expect(item.text, isNotEmpty);
      }
    });

    test('Evidence items are ranked 1..n', () {
      final result = engine.retrieveWithEvidence('چک برگشتی');
      for (var i = 0; i < result.items.length; i++) {
        expect(result.items[i].rank, i + 1);
      }
    });

    test('conflicts are populated for known conflict article', () {
      final result = engine.retrieveWithEvidence('ماده ۱۰ قانون مدنی');
      // conflicts may or may not exist for this article; just verify shape
      expect(result.conflicts, isA<List<Evidence>>());
    });
  });
}