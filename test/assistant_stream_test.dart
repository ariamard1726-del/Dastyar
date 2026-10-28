import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/assistant.dart';
import 'package:dastyar/engine.dart';
import 'package:dastyar/llm.dart';

class _FakeLlm extends LlmBackend {
  final List<String> parts;
  bool cancelled = false;

  _FakeLlm(this.parts);

  @override
  String get name => 'fake';

  @override
  Future<bool> isReady() async => true;

  @override
  Stream<String> generate(
    String prompt, {
    LlmOptions options = const LlmOptions(),
  }) async* {
    for (final p in parts) {
      yield p;
    }
  }

  @override
  void cancel() => cancelled = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine e;
  const q = 'ماده ۱۰ قانون مدنی';

  setUpAll(() async {
    e = KnowledgeEngine();
    await e.load();
  });

  test('بدون مدل، همان پاسخ موتور برمی‌گردد', () async {
    final out = await Assistant(e).ask(q).toList();
    expect(out.last, e.answer(q));
  });

  test('مادهٔ ساختگی وسط تولید جلوی مدل را می‌گیرد', () async {
    final llm = _FakeLlm(['طبق ماده ', '۹۹۹ ', 'نافذ است.']);
    final out = await Assistant(e, llm: llm).ask(q).toList();
    expect(out.last, e.answer(q));
    expect(llm.cancelled, isTrue);
  });

  test('پاسخ مستند پذیرفته می‌شود و منبع می‌گیرد', () async {
    final llm = _FakeLlm(['طبق ماده ۱۰', ' قراردادها نافذ است.']);
    final out = await Assistant(e, llm: llm).ask(q).toList();
    expect(out.last.startsWith('طبق ماده ۱۰ قراردادها نافذ است.'), isTrue);
    expect(out.last.contains('منبع:'), isTrue);
    expect(llm.cancelled, isFalse);
  });

  test('پاسخ بیش از حد بلند کنار گذاشته می‌شود', () async {
    final llm = _FakeLlm(['الف' * 50, 'ب' * 50]);
    final out = await Assistant(e, llm: llm, maxChars: 60).ask(q).toList();
    expect(out.last, e.answer(q));
  });
}
