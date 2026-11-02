import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// تنظیمات تولید پاسخ؛ هر پیاده‌سازی هر چقدر را که می‌فهمد به کار می‌گیرد.
class LlmOptions {
  final int maxTokens;
  final double temperature;
  final List<String> stop;

  const LlmOptions({
    this.maxTokens = 400,
    this.temperature = 0.2,
    this.stop = const [],
  });

  Map<String, Object> toMap() => <String, Object>{
        'maxTokens': maxTokens,
        'temperature': temperature,
        'stop': stop,
      };
}

/// رابط استاندارد مدل زبانی محلی/آفلاین.
///
/// دستیار هر پاسخ مدل را با متن قانون‌ها می‌سنجد؛ اگر ماده یا قانون ساختگی بیاورد،
/// پاسخ مطمئن موتور جای آن می‌نشیند.
abstract class LlmBackend {
  String get name;

  /// آیا مدل بارگذاری شده و آمادهٔ پاسخ است؟
  Future<bool> isReady();

  /// بارگذاری مدل (اختیاری؛ پیش‌فرض کاری نمی‌کند).
  Future<void> load() async {}

  /// پاسخ را تکه‌تکه (به‌صورت جریان) برمی‌گرداند.
  Stream<String> generate(
    String prompt, {
    LlmOptions options = const LlmOptions(),
  });

  /// تولید جاری را متوقف می‌کند (اختیاری).
  void cancel() {}

  /// حافظهٔ مدل را آزاد می‌کند (اختیاری).
  Future<void> dispose() async {}
}

/// حالت پیش‌فرض بدون مدل زبانی (پاسخ قطعی مبتنی بر بازیابی متن رسمی قانون).
class NoLlm extends LlmBackend {
  @override
  String get name => 'none';

  @override
  Future<bool> isReady() async => false;

  @override
  Stream<String> generate(
    String prompt, {
    LlmOptions options = const LlmOptions(),
  }) =>
      const Stream<String>.empty();
}

/// بک‌اند مدل زبانی روی دستگاه از طریق کانال بومی اندروید (MethodChannel / EventChannel).
///
/// اگر موتور بومی (مانند llama.cpp / MediaPipe) و فایل مدل روی دستگاه نصب شده باشد،
/// توکن‌ها را به‌صورت استریم دریافت می‌کند و در غیر این صورت بدون خطا `isReady = false` برمی‌گرداند.
class OnDeviceChannelLlm extends LlmBackend {
  final MethodChannel methodChannel;
  final EventChannel streamChannel;

  OnDeviceChannelLlm({
    this.methodChannel = const MethodChannel('com.ariabod.dastyar/llm'),
    this.streamChannel = const EventChannel('com.ariabod.dastyar/llm_stream'),
  });

  @override
  String get name => 'on-device-channel';

  @override
  Future<bool> isReady() async {
    try {
      final ready = await methodChannel.invokeMethod<bool>('isReady');
      return ready == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> load() async {
    try {
      await methodChannel.invokeMethod<void>('load');
    } catch (_) {}
  }

  @override
  Stream<String> generate(
    String prompt, {
    LlmOptions options = const LlmOptions(),
  }) {
    return streamChannel
        .receiveBroadcastStream(<String, Object>{
          'prompt': prompt,
          ...options.toMap(),
        })
        .map((event) => event?.toString() ?? '')
        .where((token) => token.isNotEmpty);
  }

  @override
  void cancel() {
    unawaited(
      methodChannel.invokeMethod<void>('cancel').catchError((_) {}),
    );
  }

  @override
  Future<void> dispose() async {
    try {
      await methodChannel.invokeMethod<void>('dispose');
    } catch (_) {}
  }
}

/// بک‌اند مدل زبانی محلی روی حلقهٔ بازگشتی همین دستگاه (`127.0.0.1` / `::1` / `localhost`).
///
/// برای حفظ تضمین «کاملاً آفلاین»، هر نشانی غیر از Loopback در همان لحظهٔ ساخت رد می‌شود
/// تا هیچ داده‌ای هرگز از دستگاه خارج نشود. از قالب استریم SSE استاندارد (`/v1/chat/completions`)
/// و NDJSON محلی (`/api/generate` مانند Ollama / llama-server در Termux) پشتیبانی می‌کند.
class LocalLoopbackLlm extends LlmBackend {
  final Uri endpoint;
  final String model;
  final Duration connectTimeout;
  HttpClient? _client;

  LocalLoopbackLlm({
    Uri? endpoint,
    this.model = 'local',
    this.connectTimeout = const Duration(milliseconds: 1200),
  }) : endpoint = endpoint ??
            Uri.parse('http://127.0.0.1:8080/v1/chat/completions') {
    if (!isLoopbackUri(this.endpoint)) {
      throw ArgumentError.value(
        this.endpoint.toString(),
        'endpoint',
        'فقط نشانی‌های حلقهٔ محلی (127.0.0.1 / ::1 / localhost) مجاز است تا داده از دستگاه خارج نشود.',
      );
    }
  }

  static bool isLoopbackHost(String host) {
    final h = host.trim().toLowerCase();
    return h == '127.0.0.1' || h == 'localhost' || h == '::1' || h == '[::1]';
  }

  static bool isLoopbackUri(Uri uri) {
    if (uri.scheme != 'http' && uri.scheme != 'https') return false;
    return isLoopbackHost(uri.host);
  }

  /// استخراج قطعهٔ متنی از یک خط استریم SSE یا NDJSON.
  static String? extractTokenFromLine(String rawLine) {
    final line = rawLine.trim();
    if (line.isEmpty) return null;
    var payload = line;
    if (payload.startsWith('data:')) {
      payload = payload.substring(5).trim();
    }
    if (payload.isEmpty || payload == '[DONE]') return null;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) return null;
      // قالب OpenAI / llama.cpp: choices[0].delta.content یا choices[0].text
      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map<String, dynamic>) {
          final delta = first['delta'];
          if (delta is Map<String, dynamic>) {
            final content = delta['content'];
            if (content is String && content.isNotEmpty) return content;
          }
          final text = first['text'];
          if (text is String && text.isNotEmpty) return text;
        }
      }
      // قالب Ollama NDJSON: {"response": "..."} یا {"message": {"content": "..."}}
      final resp = decoded['response'];
      if (resp is String && resp.isNotEmpty) return resp;
      final msg = decoded['message'];
      if (msg is Map<String, dynamic>) {
        final content = msg['content'];
        if (content is String && content.isNotEmpty) return content;
      }
      // قالب سادهٔ llama.cpp `/completion`: {"content": "..."}
      final direct = decoded['content'];
      if (direct is String && direct.isNotEmpty) return direct;
    } catch (_) {}
    return null;
  }

  @override
  String get name => 'local-loopback';

  @override
  Future<bool> isReady() async {
    try {
      final port = endpoint.hasPort
          ? endpoint.port
          : (endpoint.scheme == 'https' ? 443 : 80);
      final socket = await Socket.connect(
        endpoint.host,
        port,
        timeout: connectTimeout,
      );
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Stream<String> generate(
    String prompt, {
    LlmOptions options = const LlmOptions(),
  }) async* {
    cancel();
    final client = HttpClient()..connectionTimeout = connectTimeout;
    _client = client;
    try {
      final req = await client.postUrl(endpoint);
      req.headers.contentType = ContentType.json;
      final isOllama = endpoint.path.contains('/api/generate');
      final body = isOllama
          ? <String, Object>{
              'model': model,
              'prompt': prompt,
              'stream': true,
              'options': <String, Object>{
                'num_predict': options.maxTokens,
                'temperature': options.temperature,
                if (options.stop.isNotEmpty) 'stop': options.stop,
              },
            }
          : <String, Object>{
              'model': model,
              'stream': true,
              'max_tokens': options.maxTokens,
              'temperature': options.temperature,
              if (options.stop.isNotEmpty) 'stop': options.stop,
              'messages': <Map<String, String>>[
                <String, String>{'role': 'user', 'content': prompt},
              ],
            };
      req.add(utf8.encode(jsonEncode(body)));
      final res = await req.close();
      if (res.statusCode < 200 || res.statusCode >= 300) return;

      await for (final line
          in res.transform(utf8.decoder).transform(const LineSplitter())) {
        final token = extractTokenFromLine(line);
        if (token != null && token.isNotEmpty) {
          yield token;
        }
      }
    } catch (_) {
      // قطع ارتباط یا لغو توسط کاربر؛ Assistant به پاسخ قطعی موتور برمی‌گردد
    } finally {
      if (identical(_client, client)) {
        _client?.close(force: true);
        _client = null;
      } else {
        client.close(force: true);
      }
    }
  }

  @override
  void cancel() {
    _client?.close(force: true);
    _client = null;
  }

  @override
  Future<void> dispose() async {
    cancel();
  }
}

/// انتخابگر تطبیقی مدل زبانی محلی با بازگشت خودکار به حالت بدون مدل.
class AdaptiveLlm extends LlmBackend {
  final List<LlmBackend> candidates;
  final bool Function() isEnabled;
  LlmBackend? _active;

  AdaptiveLlm({
    required this.candidates,
    required this.isEnabled,
  });

  @override
  String get name => _active?.name ?? 'adaptive-local';

  @override
  Future<bool> isReady() async {
    if (!isEnabled()) {
      _active = null;
      return false;
    }
    for (final c in candidates) {
      try {
        if (await c.isReady()) {
          _active = c;
          return true;
        }
      } catch (_) {}
    }
    _active = null;
    return false;
  }

  @override
  Stream<String> generate(
    String prompt, {
    LlmOptions options = const LlmOptions(),
  }) {
    final target = _active;
    if (!isEnabled() || target == null) return const Stream<String>.empty();
    return target.generate(prompt, options: options);
  }

  @override
  void cancel() {
    _active?.cancel();
  }

  @override
  Future<void> dispose() async {
    for (final c in candidates) {
      await c.dispose();
    }
    _active = null;
  }
}
