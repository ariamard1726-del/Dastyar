import 'package:flutter_test/flutter_test.dart';

import 'package:dastyar/domain/settings_state.dart';

/// منطق تنظیمات بدون فلاتر: مقادیر معتبر، پیشفرضها و تبدیل رشتهٔ ذخیرهشده.
void main() {
  test('مقدار نامعتبر اندازهٔ نوشته به پیشفرض برمیگردد', () {
    expect(SettingsSnapshot.fromValues(fontScale: 99).fontScale, 1.0);
    expect(SettingsSnapshot.fromValues(fontScale: -1).fontScale, 1.0);
    expect(SettingsSnapshot.fromValues(fontScale: 1.2).fontScale, 1.2);
  });

  test('تنظیمات پیشفرض همان راه امناند', () {
    const s = SettingsSnapshot.defaults;
    expect(s.saveHistory, isTrue);
    expect(s.saveDraftProgress, isFalse);
    expect(s.secureScreen, isFalse);
    expect(s.themeMode, AppThemeMode.system);
  });

  test('تبدیل حالت نمایش رفتوبرگشت دارد', () {
    for (final mode in AppThemeMode.values) {
      expect(
        SettingsSnapshot.themeFromRaw(SettingsSnapshot.themeToRaw(mode)),
        mode,
      );
    }
    expect(SettingsSnapshot.themeFromRaw('pandas'), AppThemeMode.system);
  });

  test('copyWith وضعیت قبل را تغییر نمیدهد', () {
    const a = SettingsSnapshot(secureScreen: true);
    final b = a.copyWith(saveHistory: false);
    expect(a.saveHistory, isTrue);
    expect(b.secureScreen, isTrue);
    expect(b.saveHistory, isFalse);
  });
}
