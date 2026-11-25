import 'dart:async';
import 'dart:isolate';

import 'package:flutter/services.dart' show rootBundle;

import 'package:dastyar/domain/understanding/topic_guess.dart';
import 'package:dastyar/domain/understanding/topic_reader.dart';

/// خوانندهٔ موضوع را در یک رشتهٔ جدا اجرا می‌کند تا صفحه هنگام محاسبه
/// (روی گوشی حدود یک ثانیه یا بیشتر) قفل نشود.
///
/// هر خطایی (نبودِ فایل مدل، کمبود حافظه، زمانِ زیاد) فقط به این معناست که
/// حدسی در کار نیست و وکیل مثل قبل با قاعده‌های خودش جواب می‌دهد.
class ReaderService {
  ReaderService._(
      this._isolate, this._inbox, this._send, this.revision, this.loadMillis);

  static const String weightsAsset = 'assets/brain/noql.bin';
  static const String vocabAsset = 'assets/brain/noql_vocab.json';
  static const String headAsset = 'assets/brain/noql_head.json';

  /// بیشترین زمانی که برای یک حدس صبر می‌شود.
  static const Duration patience = Duration(seconds: 12);

  final Isolate _isolate;
  final ReceivePort _inbox;
  final SendPort _send;

  /// نسخهٔ مدل در مخزن سازنده‌اش.
  final String revision;

  /// زمان آماده‌شدن مدل روی همین دستگاه.
  final int loadMillis;

  /// آخرین حدس (برای نمایش زمان و اطمینان در صفحهٔ «درباره»).
  TopicGuess? last;

  final Map<int, Completer<TopicGuess?>> _waiting = {};
  int _next = 0;
  bool _closed = false;

  /// مدل را بار می‌کند؛ اگر نشد `null` می‌دهد.
  static Future<ReaderService?> start() async {
    Isolate? isolate;
    final inbox = ReceivePort();
    try {
      final weights = await rootBundle.load(weightsAsset);
      final vocab = await rootBundle.loadString(vocabAsset, cache: false);
      final head = await rootBundle.loadString(headAsset, cache: false);
      final first = Completer<Object?>();
      void Function(Object?) handler = (m) {
        if (!first.isCompleted) first.complete(m);
      };
      inbox.listen((m) => handler(m));
      isolate = await Isolate.spawn(
        _worker,
        [
          inbox.sendPort,
          TransferableTypedData.fromList([
            weights.buffer
                .asUint8List(weights.offsetInBytes, weights.lengthInBytes),
          ]),
          vocab,
          head,
        ],
        errorsAreFatal: false,
      );
      // وزنها در TransferableTypedData به isolate منتقل شدند؛ نگه داشتن
      // یک کپی ۱۲ مگابایتی در کش rootBundle فقط اوج حافظه را بالا میبرد.
      try {
        await rootBundle.evict(weightsAsset);
      } catch (_) {}
      final hello = await first.future.timeout(const Duration(seconds: 60));
      if (hello is! List || hello.length < 3 || hello[0] is! SendPort) {
        throw StateError('reader did not start: $hello');
      }
      final service = ReaderService._(
        isolate,
        inbox,
        hello[0] as SendPort,
        hello[1] as String,
        hello[2] as int,
      );
      handler = service._onMessage;
      return service;
    } catch (_) {
      isolate?.kill(priority: Isolate.immediate);
      inbox.close();
      return null;
    }
  }

  /// حدس موضوع برای [text]؛ `null` یعنی حدسی نیست.
  Future<TopicGuess?> read(String text) {
    if (_closed) return Future.value();
    final id = _next++;
    final done = Completer<TopicGuess?>();
    _waiting[id] = done;
    _send.send([id, text]);
    return done.future.timeout(patience, onTimeout: () {
      _waiting.remove(id);
      return null;
    });
  }

  void _onMessage(Object? m) {
    if (m is! List || m.isEmpty) return;
    final done = _waiting.remove(m[0]);
    if (done == null || done.isCompleted) return;
    if (m.length < 9) {
      done.complete(null);
      return;
    }
    final g = TopicGuess(
      m[1] as String,
      m[2] as double,
      m[3] as String,
      m[4] as double,
      confident: m[5] as bool,
      plausible: m[6] as bool,
      millis: m[7] as int,
      tokens: m[8] as int,
    );
    last = g;
    done.complete(g);
  }

  void dispose() {
    if (_closed) return;
    _closed = true;
    _isolate.kill(priority: Isolate.immediate);
    _inbox.close();
    for (final c in _waiting.values) {
      if (!c.isCompleted) c.complete(null);
    }
    _waiting.clear();
  }

  static void _worker(List<Object?> args) {
    final home = args[0] as SendPort;
    final TopicReader reader;
    final watch = Stopwatch()..start();
    try {
      final bytes =
          (args[1] as TransferableTypedData).materialize().asUint8List();
      reader = TopicReader.fromAssets(
          bytes, args[2] as String, args[3] as String);
    } catch (e) {
      home.send('error: $e');
      return;
    }
    final inbox = ReceivePort();
    home.send([
      inbox.sendPort,
      reader.revision,
      watch.elapsedMilliseconds,
    ]);
    inbox.listen((m) {
      if (m is! List || m.length < 2) return;
      try {
        final g = reader.read(m[1] as String);
        home.send([
          m[0],
          g.label,
          g.score,
          g.second,
          g.secondScore,
          g.confident,
          g.plausible,
          g.millis,
          g.tokens,
        ]);
      } catch (_) {
        home.send([m[0]]);
      }
    });
  }
}
