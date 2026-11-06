import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/model_catalog.dart';
import 'package:dastyar/core/model_store.dart';

class FakePlatform implements ModelPlatform {
  final String dir;
  String? hash;
  Uint8List? importBytes;
  String importName = 'Qwen2.5-1.5B-Instruct.gguf';
  FakePlatform(this.dir, {this.hash});

  @override
  Future<String?> modelsDir() async => dir;
  @override
  Future<String?> sha256(String path) async => hash;
  @override
  Future<String?> importFile(String destPath) async {
    final b = importBytes;
    if (b == null) return null;
    File(destPath).writeAsBytesSync(b);
    return importName;
  }

  @override
  Future<int?> totalRamMb() async => 6000;
  @override
  Future<bool> supportedAbi() async => true;
}

Uint8List fakeGguf(int n) {
  final b = Uint8List(n);
  b.setAll(0, 'GGUF'.codeUnits);
  for (var i = 4; i < n; i++) {
    b[i] = i % 251;
  }
  return b;
}

void main() {
  late Directory tmp;
  late HttpServer server;
  late Uint8List payload;
  var honorRange = true;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tmp = Directory.systemTemp.createTempSync('models');
    payload = fakeGguf(300000);
    honorRange = true;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) async {
      final range = req.headers.value(HttpHeaders.rangeHeader);
      if (range != null && honorRange) {
        final start = int.parse(range.substring(6, range.length - 1));
        req.response.statusCode = 206;
        req.response.add(payload.sublist(start));
      } else {
        req.response.add(payload);
      }
      await req.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    tmp.deleteSync(recursive: true);
  });

  ModelSpec spec({int? size}) => ModelSpec(
        id: 'gemma3_1b_q4km',
        title: 't',
        description: 'd',
        url: 'http://127.0.0.1:${server.port}/m.gguf',
        fileName: 'm.gguf',
        sizeBytes: size ?? payload.length,
        sha256: 'abc',
        chatTemplate: 'gemma3',
        minRamGb: 4,
        license: 'l',
      );

  test('دانلود، بررسی امضا و ثبت مدل نصب‌شده', () async {
    final s = ModelStore(platform: FakePlatform(tmp.path, hash: 'ABC'));
    expect(await s.download(spec()), isTrue);
    expect(s.isInstalled, isTrue);
    expect(s.phase, ModelInstallPhase.ready);
    expect(File(s.installedPath!).lengthSync(), payload.length);
    expect(s.installedTemplate, 'gemma3');

    final again = ModelStore(platform: FakePlatform(tmp.path));
    await again.load();
    expect(again.installedPath, s.installedPath);
  });

  test('ادامهٔ دانلود نیمه‌کاره با Range', () async {
    File('${tmp.path}/m.gguf.part').writeAsBytesSync(payload.sublist(0, 1000));
    final s = ModelStore(platform: FakePlatform(tmp.path, hash: 'abc'));
    expect(await s.download(spec()), isTrue);
    expect(File(s.installedPath!).readAsBytesSync(), payload);
  });

  test('سرور بدون پشتیبانی Range: دانلود از اول', () async {
    honorRange = false;
    File('${tmp.path}/m.gguf.part').writeAsBytesSync(payload.sublist(0, 1000));
    final s = ModelStore(platform: FakePlatform(tmp.path, hash: 'abc'));
    expect(await s.download(spec()), isTrue);
    expect(File(s.installedPath!).readAsBytesSync(), payload);
  });

  test('امضای نادرست: فایل حذف و خطا اعلام می‌شود', () async {
    final s = ModelStore(platform: FakePlatform(tmp.path, hash: 'zzz'));
    expect(await s.download(spec()), isFalse);
    expect(s.isInstalled, isFalse);
    expect(s.phase, ModelInstallPhase.failed);
    expect(s.error, contains('امضا'));
    expect(File('${tmp.path}/m.gguf.part').existsSync(), isFalse);
  });

  test('اندازهٔ نادرست رد می‌شود', () async {
    final s = ModelStore(platform: FakePlatform(tmp.path, hash: 'abc'));
    expect(await s.download(spec(size: payload.length + 5)), isFalse);
    expect(s.error, contains('کامل'));
  });

  test('واردکردن فایل GGUF با حفظ نام اصلی', () async {
    final p = FakePlatform(tmp.path, hash: 'unknown')
      ..importBytes = fakeGguf(5000);
    final s = ModelStore(platform: p);
    expect(await s.importFromFile(), isTrue);
    expect(s.installedId, ModelCatalog.importedId);
    expect(s.installedPath, endsWith('Qwen2.5-1.5B-Instruct.gguf'));
    expect(s.installedTemplate, '');
  });

  test('فایل غیر GGUF وارد نمی‌شود', () async {
    final p = FakePlatform(tmp.path)
      ..importBytes = Uint8List.fromList(List.filled(100, 1));
    final s = ModelStore(platform: p);
    expect(await s.importFromFile(), isFalse);
    expect(s.error, contains('GGUF'));
  });

  test('انصراف از انتخاب فایل', () async {
    final s = ModelStore(platform: FakePlatform(tmp.path));
    expect(await s.importFromFile(), isFalse);
    expect(s.phase, ModelInstallPhase.idle);
  });

  test('حذف مدل', () async {
    final s = ModelStore(platform: FakePlatform(tmp.path, hash: 'abc'));
    await s.download(spec());
    await s.delete();
    expect(s.isInstalled, isFalse);
    expect(Directory(tmp.path).listSync(), isEmpty);
  });

  test('نام امن فایل', () {
    expect(ModelStore.safeFileName('مدل من.gguf'), endsWith('.gguf'));
    expect(ModelStore.safeFileName('a/b/gemma-3.gguf'), 'gemma-3.gguf');
    expect(ModelStore.safeFileName('x'), 'x.gguf');
  });

  test('فهرست مدل‌ها: نشانی سنجاق‌شده و امضای کامل', () {
    for (final m in ModelCatalog.models) {
      expect(m.url, startsWith('https://'));
      expect(m.url, contains('/resolve/'));
      expect(m.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(m.sizeBytes, greaterThan(100000000));
    }
    expect(ModelCatalog.sizeLabel(806058240), '۸۰۶ مگابایت');
    expect(ModelCatalog.sizeLabel(2489757856), '۲٫۵ گیگابایت');
  });
}
