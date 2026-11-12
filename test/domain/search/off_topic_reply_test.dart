import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/search/retrieval_pipeline.dart';

void main() {
  test('off-topic message gets out-of-scope reply, not lawyer referral', () {
    final r = RetrievalPipeline.handleLowConfidenceRetrieval('امروز هوا چطوره؟', similarity: 0.1);
    expect(r.contains('خارج از حوزه'), isTrue);
    expect(r.contains('وکیل دادگستری'), isFalse);
  });

  test('unclear legal-ish message keeps the lawyer referral', () {
    final r = RetrievalPipeline.handleLowConfidenceRetrieval('یک موضوع حقوقی مبهم دارم', similarity: 0.1);
    expect(r.contains('وکیل دادگستری'), isTrue);
  });

  test('nonsense text gets out-of-scope reply, not lawyer referral', () {
    final r = RetrievalPipeline.handleLowConfidenceRetrieval('فلفلی قلقلی', similarity: 0.1);
    expect(r.contains('وکیل دادگستری'), isFalse);
  });

  test('legal-cue message below threshold keeps lawyer referral', () {
    final r = RetrievalPipeline.handleLowConfidenceRetrieval('من به سربازی نروم خوب هست', similarity: 0.1);
    expect(r.contains('وکیل دادگستری'), isTrue);
  });
}
