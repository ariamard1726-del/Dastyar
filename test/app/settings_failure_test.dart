import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/core/privacy.dart';
import 'package:dastyar/domain/settings.dart';

/// تنظیمات نباید بی‌صدا شکست بخورد.
///
/// بدترین حالت: کاربر «محافظت از صفحه» را روشن می‌کند، کانال بومی خطا می‌دهد
/// و تیک روشن می‌ماند؛ یعنی برنامه می‌گوید محافظت روشن است ولی اسکرین‌شات
/// آزاد است.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(PrivacyService.channel, null);
  });

  test('خطای کانال بومی، تیک محافظت صفحه را برنمی‌گرداند', () async {
    messenger.setMockMethodCallHandler(PrivacyService.channel, (call) async {
      if (call.method == 'setSecureScreen') {
        throw PlatformException(code: 'PRIVACY_ERR', message: 'no');
      }
      return null;
    });

    final s = await AppSettings.load();
    await s.setSecureScreen(true);

    expect(s.secureScreen, isFalse, reason: 'تیک نباید روشن بماند');
    expect(s.lastError, isNotNull);
    expect(await PrivacyService.setSecureScreen(true), isFalse);
  });

  test('در شروع program، خطای بومی تیک ذخیرهشده را خاموش میکند', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{'secureScreen': true});
    messenger.setMockMethodCallHandler(PrivacyService.channel, (call) async {
      throw PlatformException(code: 'PRIVACY_ERR', message: 'no');
    });

    final s = await AppSettings.load();
    expect(s.secureScreen, isTrue);
    await s.applySecureScreenAtStartup();
    expect(s.secureScreen, isFalse, reason: 'تیک نباید دروغ بگوید');
    expect(s.lastError, isNotNull);

    final afterRestart = await AppSettings.load();
    expect(afterRestart.secureScreen, isFalse,
        reason: 'تیک خاموششده باید ذخیره شود');
  });

  test('موفقیت، تیک را روشن می‌کند و خطایی نمی‌گذارد', () async {
    messenger.setMockMethodCallHandler(
      PrivacyService.channel,
      (call) async => call.method == 'setSecureScreen' ? true : null,
    );

    final s = await AppSettings.load();
    await s.setSecureScreen(true);

    expect(s.secureScreen, isTrue);
    expect(s.lastError, isNull);
    expect(await PrivacyService.setSecureScreen(true), isTrue);
  });

  test('خواندن تنظیمات، پیش‌فرض‌ها را نگه می‌دارد', () async {
    final s = await AppSettings.load();
    expect(s.fontScale, 1.0);
    expect(s.saveHistory, isTrue);
    expect(s.saveDraftProgress, isFalse);
    expect(s.secureScreen, isFalse);
  });

  test('خطا پس از نمایش پاک می‌شود', () async {
    messenger.setMockMethodCallHandler(PrivacyService.channel, (call) async {
      throw PlatformException(code: 'PRIVACY_ERR');
    });
    final s = await AppSettings.load();
    await s.setSecureScreen(true);
    expect(s.lastError, isNotNull);
    s.clearError();
    expect(s.lastError, isNull);
  });
}
