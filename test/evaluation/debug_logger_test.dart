import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/core/debug_logger.dart';

/// مقصد آزمایشی که همهٔ فراخوانی‌ها را ثبت می‌کند.
class _RecordingSink extends DebugSink {
  final List<String> events = <String>[];
  final List<String> turns = <String>[];

  @override
  void onEvent(TurnTrace trace, DebugEvent event) {
    events.add('${trace.id}|${event.stage.name}|${event.label}');
  }

  @override
  void onTurn(TurnTrace trace) => turns.add(trace.id);
}

/// مقصدی که عمداً خطا می‌دهد تا ثابت شود لاگ مسیر پاسخ را نمی‌شکند.
class _ThrowingSink extends DebugSink {
  const _ThrowingSink();

  @override
  void onEvent(TurnTrace trace, DebugEvent event) =>
      throw StateError('sink down');

  @override
  void onTurn(TurnTrace trace) => throw StateError('sink down');
}

void main() {
  group('DebugLogger — چرخهٔ عمر', () {
    test('پیش‌فرض خاموش است و هیچ ردی نمی‌سازد', () {
      final logger = DebugLogger();
      expect(logger.enabled, isFalse);

      final trace = logger.start('سلام');
      trace.add(TurnStage.input, 'پیام کاربر', {'text': 'سلام'});
      logger.finish(trace);

      expect(logger.traces, isEmpty);
      expect(trace.events, isEmpty);
      expect(trace.enabled, isFalse);
    });

    test('در حالت روشن، مراحل را به ترتیب ثبت می‌کند', () {
      final logger = DebugLogger(enabled: true);
      final trace = logger.start('چک برگشتی دارم');

      logger.record(trace, TurnStage.input, 'پیام کاربر', {'text': 'چک'});
      logger.record(trace, TurnStage.intent, 'نیت', {'label': 'cheque'});
      logger.record(trace, TurnStage.slots, 'اسلات‌ها', {'role': 'holder'});
      logger.record(trace, TurnStage.retrieval, 'مواد', {'count': 2});
      logger.record(trace, TurnStage.prompt, 'پرامپت', {'chars': 900});
      logger.record(trace, TurnStage.llm, 'خروجی', {'text': 'پاسخ'});
      logger.record(trace, TurnStage.guard, 'گارد', {'grounded': true});
      logger.record(trace, TurnStage.response, 'پاسخ نهایی', {'text': 'جواب'});
      logger.finish(trace);

      expect(trace.events.map((e) => e.stage).toList(), <TurnStage>[
        TurnStage.input,
        TurnStage.intent,
        TurnStage.slots,
        TurnStage.retrieval,
        TurnStage.prompt,
        TurnStage.llm,
        TurnStage.guard,
        TurnStage.response,
      ]);
      expect(trace.isClosed, isTrue);
      expect(logger.traces, hasLength(1));
      expect(trace.finalAnswer, 'جواب');
      expect(trace.lastOf(TurnStage.retrieval)?.data, {'count': 2});
    });

    test('پس از بستن نوبت رویداد تازه پذیرفته نمی‌شود', () {
      final logger = DebugLogger(enabled: true);
      final trace = logger.start('پرسش');
      logger.record(trace, TurnStage.input, 'ورودی');
      logger.finish(trace);
      logger.record(trace, TurnStage.response, 'دیررسیده');

      expect(trace.events, hasLength(1));
      expect(trace.lastOf(TurnStage.response), isNull);
    });

    test('حلقهٔ حافظه با ظرفیت محدود کار می‌کند', () {
      final logger = DebugLogger(enabled: true, capacity: 2);
      for (var i = 0; i < 5; i++) {
        final trace = logger.start('پیام $i');
        logger.record(trace, TurnStage.input, 'ورودی');
        logger.finish(trace);
      }
      expect(logger.traces, hasLength(2));
      expect(logger.traces.first.input, 'پیام 3');
      expect(logger.last?.input, 'پیام 4');
    });

    test('مسیر انتخاب‌شده از رویداد نیت خوانده می‌شود', () {
      final logger = DebugLogger(enabled: true);
      final trace = logger.start('مجازات صدور چک بلامحل چیست؟');
      logger.record(trace, TurnStage.intent, 'مسیر انتخاب‌شده', {'route': 'rag'});
      logger.finish(trace);
      expect(trace.route, 'rag');
    });
  });

  group('DebugLogger — حریم خصوصی و خروجی', () {
    test('redact شمارهٔ تلفن، ایمیل و اعداد بلند را ماسک می‌کند', () {
      const raw = 'تماس: 09121234567 یا a.user@example.com کد ملی 0012345678';
      final masked = DebugLogger.redact(raw);

      expect(masked, isNot(contains('09121234567')));
      expect(masked, isNot(contains('a.user@example.com')));
      expect(masked, isNot(contains('0012345678')));
      expect(masked, contains('«تلفن»'));
      expect(masked, contains('«ایمیل»'));
      expect(masked, contains('«عدد»'));
    });

    test('ماسک‌کردن ورودی در start با redactInput', () {
      final logger = DebugLogger(enabled: true, redactInput: true);
      final trace = logger.start('شماره‌ام 09121234567 است');
      logger.finish(trace);
      expect(trace.input, isNot(contains('09121234567')));
    });

    test('exportJson قابل تجزیه و شامل مراحل است', () {
      final logger = DebugLogger(enabled: true);
      final trace = logger.start('وکالت چیست؟');
      logger.record(trace, TurnStage.input, 'پیام کاربر', {'text': 'وکالت چیست؟'});
      logger.record(trace, TurnStage.response, 'پاسخ نهایی', {'text': 'پاسخ'});
      logger.finish(trace);

      final decoded = jsonDecode(logger.exportJson()) as Map<String, dynamic>;
      final turns = decoded['turns'] as List;
      expect(turns, hasLength(1));
      final events = (turns.first as Map)['events'] as List;
      expect(events, hasLength(2));
      expect((events.first as Map)['stage'], 'input');
      expect(logger.exportText(), contains('turn-1'));
    });

    test('clear همهٔ ردها را پاک می‌کند', () {
      final logger = DebugLogger(enabled: true);
      final trace = logger.start('پیام');
      logger.finish(trace);
      expect(logger.traces, isNotEmpty);
      logger.clear();
      expect(logger.traces, isEmpty);
    });
  });

  group('DebugLogger — مقصدها (sinks)', () {
    test('مقصد رویداد و پایان نوبت را دریافت می‌کند', () {
      final sink = _RecordingSink();
      final logger = DebugLogger(enabled: true, sinks: <DebugSink>[sink]);
      final trace = logger.start('سلام');
      logger.record(trace, TurnStage.input, 'ورودی');
      logger.finish(trace);

      expect(sink.events, hasLength(1));
      expect(sink.turns, <String>['turn-1']);
    });

    test('خطای مقصد، مسیر پاسخ‌دهی را نمی‌شکند', () {
      final logger = DebugLogger(
        enabled: true,
        sinks: const <DebugSink>[_ThrowingSink()],
      );
      final trace = logger.start('سلام');
      expect(
        () {
          logger.record(trace, TurnStage.input, 'ورودی');
          logger.finish(trace);
        },
        returnsNormally,
      );
      expect(trace.events, hasLength(1));
    });
  });
}
