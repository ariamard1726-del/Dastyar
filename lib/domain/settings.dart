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
    } catch (_) {}
    return s;
  }

  Future<void> setFontScale(double v) async {
    fontScale = v;
    notifyListeners();
    try {
      await _prefs?.setDouble('fontScale', v);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setString('themeMode', _themeModeName(mode));
    } catch (_) {}
  }

  Future<void> setSaveHistory(bool v) async {
    saveHistory = v;
    notifyListeners();
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setBool('saveHistory', v);
    } catch (_) {}
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
    } catch (_) {}
  }

  Future<void> setSecureScreen(bool v) async {
    secureScreen = v;
    notifyListeners();
    await PrivacyService.setSecureScreen(v);
    try {
      final p = _prefs ??= await SharedPreferences.getInstance();
      await p.setBool('secureScreen', v);
    } catch (_) {}
  }
}
