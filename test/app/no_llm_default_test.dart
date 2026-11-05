import 'package:flutter_test/flutter_test.dart';
import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/llm.dart';
import 'package:dastyar/domain/assistant.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Assistant default llm is NoLlm', () {
    final engine = KnowledgeEngine();
    final assistant = Assistant(engine);
    expect(assistant.llm, isA<NoLlm>());
  });

  test('Assistant preserves custom llm when provided', () {
    final engine = KnowledgeEngine();
    final customLlm = NoLlm();
    final assistant = Assistant(engine, llm: customLlm);
    expect(assistant.llm, same(customLlm));
  });
}
