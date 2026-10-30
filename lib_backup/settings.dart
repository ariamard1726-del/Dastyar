import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  double fontScale = 1.0;
  bool saveHistory = true;
  SharedPreferences? _prefs;

  static const List<double> scales = [0.9, 1.0, 1.2, 1.4];
  static const List<String> scaleNames = [
    'کوچک',
    'متوسط',
    'بزرگ',
    'خیلی بزرگ',
  ];

  static Future<AppSettings> load() async {
    final s = AppSettings();
    try {
      final p = await SharedPreferences.getInstance();
      s._prefs = p;
      final fs = p.getDouble('fontScale') ?? 1.0;
      s.fontScale = scales.contains(fs) ? fs : 1.0;
      s.saveHistory = p.getBool('saveHistory') ?? true;
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

  Future<void> setSaveHistory(bool v) async {
    saveHistory = v;
    notifyListeners();
    try {
      await _prefs?.setBool('saveHistory', v);
    } catch (_) {}
  }
}
