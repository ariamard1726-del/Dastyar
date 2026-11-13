import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/domain/dialogue/conversation_memory.dart';

void main() {
  test('bounced-cheque statement is not recorded as proof', () {
    expect(DialogueStateManager.extractProof('چکم برگشت خورده'), isNull);
  });

  test('explicit cheque as evidence is still recorded', () {
    final v = DialogueStateManager.extractProof('مدرکم چک است و اصلش را دارم');
    expect(v, isNotNull);
    expect(v!.raw.contains('cheque'), isTrue);
  });
}
