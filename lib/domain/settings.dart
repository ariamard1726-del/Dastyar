import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/domain/settings_state.dart';
import 'package:dastyar/core/privacy.dart';

/// لایهٔ رابط برای [SettingsSnapshot]: فقط اعلان تغییر و خواندن/نوشتن دیسک.
/// تمام قواعد مقادیر معتبر و تبدیلها در `settings_state.dart` مستقل از فلاتراند.
class AppSettings extends ChangeNotifier {
  SettingsSnapshot _state = const SettingsSnapshot();

  /// وضعیت خالص، برای آزمونها و هر مصرفکنندهٔ غیرفلاتری.
  SettingsSnapshot get snapshot => _state;

  double get fontScale => _state.fontScale;
  set fontScale(double v) => _state = _state.copyWith(fontScale: v);

  bool get saveHistory => _state.saveHistory;
  set saveHistory(bool v) => _state = _state.copyWith(saveHistory: v);

  bool get saveDraftProgress => _state.saveDraftProgress;
  set saveDraftProgress(bool v) =>
      _state = _state.copyWith(saveDraftProgress: v);

  bool get secureScreen => _state.secureScreen;
  set secureScreen(bool v) => _state = _state.copyWith(secureScreen: v);

  ThemeMode get themeMode => _flutterTheme(_state.themeMode);
  set themeMode(ThemeMode v) => _state = _state.copyWith(themeMode: _pureTheme(v));

  static ThemeMode _flutterTheme(AppThemeMode mode) => switch (mode) {
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
        AppThemeMode.system => ThemeMode.system,
      };

  static AppThemeMode _pureTheme(ThemeMode mode) => switch (mode) {
        ThemeMode.light => AppThemeMode.light,
        ThemeMode.dark => AppThemeMode.dark,
        ThemeMode.system => AppThemeMode.system,
      };

  SharedPreferences? _prefs;

  /// آخرین خطای ذخیرهٔ تنظیمات؛ صفحهٔ تنظیمات آن را به کاربر نشان میدهد.
  /// پیشتر هر خطا بیصدا بلعیده میشد و کاربر فکر میکرد تنظیمش ذخیره شده.
  String? lastError;

  void _fail(String what) {
    lastError = 'ذخیرهٔ $what ناموفق بود؛ این تنظیم ممکن است پس از بستن '
        'برنامه باقی نماند.';
    notifyListeners();
  }

  void clearError() {
    if (lastError == null) return;
    lastError = null;
    notifyListeners();
  }

  static const List<double> scales = SettingsSnapshot.scales;
  static const List<String> scaleNames = SettingsSnapshot.scaleNames;
  static const List<ThemeMode> themeModes = [
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];
  static const List<String> themeNames = SettingsSnapshot.themeNames;

  static Future<AppSettings> load() async {
    final s = AppSettings();
    try {
      final p = await SharedPreferences.getInstance();
      s._prefs = p;
      s._state = SettingsSnapshot.fromValues(
        fontScale: p.getDouble('fontScale'),
        saveHistory: p.getBool('saveHistory'),
        saveDraftProgress: p.getBool('saveDraftProgress'),
        secureScreen: p.getBool('secureScreen'),
        themeMode: p.getString('themeMode'),
      );
    } catch (_) {
      // تنظیمات پیشفرض میمانند؛ ولی کاربر باید بداند که خوانده نشد.
      s.lastError = 'خواندن تنظیمات ذخیرهشده ناموفق بود؛ تنظیمات پیشفرض '
          'به کار میرود.';
    }
    return s;
  }

  Future<void> _save(String key, Future<bool> Function(SharedPreferences p) write,
      String label) async {
    notifyListeners();
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await write(p);
    } catch (_) {
      _fail(label);
    }
  }

  Future<void> setFontScale(double v) async {
    _state = _state.copyWith(fontScale: v);
    await _save('fontScale', (p) => p.setDouble('fontScale', v), 'اندازهٔ نوشته');
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _state = _state.copyWith(themeMode: _pureTheme(mode));
    final raw = SettingsSnapshot.themeToRaw(_state.themeMode);
    await _save('themeMode', (p) => p.setString('themeMode', raw), 'حالت نمایش');
  }

  Future<void> setSaveHistory(bool v) async {
    _state = _state.copyWith(saveHistory: v);
    await _save('saveHistory', (p) => p.setBool('saveHistory', v),
        'تنظیم تاریخچه');
  }

  Future<void> setSaveDraftProgress(bool v) async {
    _state = _state.copyWith(saveDraftProgress: v);
    if (!v) {
      await DraftCheckpointStore.clear();
    }
    await _save('saveDraftProgress', (p) => p.setBool('saveDraftProgress', v),
        'تنظیم پیشنویس');
  }

  /// در شروع برنامه، تیک ذخیرهشده را با آنچه گوشی واقعاً اعمال میکند میسنجیم.
  /// پیشتر `main` نتیجهٔ کانال بومی را نادیده میگرفت و تیک روشن میماند در حالی
  /// که اسکرینشات آزاد بود.
  Future<void> applySecureScreenAtStartup() async {
    if (!secureScreen) return;
    final applied = await PrivacyService.setSecureScreen(true);
    if (applied) return;
    secureScreen = false;
    lastError = 'محافظت از صفحه روی این گوشی اعمال نشد؛ تیک آن خاموش شد.';
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setBool('secureScreen', false);
    } catch (_) {
      // پیامِ خطا حتی اگر نوشتن prefs هم شکست خورد، دیده میشود.
    }
    notifyListeners();
  }

  Future<void> setSecureScreen(bool v) async {
    final before = secureScreen;
    secureScreen = v;
    notifyListeners();
    // اگر گوشی اعمالش نکرد، تیک نباید روشن بماند: «محافظت روشن» ولی
    // اسکرینشات آزاد، بدترین حالت است.
    final applied = await PrivacyService.setSecureScreen(v);
    if (!applied) {
      secureScreen = before;
      lastError = v
          ? 'محافظت از صفحه روی این گوشی اعمال نشد؛ تیک آن روشن نمیشود.'
          : 'خاموشکردن محافظت صفحه روی این گوشی اعمال نشد.';
      notifyListeners();
      return;
    }
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setBool('secureScreen', v);
    } catch (_) {
      _fail('تنظیم محافظت صفحه');
    }
  }
}
