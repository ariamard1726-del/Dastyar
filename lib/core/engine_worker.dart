part of 'engine.dart';

/// پاسخسازیِ موتور در یک isolate دائمی.
///
/// پیشتر تنها ساختِ ایندکس در isolate بود و پردازشِ هر پیام (`engine.query`)
/// روی رشتهٔ رابط کاربری اجرا میشد. [EngineWorker] ایندکس را یک بار در همان
/// isolate میسازد و نگه میدارد و پرسشها و تطبیق واژهها را همانجا پاسخ میدهد؛
/// رابط کاربری فقط نتیجهٔ نهایی را میگیرد. API قدیمی [KnowledgeEngine.query]
/// دستنخورده مانده است تا صدها آزمون و مسیرهای داخلی وکیل تغییر نکنند.
class EngineWorker {
  EngineWorker._(this._isolate, this._inbox, this._send, this.built);

  static const Duration patience = Duration(seconds: 8);

  final Isolate _isolate;
  final ReceivePort _inbox;
  final SendPort _send;

  /// ایندکسی که در همان isolate ساخته شد؛ رابط کاربری یک کپی از آن را میپذیرد
  /// تا متن ماده و APIهای همگام همچنان در دسترس بمانند.
  final IndexBuild built;

  final Map<int, Completer<Object?>> _waiting = {};
  int _next = 0;
  bool _closed = false;

  /// `null` یعنی isolate راهاندازی نشد؛ فراخواننده به مسیر همگام قدیمی برمیگردد.
  static Future<EngineWorker?> start(Map<String, dynamic> data) async {
    final inbox = ReceivePort();
    Isolate? isolate;
    final first = Completer<SendPort>();
    final ready = Completer<IndexBuild>();
    EngineWorker? worker;
    void handler(Object? m) {
      if (m is List && m.isNotEmpty && m.first is SendPort && !first.isCompleted) {
        first.complete(m.first as SendPort);
      } else if (m is IndexBuild && !ready.isCompleted) {
        ready.complete(m);
      } else {
        worker?._onMessage(m);
      }
    }

    inbox.listen(handler);
    try {
      isolate = await Isolate.spawn(_entry, [inbox.sendPort, data]);
      final send = await first.future.timeout(const Duration(seconds: 30));
      final built = await ready.future.timeout(const Duration(seconds: 30));
      worker = EngineWorker._(isolate, inbox, send, built);
      return worker;
    } catch (_) {
      isolate?.kill(priority: Isolate.immediate);
      inbox.close();
      return null;
    }
  }

  /// [EngineReply] آماده برای پرسش. `null` یعنی خطا یا زمانِ ازدسترفته؛
  /// یک خطای زیرساخت نباید جواب کاربر را بگیرد، مسیر همگام جایگزین میشود.
  Future<EngineReply?> query(String question) {
    if (_closed) return Future.value(null);
    final id = _next++;
    final done = Completer<Object?>();
    _waiting[id] = done;
    _send.send([id, 'q', question]);
    return done.future
        .timeout(patience, onTimeout: () {
          _waiting.remove(id);
          return null;
        })
        .then((v) => v is EngineReply ? v : null);
  }

  /// اجرای یک تابعِ سطحِ بالا یا static درون همان isolate دائمی موتور.
  /// `null` یعنی خطا یا پایان مهلت؛ فراخواننده به مسیر همگام برمیگردد.
  Future<R?> run<A, R>(R Function(KnowledgeEngine engine, A arg) fn, A arg) {
    if (_closed) return Future<R?>.value(null);
    final id = _next++;
    final done = Completer<Object?>();
    _waiting[id] = done;
    _send.send([id, 'fn', fn, arg]);
    return done.future
        .timeout(patience, onTimeout: () {
          _waiting.remove(id);
          return null;
        })
        .then((v) => v is R ? v : null);
  }

  void _onMessage(Object? m) {
    if (m is! List || m.length < 2) return;
    final done = _waiting.remove(m.first);
    if (done == null || done.isCompleted) return;
    done.complete(m[1]);
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

  static void _entry(List<Object?> args) {
    final home = args[0] as SendPort;
    final data = args[1] as Map<String, dynamic>;
    final engine = KnowledgeEngine();
    late final IndexBuild built;
    try {
      built = engine.adoptWorkerData(data);
    } catch (e) {
      home.send('error: $e');
      return;
    }
    final inbox = ReceivePort();
    home.send([inbox.sendPort]);
    home.send(built);
    inbox.listen((m) {
      if (m is! List || m.length < 3) return;
      final id = m[0];
      try {
        switch (m[1]) {
          case 'q':
            home.send([id, engine.query(m[2] as String)]);
          case 'fn':
            final fn = m[2] as Function;
            home.send([id, Function.apply(fn, [engine, m[3]])]);
          default:
            return;
        }
      } catch (_) {
        home.send([id, null]);
      }
    });
  }
}
