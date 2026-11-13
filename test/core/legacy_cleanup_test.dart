import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/legacy_cleanup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.ariabod.dastyar/model');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  group('پاک‌سازی ردّ مدل زبانی و مشاورهٔ قدیمی', () {
    test('پوشهٔ مدل پاک و کلیدهای کهنه حذف می‌شوند؛ بقیهٔ تنظیمات می‌ماند',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'llm_model_id': 'gemma',
        'llm_model_path': '/data/user/0/app/files/models/gemma.gguf',
        'llm_model_template': 'gemma3',
        'useLocalLlm': true,
        'active_counsel_v1': 'enc1:xxxx',
        'active_draft_v1': 'enc1:yyyy',
        'saveHistory': true,
      });
      final calls = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call.method);
        return true;
      });

      expect(await LegacyCleanup.run(), isTrue);
      expect(calls, ['purgeModels']);
      final p = await SharedPreferences.getInstance();
      for (final k in LegacyCleanup.staleKeys) {
        expect(p.containsKey(k), isFalse, reason: k);
      }
      expect(p.getString('active_draft_v1'), 'enc1:yyyy');
      expect(p.getBool('saveHistory'), isTrue);
      expect(p.getBool(LegacyCleanup.doneKey), isTrue);

      // بار دوم دیگر سراغ فایل‌ها نمی‌رود.
      expect(await LegacyCleanup.run(), isTrue);
      expect(calls.length, 1);
    });

    test('اگر پاک‌کردن فایل شکست بخورد، بار بعد دوباره تلاش می‌شود', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'useLocalLlm': true,
      });
      var ok = false;
      var calls = 0;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls++;
        return ok;
      });

      expect(await LegacyCleanup.run(), isFalse);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool(LegacyCleanup.doneKey), isNull);

      ok = true;
      expect(await LegacyCleanup.run(), isTrue);
      expect(calls, 2);
      expect(p.getBool(LegacyCleanup.doneKey), isTrue);
    });

    test('روی سکوی بدون این کانال، خطا نمی‌دهد و کلیدها را پاک می‌کند',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'useLocalLlm': true,
      });
      expect(await LegacyCleanup.run(), isTrue);
      final p = await SharedPreferences.getInstance();
      expect(p.containsKey('useLocalLlm'), isFalse);
    });
  });
}
