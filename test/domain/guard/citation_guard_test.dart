import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/guard/citation_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CitationGuard basics', () {
    test('citedArticles returns empty for text without cites', () {
      expect(CitationGuard.citedArticles('پاسخ ساده بدون ارجاع'), isEmpty);
    });

    test('citedArticles finds cite in basic text', () {
      final result = CitationGuard.citedArticles('بر اساس ماده 1 قانون...');
      expect(result, isNotEmpty);
    });

    test('isGrounded returns true when answer has no cites', () {
      expect(CitationGuard.isGrounded('بدون ارجاع', []), isTrue);
    });

    test('checkStreaming returns false for text without cites', () {
      expect(CitationGuard.checkStreaming('بدون ارجاع', {}), isFalse);
    });

    test('allowedArticles accepts empty hit list', () {
      expect(CitationGuard.allowedArticles([]), isEmpty);
    });
  });
}
