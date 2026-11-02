import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/engine.dart';
import 'package:dastyar/core/history.dart';
import 'package:dastyar/core/llm.dart';
import 'package:dastyar/domain/assistant.dart';
import 'package:dastyar/domain/settings.dart';
import 'package:dastyar/domain/templates.dart';
import 'package:dastyar/ui/chat_controller.dart';
import 'package:dastyar/ui/chat_page.dart';

class _ControllableLlm extends LlmBackend {
  StreamController<String>? _controller;
  Completer<void>? _startedSignal;
  bool cancelled = false;

  Future<void> waitUntilStarted() async {
    if (_controller != null) return;
    final sig = _startedSignal ??= Completer<void>();
    await sig.future.timeout(const Duration(seconds: 3));
  }

  void emit(String token) {
    final c = _controller;
    if (c != null && !c.isClosed) {
      c.add(token);
    }
  }

  void finish() {
    unawaited(_controller?.close());
    _controller = null;
  }

  @override
  String get name => 'controllable';

  @override
  Future<bool> isReady() async => true;

  @override
  Stream<String> generate(
    String prompt, {
    LlmOptions options = const LlmOptions(),
  }) {
    final c = StreamController<String>();
    _controller = c;
    final sig = _startedSignal;
    if (sig != null && !sig.isCompleted) {
      _startedSignal = null;
      sig.complete();
    }
    return c.stream;
  }

  @override
  void cancel() {
    cancelled = true;
    finish();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late KnowledgeEngine engine;

  setUpAll(() async {
    engine = KnowledgeEngine();
    await engine.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('کنترلر مستقل گفتگو و مدیریت چرخهٔ حیات استریم', () {
    test('ChatController بدون ویجت، پرسش عادی و ذخیرهٔ تاریخچه را مدیریت می‌کند', () async {
      final settings = AppSettings()..saveHistory = true;
      final history = HistoryStore();
      await history.load();
      final repo = TemplateRepository();
      final ctrl = ChatController(
        engine: engine,
        assistant: Assistant(engine),
        repo: repo,
        history: history,
        settings: settings,
      );

      await ctrl
          .submit('ماده ۱۰ قانون مدنی')
          .timeout(const Duration(seconds: 5));
      expect(ctrl.busy, isFalse);
      expect(ctrl.messages.length, 2);
      expect(ctrl.messages.first.fromUser, isTrue);
      expect(ctrl.messages.last.text, contains('قراردادهای خصوصی'));
      expect(history.sessions.length, 1);

      ctrl.dispose();
    });

    test('لغو پاسخ در میانهٔ استریم مدل را متوقف و رویدادهای کهنه را مسدود می‌کند', () async {
      final llm = _ControllableLlm();
      final settings = AppSettings()..saveHistory = false;
      final ctrl = ChatController(
        engine: engine,
        assistant: Assistant(
          engine,
          llm: llm,
          stallTimeout: const Duration(seconds: 2),
        ),
        repo: TemplateRepository(),
        history: HistoryStore(),
        settings: settings,
      );

      final future = ctrl.submit('ماده ۱۰ قانون مدنی');
      await llm.waitUntilStarted();
      expect(ctrl.busy, isTrue);

      llm.emit('طبق ماده ۱۰ ');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(ctrl.messages.last.text, 'طبق ماده ۱۰ ');

      ctrl.cancelActiveAsk();
      expect(ctrl.busy, isFalse);
      expect(llm.cancelled, isTrue);

      await future.timeout(const Duration(seconds: 5));
      expect(ctrl.messages.last.text, 'طبق ماده ۱۰ ');
      ctrl.dispose();
    });

    test('dispose در میانهٔ استریم، مدل را لغو می‌کند و خطا نمی‌اندازد', () async {
      final llm = _ControllableLlm();
      final ctrl = ChatController(
        engine: engine,
        assistant: Assistant(
          engine,
          llm: llm,
          stallTimeout: const Duration(seconds: 2),
        ),
        repo: TemplateRepository(),
        history: HistoryStore(),
        settings: AppSettings()..saveHistory = false,
      );

      final future = ctrl.submit('ماده ۱۰ قانون مدنی');
      await llm.waitUntilStarted();
      expect(ctrl.busy, isTrue);

      expect(ctrl.dispose, returnsNormally);
      expect(llm.cancelled, isTrue);
      await future.timeout(const Duration(seconds: 5));
    });

    testWidgets('دکمهٔ توقف پاسخ در حین استریم نمایش داده می‌شود و کار می‌کند',
        (tester) async {
      final llm = _ControllableLlm();
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: ChatPage(
              engine: engine,
              assistant: Assistant(
                engine,
                llm: llm,
                stallTimeout: const Duration(seconds: 2),
              ),
              repo: TemplateRepository(),
              history: HistoryStore(),
              settings: AppSettings()..saveHistory = false,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'ماده ۱۰ قانون مدنی');
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      await tester.pump();

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();

      expect(llm.cancelled, isTrue);
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      expect(find.text('پاسخ متوقف شد.'), findsOneWidget);
    });
  });
}
