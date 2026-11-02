import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/llm.dart';
import 'package:dastyar/domain/assistant.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  group('بک‌اندهای مدل زبانی محلی و نگهبان امنیتی Loopback', () {
    test('LocalLoopbackLlm هر نشانی غیرمحلی را برای حفظ حریم خصوصی رد می‌کند', () {
      expect(
        () => LocalLoopbackLlm(
          endpoint: Uri.parse('https://api.openai.com/v1/chat/completions'),
        ),
        throwsArgumentError,
      );
      expect(
        () => LocalLoopbackLlm(
          endpoint: Uri.parse('http://192.168.1.20:8080/v1/chat/completions'),
        ),
        throwsArgumentError,
      );

      final local1 = LocalLoopbackLlm(
        endpoint: Uri.parse('http://127.0.0.1:11434/api/generate'),
      );
      expect(local1.name, 'local-loopback');
      local1.cancel();
    });

    test('extractTokenFromLine قالب‌های SSE (OpenAI/llama.cpp) و NDJSON (Ollama) را استخراج می‌کند', () {
      expect(
        LocalLoopbackLlm.extractTokenFromLine(
          'data: {"choices":[{"delta":{"content":"طبق ماده ۱۰ "}}]}',
        ),
        'طبق ماده ۱۰ ',
      );
      expect(LocalLoopbackLlm.extractTokenFromLine('data: [DONE]'), isNull);
      expect(
        LocalLoopbackLlm.extractTokenFromLine(
          '{"response":"قانون مدنی","done":false}',
        ),
        'قانون مدنی',
      );
    });

    test('LocalLoopbackLlm روی سرور محلی 127.0.0.1 استریم می‌کند و با Assistant راستی‌آزمایی می‌شود', () async {
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      try {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        unawaited(
          server.first.then((req) async {
            req.response.statusCode = 200;
            req.response.headers.contentType =
                ContentType('text', 'event-stream', charset: 'utf-8');
            req.response.writeln(
              'data: {"choices":[{"delta":{"content":"بر اساس ماده ۱۰ قانون مدنی، "}}]}',
            );
            await req.response.flush();
            req.response.writeln(
              'data: {"choices":[{"delta":{"content":"قراردادهای خصوصی نافذند."}}]}',
            );
            req.response.writeln('data: [DONE]');
            await req.response.close();
          }),
        );

        final llm = LocalLoopbackLlm(
          endpoint: Uri.parse(
            'http://127.0.0.1:${server.port}/v1/chat/completions',
          ),
        );
        try {
          expect(await llm.isReady(), isTrue);
          var enabled = true;
          final adaptive = AdaptiveLlm(
            candidates: [OnDeviceChannelLlm(), llm],
            isEnabled: () => enabled,
          );
          final assistant = Assistant(engine, llm: adaptive);
          final turns = await assistant
              .askWithAlternatives('ماده ۱۰ قانون مدنی')
              .toList()
              .timeout(const Duration(seconds: 5));

          expect(turns, isNotEmpty);
          expect(turns.last.text, contains('قراردادهای خصوصی نافذند.'));
          expect(turns.last.text, contains('منبع: قانون مدنی — ماده 10'));

          enabled = false;
          expect(await adaptive.isReady(), isFalse);
          await adaptive.dispose();
        } finally {
          llm.cancel();
          await server.close(force: true);
        }
      } finally {
        HttpOverrides.global = previousOverrides;
      }
    });
  });
}
