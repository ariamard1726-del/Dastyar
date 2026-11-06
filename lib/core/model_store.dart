/// مدیریت نصب اختیاری مدل زبانی روی گوشی: دانلود با امکان ادامه، واردکردن
/// از فایل، بررسی سلامت (اندازه، امضای GGUF و SHA-256) و حذف.
///
/// هیچ چیزی بدون درخواست صریح کاربر دانلود نمی‌شود و برنامه بدون مدل هم
/// کامل کار می‌کند.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/model_catalog.dart';

/// کارهای وابسته به سیستم‌عامل (پیاده‌سازی واقعی در MainActivity.kt).
abstract class ModelPlatform {
  Future<String?> modelsDir();
  Future<String?> sha256(String path);

  /// پنجرهٔ انتخاب فایل سیستم را باز می‌کند و فایل انتخاب‌شده را در [destPath]
  /// کپی می‌کند؛ نام اصلی فایل را برمی‌گرداند (اگر کاربر انصراف دهد `null`).
  Future<String?> importFile(String destPath);

  /// حافظهٔ کل گوشی به مگابایت (یا `null` اگر معلوم نباشد).
  Future<int?> totalRamMb();

  /// آیا معماری پردازندهٔ گوشی برای موتور مدل پشتیبانی می‌شود (arm64).
  Future<bool> supportedAbi();
}

class ChannelModelPlatform implements ModelPlatform {
  static const MethodChannel _ch = MethodChannel('com.ariabod.dastyar/model');
  const ChannelModelPlatform();

  Future<T?> _call<T>(String m, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(m, args);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<String?> modelsDir() => _call<String>('modelsDir');
  @override
  Future<String?> sha256(String path) => _call<String>('sha256', {'path': path});
  @override
  Future<String?> importFile(String destPath) =>
      _call<String>('importFile', {'dest': destPath});
  @override
  Future<int?> totalRamMb() => _call<int>('totalRamMb');
  @override
  Future<bool> supportedAbi() async =>
      (await _call<bool>('supportedAbi')) ?? false;
}

enum ModelInstallPhase { idle, downloading, verifying, importing, ready, failed }

class ModelStore extends ChangeNotifier {
  static const _kId = 'llm_model_id';
  static const _kPath = 'llm_model_path';
  static const _kTemplate = 'llm_model_template';

  final ModelPlatform platform;
  final HttpClient Function() _httpFactory;

  ModelStore({
    this.platform = const ChannelModelPlatform(),
    HttpClient Function()? httpFactory,
  }) : _httpFactory = httpFactory ?? HttpClient.new;

  String? installedId;
  String? installedPath;
  String installedTemplate = 'gemma3';

  ModelInstallPhase phase = ModelInstallPhase.idle;

  /// شناسهٔ مدلی که در حال دانلود/بررسی است.
  String? busyId;
  int received = 0;
  int total = 0;
  String? error;
  bool _cancel = false;
  HttpClient? _client;

  double? get progress => total > 0 ? received / total : null;
  bool get isInstalled => installedPath != null;
  bool get isBusy =>
      phase == ModelInstallPhase.downloading ||
      phase == ModelInstallPhase.verifying ||
      phase == ModelInstallPhase.importing;

  String get installedTitle {
    if (installedId == ModelCatalog.importedId) return 'مدل واردشده از فایل';
    return ModelCatalog.byId(installedId)?.title ?? '';
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    installedId = p.getString(_kId);
    installedPath = p.getString(_kPath);
    installedTemplate = p.getString(_kTemplate) ?? 'gemma3';
    final path = installedPath;
    if (path != null && !File(path).existsSync()) {
      await _forget();
    }
    notifyListeners();
  }

  Future<void> _remember(String id, String path, String template) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kId, id);
    await p.setString(_kPath, path);
    await p.setString(_kTemplate, template);
    installedId = id;
    installedPath = path;
    installedTemplate = template;
  }

  Future<void> _forget() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kId);
    await p.remove(_kPath);
    await p.remove(_kTemplate);
    installedId = null;
    installedPath = null;
  }

  void _fail(String msg) {
    phase = ModelInstallPhase.failed;
    error = msg;
    busyId = null;
    notifyListeners();
  }

  Future<String?> _dir() async {
    final d = await platform.modelsDir();
    if (d == null) return null;
    Directory(d).createSync(recursive: true);
    return d;
  }

  /// چهار بایت اول فایل GGUF همیشه «GGUF» است.
  static bool looksLikeGguf(String path) {
    try {
      final raf = File(path).openSync();
      try {
        final b = raf.readSync(4);
        return b.length == 4 &&
            b[0] == 0x47 &&
            b[1] == 0x47 &&
            b[2] == 0x55 &&
            b[3] == 0x46;
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      return false;
    }
  }

  /// دانلود مدل از فهرست؛ اگر نیمه‌کاره مانده باشد از همان‌جا ادامه می‌یابد.
  Future<bool> download(ModelSpec spec) async {
    if (isBusy) return false;
    final dir = await _dir();
    if (dir == null) {
      _fail('دسترسی به حافظهٔ برنامه ممکن نشد.');
      return false;
    }
    _cancel = false;
    error = null;
    busyId = spec.id;
    phase = ModelInstallPhase.downloading;
    total = spec.sizeBytes;
    final part = File('$dir/${spec.fileName}.part');
    final dest = File('$dir/${spec.fileName}');
    received = part.existsSync() ? part.lengthSync() : 0;
    notifyListeners();

    final client = _httpFactory()..connectionTimeout = const Duration(seconds: 30);
    _client = client;
    IOSink? sink;
    try {
      if (received < spec.sizeBytes) {
        final req = await client.getUrl(Uri.parse(spec.url));
        if (received > 0) req.headers.set(HttpHeaders.rangeHeader, 'bytes=$received-');
        final res = await req.close();
        if (res.statusCode == 200) {
          received = 0; // سرور ادامه را نپذیرفت؛ از اول.
          sink = part.openWrite();
        } else if (res.statusCode == 206) {
          sink = part.openWrite(mode: FileMode.append);
        } else {
          _fail('دانلود ممکن نشد (کد ${res.statusCode}). اتصال اینترنت را بررسی کنید یا مدل را از فایل وارد کنید.');
          return false;
        }
        var lastNotify = 0;
        await for (final chunk in res) {
          if (_cancel) break;
          sink.add(chunk);
          received += chunk.length;
          if (received - lastNotify > 1 << 20) {
            lastNotify = received;
            notifyListeners();
          }
        }
        await sink.flush();
        await sink.close();
        sink = null;
        if (_cancel) {
          phase = ModelInstallPhase.idle;
          busyId = null;
          notifyListeners();
          return false;
        }
      }
      return await _verifyAndInstall(spec, part, dest);
    } catch (_) {
      await sink?.close();
      if (_cancel) {
        phase = ModelInstallPhase.idle;
        busyId = null;
        notifyListeners();
        return false;
      }
      _fail('اتصال قطع شد. دوباره «دانلود» را بزنید تا از همان‌جا ادامه یابد.');
      return false;
    } finally {
      client.close(force: true);
      _client = null;
    }
  }

  Future<bool> _verifyAndInstall(ModelSpec spec, File part, File dest) async {
    phase = ModelInstallPhase.verifying;
    notifyListeners();
    final len = part.lengthSync();
    if (len != spec.sizeBytes || !looksLikeGguf(part.path)) {
      part.deleteSync();
      _fail('فایل دانلودشده کامل یا سالم نبود و حذف شد. دوباره امتحان کنید.');
      return false;
    }
    final hash = await platform.sha256(part.path);
    if (hash == null || hash.toLowerCase() != spec.sha256) {
      part.deleteSync();
      _fail('امضای فایل با نسخهٔ اصلی یکی نبود و برای امنیت حذف شد.');
      return false;
    }
    if (dest.existsSync()) dest.deleteSync();
    part.renameSync(dest.path);
    await _removeOther(keep: dest.path);
    await _remember(spec.id, dest.path, spec.chatTemplate);
    phase = ModelInstallPhase.ready;
    busyId = null;
    notifyListeners();
    return true;
  }

  /// واردکردن فایل GGUF که کاربر قبلاً (مثلاً با مرورگر) دانلود کرده است.
  /// اگر فایل یکی از مدل‌های فهرست باشد، شناسه و قالبش شناخته می‌شود.
  Future<bool> importFromFile() async {
    if (isBusy) return false;
    final dir = await _dir();
    if (dir == null) {
      _fail('دسترسی به حافظهٔ برنامه ممکن نشد.');
      return false;
    }
    error = null;
    busyId = ModelCatalog.importedId;
    phase = ModelInstallPhase.importing;
    notifyListeners();
    final path = '$dir/import.part';
    final original = await platform.importFile(path);
    if (original == null || !File(path).existsSync()) {
      phase = ModelInstallPhase.idle;
      busyId = null;
      notifyListeners();
      return false;
    }
    if (!looksLikeGguf(path)) {
      File(path).deleteSync();
      _fail('این فایل مدل GGUF نیست. فایلی با پسوند ‎.gguf‎ انتخاب کنید.');
      return false;
    }
    phase = ModelInstallPhase.verifying;
    notifyListeners();
    final hash = (await platform.sha256(path))?.toLowerCase();
    ModelSpec? known;
    for (final m in ModelCatalog.models) {
      if (m.sha256 == hash) known = m;
    }
    final dest = '$dir/${known?.fileName ?? safeFileName(original)}';
    if (File(dest).existsSync()) File(dest).deleteSync();
    File(path).renameSync(dest);
    await _removeOther(keep: dest);
    await _remember(known?.id ?? ModelCatalog.importedId, dest,
        known?.chatTemplate ?? '');
    phase = ModelInstallPhase.ready;
    busyId = null;
    notifyListeners();
    return true;
  }

  /// نام امن برای فایل واردشده؛ نام اصلی حفظ می‌شود چون موتور از روی آن
  /// قالب گفتگو (gemma، qwen، llama…) را تشخیص می‌دهد.
  static String safeFileName(String original) {
    var n = original.split('/').last.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (n.isEmpty || n == '.part') n = 'imported-model';
    if (!n.toLowerCase().endsWith('.gguf')) n = '$n.gguf';
    return n;
  }

  void cancel() {
    _cancel = true;
    _client?.close(force: true);
  }

  /// فقط یک مدل نگه داشته می‌شود تا حافظهٔ گوشی پر نشود.
  Future<void> _removeOther({required String keep}) async {
    final dir = await _dir();
    if (dir == null) return;
    for (final f in Directory(dir).listSync()) {
      if (f is File && f.path != keep && !f.path.endsWith('.part')) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  Future<void> delete() async {
    final dir = await _dir();
    if (dir != null) {
      for (final f in Directory(dir).listSync()) {
        try {
          f.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
    await _forget();
    phase = ModelInstallPhase.idle;
    notifyListeners();
  }
}
