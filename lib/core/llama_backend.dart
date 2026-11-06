/// اتصال موتور llama.cpp (افزونهٔ llama_flutter_android) به رابط [LlmBackend].
///
/// فقط وقتی فعال است که کاربر مدل را نصب و در تنظیمات روشن کرده باشد؛ در غیر
/// این صورت `isReady` همیشه `false` است و برنامه مسیر قطعی خودش را می‌رود.
library;

import 'dart:async';
import 'dart:io';

import 'package:llama_flutter_android/llama_flutter_android.dart' as llama;

import 'package:dastyar/core/llm.dart';
import 'package:dastyar/core/model_store.dart';

class LlamaLlm extends LlmBackend {
  final ModelStore store;
  final bool Function() enabled;

  LlamaLlm({required this.store, required this.enabled});

  llama.LlamaController? _ctl;
  String? _loadedPath;
  Future<void>? _loading;
  bool _failed = false;

  @override
  String get name => 'llama.cpp';

  bool get _possible =>
      Platform.isAndroid && enabled() && store.installedPath != null && !_failed;

  @override
  Future<bool> isReady() async {
    if (!_possible) return false;
    try {
      await load();
    } catch (_) {
      return false;
    }
    return _ctl != null && _loadedPath == store.installedPath;
  }

  @override
  Future<void> load() {
    final path = store.installedPath;
    if (path == null || !_possible) return Future.value();
    if (_loadedPath == path && _ctl != null) return Future.value();
    return _loading ??= _doLoad(path).whenComplete(() => _loading = null);
  }

  Future<void> _doLoad(String path) async {
    try {
      await _ctl?.dispose();
      final c = llama.LlamaController();
      await c.loadModel(
        modelPath: path,
        threads: 4,
        contextSize: 2048,
      );
      _ctl = c;
      _loadedPath = path;
    } catch (_) {
      // معماری ناسازگار یا حافظهٔ ناکافی: تا اجرای بعدی برنامه دوباره تلاش نکن.
      _failed = true;
      _ctl = null;
      _loadedPath = null;
    }
  }

  /// پس از تعویض یا حذف مدل.
  Future<void> reset() async {
    _failed = false;
    await dispose();
  }

  @override
  Stream<String> generate(
    String prompt, {
    LlmOptions options = const LlmOptions(),
  }) async* {
    final c = _ctl;
    if (c == null) return;
    yield* c.generateChat(
      messages: [llama.ChatMessage(role: 'user', content: prompt)],
      // قالب خالی یعنی تشخیص خودکار از نام فایل (مدل واردشده).
      template:
          store.installedTemplate.isEmpty ? null : store.installedTemplate,
      maxTokens: options.maxTokens,
      temperature: options.temperature,
      topP: 0.9,
      topK: 40,
      repeatPenalty: 1.1,
      // بذر ثابت: پاسخ یک پرسش در اجراهای مختلف یکسان می‌ماند.
      seed: 42,
      penalizeNewline: false,
    );
  }

  @override
  void cancel() {
    _ctl?.stop();
  }

  @override
  Future<void> dispose() async {
    final c = _ctl;
    _ctl = null;
    _loadedPath = null;
    await c?.dispose();
  }
}
