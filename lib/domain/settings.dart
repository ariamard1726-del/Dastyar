import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dastyar/domain/drafting.dart';
import 'package:dastyar/core/privacy.dart';

class AppSettings extends ChangeNotifier {
  double fontScale = 1.0;
  bool saveHistory = true;
  bool saveDraftProgress = false;
  bool secureScreen = false;
  ThemeMode themeMode = ThemeMode.system;
  SharedPreferences? _prefs;

  /// آخرین خطای ذخیرهٔ تنظیمات؛ صفحهٔ تنظیمات آن را به کاربر نشان می‌دهد.
  /// پیش‌تر هر خطا بی‌صدا بلعیده می‌شد و کاربر فکر می‌کرد تنظیمش ذخیره شده.
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

  static const List<double> scales = [0.9, 1.0, 1.2, 1.4];
  static const List<String> scaleNames = [
    'کوچک',
    'متوسط',
    'بزرگ',
    'خیلی بزرگ',
  ];

  static const List<ThemeMode> themeModes = [
    ThemeMode.system,
    ThemeMode.light,
    ThemeMode.dark,
  ];
  static const List<String> themeNames = [
    'هماهنگ با گوشی',
    'روشن',
    'تیره',
  ];

  static ThemeMode _parseThemeMode(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  static Future<AppSettings> load() async {
    final s = AppSettings();
    try {
      final p = await SharedPreferences.getInstance();
      s._prefs = p;
      final fs = p.getDouble('fontScale') ?? 1.0;
      s.fontScale = scales.contains(fs) ? fs : 1.0;
      s.saveHistory = p.getBool('saveHistory') ?? true;
      s.saveDraftProgress = p.getBool('saveDraftProgress') ?? false;
      s.secureScreen = p.getBool('secureScreen') ?? false;
      s.themeMode = _parseThemeMode(p.getString('themeMode'));
    } catch (_) {
      // تنظیمات پیش‌فرض می‌مانند؛ ولی کاربر باید بداند که خوانده نشد.
      s.lastError = 'خواندن تنظیمات ذخیره‌شده ناموفق بود؛ تنظیمات پیش‌فرض '
          'به کار می‌رود.';
    }
    return s;
  }

  Future<void> setFontScale(double v) async {
    fontScale = v;
    notifyListeners();
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setDouble('fontScale', v);
    } catch (_) {
      _fail('اندازهٔ نوشته');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setString('themeMode', _themeModeName(mode));
    } catch (_) {
      _fail('حالت نمایش');
    }
  }

  Future<void> setSaveHistory(bool v) async {
    saveHistory = v;
    notifyListeners();
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setBool('saveHistory', v);
    } catch (_) {
      _fail('تنظیم تاریخچه');
    }
  }

  Future<void> setSaveDraftProgress(bool v) async {
    saveDraftProgress = v;
    notifyListeners();
    if (!v) {
      await DraftCheckpointStore.clear();
    }
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setBool('saveDraftProgress', v);
    } catch (_) {
      _fail('تنظیم پیش‌نویس');
    }
  }

  /// در شروعprogram، تیک ذخیرهشده را با آنچه گوشی واقعاً اعمال میکند میسنجیم.
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
    // اسکرین‌شات آزاد، بدترین حالت است.
    final applied = await PrivacyService.setSecureScreen(v);
    if (!applied) {
      secureScreen = before;
      lastError = v
          ? 'محافظت از صفحه روی این گوشی اعمال نشد؛ تیک آن روشن نمی‌شود.'
          : 'خاموش‌کردن محافظت صفحه روی این گوشی اعمال نشد.';
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
