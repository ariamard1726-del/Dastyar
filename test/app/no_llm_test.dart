import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/domain/assistant.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  group('مأموریت ۳: حذف کامل لایهٔ مدل زبانی', () {
    test('فایل‌ها و کانال‌های بومی مدل زبانی وجود ندارند', () {
      expect(File('lib/core/llm.dart').existsSync(), isFalse);
      expect(File('lib/domain/prompt_builder.dart').existsSync(), isFalse);

      final kotlin = File(
        'android/app/src/main/kotlin/com/ariabod/dastyar/MainActivity.kt',
      ).readAsStringSync();
      expect(kotlin.contains('llm_stream'), isFalse);
      expect(kotlin.contains('com.ariabod.dastyar/llm'), isFalse);
      expect(kotlin.contains('LLM_CHANNEL'), isFalse);
      expect(kotlin.contains('.gguf'), isFalse);
    });

    test('هیچ فایل دارتی به لایهٔ مدل زبانی وابسته نیست', () {
      final dir = Directory('lib');
      final files = dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      expect(files, isNotEmpty);
      for (final f in files) {
        final src = f.readAsStringSync();
        expect(src.contains('core/llm.dart'), isFalse, reason: f.path);
        expect(src.contains('LlmBackend'), isFalse, reason: f.path);
        expect(src.contains('NoLlm'), isFalse, reason: f.path);
        expect(src.contains('llm_stream'), isFalse, reason: f.path);
        expect(src.contains('PromptBuilder'), isFalse, reason: f.path);
        expect(src.contains('useLocalLlm'), isFalse, reason: f.path);
      }
    });

    test('تنظیمات برنامه دیگر گزینهٔ مدل زبانی ندارند', () {
      final src = File('lib/domain/settings.dart').readAsStringSync();
      expect(src.contains('useLocalLlm'), isFalse);
      expect(src.contains('setUseLocalLlm'), isFalse);
    });

    test('Assistant فقط یک پاسخ قطعی از موتور می‌دهد، بدون تولید یا استریم مدل', () async {
      const q = 'ماده ۱۰ قانون مدنی';
      final assistant = Assistant(engine);

      final turns = await assistant
          .askWithAlternatives(q)
          .toList()
          .timeout(const Duration(seconds: 5));
      expect(turns, hasLength(1));
      final expected = engine.query(q);
      expect(turns.single.text, expected.text);
      expect(turns.single.alternatives, expected.alternatives);
      expect(turns.single.conflictChains, expected.conflictChains);

      final words = await assistant.ask(q).toList();
      expect(words, [engine.answer(q)]);
      expect(turns.single.text, contains('ماده 10'));
    });

    test('پاسخ قطعی حتی با پرسش طولانی از موتور جدا نمی‌شود', () async {
      const q = 'مجازات کلاهبرداری چیست و کدام ماده آن را تشدید می‌کند؟';
      final out = await Assistant(engine).ask(q).toList();
      expect(out, hasLength(1));
      expect(out.single, engine.answer(q));
    });
  });
}
